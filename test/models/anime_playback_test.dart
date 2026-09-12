import 'package:flutter_test/flutter_test.dart';
import 'package:kira/models/anime.dart';

void main() {
  test('AnimePlayback serializes enough data for video link cache', () {
    const playback = AnimePlayback(
      anime: Anime(name: 'Anime', pathWord: 'anime', cover: 'cover.jpg'),
      chapter: AnimePlaybackChapter(
        count: 1,
        name: '第1集',
        cover: 'chapter.jpg',
        vid: 'vid-1',
        video: 'https://example.com/video.m3u8',
        uuid: 'chapter-1',
        lines: {
          'line-a': AnimeChapterLine(
            name: '线路A',
            pathWord: 'line-a',
            config: true,
          ),
        },
        videoList: ['https://example.com/fallback.m3u8'],
        vCover: 'v-cover.jpg',
      ),
      isLogin: true,
      isMobileBind: false,
      isVip: false,
      isLock: false,
    );

    final decoded = AnimePlayback.fromJson(playback.toJson());

    expect(decoded.anime.pathWord, 'anime');
    expect(decoded.chapter.video, 'https://example.com/video.m3u8');
    expect(decoded.chapter.videoList, ['https://example.com/fallback.m3u8']);
    expect(decoded.chapter.lines['line-a']?.name, '线路A');
    expect(decoded.isLogin, isTrue);
  });
}
