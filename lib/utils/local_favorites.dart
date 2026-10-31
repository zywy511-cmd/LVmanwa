import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/comic.dart' hide Theme;

/// 本地收藏条目
class LocalFavoriteItem {
  final String pathWord;
  final String name;
  final String cover;
  final String sourceKey;
  final String sourceName;
  final String? author;
  final DateTime addedAt;

  const LocalFavoriteItem({
    required this.pathWord,
    required this.name,
    required this.cover,
    required this.sourceKey,
    required this.sourceName,
    this.author,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'pathWord': pathWord,
    'name': name,
    'cover': cover,
    'sourceKey': sourceKey,
    'sourceName': sourceName,
    'author': author,
    'addedAt': addedAt.toIso8601String(),
  };

  factory LocalFavoriteItem.fromJson(Map<String, dynamic> json) =>
      LocalFavoriteItem(
        pathWord: json['pathWord'] as String,
        name: json['name'] as String,
        cover: json['cover'] as String? ?? '',
        sourceKey: json['sourceKey'] as String? ?? '',
        sourceName: json['sourceName'] as String? ?? '',
        author: json['author'] as String?,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );

  Comic toComic() => Comic(
    name: name,
    pathWord: pathWord,
    cover: cover,
    authors: author == null || author!.isEmpty
        ? const []
        : [Author(name: author!, pathWord: '')],
  );
}

/// 本地收藏管理（基于 SharedPreferences）
class LocalFavorites {
  LocalFavorites._();
  static final LocalFavorites instance = LocalFavorites._();

  static const _key = 'local_favorites_v1';

  Future<List<LocalFavoriteItem>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map>()
          .map((e) => LocalFavoriteItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(List<LocalFavoriteItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  /// 获取全部收藏（按添加时间倒序）
  Future<List<LocalFavoriteItem>> getAll() async {
    final list = await _loadAll();
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  /// 判断是否已收藏
  Future<bool> isFavorite(String pathWord) async {
    final list = await _loadAll();
    return list.any((e) => e.pathWord == pathWord);
  }

  /// 添加收藏，返回是否成功
  Future<bool> add(LocalFavoriteItem item) async {
    final list = await _loadAll();
    if (list.any((e) => e.pathWord == item.pathWord)) return false;
    list.add(item);
    await _saveAll(list);
    return true;
  }

  /// 删除收藏
  Future<bool> remove(String pathWord) async {
    final list = await _loadAll();
    final before = list.length;
    list.removeWhere((e) => e.pathWord == pathWord);
    if (list.length == before) return false;
    await _saveAll(list);
    return true;
  }

  /// 切换收藏状态，返回切换后是否已收藏
  Future<bool> toggle(LocalFavoriteItem item) async {
    final list = await _loadAll();
    final idx = list.indexWhere((e) => e.pathWord == item.pathWord);
    if (idx >= 0) {
      list.removeAt(idx);
      await _saveAll(list);
      return false;
    } else {
      list.add(item);
      await _saveAll(list);
      return true;
    }
  }

  /// 收藏数量
  Future<int> count() async {
    final list = await _loadAll();
    return list.length;
  }
}
