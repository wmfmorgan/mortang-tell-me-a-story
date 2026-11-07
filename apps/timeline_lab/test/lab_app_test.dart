import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/renderers/painter_rail_renderer.dart';
import 'package:timeline_lab/renderers/render_box_layout_renderer.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/sliver_list_renderer.dart';
import 'package:timeline_lab/renderers/swimlanes_renderer.dart';
import 'package:timeline_lab/renderers/tree_graph_renderer.dart';
import 'package:timeline_lab/renderers/treemap_renderer.dart';
import 'package:timeline_lab/renderers/zoom_canvas_renderer.dart';

Future<LabController> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = LabController();
  addTearDown(c.dispose);
  await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
  await tester.pumpAndSettle();
  return c;
}

int _matches(LabController c, TimelineFilter f) =>
    applyFilter(c.dataset, f).where((e) => e.matched).length;

void main() {
  testWidgets('search updates the status line', (tester) async {
    final c = await _pump(tester);
    expect(find.text('120 stories'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('filter-search')), 'esther');
    await tester.pumpAndSettle();
    final n = _matches(c, const TimelineFilter(query: 'esther'));
    expect(n, greaterThan(0));
    expect(find.text('$n of 120 stories match'), findsOneWidget);

    final clear = find.byKey(const Key('filter-clear'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('120 stories'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('filter-search')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('person chips + era give the same count as applyFilter', (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const Key('filter-person-p-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-person-p-4')));
    await tester.pumpAndSettle();
    c.setFilter(c.filter.copyWith(fromYear: () => 1950, toYear: () => 1999));
    await tester.pumpAndSettle();

    final n = _matches(
      c,
      const TimelineFilter(
        personIds: {'p-1', 'p-4'},
        fromYear: 1950,
        toYear: 1999,
      ),
    );
    expect(find.text('$n of 120 stories match'), findsOneWidget);

    // Hide keeps the count; it only drops non-matches from the renderer.
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(c.filter.mode, FilterMode.hide);
    expect(c.entries, hasLength(n));
    expect(find.text('$n of 120 stories match'), findsOneWidget);
  });

  testWidgets('renderer picker switches the renderer', (tester) async {
    await _pump(tester);
    const roots = {
      RendererKind.sliverList: SliverListTimeline,
      RendererKind.painterRail: PainterRailTimeline,
      RendererKind.renderBoxLayout: RenderBoxTimeline,
      RendererKind.zoomCanvas: ZoomCanvasTimeline,
      RendererKind.swimlanes: SwimlanesTimeline,
      RendererKind.treeGraph: TreeGraphTimeline,
      RendererKind.treemap: TreemapTimeline,
    };
    for (final kind in [
      ...RendererKind.values.skip(1),
      RendererKind.values.first,
    ]) {
      await tester.tap(find.byKey(const Key('renderer-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kind.label).last);
      await tester.pumpAndSettle();
      for (final MapEntry(key: k, value: type) in roots.entries) {
        expect(find.byType(type), k == kind ? findsOneWidget : findsNothing);
      }
    }
  });

  testWidgets('tapping a sliver card opens the selected-story panel', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(find.byKey(const Key('selected-panel')), findsNothing);
    final newest = c.dataset.stories.last;
    await tester.tap(find.byKey(Key('card-${newest.id}')));
    await tester.pumpAndSettle();
    expect(c.selectedStoryId, newest.id);
    expect(find.byKey(const Key('selected-panel')), findsOneWidget);
    expect(find.text(newest.body), findsOneWidget);

    await tester.tap(find.byKey(const Key('selected-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('selected-panel')), findsNothing);
  });

  testWidgets('dragging the era brush filters; full range clears it', (
    tester,
  ) async {
    final c = await _pump(tester);
    final era = find.byKey(const Key('filter-era'));
    final box = tester.getRect(era);
    // Start thumb sits at the left end of the track (24px overlay inset).
    final start = Offset(box.left + 24, box.center.dy);
    await tester.dragFrom(start, const Offset(80, 0));
    await tester.pumpAndSettle();
    final from = c.filter.fromYear;
    expect(from, isNotNull);
    expect(from, greaterThan(c.dataset.minYear));
    expect(c.filter.toYear, isNull, reason: 'end thumb untouched → open');
    expect(
      find.text('${_matches(c, c.filter)} of 120 stories match'),
      findsOneWidget,
    );

    await tester.dragFrom(start + const Offset(80, 0), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(c.filter.fromYear, isNull);
    expect(c.filter.isActive, isFalse);
  });

  Set<LaneBy> laneBy(WidgetTester tester) => tester
      .widget<SegmentedButton<LaneBy>>(find.byKey(const Key('lane-by')))
      .selected;

  Finder familiesSegment() => find.descendant(
    of: find.byKey(const Key('lane-by')),
    matching: find.text('Families'),
  );

  testWidgets('renderer state survives the 900px breakpoint', (tester) async {
    final c = await _pump(tester);
    c.setRenderer(RendererKind.swimlanes);
    await tester.pumpAndSettle();
    await tester.tap(familiesSegment());
    await tester.pumpAndSettle();
    expect(laneBy(tester), {LaneBy.family});

    tester.view.physicalSize = const Size(700, 900);
    await tester.pumpAndSettle();
    expect(find.text('Filters'), findsOneWidget); // narrow layout
    expect(laneBy(tester), {LaneBy.family});
  });

  testWidgets('changing dataset size resets renderer state', (tester) async {
    final c = await _pump(tester);
    c.setRenderer(RendererKind.swimlanes);
    await tester.pumpAndSettle();
    await tester.tap(familiesSegment());
    await tester.pumpAndSettle();
    c.setDatasetSize(1000);
    await tester.pumpAndSettle();
    expect(laneBy(tester), {LaneBy.person});
  });

  group('playback', () {
    String caption(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('playback-caption'))).data!;

    testWidgets('play reveals over time; stop shows everything again', (
      tester,
    ) async {
      final c = await _pump(tester);
      c.setRenderer(RendererKind.painterRail);
      await tester.pumpAndSettle();
      expect(caption(tester), 'Press play to replay the timeline');
      expect(find.byKey(const Key('playback-watermark')), findsNothing);

      await tester.tap(find.byKey(const Key('playback-play')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
      expect(pb.playing, isTrue);
      final revealed = pb.revealedCount;
      expect(revealed, inExclusiveRange(0, 120));
      expect(caption(tester), '${pb.cursorYear!.floor()} · $revealed of 120');
      expect(
        find.text('${pb.cursorYear!.floor()}'),
        findsWidgets, // watermark (and possibly an axis label)
      );
      expect(find.byKey(const Key('playback-watermark')), findsOneWidget);

      await tester.tap(find.byKey(const Key('playback-stop')));
      await tester.pump();
      expect(pb.active, isFalse);
      expect(find.byKey(const Key('playback-watermark')), findsNothing);
      expect(caption(tester), 'Press play to replay the timeline');
    });

    testWidgets(
      'steps: next shows the oldest story, hidden cards ignore taps',
      (tester) async {
        final c = await _pump(tester);
        final oldest = c.entries.first.story;
        final newest = c.entries.last.story;
        await tester.tap(find.byKey(const Key('playback-next')));
        await tester.pump();
        expect(
          caption(tester),
          '${c.dataset.dateLabel(oldest)} · ${oldest.title} · 1 of 120',
        );
        // Camera follow left the newest card unbuilt or invisible; either way
        // it can't be selected until revealed.
        final newestCard = find.byKey(Key('card-${newest.id}'));
        if (newestCard.evaluate().isNotEmpty) {
          await tester.tap(newestCard, warnIfMissed: false);
          await tester.pump();
        }
        expect(c.selectedStoryId, isNull);
      },
    );

    testWidgets('dragging the timeline turns camera follow off', (
      tester,
    ) async {
      final c = await _pump(tester);
      c.setRenderer(RendererKind.swimlanes);
      await tester.pumpAndSettle();
      final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
      pb.seek(1);
      await tester.pump();
      expect(pb.follow, isTrue);
      await tester.drag(find.byType(LaneGridView), const Offset(200, 0));
      await tester.pump();
      expect(pb.follow, isFalse);
    });
  });
}
