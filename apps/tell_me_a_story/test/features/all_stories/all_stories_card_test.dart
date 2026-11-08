import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/all_stories/all_stories_card.dart';

void main() {
  test('dim ink is the albumDimInk token (ink at 70% on parchment)', () {
    expect(allStoriesDimInk().toARGB32(), albumDimInk.toARGB32());
  });
}
