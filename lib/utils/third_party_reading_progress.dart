import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 第三方漫源（漫屋3/漫屋吧）阅读进度本地存储。
///
/// 按 `sourceKey:comicId` 维度记录最近阅读的章节下标与图片页码，
/// 供详情页「继续阅读」断点续读。
class ThirdPartyReadingProgress {
  ThirdPartyReadingProgress._();

  static const _prefix = 'tp_reading_progress_';

  static String _key(String sourceKey, String comicId) =>
      '$_prefix$sourceKey:$comicId';

  /// 读取进度；无记录返回 null。
  static Future<ThirdPartyProgressRecord?> read(
    String sourceKey,
    String comicId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sourceKey, comicId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ThirdPartyProgressRecord(
        chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 0,
        page: (map['page'] as num?)?.toInt() ?? 1,
        totalPages: (map['totalPages'] as num?)?.toInt() ?? 0,
        chapterName: map['chapterName'] as String? ?? '',
        updatedAt: map['updatedAt'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// 保存进度。
  static Future<void> save({
    required String sourceKey,
    required String comicId,
    required int chapterIndex,
    required int page,
    required int totalPages,
    required String chapterName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(sourceKey, comicId),
      jsonEncode({
        'chapterIndex': chapterIndex,
        'page': page,
        'totalPages': totalPages,
        'chapterName': chapterName,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// 清除进度（章节全部读完等场景可调用）。
  static Future<void> clear(String sourceKey, String comicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(sourceKey, comicId));
  }
}

class ThirdPartyProgressRecord {
  final int chapterIndex;
  final int page;
  final int totalPages;
  final String chapterName;
  final String updatedAt;

  const ThirdPartyProgressRecord({
    required this.chapterIndex,
    required this.page,
    required this.totalPages,
    required this.chapterName,
    required this.updatedAt,
  });
}
