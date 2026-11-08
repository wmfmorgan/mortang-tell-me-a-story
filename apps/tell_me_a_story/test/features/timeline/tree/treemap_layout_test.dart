import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/tree/treemap_layout.dart';
import 'package:tell_me_a_story/ui/timeline/timeline_entry.dart';

import '../../../support/contrast.dart';
import '../../../support/tree_fixture.dart';

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
        expect(r.longestSide / r.shortestSide, lessThan(4));
      }
    });

    test('zero total gives empty rects', () {
      expect(squarify([0, 0], bounds), [Rect.zero, Rect.zero]);
    });
  });

  group('buildTreemap', () {
    final entries = timelineEntries(TreeFixture.stories);

    test('By decade: groups and cells add up and sort descending', () {
      final groups = buildTreemap(entries, TreeFixture.tree, TreemapBy.decade);
      expect(groups.fold(0, (s, g) => s + g.count), entries.length);
      for (var i = 1; i < groups.length; i++) {
        expect(groups[i - 1].count, greaterThanOrEqualTo(groups[i].count));
      }
      for (final g in groups) {
        for (var i = 1; i < g.cells.length; i++) {
          expect(g.cells[i - 1].count, greaterThanOrEqualTo(g.cells[i].count));
        }
        for (final c in g.cells) {
          for (final e in c.entries) {
            final year = e.story.publishedStart.year;
            expect(g.label, '${year ~/ 10 * 10}s');
            expect(c.label, '$year');
          }
        }
      }
      // Ties keep timeline order.
      expect(groups.map((g) => g.label), [
        '1970s',
        '1980s',
        '1990s',
        '1950s',
        '1960s',
      ]);
    });

    test('By family: one group per family with stories, decade cells', () {
      final groups = buildTreemap(entries, TreeFixture.tree, TreemapBy.family);
      expect(groups.map((g) => g.id), [
        TreeFixture.jenkins,
        TreeFixture.bea,
        TreeFixture.cal,
      ]);
      expect(groups.map((g) => g.label), ['Jenkins', 'Bea', 'Cal']);
      expect(groups.map((g) => g.count), [8, 3, 2]);
      final jenkins = groups.first;
      expect(jenkins.cells.map((c) => c.label).toSet(), {
        '1950s',
        '1960s',
        '1970s',
        '1980s',
        '1990s',
      });
      for (final c in jenkins.cells) {
        for (final e in c.entries) {
          expect(e.story.familyId, TreeFixture.jenkins);
        }
      }
    });

    test('By family skips families with no stories', () {
      final groups = buildTreemap(
        timelineEntries(
          TreeFixture.stories.where((s) => s.familyId != TreeFixture.cal),
        ),
        TreeFixture.tree,
        TreemapBy.family,
      );
      expect(groups.map((g) => g.id), [TreeFixture.jenkins, TreeFixture.bea]);
    });

    test('By person: once per tagged person; untagged in No one tagged', () {
      final groups = buildTreemap(entries, TreeFixture.tree, TreemapBy.person);
      final expected = entries.fold(
        0,
        (s, e) => s + (e.story.people.isEmpty ? 1 : e.story.people.length),
      );
      expect(groups.fold(0, (s, g) => s + g.count), expected);
      expect(groups.map((g) => g.label), [
        'Tom Jenkins',
        'Bea Jenkins',
        'Ada Jenkins',
        'Cal Jenkins',
        'No one tagged',
      ]);
      expect(groups.last.cells.single.entries.single.id, 's1966');
      expect(groups.first.cells.first.label, endsWith('0s'));
    });

    test('entries in a cell keep timeline order', () {
      final groups = buildTreemap(entries, TreeFixture.tree, TreemapBy.decade);
      final seventies = groups.firstWhere((g) => g.label == '1970s');
      final all = [
        for (final c in seventies.cells) ...c.entries.map((e) => e.id),
      ];
      expect(all.toSet(), {'s1975', 'b1977', 's1978'});
    });
  });

  test('ink stays ≥ 4.5:1 on the strongest fill', () {
    final strongest = albumTerracotta.withValues(alpha: treemapTileShade);
    expect(
      contrast(albumInk, over(strongest, albumParchment)),
      greaterThanOrEqualTo(4.5),
    );
    expect(treemapCellShade, lessThan(treemapTileShade));
  });
}
