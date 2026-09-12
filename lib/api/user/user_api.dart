import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/comic.dart';
import '../../utils/app_dio.dart';
import '../../utils/network_error.dart';
import '../api_transport.dart';

/// HMAC 签名密钥（与拷贝漫画官方 App 一致，base64 编码）
const _copyAuthSecretBase64 = 'M2FmMDg1OTAzMTEwMzJlZmUwNjYwNTUwYTA1NjNhNTM=';

/// 拷贝漫画 App 固定 umstring
const _copyUmstring = 'b4c89ca4104ea9a97750314d791520ac';

/// 设备指纹池（与 Venera 拷贝漫源一致）
const _copyDevicePool = [
  {'deviceinfo': '3371150V-9327', 'device': 'EB0O.675141.548'},
  {'deviceinfo': '4482161V-8412', 'device': 'SM-S9180.827361.012'},
  {'deviceinfo': '5593272V-7523', 'device': '23127PN0CC.918234.331'},
  {'deviceinfo': '6604383V-6634', 'device': 'V2309A.547182.194'},
  {'deviceinfo': '7712265V-3218', 'device': 'SM-S9110.332418.905'},
  {'deviceinfo': '8823374V-2564', 'device': '2201123C.681220.114'},
  {'deviceinfo': '9934483V-7412', 'device': 'LIO-AL00.419362.207'},
  {'deviceinfo': '1045592V-1856', 'device': 'PHK110.755014.426'},
  {'deviceinfo': '2156601V-6639', 'device': 'V2183A.890227.538'},
  {'deviceinfo': '3267710V-9475', 'device': 'GX7A4.204516.772'},
  {'deviceinfo': '4378829V-3027', 'device': 'SM-A5460.135802.649'},
  {'deviceinfo': '5489938V-8145', 'device': 'PJA110.462917.381'},
];

/// SharedPreferences 键
const _prefsKeyCopyDeviceinfo = 'copy_deviceinfo';
const _prefsKeyCopyDevice = 'copy_device';
const _prefsKeyCopyPseudoid = 'copy_pseudoid';
const _prefsKeyCopyBlockedDevices = 'copy_blocked_devices';
const _prefsKeyCopyLastDeviceinfo = 'copy_last_deviceinfo';

/// 生成 16 位随机 pseudoid
String _generatePseudoid() {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = Random();
  return List.generate(16, (_) => chars[rnd.nextInt(chars.length)]).join();
}

/// 设备指纹管理：持久化、封禁追踪、自动轮换（与 Venera 行为一致）
class _CopyDeviceFingerprint {
  final String deviceinfo;
  final String device;
  final String pseudoid;
  const _CopyDeviceFingerprint({
    required this.deviceinfo,
    required this.device,
    required this.pseudoid,
  });

  /// 从池中选取设备，排除已封禁和刚用过的
  static Map<String, String> _pickDevice(
    SharedPreferences prefs, {
    String? excludeDeviceinfo,
  }) {
    final blocked = _loadBlockedDevices(prefs);
    var candidates = _copyDevicePool.where(
      (item) =>
          item['deviceinfo'] != excludeDeviceinfo &&
          !blocked.contains(item['deviceinfo']),
    ).toList();
    if (candidates.isEmpty) {
      // 全部被封禁时降级：只排除刚用过的
      candidates = _copyDevicePool
          .where((item) => item['deviceinfo'] != excludeDeviceinfo)
          .toList();
    }
    if (candidates.isEmpty) {
      candidates = List.of(_copyDevicePool);
    }
    return candidates[Random().nextInt(candidates.length)];
  }

  static List<String> _loadBlockedDevices(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKeyCopyBlockedDevices);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveBlockedDevices(
    SharedPreferences prefs,
    List<String> devices,
  ) async {
    // 只保留最近 30 条，避免无限增长
    final trimmed = devices.length > 30
        ? devices.sublist(devices.length - 30)
        : devices;
    await prefs.setString(_prefsKeyCopyBlockedDevices, jsonEncode(trimmed));
  }

  /// 加载当前设备指纹，不存在则生成
  static Future<_CopyDeviceFingerprint> load() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceinfo = prefs.getString(_prefsKeyCopyDeviceinfo);
    var device = prefs.getString(_prefsKeyCopyDevice);
    var pseudoid = prefs.getString(_prefsKeyCopyPseudoid);
    if (deviceinfo == null || device == null) {
      final last = prefs.getString(_prefsKeyCopyLastDeviceinfo);
      final item = _pickDevice(prefs, excludeDeviceinfo: last);
      deviceinfo = item['deviceinfo']!;
      device = item['device']!;
      await prefs.setString(_prefsKeyCopyDeviceinfo, deviceinfo);
      await prefs.setString(_prefsKeyCopyDevice, device);
    }
    pseudoid ??= _generatePseudoid();
    await prefs.setString(_prefsKeyCopyPseudoid, pseudoid);
    return _CopyDeviceFingerprint(
      deviceinfo: deviceinfo,
      device: device,
      pseudoid: pseudoid,
    );
  }

  /// 标记当前设备为已封禁并重置（下次加载时生成新指纹）
  static Future<void> markBlockedAndReset() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_prefsKeyCopyDeviceinfo);
    if (current != null) {
      final blocked = _loadBlockedDevices(prefs);
      if (!blocked.contains(current)) {
        blocked.add(current);
        await _saveBlockedDevices(prefs, blocked);
      }
      await prefs.setString(_prefsKeyCopyLastDeviceinfo, current);
    }
    await prefs.remove(_prefsKeyCopyDeviceinfo);
    await prefs.remove(_prefsKeyCopyDevice);
    await prefs.remove(_prefsKeyCopyPseudoid);
  }
}

/// 计算拷贝漫画 App 的 x-auth-signature（HMAC-SHA256 of timestamp）
String _computeCopyAuthSignature(String timestamp) {
  final key = base64.decode(_copyAuthSecretBase64);
  final hmac = Hmac(sha256, key);
  return hmac.convert(utf8.encode(timestamp)).toString();
}

/// 模拟真人请求的随机延迟（600-1200ms），与 Venera throttle 一致
Future<void> _copyThrottle() async {
  final delay = 600 + Random().nextInt(600);
  await Future.delayed(Duration(milliseconds: delay));
}

class UserApi {
  final ApiTransport _t;

  UserApi(this._t);

  // ── 用户相关 ──

  /// 登录，返回用户信息
  Future<Map<String, dynamic>> login(String username, String password) async {
    final salt = Random().nextInt(9000) + 1000;
    final encoded = base64Encode(utf8.encode('$password-$salt'));
    final resp = await _t.dio.post(
      _t.url('/api/v3/login'),
      data:
          'username=$username&password=$encoded&salt=$salt&source=Official&version=2.2.0&platform=3',
      options: Options(
        contentType: 'application/x-www-form-urlencoded;charset=utf-8',
      ),
    );
    return resp.data['results'];
  }

  /// 拷贝漫画 App 登录（对齐官方 COPY/3.0.9 App 接口，非 Web 登录）
  ///
  /// 使用 `/api/v3/login` App 接口，附带设备指纹与 HMAC-SHA256 签名，
  /// 与 Venera 拷贝漫源的登录实现一致。
  /// 登录失败时自动标记当前设备指纹为封禁并换指纹重试一次。
  Future<Map<String, dynamic>> copyLogin(
    String username,
    String password,
  ) async {
    Object? lastError;
    // 最多尝试 2 次：第一次用当前指纹，失败后换指纹重试
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        // 上一次失败，标记当前指纹为封禁并重置，下次加载时生成新指纹
        await _CopyDeviceFingerprint.markBlockedAndReset();
      }
      try {
        return await _copyLoginOnce(username, password);
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError!;
  }

  /// 单次拷贝漫画 App 登录请求
  Future<Map<String, dynamic>> _copyLoginOnce(
    String username,
    String password,
  ) async {
    // 1. 模拟真人请求延迟（600-1200ms）
    await _copyThrottle();

    // 2. 加载设备指纹（持久化，与官方 App 行为一致）
    final fp = await _CopyDeviceFingerprint.load();

    // 3. 构造签名
    final now = DateTime.now();
    final ts = (now.millisecondsSinceEpoch ~/ 1000).toString();
    final sig = _computeCopyAuthSignature(ts);
    final dt =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    // 4. 密码加密：base64(password-salt)，salt 为 4 位随机数
    final salt = Random().nextInt(9000) + 1000;
    final encoded = base64Encode(utf8.encode('$password-$salt'));

    // 5. App 风格请求头（严格对齐 COPY/3.0.9）
    final headers = <String, dynamic>{
      'User-Agent': 'COPY/3.0.9',
      'source': 'copyApp',
      'deviceinfo': fp.deviceinfo,
      'dt': dt,
      'platform': '3',
      'referer': 'com.copymanga.app-3.0.9',
      'version': '3.0.9',
      'device': fp.device,
      'pseudoid': fp.pseudoid,
      'Accept': 'application/json',
      'region': '0',
      'authorization': 'Token',
      'umstring': _copyUmstring,
      'x-auth-timestamp': ts,
      'x-auth-signature': sig,
      'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
    };

    final dio = AppDio.create(
      source: 'copy_login',
      options: BaseOptions(
        validateStatus: (_) => true,
        headers: headers,
      ),
    );

    // 6. 请求 App 登录接口
    final apiHost = _t.user.copyApiHost;
    final resp = await dio.post(
      'https://$apiHost/api/v3/login',
      data:
          'username=$username&password=$encoded&salt=$salt&authorization=Token+',
    );

    final data = resp.data;
    if (data is Map && data['code'] == 200) {
      return Map<String, dynamic>.from(data['results']);
    }

    String? serverMessage;
    if (data is Map) {
      final raw = (data['message'] ?? data['detail'])?.toString().trim();
      if (raw != null && raw.isNotEmpty) serverMessage = raw;
    }
    final message =
        serverMessage ??
        (data is Map
            ? 'Login failed (code: ${data['code'] ?? resp.statusCode ?? 'unknown'})'
            : 'Login failed (HTTP ${resp.statusCode ?? 'unknown'})');
    NetworkError.throwBadResponse(
      response: resp,
      message: message,
      source: 'copy_login',
    );
  }

  /// 获取个人信息
  Future<Map<String, dynamic>> getUserInfo() async {
    return _t.get('/api/v3/member/info');
  }

  Future<void> logout() async {
    await _t.dio.post(
      _t.url('/api/v3/logout'),
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
  }

  void clearAuthState() {
    _t.clearCookies();
  }

  Future<List<String>> getSecurityQuestions() async {
    final resp = await _t.dio.get(
      _t.url('/api/v3/member/securityquestionall/'),
    );
    final results = resp.data['results'] as List? ?? const [];
    return results
        .map((e) => e['code']?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String question,
    required String answer,
  }) async {
    const hostWeb = 'www.manga2026.xyz';

    Map<String, dynamic> parseResponse(dynamic raw) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {
          return {'message': raw};
        }
      }
      return {};
    }

    String resolveMessage(Map<String, dynamic> data, Response<dynamic>? resp) {
      final results = data['results'];
      return data['message']?.toString() ??
          data['detail']?.toString() ??
          (results is Map ? results['detail']?.toString() : null) ??
          resp?.statusMessage ??
          'Registration failed';
    }

    final dio = AppDio.create(
      source: 'register',
      options: BaseOptions(
        validateStatus: (_) => true,
        headers: {
          'accept': 'application/json, text/plain, */*',
          'accept-language':
              'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7,en-GB;q=0.6,ru;q=0.5,ja;q=0.4,zh-TW;q=0.3',
          'cache-control': 'no-cache',
          'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'platform': '2',
          'pragma': 'no-cache',
          'origin': 'https://$hostWeb',
          'referer': 'https://$hostWeb/web/login/loginByAccount',
          'priority': 'u=1, i',
          'sec-ch-ua':
              '"Not:A-Brand";v="99", "Microsoft Edge";v="145", "Chromium";v="145"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'empty',
          'sec-fetch-mode': 'cors',
          'sec-fetch-site': 'same-origin',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0',
          'Cookie': _t.buildRegisterCookie(),
        },
      ),
    );

    final resp = await dio.post(
      'https://$hostWeb/api/v2/register',
      data: Uri(
        queryParameters: {
          'username': username,
          'password': password,
          'source': '',
          'platform': '2',
          'code': '',
          'invite_code': '',
          'version': '2025.12.10',
          'question': question,
          'answer': answer,
        },
      ).query,
    );

    final data = parseResponse(resp.data);
    if (resp.statusCode == 200 && data['code'] == 200) {
      final results = data['results'];
      return results is Map ? Map<String, dynamic>.from(results) : {};
    }

    final message = resolveMessage(data, resp);
    NetworkError.throwBadResponse(
      response: resp,
      message: message,
      source: 'register',
    );
  }

  /// 获取浏览记录
  Future<({List<BrowseHistoryItem> list, int total})> getBrowseHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _t.get(
      '/api/v3/member/browse/comics',
      params: {
        'free_type': 1,
        'offset': offset,
        'limit': limit,
        '_update': true,
      },
    );
    final list = (data['list'] as List).map((e) {
      final item = Map<String, dynamic>.from(e);
      return BrowseHistoryItem(
        id: item['id'] as int? ?? 0,
        lastBrowseId: item['last_chapter_id']?.toString(),
        lastBrowseName: item['last_chapter_name']?.toString(),
        comic: Comic.fromJson(Map<String, dynamic>.from(item['comic'])),
      );
    }).toList();
    return (list: list, total: data['total'] as int? ?? list.length);
  }

  Future<void> clearBrowseHistory() async {
    if (_t.user.loginSource == 'copy') {
      final dio = AppDio.create(
        source: 'copy_api',
        options: BaseOptions(
          validateStatus: (_) => true,
          headers: {
            'User-Agent': 'COPY/${_t.user.copyAppVersion}',
            'Accept': 'application/json',
            'source': 'copyApp',
            'platform': '3',
            'version': _t.user.copyAppVersion,
            'Connection': 'keep-alive',
            'Accept-Encoding': 'gzip',
            'webp': '1',
            'Authorization': 'Token ${_t.user.token}',
          },
        ),
      );
      final resp = await dio.delete(
        'https://${_t.user.copyApiHost}/api/v3/member/browse/comics',
        queryParameters: {'platform': 3},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      final data = resp.data;
      if (data is Map && data['code'] == 200) return;
      final message = data is Map
          ? (data['message']?.toString() ?? 'Failed to clear browse history')
          : 'Failed to clear browse history';
      NetworkError.throwBadResponse(
        response: resp,
        message: message,
        source: 'copy_api',
      );
    } else {
      await _t.dio.delete(
        _t.url('/api/v3/member/browse/comics'),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
    }
  }

  Future<void> clearAnimeBrowseHistory() async {
    if (_t.user.loginSource == 'copy') {
      final dio = AppDio.create(
        source: 'copy_api',
        options: BaseOptions(
          validateStatus: (_) => true,
          headers: {
            'User-Agent': 'COPY/${_t.user.copyAppVersion}',
            'Accept': 'application/json',
            'source': 'copyApp',
            'platform': '3',
            'version': _t.user.copyAppVersion,
            'Connection': 'keep-alive',
            'Accept-Encoding': 'gzip',
            'webp': '1',
            'Authorization': 'Token ${_t.user.token}',
          },
        ),
      );
      final resp = await dio.delete(
        'https://${_t.user.copyApiHost}/api/v3/member/browse/cartoons',
        queryParameters: {'platform': 3},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      final data = resp.data;
      if (data is Map && data['code'] == 200) return;
      final message = data is Map
          ? (data['message']?.toString() ?? 'Failed to clear browse history')
          : 'Failed to clear browse history';
      NetworkError.throwBadResponse(
        response: resp,
        message: message,
        source: 'copy_api',
      );
    } else {
      await _t.dio.delete(
        _t.url('/api/v3/member/browse/cartoons'),
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
    }
  }
}
