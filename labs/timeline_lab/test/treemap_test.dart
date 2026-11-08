import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/treemap_layout.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

import 'support/contrast.dart';

void main() {
  group('squarify', () {
    const bounds = Rect.fromLTWH(10, 20, 640, 360);
    for (final values in <List<double>>[
      [6, 6, 4, 3, 2, 2, 1],
      [100, 1, 1, 1],
      [1],
      [5, 5, 5, 5, 5, 5, 5, 5, 5],
    ]) {
      test('tiles proportionally without overlap: $values', () {
        final rects = squarify(values, bounds);
        final total = values.fold(0.0, (a, b) => a + b);
        final boundsArea = bounds.width * bounds.height;
        var covered = 0.0;
        for (final (i, r) in rects.indexed) {
          final area = r.width * r.height;
          expect(area, closeTo(values[i] / total * boundsArea, 1e-6));
          expect(r.left, greaterThanOrEqualTo(bounds.left - 1e-6));
          expect(r.top, greaterThanOrEqualTo(bounds.top - 1e-6));
          expect(r.right, lessThanOrEqualTo(bounds.right + 1e-6));
          expect(r.bottom, lessThanOrEqualTo(bounds.bottom + 1e-6));
          covered += area;
          for (final other in rects.skip(i + 1)) {
            final o = r.intersect(other);
            final overlap = o.width > 0 && o.height > 0
                ? o.width * o.height
                : 0.0;
            expect(overlap, lessThan(1e-6));
          }
        }
        expect(covered, closeTo(boundsArea, 1e-6));
      });
    }

    test('squarified cells are not slivers', () {
      final rects = squarify([6.0, 6, 4, 3, 2, 2, 1], bounds);
      for (final r in rects) {
        final aspect = r.longestSide / r.shortestSide;
        expect(aspect, lessThan(4));
      }
    });

    test('zero total gives empty rects', () {
      expect(squarify([0, 0], bounds), [Rect.zero, Rect.zero]);
    });
  });

  group('buildTreemap', () {
    final d = generateDataset();
    final entries = applyFilter(d, const TimelineFilter());

    test('decade view: groups and cells add up and sort descending', () {
      final groups = buildTreemap(entries, d, TreemapBy.decade);
      expect(groups.fold(0, (s, g) => s + g.count), entries.length);
      for (var i = 1; i < groups.length; i++) {
        expect(groups[i - 1].count, greaterThanOrEqualTo(groups[i].count));
      }
      for (final g in groups) {
        for (final c in g.cells) {
          for (final e in c.entries) {
            expect('${e.story.decade}', g.id);
            expect('${e.story.start.year}', c.label);
          }
        }
      }
    });

    test('person view counts a story once per person', () {
      final groups = buildTreemap(entries, d, TreemapBy.person);
      final expected = entries.fold(
        0,
        (s, e) =>
            s + (e.story.personIds.isEmpty ? 1 : e.story.personIds.length),
      );
      expect(groups.fold(0, (s, g) => s + g.count), expected);
      expect(groups.map((g) => g.id), contains(untaggedGroup));
    });

    test('family view uses family groups and decade cells', () {
      final groups = buildTreemap(entries, d, TreemapBy.family);
      expect(groups.map((g) => g.id).toSet(), d.families.keys.toSet());
    });
  });

  group('widget', () {
    Future<LabController> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = LabController()..setRenderer(RendererKind.treemap);
      addTearDown(c.dispose);
      await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('drill into a group, a cell, then select a story', (
      tester,
    ) async {
      final c = await pump(tester);
      final groups = buildTreemap(c.entries, c.dataset, TreemapBy.decade);
      final g = groups.first;
      await tester.tap(find.byKey(Key('treemap-group-${g.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('treemap-crumb-group')), findsOneWidget);

      final cell = g.cells.first;
      await tester.tap(find.byKey(Key('treemap-cell-${cell.id}')));
      await tester.pumpAndSettle();
      final tiles = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('treemap-story-'),
      );
      expect(tiles, findsNWidgets(cell.count));

      final story = cell.entries.first.story;
      await tester.tap(find.byKey(Key('treemap-story-${story.id}')));
      await tester.pumpAndSettle();
      expect(c.selectedStoryId, story.id);

      await tester.tap(find.byKey(const Key('treemap-crumb-root')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('treemap-crumb-group')), findsNothing);
      expect(find.byKey(Key('treemap-group-${g.id}')), findsOneWidget);
    });

    testWidgets('playback fills cells without moving them', (tester) async {
      final c = await pump(tester);
      final groups = buildTreemap(c.entries, c.dataset, TreemapBy.decade);
      final cell = groups.first.cells.first;
      final finder = find.byKey(Key('treemap-cell-${cell.id}'));
      final rectBefore = tester.getRect(finder);

      double fillOf() => tester
          .widget<FractionallySizedBox>(
            find.descendant(
              of: finder,
              matching: find.byType(FractionallySizedBox),
            ),
          )
          .heightFactor!;
      expect(fillOf(), 1);

      final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
      final firstId = cell.entries.first.story.id;
      final lastId = cell.entries.last.story.id;
      // Between this cell's first and last story: partly filled.
      pb.seek(0);
      while (pb.reveal(firstId) == 0) {
        pb.seek(pb.clock + 0.05);
      }
      await tester.pump();
      expect(cell.count, greaterThan(1));
      expect(pb.reveal(lastId), 0);
      expect(fillOf(), inExclusiveRange(0, 1));
      expect(tester.getRect(finder), rectBefore);

      pb.seek(pb.duration);
      await tester.pump();
      expect(fillOf(), 1);
    });
  });

  test('shade is quiet and uniform while nothing is dimmed', () {
    expect(treemapShade(1, dimming: false), treemapShade(0.3, dimming: false));
  });

  test('dim shading steps up with the matched share', () {
    expect(
      [
        for (final s in [0.0, 0.3, 0.6, 1.0]) treemapShade(s, dimming: true),
      ],
      [0.0, 0.16, 0.28, 0.40],
    );
  });

  test('ink stays ≥ 4.5:1 on the strongest shade', () {
    final strongest = labTerracotta.withValues(
      alpha: treemapShade(1, dimming: true),
    );
    expect(
      contrast(labInk, over(strongest, labParchment)),
      greaterThanOrEqualTo(4.5),
    );
  });
}
