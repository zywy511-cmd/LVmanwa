import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DandanplayBindingRecord {
  final String pathWord;
  final String localTitle;
  final String? localUuid;
  final int animeId;
  final String bangumiId;
  final String animeTitle;
  final String? imageUrl;
  final DateTime boundAt;
  final String? alignmentChapterUuid;
  final int? alignmentEpisodeId;

  const DandanplayBindingRecord({
    required this.pathWord,
    required this.localTitle,
    required this.animeId,
    required this.bangumiId,
    required this.animeTitle,
    required this.boundAt,
    this.localUuid,
    this.imageUrl,
    this.alignmentChapterUuid,
    this.alignmentEpisodeId,
  });

  factory DandanplayBindingRecord.fromJson(Map<String, dynamic> json) {
    return DandanplayBindingRecord(
      pathWord: json['pathWord']?.toString() ?? '',
      localTitle: json['localTitle']?.toString() ?? '',
      localUuid: json['localUuid']?.toString(),
      animeId: json['animeId'] as int? ?? 0,
      bangumiId: json['bangumiId']?.toString() ?? '',
      animeTitle: json['animeTitle']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      boundAt:
          DateTime.tryParse(json['boundAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      alignmentChapterUuid: json['alignmentChapterUuid']?.toString(),
      alignmentEpisodeId: _parseInt(json['alignmentEpisodeId']),
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {
    'pathWord': pathWord,
    'localTitle': localTitle,
    if (localUuid != null) 'localUuid': localUuid,
    'animeId': animeId,
    'bangumiId': bangumiId,
    'animeTitle': animeTitle,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'boundAt': boundAt.toIso8601String(),
    if (alignmentChapterUuid != null)
      'alignmentChapterUuid': alignmentChapterUuid,
    if (alignmentEpisodeId != null) 'alignmentEpisodeId': alignmentEpisodeId,
  };

  bool get hasAlignment =>
      alignmentChapterUuid != null && alignmentEpisodeId != null;

  DandanplayBindingRecord withAlignment({
    required String chapterUuid,
    required int episodeId,
  }) {
    return DandanplayBindingRecord(
      pathWord: pathWord,
      localTitle: localTitle,
      localUuid: localUuid,
      animeId: animeId,
      bangumiId: bangumiId,
      animeTitle: animeTitle,
      imageUrl: imageUrl,
      boundAt: boundAt,
      alignmentChapterUuid: chapterUuid,
      alignmentEpisodeId: episodeId,
    );
  }

  DandanplayBindingRecord withoutAlignment() {
    return DandanplayBindingRecord(
      pathWord: pathWord,
      localTitle: localTitle,
      localUuid: localUuid,
      animeId: animeId,
      bangumiId: bangumiId,
      animeTitle: animeTitle,
      imageUrl: imageUrl,
      boundAt: boundAt,
    );
  }
}

class DandanplayBindingStore {
  static const _prefix = 'dandanplay_binding_';

  String _key(String pathWord) =>
      '$_prefix${Uri.encodeComponent(pathWord.trim())}';

  Future<DandanplayBindingRecord?> getByPathWord(String pathWord) async {
    if (pathWord.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(pathWord));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DandanplayBindingRecord.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(DandanplayBindingRecord record) async {
    if (record.pathWord.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(record.pathWord), jsonEncode(record.toJson()));
  }

  Future<void> removeByPathWord(String pathWord) async {
    if (pathWord.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(pathWord));
  }
}
