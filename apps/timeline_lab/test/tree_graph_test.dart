import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/renderers/tree_graph_layout.dart';
import 'package:timeline_lab/renderers/tree_graph_renderer.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

List<TreeNode> _all(TreeNode n) => [n, for (final c in n.children) ..._all(c)];

List<String> _shownStoryIds(TreeNode root) => [
  for (final n in _all(root))
    if (n.storyId != null) n.storyId!,
  for (final n in _all(root)) ...n.hiddenStoryIds,
];

void main() {
  final d = generateDataset(storyCount: 1000);
  final entries = applyFilter(d, const TimelineFilter());

  group('time tree', () {
    test('root → decade → year → story, every story reachable once', () {
      final root = buildTimeTree(entries)!;
      expect(root.kind, TreeNodeKind.root);
      for (final dec in root.children) {
        expect(dec.kind, TreeNodeKind.decade);
        for (final y in dec.children) {
          expect(y.kind, TreeNodeKind.year);
          expect(int.parse(y.label) ~/ 10 * 10, int.parse(dec.id.substring(2)));
          for (final leaf in y.children) {
            expect(leaf.kind, anyOf(TreeNodeKind.story, TreeNodeKind.overflow));
            expect(leaf.children, isEmpty);
          }
        }
      }
      final ids = _shownStoryIds(root);
      expect(ids, hasLength(entries.length));
      expect(ids.toSet(), hasLength(entries.length));
      expect(root.storyCount, entries.length);
    });

    test('dense years collapse to maxLeaves-1 stories plus overflow', () {
      final root = buildTimeTree(entries, maxLeaves: 4)!;
      final years = [for (final dec in root.children) ...dec.children];
      final dense = years.firstWhere((y) => y.storyCount > 4);
      expect(dense.children, hasLength(4));
      final more = dense.children.last;
      expect(more.kind, TreeNodeKind.overflow);
      expect(more.storyCount, dense.storyCount - 3);
      // Collapsed stories are the latest of the year, in date order.
      final yearIds = [
        for (final e in entries)
          if ('${e.story.start.year}' == dense.label) e.story.id,
      ];
      expect(more.hiddenStoryIds, yearIds.sublist(3));

      final expanded = buildTimeTree(
        entries,
        maxLeaves: 4,
        expanded: {dense.id},
      )!;
      final again = [for (final dec in expanded.children) ...dec.children]
          .firstWhere((y) => y.id == dense.id);
      expect(again.children.map((c) => c.storyId), yearIds);
    });

    test('a node appears with its earliest story', () {
      final root = buildTimeTree(entries)!;
      expect(root.firstStoryId, entries.first.story.id);
      for (final dec in root.children) {
        final first = entries.firstWhere(
          (e) => '${e.story.decade}s' == dec.label,
        );
        expect(dec.firstStoryId, first.story.id);
      }
    });
  });

  group('family tree', () {
    test('branches hang off their origin story and keep it visible', () {
      final root = buildFamilyTree(entries, d, maxLeaves: 2)!;
      expect(root.id, 'f-fam-root');
      for (final f in d.families.values.where((f) => f.isBranch)) {
        final node = _all(root).singleWhere((n) => n.id == 'f-${f.id}');
        expect(node.parent!.storyId, f.originStoryId);
        expect(node.parent!.parent!.parent, isNotNull);
      }
      expect(_shownStoryIds(root).toSet(), hasLength(entries.length));
    });

    test('during playback no node appears before its parent', () {
      final root = buildFamilyTree(entries, d)!;
      final order = {for (final (i, e) in entries.indexed) e.story.id: i};
      for (final n in _all(root)) {
        if (n.parent == null) continue;
        expect(
          order[n.revealId]!,
          greaterThanOrEqualTo(order[n.parent!.revealId]!),
          reason: '${n.id} would appear before ${n.parent!.id}',
        );
      }
      // Branches appear with their origin story at the earliest.
      for (final f in d.families.values.where((f) => f.isBranch)) {
        final node = _all(root).singleWhere((n) => n.id == 'f-${f.id}');
        expect(
          order[node.revealId]!,
          greaterThanOrEqualTo(order[f.originStoryId]!),
        );
      }
    });

    test('without the origin story the branch attaches to its parent', () {
      final origins = {for (final f in d.families.values) f.originStoryId};
      final hidden = applyFilter(
        d,
        const TimelineFilter(mode: FilterMode.hide),
      ).where((e) => !origins.contains(e.story.id)).toList();
      final root = buildFamilyTree(hidden, d)!;
      final reyes = _all(root).singleWhere((n) => n.id == 'f-fam-reyes');
      expect(reyes.parent, root);
    });
  });

  test('layout: parents centred on children, depth on x, no shared rows', () {
    final layout = TreeLayout(buildTimeTree(entries)!);
    final ys = <double>[];
    for (final n in layout.nodes) {
      final p = layout.positions[n]!;
      expect(p.dx, closeTo(layout.pad + n.depth * layout.levelGap, 1e-9));
      if (n.children.isEmpty) {
        ys.add(p.dy);
      } else {
        final first = layout.positions[n.children.first]!.dy;
        final last = layout.positions[n.children.last]!.dy;
        expect(p.dy, closeTo((first + last) / 2, 1e-9));
      }
    }
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i] - ys[i - 1], closeTo(layout.leafGap, 1e-9));
    }
    for (final e in entries) {
      expect(layout.storyNodes, contains(e.story.id));
    }
  });

  testWidgets('tapping an overflow node expands it; a leaf selects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: Scaffold(
          body: TreeGraphTimeline(
            data: TimelineViewData(
              dataset: d,
              entries: entries,
              mode: FilterMode.dim,
              selectedId: null,
              onSelect: (id) => selected = id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TreeLayout layout() =>
        (tester
                    .widget<CustomPaint>(
                      find.byWidgetPredicate(
                        (w) => w is CustomPaint && w.painter is TreePainter,
                      ),
                    )
                    .painter!
                as TreePainter)
            .layout;
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is TreePainter,
    );

    Future<void> tapNode(TreeNode n) async {
      final local = layout().positions[n]!;
      // Bring the node on screen, then tap it.
      final position = Scrollable.of(
        tester.element(canvas),
        axis: Axis.vertical,
      ).position;
      position.jumpTo((local.dy - 200).clamp(0, position.maxScrollExtent));
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(canvas) + local);
      await tester.pump();
    }

    final before = layout();
    final more = before.nodes.firstWhere(
      (n) => n.kind == TreeNodeKind.overflow,
    );
    final yearId = more.parent!.id;
    await tapNode(more);
    final after = layout();
    final year = after.nodes.firstWhere((n) => n.id == yearId);
    expect(year.children.every((c) => c.kind == TreeNodeKind.story), isTrue);
    expect(year.children, hasLength(more.parent!.storyCount));

    final leaf = year.children.last;
    await tapNode(leaf);
    expect(selected, leaf.storyId);
  });

  test('a finger radius reaches the nearest dot; labels are not targets', () {
    final layout = TreeLayout(buildTimeTree(entries)!);
    final leaf = layout.nodes.firstWhere(
      (n) => n.kind == TreeNodeKind.story && n.children.isEmpty,
    );
    final p = layout.positions[leaf]!;
    // The label is not a target, even for a finger (D-i5).
    expect(
      layout.hitTest(p + const Offset(120, 0), radius: LabTarget.fingerRadius),
      isNull,
    );
    // 12 pt below the dot: outside the precise radius, inside the finger
    // one, and nearer this dot than the next row (26 pt away).
    final q = p + const Offset(0, 12);
    expect(layout.hitTest(q), isNull);
    expect(layout.hitTest(q, radius: LabTarget.fingerRadius), same(leaf));

    // Inner nodes use the same rule.
    final years = [
      for (final n in layout.nodes)
        if (n.kind == TreeNodeKind.year) n,
    ];
    final year = years.firstWhere(
      (y) => years.every(
        (o) =>
            identical(o, y) ||
            (layout.positions[o]! - layout.positions[y]!).distance >
                2 * LabTarget.fingerRadius,
      ),
    );
    final r = layout.positions[year]! + const Offset(0, 18);
    expect(layout.hitTest(r), isNull);
    expect(layout.hitTest(r, radius: LabTarget.fingerRadius), same(year));
  });
}
