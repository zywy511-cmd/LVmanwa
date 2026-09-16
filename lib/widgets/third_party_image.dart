import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/third_party/third_party_source.dart';
import '../api/third_party/third_party_sources.dart';
import '../utils/app_dio.dart';

/// 第三方漫源图片的内存缓存（URL -> 解密后的字节）。
class _TpImageCache {
  _TpImageCache._();

  static const _maxEntries = 400;
  static final Map<String, Uint8List> _cache = {};

  static Uint8List? get(String key) => _cache[key];

  static void put(String key, Uint8List bytes) {
    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = bytes;
  }

  static void clear() => _cache.clear();
}

/// 第三方漫源图片加载器：
/// 带请求头下载原始字节 → 明文探测/解密 → 内存缓存 → 交给 Flutter 解码显示。
class ThirdPartyImageProvider extends ImageProvider<ThirdPartyImageProvider> {
  final String url;
  final ThirdPartyImageRequest request;
  final String cacheKey;

  ThirdPartyImageProvider(this.url, this.request) : cacheKey = url;

  static final Dio _dio = () {
    final dio = AppDio.create(
      source: 'tp-image',
      enableRateLimit: false,
      options: BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );
    // 第三方图片 CDN 个别节点证书过期（例如 mwfimsvfast40.cc），
    // 导致封面/章节图握手失败。这里仅放行「证书已过期」一种情况，
    // hostname 不匹配、自签名等其它校验错误仍然拒绝，不做全局放开。
    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) {
            if (cert == null) return false;
            try {
              return cert.endValidity.isBefore(DateTime.now());
            } catch (_) {
              return false;
            }
          };
          return client;
        },
      );
    }
    return dio;
  }();

  @override
  Future<ThirdPartyImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<ThirdPartyImageProvider>(this);

  /// 下载并（如有需要）解密图片字节；带内存缓存。
  Future<Uint8List> fetchBytes() async {
    final cached = _TpImageCache.get(cacheKey);
    if (cached != null) return cached;
    final res = await _dio.get(
      url,
      options: Options(headers: request.headers),
    );
    if (res.statusCode != 200 || res.data is! Uint8List) {
      throw Exception('图片下载失败: $url (${res.statusCode})');
    }
    var bytes = res.data as Uint8List;
    final decryptor = request.decryptor;
    if (decryptor != null) {
      bytes = decryptor(bytes);
    }
    _TpImageCache.put(cacheKey, bytes);
    return bytes;
  }

  @override
  ImageStreamCompleter loadImage(
    ThirdPartyImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_loadAsync(key, decode));
  }

  Future<ImageInfo> _loadAsync(
    ThirdPartyImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final bytes = await fetchBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await decode(buffer);
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } catch (e) {
      throw Exception('第三方图片加载失败: $url\n$e');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ThirdPartyImageProvider && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

/// 封面/图片组件：第三方漫画走 [ThirdPartyImageProvider]（带 headers/解密），
/// 普通漫画走 CachedNetworkImage，两者外观一致。
class TpAwareImage extends StatelessWidget {
  final String? sourceKey;
  final String url;
  final BoxFit fit;

  /// 加载中占位高度（滚动阅读模式下 fitWidth 且图片高度未知时使用）。
  final double? loadingHeight;

  const TpAwareImage({
    super.key,
    required this.sourceKey,
    required this.url,
    this.fit = BoxFit.cover,
    this.loadingHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (sourceKey == null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, _) => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => _tpImageError(context),
      );
    }
    final source = ThirdPartySources.byKey(sourceKey!);
    final request = source?.imageRequest(url);
    if (request == null) return _tpImageError(context);
    return Image(
      image: ThirdPartyImageProvider(url, request),
      fit: fit,
      errorBuilder: (_, _, _) => _tpImageError(context),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return SizedBox(
          height: loadingHeight,
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _tpImageError(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
