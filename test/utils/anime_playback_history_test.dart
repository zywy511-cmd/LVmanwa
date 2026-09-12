import 'package:flutter_test/flutter_test.dart';
import 'package:kira/utils/anime_playback_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves progress and preserves danmaku binding', () async {
    await AnimePlaybackHistory.saveProgress(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      position: const Duration(minutes: 10, seconds: 14),
      duration: const Duration(minutes: 24),
    );

    await AnimePlaybackHistory.saveDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      episodeId: 12345,
    );

    var record = await AnimePlaybackHistory.get(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
    );

    expect(record?.position, const Duration(minutes: 10, seconds: 14));
    expect(record?.duration, const Duration(minutes: 24));
    expect(record?.danmakuEpisodeId, 12345);

    await AnimePlaybackHistory.saveProgress(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      position: const Duration(minutes: 11),
      duration: const Duration(minutes: 24),
    );

    record = await AnimePlaybackHistory.get(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
    );

    expect(record?.position, const Duration(minutes: 11));
    expect(record?.danmakuEpisodeId, 12345);
  });

  test('remove deletes one chapter record', () async {
    await AnimePlaybackHistory.saveDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      episodeId: 12345,
    );

    await AnimePlaybackHistory.remove(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
    );

    expect(
      await AnimePlaybackHistory.get(
        pathWord: 'anime-a',
        chapterUuid: 'chapter-3',
      ),
      isNull,
    );
  });

  test('clear danmaku binding preserves progress', () async {
    await AnimePlaybackHistory.saveProgress(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      position: const Duration(minutes: 10),
      duration: const Duration(minutes: 24),
    );
    await AnimePlaybackHistory.saveDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      episodeId: 12345,
    );

    await AnimePlaybackHistory.clearDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
    );

    final record = await AnimePlaybackHistory.get(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
    );

    expect(record?.position, const Duration(minutes: 10));
    expect(record?.duration, const Duration(minutes: 24));
    expect(record?.danmakuEpisodeId, isNull);
  });

  test('clear danmaku binding removes danmaku-only record', () async {
    await AnimePlaybackHistory.saveDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      episodeId: 12345,
    );

    await AnimePlaybackHistory.clearDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
    );

    expect(
      await AnimePlaybackHistory.get(
        pathWord: 'anime-a',
        chapterUuid: 'chapter-3',
      ),
      isNull,
    );
  });

  test('latest progress for anime returns newest non-zero progress', () async {
    await AnimePlaybackHistory.saveProgress(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-1',
      chapterName: '第1集',
      position: const Duration(minutes: 4),
      duration: const Duration(minutes: 24),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await AnimePlaybackHistory.saveDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-2',
      chapterName: '第2集',
      episodeId: 20002,
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await AnimePlaybackHistory.saveProgress(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-3',
      chapterName: '第3集',
      position: const Duration(minutes: 10, seconds: 14),
      duration: const Duration(minutes: 24),
    );

    final record = await AnimePlaybackHistory.latestProgressForAnime(
      pathWord: 'anime-a',
    );

    expect(record?.chapterUuid, 'chapter-3');
    expect(record?.chapterName, '第3集');
    expect(record?.position, const Duration(minutes: 10, seconds: 14));
  });

  test('progress records for anime excludes danmaku-only records', () async {
    await AnimePlaybackHistory.saveProgress(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-1',
      chapterName: '第1集',
      position: const Duration(minutes: 4),
      duration: const Duration(minutes: 24),
    );
    await AnimePlaybackHistory.saveDanmakuEpisode(
      pathWord: 'anime-a',
      chapterUuid: 'chapter-2',
      chapterName: '第2集',
      episodeId: 20002,
    );

    final records = await AnimePlaybackHistory.progressRecordsForAnime(
      pathWord: 'anime-a',
    );

    expect(records.map((record) => record.chapterUuid), ['chapter-1']);
  });
}
