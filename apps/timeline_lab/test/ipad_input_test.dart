import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/swimlanes_renderer.dart';
import 'package:timeline_lab/renderers/tree_graph_renderer.dart';
import 'package:timeline_lab/renderers/treemap_renderer.dart';
import 'package:timeline_lab/renderers/zoom_canvas_renderer.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

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

  group('zoom canvas', () {
    testWidgets('a finger 15px off a years-level dot selects it', (
      tester,
    ) async {
      setIpadView(tester, ipadSizes['mini_portrait']!, dpr: 1);
      final c = LabController();
      addTearDown(c.dispose);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: labTheme(useGoogleFonts: false),
          home: Scaffold(
            body: ZoomCanvasTimeline(
              initialScale: 3,
              data: TimelineViewData(
                dataset: c.dataset,
                entries: c.entries,
                mode: c.filter.mode,
                selectedId: null,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dots = find
          .descendant(
            of: find.byType(ZoomCanvasTimeline),
            matching: find.byWidgetPredicate(
              (w) => w is GestureDetector && w.key == null && w.onTap != null,
            ),
          )
          .evaluate()
          .toList();
      final centers = [
        for (final e in dots)
          tester.getCenter(find.byElementPredicate((x) => x == e)),
      ];
      final view = tester.getRect(find.byType(ZoomCanvasTimeline)).deflate(30);
      final i = centers.indexWhere(
        (p) =>
            view.contains(p) &&
            centers.every((q) => q == p || (q - p).distance > 60),
      );
      final id =
          (dots[i].findAncestorWidgetOfExactType<Positioned>()!.key!
                  as ValueKey<String>)
              .value;
      await tester.tapAt(centers[i] + const Offset(0, 15));
      await tester.pump();
      expect(selected, id);
    });
  });
  group('swimlanes', () {
    testWidgets('a multi-story cell opens the chooser', (tester) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['mini_portrait']!,
        kind: RendererKind.swimlanes,
      );
      final multi = find
          .byWidgetPredicate((w) => w is LaneCell && w.entries.length > 1)
          .hitTestable()
          .first;
      final cell = tester.widget<LaneCell>(multi);
      await tester.tap(multi);
      await tester.pumpAndSettle();
      expect(
        find.byType(PopupMenuItem<String>),
        findsNWidgets(cell.entries.length),
      );
      final second = cell.entries[1].story.id;
      await tester.tap(find.byKey(Key('chooser-$second')));
      await tester.pumpAndSettle();
      expect(c.selectedStoryId, second);
    }, variant: ios);
  });
  group('treemap', () {
    Future<TreemapCellTile> smallCell(WidgetTester tester) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['split_half']!,
        kind: RendererKind.treemap,
        dpr: 1,
      );
      c.setDatasetSize(1000);
      await tester.pumpAndSettle();
      return find.byType(TreemapCellTile).evaluate().firstWhere((e) {
            final s = (e.renderObject! as RenderBox).size;
            return s.width < LabTarget.min || s.height < LabTarget.min;
          }).widget
          as TreemapCellTile;
    }

    testWidgets('finger on a tiny cell opens its group', (tester) async {
      final tile = await smallCell(tester);
      await tester.tapAt(tester.getCenter(find.byWidget(tile)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('treemap-crumb-group')), findsOneWidget);
      expect(
        find.byKey(Key('treemap-story-${tile.cell.entries.first.story.id}')),
        findsNothing,
      );
    }, variant: ios);

    testWidgets('mouse on a tiny cell opens the cell', (tester) async {
      final tile = await smallCell(tester);
      await tester.tapAt(
        tester.getCenter(find.byWidget(tile)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('treemap-story-${tile.cell.entries.first.story.id}')),
        findsOneWidget,
      );
    }, variant: ios);
  });
}
