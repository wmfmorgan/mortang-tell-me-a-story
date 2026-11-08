import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../input/pointer_input.dart';
import '../model/lab_models.dart';
import '../playback/playback_controller.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
import '../widgets/view_switch.dart';
import 'canvas_label.dart';
import 'renderer_contract.dart';
import 'story_marker.dart';
import 'tree_graph_layout.dart';

/// F: node-link tree on one `CustomPainter`. Time tree (root → decade →
/// year → story) or family tree (branches hang off their origin story).
/// Dense groups collapse into a `+N` node that expands on tap.
class TreeGraphTimeline extends StatefulWidget {
  const TreeGraphTimeline({super.key, required this.data});

  final TimelineViewData data;

  @override
  State<TreeGraphTimeline> createState() => _TreeGraphTimelineState();
}

class _TreeGraphTimelineState extends State<TreeGraphTimeline> {
  TreeBy _by = TreeBy.time;
  final Set<String> _expanded = {};
  final _vCtl = ScrollController();
  final _hCtl = ScrollController();
  TreeLayout? _layout;
  String? _lastFollowed;
  final _hoverTarget = ValueNotifier(false);

  PlaybackController? get _playback => widget.data.playback;

  @override
  void initState() {
    super.initState();
    _rebuild();
    _playback?.addListener(_follow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.data.newestMatched?.id;
      if (mounted && id != null) _scrollToStory(id);
    });
  }

  @override
  void didUpdateWidget(TreeGraphTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(old.data.entries, widget.data.entries) ||
        !identical(old.data.dataset, widget.data.dataset)) {
      _rebuild();
    }
    if (old.data.playback != _playback) {
      old.data.playback?.removeListener(_follow);
      _playback?.addListener(_follow);
    }
  }

  void _rebuild() {
    final d = widget.data;
    final root = switch (_by) {
      TreeBy.time => buildTimeTree(d.entries, expanded: _expanded),
      TreeBy.family => buildFamilyTree(
        d.entries,
        d.dataset,
        expanded: _expanded,
      ),
    };
    _layout = root == null ? null : TreeLayout(root);
  }

  void _scrollToStory(String storyId) {
    final layout = _layout;
    final node = layout?.storyNodes[storyId];
    if (node == null || !_vCtl.hasClients) return;
    _vCtl.jumpTo(
      scrollOffsetToPlace(
        layout!.positions[node]!.dy,
        _vCtl.position,
        kFocusAlignment,
      ),
    );
  }

  void _follow() {
    final pb = _playback!;
    final current = pb.current;
    if (!pb.follow || current == null || current.id == _lastFollowed) return;
    _lastFollowed = current.id;
    _scrollToStory(current.id);
  }

  void _onTap(TreeNode node) {
    switch (node.kind) {
      case TreeNodeKind.story:
        widget.data.onSelect(node.storyId!);
      case TreeNodeKind.overflow:
        setState(() {
          _expanded.add(node.parent!.id);
          _rebuild();
        });
      case _ when _expanded.contains(node.id):
        setState(() {
          _expanded.remove(node.id);
          _rebuild();
        });
      case _:
        break;
    }
  }

  @override
  void dispose() {
    _playback?.removeListener(_follow);
    _vCtl.dispose();
    _hCtl.dispose();
    _hoverTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ViewSwitch<TreeBy>(
          switchKey: const Key('tree-by'),
          label: 'Tree',
          values: TreeBy.values,
          labelOf: (v) => switch (v) {
            TreeBy.time => 'Time',
            TreeBy.family => 'Family',
          },
          selected: _by,
          onChanged: (v) => setState(() {
            _by = v;
            _expanded.clear();
            _rebuild();
          }),
        ),
        Expanded(
          child: layout == null
              ? const SizedBox.shrink()
              : NotificationListener<ScrollStartNotification>(
                  onNotification: (n) =>
                      disableFollowOnUserScroll(n, _playback),
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      controller: _vCtl,
                      child: ConstrainedBox(
                        // A short (filtered) tree still pans anywhere (F7).
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: SingleChildScrollView(
                          controller: _hCtl,
                          scrollDirection: Axis.horizontal,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _hoverTarget,
                            // Only the cursor rebuilds; the painter and its
                            // laid-out labels are reused.
                            builder: (context, over, child) => MouseRegion(
                              cursor: over
                                  ? SystemMouseCursors.click
                                  : MouseCursor.defer,
                              onHover: (e) => _hoverTarget.value =
                                  layout.hitTest(e.localPosition) != null,
                              onExit: (_) => _hoverTarget.value = false,
                              child: child,
                            ),
                            child: GestureDetector(
                              onTapUp: (details) {
                                final hit = layout.hitTest(
                                  details.localPosition,
                                  radius: hitRadiusFor(
                                    details.kind,
                                    precise: TreeLayout.hitRadius,
                                  ),
                                );
                                if (hit != null) _onTap(hit);
                              },
                              child: CustomPaint(
                                size: layout.size,
                                painter: TreePainter(
                                  layout: layout,
                                  dataset: widget.data.dataset,
                                  selectedId: widget.data.selectedId,
                                  playback: _playback,
                                  labelStyle: theme.labelSmall!,
                                  headingStyle: LabText.group(theme),
                                  badgeStyle: LabText.badge(theme),
                                  dimming: widget.data.anyDimmed,
                                  onTapNode: _onTap,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Edges into matched nodes read as the path only while something is
/// dimmed; otherwise every edge recedes.
Color treeEdgeColor({required bool childMatched, required bool dimming}) =>
    dimming && childMatched ? labRuleStrong : labRule;

class TreePainter extends CustomPainter {
  TreePainter({
    required this.layout,
    required this.dataset,
    required this.selectedId,
    required this.playback,
    required this.labelStyle,
    required this.headingStyle,
    required this.badgeStyle,
    required this.dimming,
    required this.onTapNode,
  }) : super(repaint: playback);

  final TreeLayout layout;
  final LabDataset dataset;
  final String? selectedId;
  final PlaybackController? playback;
  final TextStyle labelStyle;
  final TextStyle headingStyle;
  final TextStyle badgeStyle;
  final bool dimming;
  final ValueChanged<TreeNode> onTapNode;

  /// Text is laid out once per painter, not per playback tick.
  final Map<TreeNode, CanvasLabel> _labels = {};

  late final Map<String, LabStory> _stories = {
    for (final s in dataset.stories) s.id: s,
  };

  double _reveal(String storyId) => playback?.reveal(storyId) ?? 1;

  /// Unmatched labels use [labDimmedInk], the lightest text the dim rule
  /// allows; playback fades are applied on top with a layer.
  CanvasLabel _label(TreeNode n) => _labels.putIfAbsent(n, () {
    final leaf = n.kind == TreeNodeKind.story && n.children.isEmpty;
    final style = (leaf ? labelStyle : headingStyle).copyWith(
      color: n.matched ? labInk : labDimmedInk,
    );
    return CanvasLabel(
      n.label,
      style,
      maxWidth: leaf ? layout.labelWidth - 16 : layout.levelGap - 24,
    );
  });

  static String _overflowText(int count) => '+$count more';

  @override
  void paint(Canvas canvas, Size size) {
    final pos = layout.positions;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = LabStroke.rule;
    for (final n in layout.nodes) {
      final from = pos[n]!;
      for (final c in n.children) {
        final r = _reveal(c.revealId);
        if (r == 0) continue;
        final to = pos[c]!;
        final midX = (from.dx + to.dx) / 2;
        final base = treeEdgeColor(childMatched: c.matched, dimming: dimming);
        edge.color = base.withValues(alpha: base.a * r);
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy),
          edge,
        );
      }
    }

    final knockout = Paint()..color = labParchment;
    for (final n in layout.nodes) {
      final r = _reveal(n.revealId);
      if (r == 0) continue;
      final p = pos[n]!;
      if (n.kind == TreeNodeKind.overflow) {
        _paintOverflow(canvas, n, p, r);
        continue;
      }
      final story = n.kind == TreeNodeKind.story;
      if (story) {
        paintStoryMarker(
          canvas,
          p,
          MarkerSpec(
            matched: n.matched,
            origin: isOrigin(_stories[n.storyId]!, dataset),
            selected: n.storyId == selectedId,
            diameter: LabMarker.small,
          ),
          reveal: r,
        );
      } else {
        // Groups: filled ink when anything under them matches, hollow
        // dimmed ink when nothing does (Decision D6).
        final group = Paint()
          ..color = (n.matched ? labInk : labDimmedInk).withValues(alpha: r);
        if (!n.matched) {
          group
            ..style = PaintingStyle.stroke
            ..strokeWidth = LabMarker.hollow;
        }
        canvas.drawCircle(p, LabMarker.small / 2, group);
      }

      final label = _label(n);
      // Leaves label to the right. Groups label above-right, inside their
      // own row band, so tightly packed sibling years never collide.
      final at = story
          ? p +
                Offset(
                  MarkerSpec.extent(LabMarker.small) / 2 + 2,
                  -label.size.height / 2,
                )
          : p + Offset(8, -label.size.height - 1);
      final box = at & label.size;
      // Group labels sit where incoming edges run; knock the edges out.
      if (!story) canvas.drawRect(box.inflate(2), knockout);
      if (r < 1) {
        canvas.saveLayer(box, Paint()..color = labInk.withValues(alpha: r));
        label.paint(canvas, at);
        canvas.restore();
      } else {
        label.paint(canvas, at);
      }
    }
  }

  /// `+N more` as one ink pill holding its own text.
  void _paintOverflow(Canvas canvas, TreeNode n, Offset p, double r) {
    final shown = n.hiddenStoryIds.where((id) => _reveal(id) > 0).length;
    final label = CanvasLabel(
      _overflowText(shown),
      badgeStyle.copyWith(color: labParchment.withValues(alpha: r)),
    );
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        p.dx - LabSpace.xs,
        p.dy - label.size.height / 2 - 2,
        label.size.width + 2 * LabSpace.s,
        label.size.height + 4,
      ),
      const Radius.circular(LabRadius.pill),
    );
    canvas.drawRRect(pill, Paint()..color = labInk.withValues(alpha: r));
    label.paint(
      canvas,
      Offset(pill.left + LabSpace.s, p.dy),
      anchor: Alignment.centerLeft,
    );
    label.dispose();
    if (n.hiddenStoryIds.contains(selectedId)) {
      canvas.drawRRect(
        pill.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = LabMarker.ring
          ..color = labTerracotta,
      );
    }
  }

  @override
  bool shouldRepaint(TreePainter old) =>
      !identical(old.layout, layout) ||
      old.selectedId != selectedId ||
      old.playback != playback ||
      old.dimming != dimming ||
      old.labelStyle != labelStyle;

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final n in layout.nodes)
          CustomPainterSemantics(
            rect: layout.rectOf(n),
            properties: SemanticsProperties(
              label: switch (n.kind) {
                TreeNodeKind.story =>
                  '${n.label}, ${dataset.dateLabel(_stories[n.storyId]!)}',
                TreeNodeKind.overflow => '${n.storyCount} more stories',
                _ => '${n.label}, ${n.storyCount} stories',
              },
              button:
                  n.kind == TreeNodeKind.story ||
                  n.kind == TreeNodeKind.overflow,
              textDirection: TextDirection.ltr,
              onTap:
                  n.kind == TreeNodeKind.story ||
                      n.kind == TreeNodeKind.overflow
                  ? () => onTapNode(n)
                  : null,
            ),
          ),
      ];

  @override
  bool shouldRebuildSemantics(TreePainter oldDelegate) =>
      !identical(oldDelegate.layout, layout);
}
