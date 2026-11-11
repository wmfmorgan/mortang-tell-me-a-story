import 'dart:ui' show Offset, Rect, Size;

import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/core/widgets/story/story_title.dart';

enum TreeNodeKind { root, family, decade, story, overflow }

/// One node of the family tree graph. Children are in ascending date order,
/// with branch families after the stories they hang from.
class TreeNode {
  TreeNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.familyId,
    this.storyId,
    this.hiddenStoryIds = const [],
  });

  final String id;
  final TreeNodeKind kind;
  final String label;

  /// The family this node belongs to (null for the multi-root hub).
  final String? familyId;

  /// Story leaves (and origin stories that grow a branch).
  final String? storyId;

  /// Overflow node: the stories it stands for, in date order.
  final List<String> hiddenStoryIds;

  final List<TreeNode> children = [];
  TreeNode? parent;

  /// Stories at or under this node (overflow counts its hidden stories).
  late int storyCount;

  void add(TreeNode child) {
    child.parent = this;
    children.add(child);
  }

  int get depth => parent == null ? 0 : parent!.depth + 1;
}

/// Groups larger than this collapse to `maxLeaves - 1` stories and `+N`.
const treeGraphMaxLeaves = 6;

void _countUp(TreeNode node) {
  for (final c in node.children) {
    _countUp(c);
  }
  node.storyCount = node.kind == TreeNodeKind.overflow
      ? node.hiddenStoryIds.length
      : (node.storyId == null ? 0 : 1) +
            node.children.fold(0, (sum, c) => sum + c.storyCount);
}

/// Adds story leaves under [parent], collapsing all but `maxLeaves - 1` into
/// an overflow node unless [parent] is in [expanded]. Stories in [keep]
/// (branch origins) are never collapsed.
void _addLeaves(
  TreeNode parent,
  List<Story> stories, {
  required Set<String> expanded,
  required int maxLeaves,
  required Set<String> keep,
  required Map<String, TreeNode> leafById,
}) {
  final collapse = stories.length > maxLeaves && !expanded.contains(parent.id);
  final hidden = <String>[];
  var shown = 0;
  for (final s in stories) {
    if (collapse && shown >= maxLeaves - 1 && !keep.contains(s.id)) {
      hidden.add(s.id);
      continue;
    }
    final leaf = TreeNode(
      id: 's:${s.id}',
      kind: TreeNodeKind.story,
      label: storyTitle(s),
      familyId: s.familyId,
      storyId: s.id,
    );
    leafById[s.id] = leaf;
    parent.add(leaf);
    shown++;
  }
  if (hidden.isNotEmpty) {
    parent.add(
      TreeNode(
        id: 'more:${parent.id}',
        kind: TreeNodeKind.overflow,
        label: '+${hidden.length}',
        familyId: parent.familyId,
        hiddenStoryIds: hidden,
      ),
    );
  }
}

int _decadeOf(Story s) => s.publishedStart.year ~/ 10 * 10;

/// Family → decade → story, with each branch family hanging off its origin
/// story (or off its parent family when the origin isn't published).
/// [stories] are the tree's published stories in timeline order. A family
/// whose parent is not in [tree] (none, or soft-deleted) is a root; several
/// roots hang from one hub labelled [rootLabel]. Returns null when there are
/// no stories.
TreeNode? buildFamilyTree(
  List<Story> stories,
  List<TreeFamily> tree, {
  required String rootLabel,
  Set<String> expanded = const {},
  int maxLeaves = treeGraphMaxLeaves,
}) {
  if (stories.isEmpty) return null;
  final byFamily = <String, List<Story>>{};
  for (final s in stories) {
    (byFamily[s.familyId] ??= []).add(s);
  }
  final ids = {for (final f in tree) f.id};
  final origins = {
    for (final f in tree)
      if (f.originStoryId != null) f.originStoryId!,
  };
  final leafById = <String, TreeNode>{};

  TreeNode? buildFamily(TreeFamily f) {
    final mine = byFamily[f.id] ?? const <Story>[];
    final branchNodes = [
      for (final b in tree)
        if (b.parentFamilyId == f.id)
          if (buildFamily(b) case final n?) (b, n),
    ];
    if (mine.isEmpty && branchNodes.isEmpty) return null;
    final node = TreeNode(
      id: 'f-${f.id}',
      kind: TreeNodeKind.family,
      label: f.branchYear == null ? f.name : '${f.name} (${f.branchYear})',
      familyId: f.id,
    );
    final decades = <int, List<Story>>{};
    for (final s in mine) {
      (decades[_decadeOf(s)] ??= []).add(s);
    }
    for (final MapEntry(key: decade, value: inDecade) in decades.entries) {
      final dNode = TreeNode(
        id: 'f-${f.id}-d-$decade',
        kind: TreeNodeKind.decade,
        label: '${decade}s',
        familyId: f.id,
      );
      node.add(dNode);
      _addLeaves(
        dNode,
        inDecade,
        expanded: expanded,
        maxLeaves: maxLeaves,
        keep: origins,
        leafById: leafById,
      );
    }
    // Attach after this family's leaves exist so the origin leaf is found.
    for (final (b, bNode) in branchNodes) {
      (leafById[b.originStoryId] ?? node).add(bNode);
    }
    return node;
  }

  final roots = [
    for (final f in tree)
      if (f.parentFamilyId == null || !ids.contains(f.parentFamilyId))
        ?buildFamily(f),
  ];
  if (roots.isEmpty) return null;
  final TreeNode root;
  if (roots.length == 1) {
    root = roots.single;
  } else {
    root = TreeNode(
      id: 'root',
      kind: TreeNodeKind.root,
      label: rootLabel,
      familyId: null,
    );
    roots.forEach(root.add);
  }
  _countUp(root);
  return root;
}

/// Tidy layered layout, depth on x, leaves stacked on y in date order.
/// Parents sit at the vertical middle of their first and last child.
class TreeLayout {
  TreeLayout(
    this.root, {
    this.levelGap = 190,
    this.leafGap = 26,
    this.pad = 32,
    this.labelWidth = 260,
  }) {
    var nextY = pad;
    var maxDepth = 0;
    void place(TreeNode n, int depth) {
      maxDepth = depth > maxDepth ? depth : maxDepth;
      for (final c in n.children) {
        place(c, depth + 1);
      }
      final double y;
      if (n.children.isEmpty) {
        y = nextY;
        nextY += leafGap;
      } else {
        y =
            (positions[n.children.first]!.dy + positions[n.children.last]!.dy) /
            2;
      }
      positions[n] = Offset(pad + depth * levelGap, y);
      nodes.add(n);
      if (n.storyId != null) storyNodes[n.storyId!] = n;
      for (final id in n.hiddenStoryIds) {
        storyNodes[id] = n;
      }
    }

    place(root, 0);
    size = Size(pad * 2 + maxDepth * levelGap + labelWidth, nextY + pad);
  }

  final TreeNode root;
  final double levelGap;
  final double leafGap;
  final double pad;
  final double labelWidth;

  /// Post-order (children before parents).
  final List<TreeNode> nodes = [];
  final Map<TreeNode, Offset> positions = {};

  /// Story id → the node that shows it (its leaf, or the overflow node that
  /// collapsed it).
  final Map<String, TreeNode> storyNodes = {};
  late final Size size;

  static const hitRadius = 10.0;

  /// The node whose centre is nearest [p] within [radius]. Labels are not
  /// targets; callers pass `AlbumTarget.fingerRadius` for finger taps.
  TreeNode? hitTest(Offset p, {double radius = hitRadius}) {
    TreeNode? best;
    var bestDist = double.infinity;
    for (final n in nodes) {
      final dist = (positions[n]! - p).distance;
      if (dist <= radius && dist < bestDist) {
        best = n;
        bestDist = dist;
      }
    }
    return best;
  }

  Rect rectOf(TreeNode n) =>
      Rect.fromCircle(center: positions[n]!, radius: hitRadius);
}
