import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/model/lab_models.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/swimlanes_renderer.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

LabStory _s(String id, int year, List<String> people) => LabStory(
  id: id,
  familyId: 'fam-root',
  title: id,
  body: '',
  start: DateTime.utc(year),
  precision: DatePrecision.year,
  createdAt: DateTime.utc(2025),
  placeId: null,
  personIds: people,
  photoCount: 0,
);

void main() {
  test('bucketLanes fans multi-person stories out and keeps untagged', () {
    final d = LabDataset(
      stories: [
        _s('two', 1950, ['p-0', 'p-1']),
        _s('none', 1952, []),
      ],
      people: const {
        'p-0': LabPerson(id: 'p-0', name: 'A'),
        'p-1': LabPerson(id: 'p-1', name: 'B'),
      },
      places: const {},
      families: const {'fam-root': LabFamily(id: 'fam-root', name: 'M')},
    );
    final entries = applyFilter(d, const TimelineFilter());
    final b = bucketLanes(entries, d, LaneBy.person);
    expect(laneKeys(d, LaneBy.person), ['p-0', 'p-1', untaggedLane]);
    expect(b[(0, 0)]!.single.story.id, 'two');
    expect(b[(1, 0)]!.single.story.id, 'two');
    expect(b[(2, 2)]!.single.story.id, 'none');
    expect(b, hasLength(3));

    final byFamily = bucketLanes(entries, d, LaneBy.family);
    expect(byFamily[(0, 0)]!.single.story.id, 'two');
    expect(byFamily[(0, 2)]!.single.story.id, 'none');
  });

  testWidgets('5000 stories build only the visible cells', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = LabController(datasetSize: 5000);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: Scaffold(
          body: SwimlanesTimeline(
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

    final viewport = tester.getSize(find.byType(LaneGridView));
    const cacheExtent = 250.0; // RenderAbstractViewport.defaultCacheExtent
    // Cache extent on both sides of the viewport, plus partial columns.
    final cols = ((viewport.width + 2 * cacheExtent) / 96).ceil() + 2;
    final rows = ((viewport.height + 2 * cacheExtent) / 72).ceil() + 2;
    final lanes = laneKeys(c.dataset, LaneBy.person).length;
    final totalCells = lanes * (c.dataset.maxYear - c.dataset.minYear + 1);

    final cells = find.byType(LaneCell);
    final built = cells.evaluate().length;
    expect(built, lessThanOrEqualTo(cols * (rows < lanes ? rows : lanes)));
    expect(built, lessThan(totalCells ~/ 4));

    // The renderer opens scrolled to the newest year, so the first scroll
    // goes left: cells just left of the viewport must already be built.
    final gridLeft = tester.getTopLeft(find.byType(LaneGridView)).dx;
    final leading = [
      for (var i = 0; i < built; i++)
        if (tester.getRect(cells.at(i)).right <= gridLeft) i,
    ];
    expect(leading, isNotEmpty);
  });
}
