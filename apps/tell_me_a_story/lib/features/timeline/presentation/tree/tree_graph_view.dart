import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/tree_graph_layout.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_layout.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_view.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/core/widgets/timeline/canvas_label.dart';
import 'package:tell_me_a_story/core/widgets/timeline/empty_timeline.dart';
import 'package:tell_me_a_story/core/widgets/timeline/pointer_input.dart';
import 'package:tell_me_a_story/core/widgets/timeline/story_marker.dart';

/// C8: the semantics label of a `+N` node.
String moreStoriesLabel(int n) => '$n more stories';

/// All Stories' count wording (`groupCountLabel`).
String _storyCount(int n) => n == 1 ? '1 story' : '$n stories';

/// The family tree graph (Q2, Family mode): family → decade → story, with
/// each branch hanging off its origin story, on one `CustomPainter`. Dense
/// decades collapse to `+N`, which expands on tap. A story opens the reader;
/// a family is selected and offers its timeline (C19), as the treemap's
/// family header does.
class TreeGraphView extends StatefulWidget {
  const TreeGraphView({
    super.key,
    required this.title,
    required this.stories,
    required this.tree,
    required this.onStory,
    required this.onFamily,
    this.viewSwitch,
  });

  /// C2, the page heading. Also the hub's label when the tree has several
  /// root families.
  final String title;

  /// Published stories of the tree, in timeline order.
  final List<Story> stories;
  final List<TreeFamily> tree;
  final ValueChanged<String> onStory;

  /// The [openFamilyTimelineLabel] action of the selected family.
  final ValueChanged<String> onFamily;

  /// The page's view switch (C3/C4), in its own row under the heading.
  final Widget? viewSwitch;

  @override
  State<TreeGraphView> createState() => _TreeGraphViewState();
}

class _TreeGraphViewState extends State<TreeGraphView> {
  final Set<String> _expanded = {};
  String? _selectedFamilyId;
  final _vCtl = ScrollController();
  final _hCtl = ScrollController();
  final _hoverTarget = ValueNotifier(false);
  TreeLayout? _layout;
  late Map<String, Story> _storyById;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(TreeGraphView old) {
    super.didUpdateWidget(old);
    if (!identical(old.stories, widget.stories) ||
        !identical(old.tree, widget.tree) ||
        old.title != widget.title) {
      if (!widget.tree.any((f) => f.id == _selectedFamilyId)) {
        _selectedFamilyId = null;
      }
      _rebuild();
    }
  }

  void _rebuild() {
    _storyById = {for (final s in widget.stories) s.id: s};
    final root = buildFamilyTree(
      widget.stories,
      widget.tree,
      rootLabel: widget.title,
      expanded: _expanded,
    );
    _layout = root == null ? null : TreeLayout(root);
  }

  void _onTap(TreeNode node) {
    switch (node.kind) {
      case TreeNodeKind.story:
        if (node.storyId case final storyId?) widget.onStory(storyId);
      case TreeNodeKind.overflow:
        if (node.parent case final parent?) {
          setState(() {
            _expanded.add(parent.id);
            _rebuild();
          });
        }
      case TreeNodeKind.family:
        setState(() => _selectedFamilyId = node.familyId);
      case TreeNodeKind.decade when _expanded.contains(node.id):
        setState(() {
          _expanded.remove(node.id);
          _rebuild();
        });
      case TreeNodeKind.decade || TreeNodeKind.root:
        break;
    }
  }

  @override
  void dispose() {
    _vCtl.dispose();
    _hCtl.dispose();
    _hoverTarget.dispose();
    super.dispose();
  }

  String? _familyName(String? id) {
    for (final f in widget.tree) {
      if (f.id == id) return f.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final selectedId = _selectedFamilyId;
    final selectedName = _familyName(selectedId);
    final viewSwitch = widget.viewSwitch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GraphHeading(
          title: widget.title,
          selected: selectedId != null && selectedName != null
              ? (id: selectedId, name: selectedName)
              : null,
          onFamily: widget.onFamily,
        ),
        if (layout == null)
          const Expanded(child: EmptyTimeline(message: emptyTreeMessage))
        else ...[
          ?viewSwitch,
          Expanded(
            child: _TreeGraphCanvas(
              painter: _painter(context, layout),
              vertical: _vCtl,
              horizontal: _hCtl,
              hoverTarget: _hoverTarget,
              onTap: _onTap,
            ),
          ),
        ],
      ],
    );
  }

  TreeGraphPainter _painter(BuildContext context, TreeLayout layout) {
    final theme = Theme.of(context).textTheme;
    // albumTheme() always sets labelSmall.
    final labelSmall = theme.labelSmall ?? const TextStyle();
    return TreeGraphPainter(
      layout: layout,
      stories: _storyById,
      tree: widget.tree,
      tints: treemapFamilyTints(widget.tree),
      selectedFamilyId: _selectedFamilyId,
      labelStyle: labelSmall.copyWith(color: albumInk),
      headingStyle: AlbumText.group(theme).copyWith(color: albumInk),
      badgeStyle: AlbumText.badge(theme),
      onTapNode: _onTap,
    );
  }
}

/// C2, then the C19 action of the selected family.
class _GraphHeading extends StatelessWidget {
  const _GraphHeading({
    required this.title,
    required this.selected,
    required this.onFamily,
  });

  final String title;
  final ({String id, String name})? selected;
  final ValueChanged<String> onFamily;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AlbumSpace.l,
        AlbumSpace.xl,
        AlbumSpace.l,
        AlbumSpace.xs,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AlbumSpace.xs,
        runSpacing: AlbumSpace.xs,
        children: [
          TreeHeading(title),
          if (selected != null) ...[
            const SizedBox(width: AlbumSpace.m),
            OpenFamilyTimelineAction(
              key: const Key('tree-graph-open-family'),
              family: selected.name,
              onPressed: () => onFamily(selected.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// The pannable graph canvas: scrolls both ways, a pointer cursor over a
/// node, taps hit-tested with the pointer's radius.
class _TreeGraphCanvas extends StatelessWidget {
  const _TreeGraphCanvas({
    required this.painter,
    required this.vertical,
    required this.horizontal,
    required this.hoverTarget,
    required this.onTap,
  });

  final TreeGraphPainter painter;
  final ScrollController vertical;
  final ScrollController horizontal;
  final ValueNotifier<bool> hoverTarget;
  final ValueChanged<TreeNode> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const Key('tree-graph-pan'),
      builder: (context, box) => SingleChildScrollView(
        controller: vertical,
        child: ConstrainedBox(
          // A short tree still pans anywhere in the viewport.
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: SingleChildScrollView(
            controller: horizontal,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Align(
                alignment: Alignment.topLeft,
                child: _HoverCanvas(
                  painter: painter,
                  hoverTarget: hoverTarget,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverCanvas extends StatelessWidget {
  const _HoverCanvas({
    required this.painter,
    required this.hoverTarget,
    required this.onTap,
  });

  final TreeGraphPainter painter;
  final ValueNotifier<bool> hoverTarget;
  final ValueChanged<TreeNode> onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hoverTarget,
      // Only the cursor rebuilds; the painter and its laid-out labels are
      // reused.
      builder: (context, over, child) => MouseRegion(
        cursor: over ? SystemMouseCursors.click : MouseCursor.defer,
        onHover: (e) =>
            hoverTarget.value = painter.nodeAt(e.localPosition) != null,
        onExit: (_) => hoverTarget.value = false,
        child: child,
      ),
      child: GestureDetector(
        onTapUp: (details) {
          final hit = painter.nodeAt(
            details.localPosition,
            radius: hitRadiusFor(details.kind, precise: TreeLayout.hitRadius),
          );
          if (hit != null) onTap(hit);
        },
        child: CustomPaint(
          key: const Key('tree-graph-canvas'),
          size: painter.layout.size,
          painter: painter,
        ),
      ),
    );
  }
}

class TreeGraphPainter extends CustomPainter {
  TreeGraphPainter({
    required this.layout,
    required this.stories,
    required this.tree,
    required this.tints,
    required this.selectedFamilyId,
    required this.labelStyle,
    required this.headingStyle,
    required this.badgeStyle,
    required this.onTapNode,
  });

  final TreeLayout layout;
  final Map<String, Story> stories;
  final List<TreeFamily> tree;

  /// The treemap's family tints (7.7), so a family keeps its colour across
  /// both views.
  final Map<String, Color> tints;
  final String? selectedFamilyId;
  final TextStyle labelStyle;
  final TextStyle headingStyle;
  final TextStyle badgeStyle;
  final ValueChanged<TreeNode> onTapNode;

  /// Padding of a family name inside its tinted chip.
  static const _chipPad = EdgeInsets.symmetric(horizontal: 6, vertical: 2);

  /// Text is laid out once per painter.
  final Map<TreeNode, CanvasLabel> _labels = {};

  CanvasLabel _label(TreeNode n) => _labels.putIfAbsent(n, () {
    final leaf = n.kind == TreeNodeKind.story && n.children.isEmpty;
    return switch (n.kind) {
      TreeNodeKind.overflow => CanvasLabel(n.label, badgeStyle),
      TreeNodeKind.family => CanvasLabel(
        n.label,
        headingStyle,
        maxWidth: layout.levelGap - 24 - _chipPad.horizontal,
      ),
      _ => CanvasLabel(
        n.label,
        leaf ? labelStyle : headingStyle,
        maxWidth: leaf ? layout.labelWidth - 16 : layout.levelGap - 24,
      ),
    };
  });

  /// Knocks edges out behind group labels and family chips.
  static final _knockout = Paint()..color = albumParchment;

  /// The dot of a family, decade or root node.
  static final _groupDot = Paint()..color = albumInk;

  @override
  void paint(Canvas canvas, Size size) {
    _paintEdges(canvas);
    for (final n in layout.nodes) {
      final p = layout.positionOf(n);
      final label = _label(n);
      switch (n.kind) {
        case TreeNodeKind.overflow:
          _paintOverflow(canvas, n, label, p);
        case TreeNodeKind.story:
          _paintStory(canvas, n, label, p);
        case TreeNodeKind.family:
          _paintFamily(canvas, n, label, p);
        case TreeNodeKind.decade || TreeNodeKind.root:
          _paintGroup(canvas, label, p);
      }
    }
  }

  /// One curve from every node to each of its children.
  void _paintEdges(Canvas canvas) {
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AlbumStroke.rule
      ..color = albumRule;
    for (final n in layout.nodes) {
      final from = layout.positionOf(n);
      for (final c in n.children) {
        final to = layout.positionOf(c);
        final midX = (from.dx + to.dx) / 2;
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy),
          edge,
        );
      }
    }
  }

  /// A story marker with its title to the right.
  void _paintStory(Canvas canvas, TreeNode n, CanvasLabel label, Offset p) {
    final story = stories[n.storyId];
    paintStoryMarker(
      canvas,
      p,
      MarkerSpec(
        matched: true,
        origin: story != null && isOrigin(story, tree),
        diameter: AlbumMarker.small,
      ),
    );
    label.paint(
      canvas,
      p +
          Offset(
            MarkerSpec.extent(AlbumMarker.small) / 2 + 2,
            -label.size.height / 2,
          ),
    );
  }

  /// A family dot. The name sits above-right on a chip in the family's
  /// tint, so the graph and the treemap share one colour per family.
  void _paintFamily(Canvas canvas, TreeNode n, CanvasLabel label, Offset p) {
    canvas.drawCircle(p, AlbumMarker.small / 2, _groupDot);
    final chipRect = familyChipRect(n);
    final at = _chipPad.deflateRect(chipRect).topLeft;
    final chip = RRect.fromRectAndRadius(
      chipRect,
      const Radius.circular(AlbumRadius.tile),
    );
    canvas
      ..drawRRect(chip, _knockout)
      ..drawRRect(chip, Paint()..color = tints[n.familyId] ?? albumPillFill)
      ..drawRRect(
        chip,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AlbumStroke.hairline
          ..color = albumRuleStrong,
      );
    if (n.familyId == selectedFamilyId) {
      canvas.drawRRect(
        chip.inflate(AlbumMarker.gap + AlbumMarker.ring / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AlbumMarker.ring
          ..color = albumTerracotta,
      );
    }
    label.paint(canvas, at);
  }

  /// A decade or root dot. Its label sits above-right, inside the node's own
  /// row band; group labels sit where incoming edges run, so knock the edges
  /// out.
  void _paintGroup(Canvas canvas, CanvasLabel label, Offset p) {
    canvas.drawCircle(p, AlbumMarker.small / 2, _groupDot);
    final at = p + Offset(8, -label.size.height - 1);
    canvas.drawRect((at & label.size).inflate(2), _knockout);
    label.paint(canvas, at);
  }

  /// The `+N` pill of overflow node [n], in canvas coordinates. The whole
  /// pill is a target: it is the node, not a label beside it.
  Rect overflowRect(TreeNode n) {
    final p = layout.positionOf(n);
    final label = _label(n);
    return Rect.fromLTWH(
      p.dx - AlbumSpace.xs,
      p.dy - label.size.height / 2 - 2,
      label.size.width + 2 * AlbumSpace.s,
      label.size.height + 4,
    );
  }

  /// The tinted name chip of family node [n], in canvas coordinates: above
  /// and right of its dot.
  Rect familyChipRect(TreeNode n) {
    final p = layout.positionOf(n);
    final label = _label(n);
    final at =
        p + Offset(8 + _chipPad.left, -label.size.height - 1 - _chipPad.bottom);
    return _chipPad.inflateRect(at & label.size);
  }

  /// The painted box of [n] that is itself a target: the `+N` pill or a
  /// family's name chip. Null for nodes that are only a dot.
  Rect? targetBox(TreeNode n) => switch (n.kind) {
    TreeNodeKind.overflow => overflowRect(n),
    TreeNodeKind.family => familyChipRect(n),
    _ => null,
  };

  /// The node whose `+N` pill or family chip contains [p], else the node
  /// nearest [p] within [radius] ([TreeLayout.hitTest]). Other labels are
  /// not targets.
  TreeNode? nodeAt(Offset p, {double radius = TreeLayout.hitRadius}) =>
      layout.nodes
          .where((n) => targetBox(n)?.contains(p) ?? false)
          .firstOrNull ??
      layout.hitTest(p, radius: radius);

  /// `+N` as one ink pill holding its own text.
  void _paintOverflow(Canvas canvas, TreeNode n, CanvasLabel label, Offset p) {
    final pill = RRect.fromRectAndRadius(
      overflowRect(n),
      const Radius.circular(AlbumRadius.pill),
    );
    canvas.drawRRect(pill, Paint()..color = albumInk);
    label.paint(
      canvas,
      Offset(pill.left + AlbumSpace.s, p.dy),
      anchor: Alignment.centerLeft,
    );
  }

  @override
  bool shouldRepaint(TreeGraphPainter old) =>
      !identical(old.layout, layout) ||
      old.selectedFamilyId != selectedFamilyId ||
      old.labelStyle != labelStyle ||
      old.headingStyle != headingStyle ||
      old.badgeStyle != badgeStyle;

  String _semanticsLabel(TreeNode n) => switch (n.kind) {
    TreeNodeKind.story => switch (stories[n.storyId]) {
      final story? => '${n.label}, ${storyDateLabelFor(story)}',
      null => n.label,
    },
    TreeNodeKind.overflow => moreStoriesLabel(n.storyCount),
    _ => '${n.label}, ${_storyCount(n.storyCount)}',
  };

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final n in layout.nodes)
          CustomPainterSemantics(
            // One node per family: its dot and its chip together.
            rect: switch (n.kind) {
              TreeNodeKind.overflow => overflowRect(n),
              TreeNodeKind.family => familyChipRect(
                n,
              ).expandToInclude(layout.rectOf(n)),
              _ => layout.rectOf(n),
            },
            properties: SemanticsProperties(
              label: _semanticsLabel(n),
              button: _tappable(n),
              selected: n.kind == TreeNodeKind.family
                  ? n.familyId == selectedFamilyId
                  : null,
              textDirection: TextDirection.ltr,
              onTap: _tappable(n) ? () => onTapNode(n) : null,
            ),
          ),
      ];

  static bool _tappable(TreeNode n) => switch (n.kind) {
    TreeNodeKind.story || TreeNodeKind.overflow || TreeNodeKind.family => true,
    TreeNodeKind.decade || TreeNodeKind.root => false,
  };

  @override
  bool shouldRebuildSemantics(TreeGraphPainter oldDelegate) =>
      !identical(oldDelegate.layout, layout) ||
      oldDelegate.selectedFamilyId != selectedFamilyId;
}
