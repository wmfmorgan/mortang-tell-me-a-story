import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/ui/timeline/timeline_entry.dart';

/// The treemap groupings (O5): C5–C7.
enum TreemapBy { family, decade, person }

/// Fill of every overview cell: one quiet shade of terracotta. The area is
/// the information; nothing is dimmed on the tree views (O6).
const treemapCellShade = 0.10;

/// Fill of a story tile at the deepest level.
const treemapTileShade = 0.18;

/// Squarified treemap (Bruls, Huizing, van Wijk 2000). [values] must be in
/// descending order; returns one rect per value, in the same order, tiling
/// [bounds] with areas proportional to the values. Zero values get
/// [Rect.zero].
List<Rect> squarify(List<double> values, Rect bounds) {
  final total = values.fold(0.0, (a, b) => a + b);
  if (total <= 0 || bounds.isEmpty) {
    return List.filled(values.length, Rect.zero);
  }
  final scale = bounds.width * bounds.height / total;
  final areas = [for (final v in values) v * scale];
  final out = List<Rect>.filled(values.length, Rect.zero);

  var free = bounds;
  var rowStart = 0;
  var rowSum = 0.0;

  double worst(int start, int end, double sum, double side) {
    var maxA = 0.0, minA = double.infinity;
    for (var i = start; i < end; i++) {
      maxA = math.max(maxA, areas[i]);
      minA = math.min(minA, areas[i]);
    }
    final s2 = sum * sum, w2 = side * side;
    return math.max(w2 * maxA / s2, s2 / (w2 * minA));
  }

  void layoutRow(int start, int end, double sum) {
    if (free.width >= free.height) {
      // Column on the left.
      final w = sum / free.height;
      var y = free.top;
      for (var i = start; i < end; i++) {
        final h = areas[i] / w;
        out[i] = Rect.fromLTWH(free.left, y, w, h);
        y += h;
      }
      free = Rect.fromLTRB(free.left + w, free.top, free.right, free.bottom);
    } else {
      // Row on the top.
      final h = sum / free.width;
      var x = free.left;
      for (var i = start; i < end; i++) {
        final w = areas[i] / h;
        out[i] = Rect.fromLTWH(x, free.top, w, h);
        x += w;
      }
      free = Rect.fromLTRB(free.left, free.top + h, free.right, free.bottom);
    }
  }

  final n = areas.lastIndexWhere((a) => a > 0) + 1;
  var i = 0;
  while (i < n) {
    final side = math.min(free.width, free.height);
    final withNext = rowSum + areas[i];
    if (i == rowStart ||
        worst(rowStart, i + 1, withNext, side) <=
            worst(rowStart, i, rowSum, side)) {
      rowSum = withNext;
      i++;
      continue;
    }
    layoutRow(rowStart, i, rowSum);
    rowStart = i;
    rowSum = 0;
  }
  if (rowStart < n) layoutRow(rowStart, n, rowSum);
  return out;
}

/// A leaf cell of the overview: the stories of one group in one sub-period.
class TreemapCell {
  TreemapCell({required this.id, required this.label});

  final String id;
  final String label;

  /// Timeline order.
  final List<TimelineEntry> entries = [];

  int get count => entries.length;
}

/// A top-level group (family, decade or person) of cells.
class TreemapGroup {
  TreemapGroup({required this.id, required this.label});

  final String id;
  final String label;
  final List<TreemapCell> cells = [];

  int get count => cells.fold(0, (sum, c) => sum + c.count);
}

/// Group id for stories with no tagged person in [TreemapBy.person].
const noOneTaggedGroup = '_none';

/// All Stories' heading for the same group.
const noOneTaggedLabel = 'No one tagged';

/// Groups → cells, both sorted by story count descending (ties keep
/// timeline order) as [squarify] expects. [entries] come in timeline order.
///
/// * family → decade (the label is the family's name in [tree])
/// * decade → year
/// * person → decade; a story with k tagged people counts in k groups, and
///   untagged stories go to [noOneTaggedGroup].
List<TreemapGroup> buildTreemap(
  List<TimelineEntry> entries,
  List<TreeFamily> tree,
  TreemapBy by,
) {
  final names = {for (final f in tree) f.id: f.name};
  final groups = <String, TreemapGroup>{};
  final cells = <String, TreemapCell>{};

  void add(
    String groupId,
    String groupLabel,
    int sub,
    String subLabel,
    TimelineEntry e,
  ) {
    final g = groups.putIfAbsent(
      groupId,
      () => TreemapGroup(id: groupId, label: groupLabel),
    );
    final cellId = '$groupId/$sub';
    final c = cells.putIfAbsent(cellId, () {
      final cell = TreemapCell(id: cellId, label: subLabel);
      g.cells.add(cell);
      return cell;
    });
    c.entries.add(e);
  }

  for (final e in entries) {
    final s = e.story;
    final year = s.publishedStart.year;
    final decade = year ~/ 10 * 10;
    switch (by) {
      case TreemapBy.decade:
        add('$decade', '${decade}s', year, '$year', e);
      case TreemapBy.family:
        add(s.familyId, names[s.familyId] ?? '', decade, '${decade}s', e);
      case TreemapBy.person:
        if (s.people.isEmpty) {
          add(noOneTaggedGroup, noOneTaggedLabel, decade, '${decade}s', e);
        }
        for (final p in s.people) {
          add(p.id, p.name, decade, '${decade}s', e);
        }
    }
  }

  final out = groups.values.toList();
  for (final g in out) {
    _sortDesc(g.cells, (c) => c.count);
  }
  _sortDesc(out, (g) => g.count);
  return out;
}

/// Stable descending sort.
void _sortDesc<T>(List<T> list, int Function(T) key) {
  final indexed = list.indexed.toList()
    ..sort((a, b) {
      final byKey = key(b.$2).compareTo(key(a.$2));
      return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
    });
  list
    ..clear()
    ..addAll(indexed.map((p) => p.$2));
}
