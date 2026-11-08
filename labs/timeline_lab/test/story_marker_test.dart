import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/story_marker.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

void main() {
  test('origin ring leaves a gap around the dot', () {
    const m = MarkerSpec(matched: true, origin: true);
    expect(m.originRadius - LabMarker.ring / 2 - m.dotRadius, LabMarker.gap);
  });

  test('selection ring clears the origin ring', () {
    const m = MarkerSpec(matched: true, origin: true, selected: true);
    expect(
      m.selectedRadius - LabMarker.ring / 2,
      greaterThan(m.originRadius + LabMarker.ring / 2),
    );
    expect(
      2 * (m.selectedRadius + LabMarker.ring / 2),
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
        Size.square(MarkerSpec.extent(LabMarker.dot)),
      );
    }
  });
}
