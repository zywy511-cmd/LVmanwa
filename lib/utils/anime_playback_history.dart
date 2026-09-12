import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 本地动漫播放记录，按作品和剧集保存播放进度及弹幕来源绑定。
class AnimePlaybackHistory {
  static const _prefix = 'anime_playback_history_';

  static String _key(String pathWord, String chapterUuid) =>
      '$_prefix${Uri.encodeComponent(pathWord)}_${Uri.encodeComponent(chapterUuid)}';

  static bool _isValidKey(String pathWord, String chapterUuid) =>
      pathWord.trim().isNotEmpty && chapterUuid.trim().isNotEmpty;

  static Future<AnimePlaybackRecord?> get({
    required String pathWord,
    required String chapterUuid,
  }) async {
    if (!_isValidKey(pathWord, chapterUuid)) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(pathWord, chapterUuid));
    if (raw == null || raw.isEmpty) return null;
    return _decode(raw);
  }

  static Future<AnimePlaybackRecord?> latestProgressForAnime({
    required String pathWord,
    Duration minPosition = const Duration(seconds: 3),
  }) async {
    final records = await progressRecordsForAnime(
      pathWord: pathWord,
      minPosition: minPosition,
    );
    if (records.isEmpty) return null;

    records.sort((a, b) {
      final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return records.first;
  }

  static Future<List<AnimePlaybackRecord>> progressRecordsForAnime({
    required String pathWord,
    Duration minPosition = const Duration(seconds: 3),
  }) async {
    if (pathWord.trim().isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = '$_prefix${Uri.encodeComponent(pathWord)}_';
    return prefs
        .getKeys()
        .where((key) => key.startsWith(keyPrefix))
        .map((key) => prefs.getString(key))
        .whereType<String>()
        .map(_decode)
        .whereType<AnimePlaybackRecord>()
        .where((record) => record.position >= minPosition)
        .toList();
  }

  static Future<void> saveProgress({
    required String pathWord,
    required String chapterUuid,
    required String chapterName,
    required Duration position,
    required Duration duration,
  }) async {
    if (!_isValidKey(pathWord, chapterUuid)) return;
    final existing = await get(pathWord: pathWord, chapterUuid: chapterUuid);
    await _save(
      pathWord: pathWord,
      chapterUuid: chapterUuid,
      record: AnimePlaybackRecord(
        chapterUuid: chapterUuid,
        chapterName: chapterName,
        position: position,
        duration: duration,
        danmakuEpisodeId: existing?.danmakuEpisodeId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> saveDanmakuEpisode({
    required String pathWord,
    required String chapterUuid,
    required String chapterName,
    required int episodeId,
  }) async {
    if (!_isValidKey(pathWord, chapterUuid)) return;
    final existing = await get(pathWord: pathWord, chapterUuid: chapterUuid);
    await _save(
      pathWord: pathWord,
      chapterUuid: chapterUuid,
      record: AnimePlaybackRecord(
        chapterUuid: chapterUuid,
        chapterName: chapterName,
        position: existing?.position ?? Duration.zero,
        duration: existing?.duration ?? Duration.zero,
        danmakuEpisodeId: episodeId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> clearDanmakuEpisode({
    required String pathWord,
    required String chapterUuid,
    required String chapterName,
  }) async {
    if (!_isValidKey(pathWord, chapterUuid)) return;
    final existing = await get(pathWord: pathWord, chapterUuid: chapterUuid);
    if (existing == null) return;
    if (existing.position == Duration.zero &&
        existing.duration == Duration.zero) {
      await remove(pathWord: pathWord, chapterUuid: chapterUuid);
      return;
    }
    await _save(
      pathWord: pathWord,
      chapterUuid: chapterUuid,
      record: AnimePlaybackRecord(
        chapterUuid: chapterUuid,
        chapterName: chapterName,
        position: existing.position,
        duration: existing.duration,
        updatedAt: DateTime.now(),
      ),
    );
  }

  static Future<void> remove({
    required String pathWord,
    required String chapterUuid,
  }) async {
    if (!_isValidKey(pathWord, chapterUuid)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(pathWord, chapterUuid));
  }

  static Future<void> _save({
    required String pathWord,
    required String chapterUuid,
    required AnimePlaybackRecord record,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(pathWord, chapterUuid), jsonEncode(record));
  }

  static AnimePlaybackRecord? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      return AnimePlaybackRecord(
        chapterUuid: map['chapterUuid']?.toString() ?? '',
        chapterName: map['chapterName']?.toString() ?? '',
        position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
        duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
        danmakuEpisodeId: map['danmakuEpisodeId'] as int?,
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}

class AnimePlaybackRecord {
  final String chapterUuid;
  final String chapterName;
  final Duration position;
  final Duration duration;
  final int? danmakuEpisodeId;
  final DateTime? updatedAt;

  const AnimePlaybackRecord({
    required this.chapterUuid,
    required this.chapterName,
    required this.position,
    required this.duration,
    this.danmakuEpisodeId,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'chapterUuid': chapterUuid,
    'chapterName': chapterName,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    if (danmakuEpisodeId != null) 'danmakuEpisodeId': danmakuEpisodeId,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };
}
