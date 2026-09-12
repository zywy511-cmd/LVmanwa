import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/api/third_party/manwaba_source.dart';
import '../lib/api/third_party/third_party_source.dart';
import '../lib/api/third_party/waman3_source.dart';

/// 测试环境带一个 dart:io 无法解析的沙箱代理变量，这里强制直连。
class _DirectHttpOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return 'DIRECT';
  }
}

/// 端到端验证：主页 + 搜索 + 详情/章节 + 真实下载章节图片并解密验证 magic bytes。
void main() {
  HttpOverrides.global = _DirectHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> verifyReadingChain(
    ThirdPartyComicSource source,
    String keyword,
  ) async {
    // 搜索拿到一个漫画
    final search = await source.search(keyword, 1);
    expect(search.comics, isNotEmpty, reason: '搜索应有结果');
    final comic = search.comics.first;
    // ignore: avoid_print
    print('[${source.key}] 搜索命中: ${comic.name} (${comic.pathWord})');

    // 详情 + 章节
    final comicId = ThirdPartyComicSource.comicIdOfPathWord(comic.pathWord);
    final detail = await source.loadInfo(comicId);
    expect(detail.chapters, isNotEmpty, reason: '详情应有章节');
    // ignore: avoid_print
    print('[${source.key}] 详情: ${detail.title}，章节数 ${detail.chapters.length}'
        '，首章「${detail.chapters.first.name}」，末章「${detail.chapters.last.name}」');

    // 章节图片列表
    final ep = detail.chapters.last; // 最新一章
    final images = await source.loadEp(comicId, ep.id);
    expect(images, isNotEmpty, reason: '章节应有图片');
    // ignore: avoid_print
    print('[${source.key}] 章节「${ep.name}」图片 ${images.length} 张，首图: ${images.first}');

    // 真实下载第一张并解密，验证 magic bytes
    final request = source.imageRequest(images.first);
    expect(request, isNotNull);
    final dio = DioAdapter.dio;
    final res = await dio.get(
      images.first,
      options: Options(
        headers: request!.headers,
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );
    expect(res.statusCode, 200, reason: '图片应可下载');
    final raw = res.data as Uint8List;
    final decrypted = request.decryptor?.call(raw) ?? raw;
    expect(
      ThirdPartyComicSource.isPlainImage(decrypted),
      true,
      reason: '解密后应为可解码图片（magic bytes 校验）',
    );
    // ignore: avoid_print
    print('[${source.key}] 图片下载 ${raw.length}B -> 解密后 ${decrypted.length}B'
        '，magic: ${decrypted.take(4).map((b) => b.toRadixString(16)).join(" ")}');

    // 封面同样可加载（明文或解密后为图片）
    final coverRequest = source.imageRequest(comic.cover);
    if (coverRequest != null && comic.cover.isNotEmpty) {
      final coverRes = await dio.get(
        comic.cover,
        options: Options(
          headers: coverRequest.headers,
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      if (coverRes.statusCode == 200 && coverRes.data is Uint8List) {
        final coverBytes = coverRequest.decryptor?.call(coverRes.data) ??
            coverRes.data as Uint8List;
        // ignore: avoid_print
        print('[${source.key}] 封面可下载: ${coverBytes.length}B '
            'plain=${ThirdPartyComicSource.isPlainImage(coverBytes)}');
      }
    }
  }

  test('漫屋3: 搜索→详情→章节→真实下载解密图片', () async {
    await verifyReadingChain(Waman3Source.instance, '火影');
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('漫屋吧: 搜索→详情→章节→真实下载解密图片', () async {
    final source = ManwabaSource.instance;
    await source.autoDetect(); // 先检测可用域名
    await verifyReadingChain(source, '火影');
  }, timeout: const Timeout(Duration(minutes: 4)));
}

/// 测试用直连 dio。
class DioAdapter {
  DioAdapter._();
  static final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (_) => true,
    ),
  );
}
