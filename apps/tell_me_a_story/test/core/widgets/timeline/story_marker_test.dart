import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/widgets/timeline/story_marker.dart';

Story _story(String id) => Story(
  id: id,
  familyId: 'root',
  authorId: 'u1',
  timeframeStart: DateTime(1975, 8, 9),
  status: StoryStatus.published,
);

void main() {
  test('origin ring leaves a gap around the dot', () {
    const m = MarkerSpec(matched: true, origin: true);
    expect(
      m.originRadius - AlbumMarker.ring / 2 - m.dotRadius,
      AlbumMarker.gap,
    );
  });

  test('selection ring clears the origin ring', () {
    const m = MarkerSpec(matched: true, origin: true, selected: true);
    expect(
      m.selectedRadius - AlbumMarker.ring / 2,
      greaterThan(m.originRadius + AlbumMarker.ring / 2),
    );
    expect(
      2 * (m.selectedRadius + AlbumMarker.ring / 2),
      lessThanOrEqualTo(MarkerSpec.extent(m.diameter)),
    );
  });

  testWidgets('StoryDot keeps one size in every state', (tester) async {
    for (final spec in const [
      MarkerSpec(matched: true),
      MarkerSpec(matched: false, origin: true, selected: true),
    ]) {
      await tester.pumpWidget(Center(child: StoryDot(spec: spec)));
      expect(
        tester.getSize(find.byType(StoryDot)),
        Size.square(MarkerSpec.extent(AlbumMarker.dot)),
      );
    }
  });

  test('a story is an origin when some branch starts at it', () {
    const families = [
      TreeFamily(id: 'root', name: 'Jenkins'),
      TreeFamily(
        id: 'bea',
        name: 'Bea',
        parentFamilyId: 'root',
        originStoryId: 's1975',
        branchYear: 1975,
      ),
    ];
    expect(isOrigin(_story('s1975'), families), isTrue);
    expect(isOrigin(_story('s1952'), families), isFalse);
  });
}
