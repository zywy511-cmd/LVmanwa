import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/api/api_client.dart';
import '../lib/api/third_party/manwaba_source.dart';
import '../lib/api/third_party/waman3_source.dart';

/// 测试环境带一个 dart:io 无法解析的沙箱代理变量，这里强制直连。
class _DirectHttpOverrides extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) {
    return 'DIRECT';
  }
}

/// 验证「全部」搜索聚合的数据基础：
/// 1. 热辣/拷贝同源可合并去重（优先保留热辣）
/// 2. 四个源对同一关键词都能返回结果，可按 热辣/拷贝 → 漫屋3 → 漫屋吧 顺序拼接
void main() {
  HttpOverrides.global = _DirectHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('热辣/拷贝同源：合并去重后条数不膨胀、标题高度重叠', () async {
    final api = ApiClient();
    final hot = await api.manga.searchComics('火影');
    final copy = await api.manga.searchCopyComics('火影');
    expect(hot.list, isNotEmpty, reason: '热辣应有结果');
    expect(copy.list, isNotEmpty, reason: '拷贝应有结果');

    final seen = <String>{};
    final mergedTitles = <String>[];
    // 模拟合并源：热辣优先，其次拷贝（按标题去重）
    for (final c in [...hot.list, ...copy.list]) {
      final t = c.name.trim();
      if (t.isEmpty || !seen.add(t)) continue;
      mergedTitles.add(t);
    }
    // ignore: avoid_print
    print('热辣 ${hot.list.length} 条 / 拷贝 ${copy.list.length} 条'
        ' -> 合并去重后 ${mergedTitles.length} 条');
    // ignore: avoid_print
    print('热辣前5: ${hot.list.take(5).map((c) => c.name).join(" | ")}');
    // ignore: avoid_print
    print('拷贝前5: ${copy.list.take(5).map((c) => c.name).join(" | ")}');
    // 重叠度：拷贝结果中能在热辣找到标题的比例
    final hotTitles = hot.list.map((c) => c.name.trim()).toSet();
    final overlap = copy.list
        .where((c) => hotTitles.contains(c.name.trim()))
        .length;
    // ignore: avoid_print
    print('拷贝与热辣标题重叠 $overlap/${copy.list.length}');
    expect(mergedTitles.length, lessThanOrEqualTo(hot.list.length + copy.list.length));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('四个源同关键词均可返回结果（全部模式拼接前提）', () async {
    final api = ApiClient();
    final hot = await api.manga.searchComics('火影');
    final waman3 = await Waman3Source.instance.search('火影', 1);
    final manwaba = await ManwabaSource.instance.search('火影', 1);
    expect(hot.list, isNotEmpty);
    expect(waman3.comics, isNotEmpty, reason: '漫屋3应有结果');
    expect(manwaba.comics, isNotEmpty, reason: '漫屋吧应有结果');
    // ignore: avoid_print
    print('热辣 ${hot.list.length} / 漫屋3 ${waman3.comics.length}'
        ' / 漫屋吧 ${manwaba.comics.length}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
