import 'package:flutter_test/flutter_test.dart';
import 'package:kira/utils/dandanplay_episode_binding.dart';

void main() {
  test('binds sequentially when no current binding exists', () {
    expect(
      inferSequentialDandanplayEpisodeBindings(
        currentEpisodeIds: [null, null, null],
        availableEpisodeIds: [101, 102],
      ),
      [101, 102, null],
    );
  });

  test('fills new tail chapters from the last existing binding', () {
    expect(
      inferSequentialDandanplayEpisodeBindings(
        currentEpisodeIds: [204, 205, 206, null, null],
        availableEpisodeIds: [201, 202, 203, 204, 205, 206, 207, 208],
      ),
      [204, 205, 206, 207, 208],
    );
  });

  test('preserves gaps before the last existing binding', () {
    expect(
      inferSequentialDandanplayEpisodeBindings(
        currentEpisodeIds: [301, null, 303, null],
        availableEpisodeIds: [301, 302, 303, 304],
      ),
      [301, null, 303, 304],
    );
  });

  test('keeps bindings unchanged when the latest anchor is unavailable', () {
    expect(
      inferSequentialDandanplayEpisodeBindings(
        currentEpisodeIds: [401, 999, null],
        availableEpisodeIds: [401, 402, 403],
      ),
      [401, 999, null],
    );
  });
}
