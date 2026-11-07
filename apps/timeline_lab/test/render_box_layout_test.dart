import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/renderers/render_box_layout_renderer.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

void main() {
  testWidgets('cards never overlap per side and never sit above their ideal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final d = generateDataset(storyCount: 30);
    final entries = applyFilter(d, const TimelineFilter());
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: Scaffold(
          body: RenderBoxTimeline(
            data: TimelineViewData(
              dataset: d,
              entries: entries,
              mode: FilterMode.dim,
              selectedId: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final layout = tester.renderObject<RenderTimeAxisLayout>(
      find.byType(TimeAxisLayout),
    );
    final bySide = <AxisSide, List<Rect>>{};
    final lastBottom = <AxisSide, double>{};
    var count = 0;
    layout.visitChildren((child) {
      final box = child as RenderBox;
      final pd = box.parentData! as TimeAxisParentData;
      final rect = pd.offset & box.size;
      final idealTop = pd.idealY - box.size.height / 2;
      // The first card on a side is only bounded by the top edge (y >= 0).
      final prev = lastBottom[pd.side] ?? -8;
      if (rect.top > idealTop + 1e-6) {
        // Pushed down: it must sit exactly one gap below the previous card
        // on its side, never further (no wasted drift).
        expect(rect.top, closeTo(prev + 8, 1e-6));
      } else {
        expect(rect.top, closeTo(idealTop, 1e-6));
      }
      lastBottom[pd.side] = rect.bottom;
      (bySide[pd.side] ??= []).add(rect);
      count++;
    });
    expect(count, 30);
    expect(bySide.keys, containsAll(AxisSide.values));

    for (final rects in bySide.values) {
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '${rects[i]} overlaps ${rects[j]}',
          );
        }
      }
    }

    // All 30 cards are built (non-lazy) and newest sits above oldest.
    final newest = tester.getRect(find.byKey(Key('card-${d.stories.last.id}')));
    final oldest = tester.getRect(
      find.byKey(Key('card-${d.stories.first.id}')),
    );
    expect(newest.top, lessThan(oldest.top));
  });
}
