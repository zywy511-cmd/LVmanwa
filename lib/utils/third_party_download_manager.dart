import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/third_party/third_party_source.dart';
import '../api/third_party/third_party_sources.dart';

/// 第三方漫源单章下载进度
class TpChapterDownloadProgress {
  final int loaded;
  final int total;
  final String message;

  const TpChapterDownloadProgress({
    required this.loaded,
    required this.total,
    required this.message,
  });

  double get value => total == 0 ? 0 : loaded / total;
}

/// 第三方漫源下载管理器：把章节图片缓存到本地，离线可读。
/// 图片并发下载数默认 8，与拷贝漫画保持一致。
class ThirdPartyDownloadManager {
  ThirdPartyDownloadManager._();
  static final ThirdPartyDownloadManager instance = ThirdPartyDownloadManager._();

  static const _rootFolderName = 'third_party_downloads';
  static const _manifestFileName = 'manifest.json';
  static const _defaultImageConcurrency = 8;
  static const Duration _timeout = Duration(seconds: 30);

  bool _initialized = false;
  Directory? _rootDir;
  Map<String, Map<String, dynamic>> _manifest = {}; // comicPathWord -> chapterId -> meta

  Future<void> init() async {
    if (_initialized) return;
    final appDir = await getApplicationDocumentsDirectory();
    _rootDir = Directory('${appDir.path}/$_rootFolderName');
    if (!await _rootDir!.exists()) {
      await _rootDir!.create(recursive: true);
    }
    await _loadManifest();
    _initialized = true;
  }

  Future<void> _loadManifest() async {
    final file = File('${_rootDir!.path}/$_manifestFileName');
    if (!await file.exists()) return;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _manifest = decoded.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    } catch (_) {
      _manifest = {};
    }
  }

  Future<void> _saveManifest() async {
    final file = File('${_rootDir!.path}/$_manifestFileName');
    await file.writeAsString(jsonEncode(_manifest));
  }

  String _chapterDir(String comicPathWord, String chapterId) =>
      '${_rootDir!.path}/${_safe(comicPathWord)}/${_safe(chapterId)}';

  String _safe(String s) => s.replaceAll(RegExp(r'[^\w\-]'), '_');

  /// 判断某章节是否已下载
  Future<bool> isChapterDownloaded(String comicPathWord, String chapterId) async {
    await init();
    return _manifest[comicPathWord]?.containsKey(chapterId) ?? false;
  }

  /// 获取已下载章节的本地图片路径列表
  Future<List<String>?> getLocalImages(String comicPathWord, String chapterId) async {
    await init();
    final meta = _manifest[comicPathWord]?[chapterId];
    if (meta == null) return null;
    final dir = Directory(_chapterDir(comicPathWord, chapterId));
    if (!await dir.exists()) return null;
    final files = await dir.list().where((e) => e is File).cast<File>().toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files.map((f) => f.path).toList();
  }

  /// 下载整个章节，返回进度流
  Stream<TpChapterDownloadProgress> downloadChapter({
    required String sourceKey,
    required String comicId,
    required String comicName,
    required String chapterId,
    required String chapterName,
    required List<String> imageUrls,
  }) async* {
    await init();
    final source = ThirdPartySources.byKey(sourceKey);
    if (source == null) throw Exception('未知漫源: $sourceKey');

    final comicPathWord = '${sourceKey}:$comicId';
    final dirPath = _chapterDir(comicPathWord, chapterId);
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);

    final total = imageUrls.length;
    var loaded = 0;
    yield TpChapterDownloadProgress(
      loaded: loaded,
      total: total,
      message: '准备下载 $chapterName',
    );

    // 并发下载，最多 _defaultImageConcurrency 张同时进行
    final queue = List<String>.from(imageUrls);
    final active = <Future<void>>[];
    final errors = <String>[];

    while (queue.isNotEmpty || active.isNotEmpty) {
      // 补充并发任务
      while (active.length < _defaultImageConcurrency && queue.isNotEmpty) {
        final url = queue.removeAt(0);
        final index = imageUrls.indexOf(url);
        active.add(
          _downloadSingleImage(source, url, '$dirPath/${index.toString().padLeft(4, '0')}.jpg')
              .then((_) {
            loaded++;
          }).catchError((e) {
            errors.add(url);
            loaded++;
          }),
        );
      }
      yield TpChapterDownloadProgress(
        loaded: loaded,
        total: total,
        message: '正在下载 $loaded/$total',
      );
      await Future.any(active);
      active.removeWhere((f) => f.isCompleted);
    }

    // 保存 manifest
    _manifest.putIfAbsent(comicPathWord, () => {});
    _manifest[comicPathWord]![chapterId] = {
      'chapterName': chapterName,
      'comicName': comicName,
      'totalImages': total,
      'errors': errors.length,
      'downloadedAt': DateTime.now().toIso8601String(),
    };
    await _saveManifest();

    yield TpChapterDownloadProgress(
      loaded: total,
      total: total,
      message: errors.isEmpty ? '下载完成' : '下载完成，${errors.length} 张失败',
    );
  }

  Future<void> _downloadSingleImage(
    ThirdPartyComicSource source,
    String url,
    String savePath,
  ) async {
    final request = source.imageRequest(url);
    if (request == null) throw Exception('无法创建图片请求: $url');

    final client = HttpClient()..connectionTimeout = _timeout;
    // 忽略证书错误（部分漫源 CDN 证书过期）
    client.badCertificateCallback = (cert, host, port) => true;

    final req = await client.getUrl(Uri.parse(url));
    request.headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final bytes = await consolidateHttpClientResponseBytes(res);
    var finalBytes = bytes;
    final decryptor = request.decryptor;
    if (decryptor != null) {
      finalBytes = decryptor(bytes);
    }

    final file = File(savePath);
    await file.writeAsBytes(finalBytes);
    client.close(force: true);
  }

  /// 删除某章节的本地缓存
  Future<void> deleteChapter(String comicPathWord, String chapterId) async {
    await init();
    final dir = Directory(_chapterDir(comicPathWord, chapterId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _manifest[comicPathWord]?.remove(chapterId);
    if (_manifest[comicPathWord]?.isEmpty ?? true) {
      _manifest.remove(comicPathWord);
    }
    await _saveManifest();
  }

  /// 获取某漫画已下载的章节列表
  Future<Map<String, dynamic>> downloadedChapters(String comicPathWord) async {
    await init();
    return Map<String, dynamic>.from(_manifest[comicPathWord] ?? {});
  }
}
