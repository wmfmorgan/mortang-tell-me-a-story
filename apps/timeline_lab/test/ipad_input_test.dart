import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/tree_graph_renderer.dart';

import 'support/ipad.dart';

void main() {
  group('tree graph', () {
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is TreePainter,
    );

    testWidgets('a horizontal drag below a short tree still pans', (
      tester,
    ) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['mini_portrait']!,
        kind: RendererKind.treeGraph,
      );
      c.setFilter(
        TimelineFilter(
          mode: FilterMode.hide,
          query: c.entries.first.story.title,
        ),
      );
      await tester.pumpAndSettle();
      final h = Scrollable.of(
        tester.element(canvas),
        axis: Axis.horizontal,
      ).position;
      final before = h.pixels;
      final r = tester.getRect(rendererRoot);
      await tester.dragFrom(
        r.bottomCenter - const Offset(0, 40),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(h.pixels, greaterThan(before));
    }, variant: ios);
  });
}
