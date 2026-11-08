import 'dart:ui' show Offset, Rect, Size;

import '../filter/timeline_filter.dart';
import '../model/lab_models.dart';

enum TreeBy { time, family }

enum TreeNodeKind { root, family, decade, year, story, overflow }

/// One node of the tree graph. Children are in ascending date order.
class TreeNode {
  TreeNode({
    required this.id,
    required this.kind,
    required this.label,
    this.storyId,
    this.matched = true,
    this.hiddenStoryIds = const [],
  });

  final String id;
  final TreeNodeKind kind;
  final String label;

  /// Story leaves (and origin stories that grow a branch).
  final String? storyId;

  /// Leaf: the entry's match flag. Internal: set by [finalizeTree] to
  /// "any descendant matched". Overflow: any hidden story matched.
  bool matched;

  /// Overflow node: the stories it stands for, in date order.
  final List<String> hiddenStoryIds;

  final List<TreeNode> children = [];
  TreeNode? parent;

  /// Earliest descendant story: the node appears when this one is revealed.
  late String firstStoryId;

  /// Stories at or under this node (overflow counts its hidden stories).
  late int storyCount;

  /// Matched stories at or under this node.
  late int matchedCount;

  /// Story whose reveal shows this node during playback: the later of its
  /// own [firstStoryId] and its parent's [revealId], so a node (e.g. a
  /// branch whose first story predates its origin story) never appears
  /// before the node it hangs from.
  late String revealId;

  void add(TreeNode child) {
    child.parent = this;
    children.add(child);
  }

  int get depth => parent == null ? 0 : parent!.depth + 1;
}

const _defaultMaxLeaves = 6;

/// Fills [TreeNode.firstStoryId], counts, internal match flags and
/// [TreeNode.revealId]. [entries] are the tree's entries in ascending order.
void finalizeTree(TreeNode root, List<TimelineEntry> entries) {
  final matchedById = {for (final e in entries) e.story.id: e.matched};
  final order = {for (final (i, e) in entries.indexed) e.story.id: i};
  _countUp(root, matchedById);
  void revealDown(TreeNode n, String? parentId) {
    n.revealId = parentId != null && order[parentId]! > order[n.firstStoryId]!
        ? parentId
        : n.firstStoryId;
    for (final c in n.children) {
      revealDown(c, n.revealId);
    }
  }

  revealDown(root, null);
}

void _countUp(TreeNode node, Map<String, bool> matchedById) {
  for (final c in node.children) {
    _countUp(c, matchedById);
  }
  switch (node.kind) {
    case TreeNodeKind.overflow:
      node.firstStoryId = node.hiddenStoryIds.first;
      node.storyCount = node.hiddenStoryIds.length;
      node.matchedCount = node.hiddenStoryIds
          .where((id) => matchedById[id] ?? false)
          .length;
    case _:
      final own = node.storyId == null ? 0 : 1;
      final ownMatched = node.storyId != null && node.matched ? 1 : 0;
      node.firstStoryId = node.storyId ?? node.children.first.firstStoryId;
      node.storyCount =
          own + node.children.fold(0, (sum, c) => sum + c.storyCount);
      node.matchedCount =
          ownMatched + node.children.fold(0, (sum, c) => sum + c.matchedCount);
  }
  if (node.storyId == null) node.matched = node.matchedCount > 0;
}

/// Adds story leaves under [parent], collapsing all but `maxLeaves - 1` into
/// an overflow node unless [parent] is in [expanded]. Stories in [keep]
/// (branch origins) are never collapsed.
void _addLeaves(
  TreeNode parent,
  List<TimelineEntry> entries, {
  required Set<String> expanded,
  required int maxLeaves,
  Set<String> keep = const {},
  required Map<String, TreeNode> leafById,
}) {
  final collapse = entries.length > maxLeaves && !expanded.contains(parent.id);
  final hidden = <String>[];
  var shown = 0;
  for (final e in entries) {
    final id = e.story.id;
    if (collapse && shown >= maxLeaves - 1 && !keep.contains(id)) {
      hidden.add(id);
      continue;
    }
    final leaf = TreeNode(
      id: 's:$id',
      kind: TreeNodeKind.story,
      label: e.story.title,
      storyId: id,
      matched: e.matched,
    );
    leafById[id] = leaf;
    parent.add(leaf);
    shown++;
  }
  if (hidden.isNotEmpty) {
    parent.add(
      TreeNode(
        id: 'more:${parent.id}',
        kind: TreeNodeKind.overflow,
        label: '+${hidden.length} more',
        hiddenStoryIds: hidden,
      ),
    );
  }
}

Map<int, List<TimelineEntry>> _groupBy(
  Iterable<TimelineEntry> entries,
  int Function(TimelineEntry) key,
) {
  final out = <int, List<TimelineEntry>>{};
  for (final e in entries) {
    (out[key(e)] ??= []).add(e);
  }
  return out;
}

/// Root → decade → year → story. Balanced, B-tree-like, depth 3 to leaves.
/// Returns null when there are no entries.
TreeNode? buildTimeTree(
  List<TimelineEntry> entries, {
  Set<String> expanded = const {},
  int maxLeaves = _defaultMaxLeaves,
}) {
  if (entries.isEmpty) return null;
  final root = TreeNode(
    id: 'root',
    kind: TreeNodeKind.root,
    label: 'All stories',
  );
  final leafById = <String, TreeNode>{};
  for (final MapEntry(key: decade, value: inDecade) in _groupBy(
    entries,
    (e) => e.story.decade,
  ).entries) {
    final dNode = TreeNode(
      id: 'd-$decade',
      kind: TreeNodeKind.decade,
      label: '${decade}s',
    );
    root.add(dNode);
    for (final MapEntry(key: year, value: inYear) in _groupBy(
      inDecade,
      (e) => e.story.start.year,
    ).entries) {
      final yNode = TreeNode(
        id: 'y-$year',
        kind: TreeNodeKind.year,
        label: '$year',
      );
      dNode.add(yNode);
      _addLeaves(
        yNode,
        inYear,
        expanded: expanded,
        maxLeaves: maxLeaves,
        leafById: leafById,
      );
    }
  }
  finalizeTree(root, entries);
  return root;
}

/// Family → decade → story, with each branch family hanging off its origin
/// story (or off its parent family when the origin isn't in [entries]).
/// Returns null when there are no entries.
TreeNode? buildFamilyTree(
  List<TimelineEntry> entries,
  LabDataset d, {
  Set<String> expanded = const {},
  int maxLeaves = _defaultMaxLeaves,
}) {
  if (entries.isEmpty) return null;
  final byFamily = <String, List<TimelineEntry>>{};
  for (final e in entries) {
    (byFamily[e.story.familyId] ??= []).add(e);
  }
  final origins = {
    for (final f in d.families.values)
      if (f.originStoryId != null) f.originStoryId!,
  };
  final leafById = <String, TreeNode>{};

  TreeNode? buildFamily(LabFamily f) {
    final mine = byFamily[f.id] ?? const <TimelineEntry>[];
    final branches = d.families.values
        .where((b) => b.parentFamilyId == f.id)
        .toList();
    final branchNodes = [
      for (final b in branches)
        if (buildFamily(b) case final n?) (b, n),
    ];
    if (mine.isEmpty && branchNodes.isEmpty) return null;
    final node = TreeNode(
      id: 'f-${f.id}',
      kind: TreeNodeKind.family,
      label: f.branchYear == null ? f.name : '${f.name} (${f.branchYear})',
    );
    for (final MapEntry(key: decade, value: inDecade) in _groupBy(
      mine,
      (e) => e.story.decade,
    ).entries) {
      final dNode = TreeNode(
        id: 'f-${f.id}-d-$decade',
        kind: TreeNodeKind.decade,
        label: '${decade}s',
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
    for (final f in d.families.values)
      if (f.parentFamilyId == null) ?buildFamily(f),
  ];
  final TreeNode root;
  if (roots.length == 1) {
    root = roots.single;
  } else {
    root = TreeNode(id: 'root', kind: TreeNodeKind.root, label: 'Families');
    roots.forEach(root.add);
  }
  finalizeTree(root, entries);
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
  /// targets (D-i5); callers pass `LabTarget.fingerRadius` for finger taps.
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
