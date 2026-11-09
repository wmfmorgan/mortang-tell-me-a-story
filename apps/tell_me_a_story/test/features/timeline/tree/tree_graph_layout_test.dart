import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/tree/tree_graph_layout.dart';
import 'package:tell_me_a_story/features/timeline/tree/treemap_layout.dart';

import '../../../support/contrast.dart';
import '../../../support/tree_fixture.dart';

// Ported from the timeline lab's tree_graph_test.dart, Family mode only.

List<TreeNode> _all(TreeNode n) => [n, for (final c in n.children) ..._all(c)];

List<String> _shownStoryIds(TreeNode root) => [
  for (final n in _all(root))
    if (n.storyId != null) n.storyId!,
  for (final n in _all(root)) ...n.hiddenStoryIds,
];

TreeNode _node(TreeNode root, String id) =>
    _all(root).singleWhere((n) => n.id == id);

TreeNode? _build(
  List<Story> stories, {
  List<TreeFamily> tree = TreeFixture.tree,
  Set<String> expanded = const {},
  int maxLeaves = treeGraphMaxLeaves,
}) => buildFamilyTree(
  stories,
  tree,
  rootLabel: 'Jenkins family tree',
  expanded: expanded,
  maxLeaves: maxLeaves,
);

void main() {
  group('family tree', () {
    test('Jenkins is the root; branches hang off their origin stories', () {
      final root = _build(TreeFixture.stories)!;
      expect(root.kind, TreeNodeKind.family);
      expect(root.id, 'f-${TreeFixture.jenkins}');
      expect(root.label, 'Jenkins');
      expect(root.parent, isNull);
      final bea = _node(root, 'f-${TreeFixture.bea}');
      final cal = _node(root, 'f-${TreeFixture.cal}');
      expect(bea.label, 'Bea (1975)');
      expect(bea.parent!.storyId, 's1975');
      expect(cal.parent!.storyId, 's1984');
      // Decades of a family, in date order.
      expect(
        [for (final d in root.children) d.label],
        ['1950s', '1960s', '1970s', '1980s', '1990s'],
      );
      final ids = _shownStoryIds(root);
      expect(ids, hasLength(TreeFixture.stories.length));
      expect(ids.toSet(), hasLength(TreeFixture.stories.length));
      expect(root.storyCount, TreeFixture.stories.length);
      expect(bea.storyCount, 3);
    });

    test('a decade over six collapses to five stories and +N', () {
      final root = _build(TreeFixture.crowded)!;
      final sixties = _node(root, 'f-${TreeFixture.jenkins}-d-1960');
      expect(sixties.storyCount, 8);
      expect(sixties.children, hasLength(6));
      expect(
        [for (final c in sixties.children.take(5)) c.storyId],
        ['x1960', 's1961', 'x1962', 'x1963', 'x1964'],
      );
      final more = sixties.children.last;
      expect(more.kind, TreeNodeKind.overflow);
      expect(more.label, '+3');
      expect(more.storyCount, 3);
      // The latest stories of the decade, in date order.
      expect(more.hiddenStoryIds, ['s1966', 'x1967', 'x1969']);
      expect(
        _shownStoryIds(root).toSet(),
        hasLength(TreeFixture.crowded.length),
      );

      final expanded = _build(TreeFixture.crowded, expanded: {sixties.id})!;
      final again = _node(expanded, sixties.id);
      expect(again.children.map((c) => c.kind).toSet(), {TreeNodeKind.story});
      expect(again.children, hasLength(8));
    });

    test('a branch origin never collapses', () {
      final root = _build(TreeFixture.stories, maxLeaves: 1)!;
      final seventies = _node(root, 'f-${TreeFixture.jenkins}-d-1970');
      expect(seventies.children.first.storyId, 's1975');
      expect(seventies.children.last.hiddenStoryIds, ['s1978']);
      expect(_node(root, 'f-${TreeFixture.bea}').parent!.storyId, 's1975');
      expect(_node(root, 'f-${TreeFixture.cal}').parent!.storyId, 's1984');
    });

    test('without its published origin a branch hangs off its parent', () {
      final root = _build([
        for (final s in TreeFixture.stories)
          if (s.id != 's1975') s,
      ])!;
      expect(_node(root, 'f-${TreeFixture.bea}').parent, same(root));
    });

    test('a family whose parent is not in the tree is a root', () {
      // Cal's parent is soft-deleted or gone: two roots under the hub.
      final tree = [
        TreeFixture.tree[0],
        TreeFixture.tree[1],
        const TreeFamily(
          id: TreeFixture.cal,
          name: 'Cal',
          parentFamilyId: 'deleted',
          originStoryId: 's1984',
        ),
      ];
      final root = _build(TreeFixture.stories, tree: tree)!;
      expect(root.kind, TreeNodeKind.root);
      expect(root.label, 'Jenkins family tree');
      expect(
        [for (final c in root.children) c.id],
        ['f-${TreeFixture.jenkins}', 'f-${TreeFixture.cal}'],
      );
      expect(root.storyCount, TreeFixture.stories.length);
    });

    test('a family with no stories and no branches is left out', () {
      final root = _build([
        for (final s in TreeFixture.stories)
          if (s.familyId != TreeFixture.cal) s,
      ])!;
      expect(_all(root).where((n) => n.familyId == TreeFixture.cal), isEmpty);
      expect(_build(const []), isNull);
    });
  });

  test('layout: parents centred on children, depth on x, no shared rows', () {
    final layout = TreeLayout(_build(TreeFixture.crowded)!);
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
    for (final s in TreeFixture.crowded) {
      expect(layout.storyNodes, contains(s.id));
    }
  });

  test('a finger radius reaches the nearest dot; labels are not targets', () {
    final layout = TreeLayout(_build(TreeFixture.stories)!);
    final leaf = layout.nodes.firstWhere(
      (n) => n.kind == TreeNodeKind.story && n.children.isEmpty,
    );
    final p = layout.positions[leaf]!;
    expect(
      layout.hitTest(
        p + const Offset(120, 0),
        radius: AlbumTarget.fingerRadius,
      ),
      isNull,
    );
    // 12 pt below the dot: outside the precise radius, inside the finger
    // one, and nearer this dot than the next row (26 pt away).
    final q = p + const Offset(0, 12);
    expect(layout.hitTest(q), isNull);
    expect(layout.hitTest(q, radius: AlbumTarget.fingerRadius), same(leaf));
  });

  test('ink reads on every family tint, and the +N text on its pill', () {
    for (final tint in treemapPalette) {
      expect(
        contrast(albumInk, over(tint, albumParchment)),
        greaterThanOrEqualTo(4.5),
        reason: '$tint',
      );
    }
    expect(contrast(albumParchment, albumInk), greaterThanOrEqualTo(4.5));
  });

  test('1 000 stories: built and laid out, every story reachable', () {
    final (:stories, :tree) = TreeFixture.synthetic(1000);
    final watch = Stopwatch()..start();
    final root = buildFamilyTree(stories, tree, rootLabel: 'Jenkins')!;
    final layout = TreeLayout(root);
    watch.stop();
    expect(root.storyCount, 1000);
    expect(layout.storyNodes, hasLength(1000));
    expect(_shownStoryIds(root).toSet(), hasLength(1000));
    // A sanity bound only: the iPad measurement (7.M) decides.
    expect(watch.elapsedMilliseconds, lessThan(500));
  });
}
