import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

import '../../models/comic.dart' hide Theme;
import '../../models/user_manager.dart';
import '../../utils/app_dio.dart';
import 'third_party_source.dart';

/// 漫屋3 漫源（Venera 源 `Code_20260830.js` 的 Dart 移植）。
///
/// 站点特征：
///  - API 响应整体是 JSON 包裹的 base64 字符串，内容为 AES-256-ECB 加密，
///    密钥 = md5Hex(devid + API_KEY_SALT) 的 UTF-8 字节（32 字节）。
///  - 请求头需带 devid + x-token = md5(devid + "," + TOKEN_SALT)。
///  - 图片为 AES-128-CBC 加密（本轮未接入阅读器，仅保留解密辅助方法）。
class Waman3Source extends ThirdPartyComicSource {
  Waman3Source._();

  static final Waman3Source instance = Waman3Source._();

  @override
  String get key => 'waman3';

  @override
  String get name => '漫屋3';

  // ── 站点常量（与 Venera 源一致）──
  static const tokenSalt = 'jsdaghuiaonfyudsfnkgjdfkdd';
  static const apiKeySalt = ',noiusdfy73osadjap012njdsfn';
  static const imageSecretKey = 'my2ecret782ecret';
  static const defaultBaseUrl = 'https://mseeowpma.cc';

  /// 测速 / 设置可选节点，与 Venera 源 `baseUrl` 下拉一致。
  static const baseUrlOptions = [
    'https://mseeowpma.cc',
    'http://mseeowpm.pro',
    'http://mseeowpm1.xyz',
    'http://mseeowpm2.cc',
  ];

  static const userAgent =
      'Mozilla/5.0 (Linux; Android 12; PGT-AN20) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36 '
      'mwa-1.1.26+1 (Android/12 HONOR/PGT-AN20)';

  late final Dio _dio = AppDio.create(
    source: key,
    enableRateLimit: false,
    options: BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );

  /// 当前 API 地址（来自 我的-网络 设置）。
  String get baseUrl {
    final value = UserManager().waman3BaseUrl.trim();
    return value.isEmpty ? defaultBaseUrl : value;
  }

  // ── 加密工具 ──

  String _md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

  /// 移除 PKCS7 填充（与 Venera 源 stripPkcs7Padding 一致）。
  Uint8List _stripPkcs7(Uint8List data) {
    final len = data.length;
    if (len == 0) return data;
    final padLen = data[len - 1];
    if (padLen == 0 || padLen > 16 || padLen > len) return data;
    for (var i = len - padLen; i < len; i++) {
      if (data[i] != padLen) return data;
    }
    return Uint8List.sublistView(data, 0, len - padLen);
  }

  /// AES-ECB 解密（按 key 长度自动 AES-128/192/256），手工去除填充由调用方处理。
  Uint8List _aesEcbDecrypt(Uint8List cipher, Uint8List key) {
    final engine = ECBBlockCipher(AESEngine())
      ..init(false, KeyParameter(key));
    final out = Uint8List(cipher.length);
    var off = 0;
    while (off + 16 <= cipher.length) {
      off += engine.processBlock(cipher, off, out, off);
    }
    return Uint8List.sublistView(out, 0, off);
  }

  /// 从解密文本中截取 JSON（第一个 `{` 到最后一个 `}`，数组同理）。
  String _findJson(String text) {
    var start = text.indexOf('{');
    var end = text.lastIndexOf('}');
    if (start == -1) {
      start = text.indexOf('[');
      end = text.lastIndexOf(']');
    }
    return text.substring(start, end + 1);
  }

  /// 解密 API 响应：base64 -> AES-256-ECB(devid 派生密钥) -> PKCS7 -> UTF-8。
  String _apiDecrypt(String encryptedBase64, String devid) {
    final keyHex = _md5Hex(devid + apiKeySalt);
    final keyBytes = Uint8List.fromList(utf8.encode(keyHex));
    final encrypted = base64Decode(encryptedBase64);
    final decrypted = _stripPkcs7(_aesEcbDecrypt(encrypted, keyBytes));
    return utf8.decode(decrypted);
  }

  // ── 请求 ──

  /// 发送 API 请求并解密响应，返回完整 JSON（含 code/data）。
  Future<Map<String, dynamic>> fetchApi(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    final base = baseUrl;
    final devid = DateTime.now().millisecondsSinceEpoch.toString();
    final token = _md5Hex('$devid,$tokenSalt');
    final headers = {
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
      'Origin': base,
      'Referer': '$base/',
      'Content-Type': 'application/json; charset=utf-8',
      'devid': devid,
      'x-token': token,
      'User-Agent': userAgent,
    };
    final paramsString = params == null
        ? ''
        : params.entries
            .map(
              (e) =>
                  '${e.key}=${Uri.encodeQueryComponent('${e.value}')}',
            )
            .join('&');
    final url = paramsString.isEmpty ? '$base$path' : '$base$path?$paramsString';
    final res = await _dio.get(
      url,
      options: Options(headers: headers),
    );
    if (res.statusCode != 200) {
      throw '漫屋3 API 请求失败: ${res.statusCode}';
    }
    final body = res.data;
    if (body is! String || body.isEmpty) {
      throw '漫屋3 API 响应为空';
    }
    final encB64 = jsonDecode(body);
    if (encB64 is! String) {
      throw '漫屋3 API 响应格式异常';
    }
    final decrypted = _apiDecrypt(encB64, devid);
    final jsonText = _findJson(decrypted);
    final data = jsonDecode(jsonText);
    if (data is! Map<String, dynamic>) {
      throw '漫屋3 API 响应格式异常';
    }
    return data;
  }

  // ── 数据映射 ──

  Comic _buildComic(Map<String, dynamic> item) {
    final id = '${item['id'] ?? ''}';
    final name = '${item['name'] ?? ''}';
    final cover = '${item['picx'] ?? item['pic'] ?? ''}'.trim();
    final authors = <Author>[];
    final author = '${item['author'] ?? ''}'.trim();
    if (author.isNotEmpty) {
      authors.add(Author(name: author, pathWord: ''));
    }
    Map<String, dynamic>? status;
    final serialize = '${item['serialize'] ?? ''}'.trim();
    if (serialize.isNotEmpty) {
      status = {'display': serialize};
    }
    return Comic(
      name: name,
      pathWord: encodeComicId(id),
      cover: cover,
      authors: authors,
      brief: '${item['text'] ?? ''}',
      status: status,
    );
  }

  // ── 主页板块 ──

  @override
  Future<Map<String, List<Comic>>> loadHome() async {
    final data = await fetchApi('/api/index/index');
    if (data['code'] != 1) {
      throw '漫屋3 首页加载失败: ${data['msg'] ?? ''}';
    }
    final root = data['data'];
    final cls = root is Map<String, dynamic> ? root['class'] : null;
    final result = <String, List<Comic>>{};
    if (cls is List) {
      for (final raw in cls) {
        if (raw is! Map<String, dynamic>) continue;
        if (raw['name'] != '女主逆袭') continue;
        final list = raw['comic'];
        if (list is! List) continue;
        final comics = list
            .whereType<Map<String, dynamic>>()
            .take(10)
            .map(_buildComic)
            .toList();
        if (comics.isNotEmpty) {
          result['女主逆袭'] = comics;
        }
      }
    }
    return result;
  }

  // ── 搜索 ──

  @override
  Future<ThirdPartySearchResult> search(String keyword, int page) async {
    final data = await fetchApi(
      '/api/search/index',
      params: {'k': keyword, 'page': page},
    );
    if (data['code'] != 1) {
      throw '漫屋3 搜索失败: ${data['msg'] ?? ''}';
    }
    final root = data['data'];
    final rootMap = root is Map<String, dynamic> ? root : const <String, dynamic>{};
    final list = (rootMap['list'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const <Map<String, dynamic>>[];
    final total = (rootMap['nums'] as num?)?.toInt() ?? list.length;
    final size = (rootMap['size'] as num?)?.toInt() ?? 20;
    final maxPage = size <= 0 ? 1 : (total / size).ceil();
    return ThirdPartySearchResult(
      comics: list.map(_buildComic).toList(),
      maxPage: maxPage,
    );
  }

  // ── 漫画详情 / 章节 / 图片 ──

  @override
  Future<ThirdPartyComicDetail> loadInfo(String comicId) async {
    final data = await fetchApi(
      '/api/detail/index',
      params: {'id': comicId},
    );
    if (data['code'] != 1) {
      throw '漫屋3 详情加载失败: ${data['msg'] ?? ''}';
    }
    final root = data['data'];
    if (root is! Map<String, dynamic>) {
      throw '漫屋3 详情数据异常';
    }
    final chapterList = root['chapter_list'];
    final chapters = <ThirdPartyChapter>[];
    if (chapterList is List) {
      final sorted = chapterList.whereType<Map<String, dynamic>>().toList()
        ..sort((a, b) => ((a['sort'] as num?)?.toInt() ?? 0)
            .compareTo((b['sort'] as num?)?.toInt() ?? 0));
      for (final ch in sorted) {
        final chId = '${ch['id'] ?? ''}';
        if (chId.isEmpty) continue;
        chapters.add(ThirdPartyChapter(id: chId, name: '${ch['name'] ?? ''}'));
      }
    }
    final authors = <String>[];
    final authorText = '${root['author'] ?? ''}'.trim();
    if (authorText.isNotEmpty) {
      authors.addAll(
        authorText
            .split(RegExp(r'[/、,，]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }
    final tags = <String>[];
    final rawTags = root['tags'];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is Map) {
          final name = '${t['name'] ?? ''}'.trim();
          if (name.isNotEmpty) tags.add(name);
        }
      }
    }
    final state = '${root['state'] ?? ''}'.trim();
    if (state.isNotEmpty) tags.add('状态: $state');
    final area = '${root['book_area'] ?? ''}'.trim();
    if (area.isNotEmpty) tags.add('地区: $area');
    final category = '${root['category_name'] ?? ''}'.trim();
    if (category.isNotEmpty) tags.add('分类: $category');

    return ThirdPartyComicDetail(
      title: '${root['name'] ?? ''}',
      cover: '${root['picx'] ?? ''}',
      description: '${root['text'] ?? ''}',
      authors: authors,
      tags: tags,
      statusDisplay: state.isEmpty ? null : state,
      updateTime: '${root['last_time'] ?? ''}',
      chapters: chapters,
    );
  }

  @override
  Future<List<String>> loadEp(String comicId, String epId) async {
    final data = await fetchApi(
      '/api/chapters/index',
      params: {'id': epId, 'img_host': 0},
    );
    if (data['code'] != 1) {
      throw '漫屋3 章节加载失败: ${data['msg'] ?? ''}';
    }
    final root = data['data'];
    final piclist = root is Map<String, dynamic> ? root['piclist'] : null;
    if (piclist is! List) return const [];
    return piclist
        .whereType<Map<String, dynamic>>()
        .map((pic) => '${pic['pic'] ?? ''}')
        .where((url) => url.isNotEmpty)
        .toList();
  }

  @override
  ThirdPartyImageRequest? imageRequest(String url) {
    final base = baseUrl;
    return ThirdPartyImageRequest(
      headers: {
        'User-Agent': userAgent,
        'Referer': '$base/',
      },
      decryptor: (bytes) {
        if (ThirdPartyComicSource.isPlainImage(bytes)) return bytes;
        final keyBytes = Uint8List.fromList(utf8.encode(imageSecretKey));
        final decrypted = ThirdPartyComicSource.probeOrDecryptCbc(
          bytes,
          key: keyBytes,
          iv: keyBytes,
        );
        return ThirdPartyComicSource.stripPkcs7(decrypted);
      },
    );
  }

  // ── 节点测速（设置页使用）──

  /// 对全部候选节点测速，返回 (url, 延迟ms) 升序列表。
  Future<List<({String url, int latencyMs})>> speedTest() async {
    final results = <({String url, int latencyMs})>[];
    for (final url in baseUrlOptions) {
      final stopwatch = Stopwatch()..start();
      try {
        final res = await _dio.head(
          url,
          options: Options(
            headers: {
              'User-Agent': userAgent,
              'Accept': 'application/json, text/plain, */*',
            },
          ),
        );
        stopwatch.stop();
        final code = res.statusCode;
        if (code != null && code >= 200 && code < 400) {
          results.add((url: url, latencyMs: stopwatch.elapsedMilliseconds));
        }
      } catch (_) {
        // 失败节点跳过
      }
    }
    results.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
    return results;
  }
}
