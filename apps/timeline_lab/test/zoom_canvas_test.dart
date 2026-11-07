import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/story_marker.dart';
import 'package:timeline_lab/renderers/zoom_canvas_renderer.dart';
import 'package:timeline_lab/theme/lab_theme.dart';
import 'package:timeline_lab/widgets/story_card.dart';

Future<LabController> _pump(
  WidgetTester tester,
  double scale, {
  int size = 1000,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = LabController(datasetSize: size);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: labTheme(useGoogleFonts: false),
      home: Scaffold(
        body: ZoomCanvasTimeline(
          initialScale: scale,
          data: TimelineViewData(
            dataset: c.dataset,
            entries: c.entries,
            mode: c.filter.mode,
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

void main() {
  test('lodForScale thresholds', () {
    expect(lodForScale(1.49), ZoomLod.decades);
    expect(lodForScale(1.5), ZoomLod.years);
    expect(lodForScale(5.99), ZoomLod.years);
    expect(lodForScale(6), ZoomLod.cards);
  });

  testWidgets('cards LOD builds only visible cards', (tester) async {
    final c = await _pump(tester, 10);
    final built = find.byType(StoryCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(c.entries.length ~/ 10));
  });

  for (final size in [1000, 5000]) {
    testWidgets('cards stay inside the world and their lane band ($size)', (
      tester,
    ) async {
      final c = await _pump(tester, 6, size: size);
      final tc = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final origin = tester.getTopLeft(find.byType(InteractiveViewer));
      final viewport = tester.getSize(find.byType(InteractiveViewer));
      final visible = Rect.fromPoints(
        tc.toScene(Offset.zero),
        tc.toScene(viewport.bottomRight(Offset.zero)),
      );
      final lanes = familyLaneOrder(c.dataset);
      final cards = find.byType(StoryCard).evaluate().toList();
      expect(cards, isNotEmpty);
      for (final el in cards) {
        final card = el.widget as StoryCard;
        final screen = tester.getRect(find.byWidget(card));
        final scene = Rect.fromPoints(
          tc.toScene(screen.topLeft - origin),
          tc.toScene(screen.bottomRight - origin),
        );
        final laneTop = zoomLaneY(lanes.indexOf(card.story.familyId));
        expect(scene.top, greaterThanOrEqualTo(laneTop - 1e-6));
        expect(scene.bottom, lessThanOrEqualTo(laneTop + laneGap + 1e-6));
        expect(scene.bottom, lessThanOrEqualTo(480 + 1e-6));
        // Culling: nothing is built for a lane that's entirely off screen.
        expect(laneTop + laneGap, greaterThan(visible.top));
        expect(laneTop - laneGap * 0.25, lessThan(visible.bottom));
      }
    });
  }

  testWidgets('tapping a decade bubble zooms to 2x', (tester) async {
    await _pump(tester, 1);
    expect(_scale(tester), closeTo(1, 1e-9));
    await tester.tap(find.byKey(const Key('decade-bubble-2000')));
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(2, 1e-6));
    expect(find.byKey(const Key('decade-bubble-2000')), findsNothing);
  });
}
