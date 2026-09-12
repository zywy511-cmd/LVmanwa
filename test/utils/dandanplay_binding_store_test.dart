import 'package:flutter_test/flutter_test.dart';
import 'package:kira/utils/dandanplay_binding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves, loads, and removes dandanplay binding', () async {
    final store = DandanplayBindingStore();
    final record = DandanplayBindingRecord(
      pathWord: 'witch_hat_atelier',
      localTitle: '尖帽子的魔法工房',
      localUuid: 'local-uuid',
      animeId: 17305,
      bangumiId: '17305',
      animeTitle: '尖帽子的魔法工房',
      imageUrl:
          'https://assets.anixplayer.net/image/poster/small/17305-e015ff826f34a89ea4253a316299ae00.jpg',
      boundAt: DateTime(2026, 4, 6, 12),
    );

    final alignedRecord = record.withAlignment(
      chapterUuid: 'chapter-1',
      episodeId: 901,
    );

    await store.save(alignedRecord);

    final loaded = await store.getByPathWord('witch_hat_atelier');
    expect(loaded, isNotNull);
    expect(loaded!.pathWord, 'witch_hat_atelier');
    expect(loaded.localTitle, '尖帽子的魔法工房');
    expect(loaded.localUuid, 'local-uuid');
    expect(loaded.animeId, 17305);
    expect(loaded.bangumiId, '17305');
    expect(loaded.animeTitle, '尖帽子的魔法工房');
    expect(loaded.imageUrl, record.imageUrl);
    expect(loaded.hasAlignment, isTrue);
    expect(loaded.alignmentChapterUuid, 'chapter-1');
    expect(loaded.alignmentEpisodeId, 901);

    await store.save(loaded.withoutAlignment());
    final withoutAlignment = await store.getByPathWord('witch_hat_atelier');
    expect(withoutAlignment, isNotNull);
    expect(withoutAlignment!.hasAlignment, isFalse);
    expect(withoutAlignment.alignmentChapterUuid, isNull);
    expect(withoutAlignment.alignmentEpisodeId, isNull);

    await store.removeByPathWord('witch_hat_atelier');

    expect(await store.getByPathWord('witch_hat_atelier'), isNull);
  });
}
