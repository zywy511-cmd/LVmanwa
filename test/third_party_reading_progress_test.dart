import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/utils/third_party_reading_progress.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('进度为空时返回 null', () async {
    final record = await ThirdPartyReadingProgress.read('waman3', '322501');
    expect(record, isNull);
  });

  test('保存后可读取，且按 sourceKey:comicId 隔离', () async {
    await ThirdPartyReadingProgress.save(
      sourceKey: 'waman3',
      comicId: '322501',
      chapterIndex: 2,
      page: 15,
      totalPages: 74,
      chapterName: '第3话',
    );
    final record = await ThirdPartyReadingProgress.read('waman3', '322501');
    expect(record, isNotNull);
    expect(record!.chapterIndex, 2);
    expect(record.page, 15);
    expect(record.totalPages, 74);
    expect(record.chapterName, '第3话');
    expect(record.updatedAt, isNotEmpty);

    // 不同 comicId 不串
    final other = await ThirdPartyReadingProgress.read('waman3', '999');
    expect(other, isNull);
    // 不同源不串
    final otherSource = await ThirdPartyReadingProgress.read('manwaba', '322501');
    expect(otherSource, isNull);
  });

  test('覆盖更新与清除', () async {
    await ThirdPartyReadingProgress.save(
      sourceKey: 'waman3',
      comicId: '322501',
      chapterIndex: 1,
      page: 1,
      totalPages: 74,
      chapterName: '第2话',
    );
    await ThirdPartyReadingProgress.save(
      sourceKey: 'waman3',
      comicId: '322501',
      chapterIndex: 3,
      page: 30,
      totalPages: 74,
      chapterName: '第4话',
    );
    final record = await ThirdPartyReadingProgress.read('waman3', '322501');
    expect(record!.chapterIndex, 3);
    expect(record.page, 30);

    await ThirdPartyReadingProgress.clear('waman3', '322501');
    expect(await ThirdPartyReadingProgress.read('waman3', '322501'), isNull);
  });
}
