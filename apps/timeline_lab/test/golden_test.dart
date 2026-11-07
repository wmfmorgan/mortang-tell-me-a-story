import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/zoom_canvas_renderer.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

const _scenarioFilter = TimelineFilter(
  personIds: {'p-1', 'p-4'},
  fromYear: 1950,
  toYear: 1999,
);

final _scenarios = <String, TimelineFilter>{
  'all': const TimelineFilter(),
  'dim': _scenarioFilter.copyWith(mode: FilterMode.dim),
  'hide': _scenarioFilter.copyWith(mode: FilterMode.hide),
};

void _surface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final kind in RendererKind.values) {
    for (final MapEntry(key: scenario, value: filter) in _scenarios.entries) {
      testWidgets('golden ${kind.name}_$scenario', (tester) async {
        _surface(tester, const Size(1280, 800));
        final c = LabController()
          ..setRenderer(kind)
          ..setFilter(filter);
        addTearDown(c.dispose);
        await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(LabHome),
          matchesGoldenFile('goldens/${kind.name}_$scenario.png'),
        );
      });
    }
  }

  // Mid-playback in dim mode: the cursor, partial reveal, and unmatched
  // stories appearing dimmed. Each renderer uses its default design.
  for (final kind in RendererKind.values) {
    testWidgets('golden ${kind.name}_playback', (tester) async {
      _surface(tester, const Size(1280, 800));
      final c = LabController()
        ..setRenderer(kind)
        ..setFilter(_scenarios['dim']!);
      addTearDown(c.dispose);
      await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
      await tester.pumpAndSettle();
      final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
      pb.seek(pb.duration * 0.5);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LabHome),
        matchesGoldenFile('goldens/${kind.name}_playback.png'),
      );
    });
  }

  for (final (lod, scale) in [
    ('decades', 1.0),
    ('years', 3.0),
    ('cards', 10.0),
  ]) {
    testWidgets('golden zoomCanvas_lod_$lod', (tester) async {
      _surface(tester, const Size(1280, 800));
      final c = LabController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
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
      await expectLater(
        find.byType(ZoomCanvasTimeline),
        matchesGoldenFile('goldens/zoomCanvas_lod_$lod.png'),
      );
    });
  }

  testWidgets('golden sliverList_narrow', (tester) async {
    _surface(tester, const Size(700, 900));
    final c = LabController();
    addTearDown(c.dispose);
    await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LabHome),
      matchesGoldenFile('goldens/sliverList_narrow.png'),
    );
  });
}
