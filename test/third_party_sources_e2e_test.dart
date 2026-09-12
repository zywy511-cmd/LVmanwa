import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/api/third_party/manwaba_source.dart';
import '../lib/api/third_party/waman3_source.dart';

/// 测试环境带一个 dart:io 无法解析的沙箱代理变量，这里强制直连。
class _DirectHttpOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return 'DIRECT';
  }
}

/// 端到端验证：直接请求真实站点，验证解密链、首页板块与搜索解析。
/// 不初始化 widget binding，保证 dio 走真实网络。
void main() {
  HttpOverrides.global = _DirectHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('漫屋3: 首页 + 搜索（AES-256-ECB 解密链）', () async {
    final source = Waman3Source.instance;
    final home = await source.loadHome();
    expect(home.isNotEmpty, true, reason: '首页应有板块');
    final section = home.entries.first;
    expect(section.value.length, greaterThan(0), reason: '板块应有漫画');
    final comic = section.value.first;
    expect(comic.name, isNotEmpty);
    expect(comic.pathWord, startsWith('waman3:'));
    expect(comic.cover, isNotEmpty);
    // ignore: avoid_print
    print('漫屋3 首页板块「${section.key}」${section.value.length} 本，首本：${comic.name}');

    final result = await source.search('火影', 1);
    // ignore: avoid_print
    print('漫屋3 搜索「火影」第1页 ${result.comics.length} 条 / 共 ${result.maxPage} 页');
    if (result.comics.isNotEmpty) {
      final first = result.comics.first;
      expect(first.name, isNotEmpty);
      expect(first.pathWord, startsWith('waman3:'));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('漫屋吧: 自动检测 + 首页 + 搜索 + 图片URL重写', () async {
    final source = ManwabaSource.instance;
    final detected = await source.autoDetect();
    // ignore: avoid_print
    print('漫屋吧 检测结果: api=${detected.apiHost} image=${detected.imageHost}');

    final home = await source.loadHome();
    expect(home.isNotEmpty, true, reason: '首页应有板块');
    // ignore: avoid_print
    print('漫屋吧 首页板块: ${home.keys.toList()}');
    final comic = home.entries.first.value.first;
    expect(comic.pathWord, startsWith('manwaba:'));

    final result = await source.search('火影', 1);
    // ignore: avoid_print
    print('漫屋吧 搜索「火影」第1页 ${result.comics.length} 条 / 共 ${result.maxPage} 页');
    if (result.comics.isNotEmpty) {
      final first = result.comics.first;
      expect(first.cover, startsWith('https://'), reason: '封面应重写到 https 图源');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
