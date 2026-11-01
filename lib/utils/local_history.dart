import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/comic.dart' hide Theme;

/// 本地浏览记录条目
class LocalHistoryItem {
  final String pathWord;
  final String name;
  final String cover;
  final String sourceKey;
  final String sourceName;
  final String? chapterName;
  final int? page;
  final DateTime viewedAt;

  const LocalHistoryItem({
    required this.pathWord,
    required this.name,
    required this.cover,
    required this.sourceKey,
    required this.sourceName,
    this.chapterName,
    this.page,
    required this.viewedAt,
  });

  Map<String, dynamic> toJson() => {
    'pathWord': pathWord,
    'name': name,
    'cover': cover,
    'sourceKey': sourceKey,
    'sourceName': sourceName,
    'chapterName': chapterName,
    'page': page,
    'viewedAt': viewedAt.toIso8601String(),
  };

  factory LocalHistoryItem.fromJson(Map<String, dynamic> json) =>
      LocalHistoryItem(
        pathWord: json['pathWord'] as String,
        name: json['name'] as String,
        cover: json['cover'] as String? ?? '',
        sourceKey: json['sourceKey'] as String? ?? '',
        sourceName: json['sourceName'] as String? ?? '',
        chapterName: json['chapterName'] as String?,
        page: json['page'] as int?,
        viewedAt: DateTime.parse(json['viewedAt'] as String),
      );

  Comic toComic() => Comic(
    name: name,
    pathWord: pathWord,
    cover: cover,
    authors: const [],
  );
}

/// 本地浏览记录管理（基于 SharedPreferences）
class LocalHistory {
  LocalHistory._();
  static final LocalHistory instance = LocalHistory._();

  static const _key = 'local_history_v1';
  static const _maxCount = 200; // 最多保存200条

  Future<List<LocalHistoryItem>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => LocalHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<LocalHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    // 只保留最新的 _maxCount 条
    if (items.length > _maxCount) {
      items = items.sublist(0, _maxCount);
    }
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// 获取全部浏览记录（按时间倒序）
  Future<List<LocalHistoryItem>> getAll() async {
    final list = await _loadAll();
    list.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return list;
  }

  /// 添加/更新浏览记录（同一漫画只保留最新一条）
  Future<void> add(LocalHistoryItem item) async {
    final list = await _loadAll();
    // 移除已存在的同 pathWord 记录
    list.removeWhere((e) => e.pathWord == item.pathWord);
    // 新记录插到最前面
    list.insert(0, item);
    await _saveAll(list);
  }

  /// 删除单条记录
  Future<bool> remove(String pathWord) async {
    final list = await _loadAll();
    final before = list.length;
    list.removeWhere((e) => e.pathWord == pathWord);
    if (list.length == before) return false;
    await _saveAll(list);
    return true;
  }

  /// 清空所有记录
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// 记录数量
  Future<int> count() async {
    final list = await _loadAll();
    return list.length;
  }
}
