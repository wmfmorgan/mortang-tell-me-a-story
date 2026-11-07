import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../model/lab_models.dart';
import '../playback/playback_controller.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
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
    final p = _vCtl.position;
    _vCtl.jumpTo(
      (layout!.positions[node]!.dy - p.viewportDimension * 0.4).clamp(
        0,
        p.maxScrollExtent,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = _layout;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<TreeBy>(
            key: const Key('tree-by'),
            segments: const [
              ButtonSegment(value: TreeBy.time, label: Text('Time')),
              ButtonSegment(value: TreeBy.family, label: Text('Family')),
            ],
            selected: {_by},
            onSelectionChanged: (s) => setState(() {
              _by = s.first;
              _expanded.clear();
              _rebuild();
            }),
          ),
        ),
        Expanded(
          child: layout == null
              ? Center(child: Text('No stories', style: theme.bodyMedium))
              : NotificationListener<ScrollStartNotification>(
                  onNotification: (n) =>
                      disableFollowOnUserScroll(n, _playback),
                  child: SingleChildScrollView(
                    controller: _vCtl,
                    child: SingleChildScrollView(
                      controller: _hCtl,
                      scrollDirection: Axis.horizontal,
                      child: GestureDetector(
                        onTapUp: (details) {
                          final hit = layout.hitTest(details.localPosition);
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
                            headingStyle: theme.labelLarge!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            onTapNode: _onTap,
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

class TreePainter extends CustomPainter {
  TreePainter({
    required this.layout,
    required this.dataset,
    required this.selectedId,
    required this.playback,
    required this.labelStyle,
    required this.headingStyle,
    required this.onTapNode,
  }) : super(repaint: playback);

  final TreeLayout layout;
  final LabDataset dataset;
  final String? selectedId;
  final PlaybackController? playback;
  final TextStyle labelStyle;
  final TextStyle headingStyle;
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

  Color _nodeColor(TreeNode n) => switch (n.kind) {
    TreeNodeKind.story => markerColor(_stories[n.storyId]!, dataset),
    TreeNodeKind.family => switch (n.id) {
      'f-fam-reyes' => labSage,
      'f-fam-okafor' => labMoss,
      _ => labTerracotta,
    },
    _ => labInk,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final pos = layout.positions;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final n in layout.nodes) {
      final from = pos[n]!;
      for (final c in n.children) {
        final r = _reveal(c.revealId);
        if (r == 0) continue;
        final to = pos[c]!;
        final midX = (from.dx + to.dx) / 2;
        edge.color = labInk.withValues(
          alpha: 0.35 * r * (c.matched ? 1 : labDimOpacity),
        );
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy),
          edge,
        );
      }
    }

    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final n in layout.nodes) {
      final r = _reveal(n.revealId);
      if (r == 0) continue;
      final p = pos[n]!;
      final dim = n.matched ? 1.0 : labDimOpacity;
      final isLeafLike =
          n.kind == TreeNodeKind.story || n.kind == TreeNodeKind.overflow;

      if (n.kind == TreeNodeKind.overflow) {
        final shown = n.hiddenStoryIds.where((id) => _reveal(id) > 0).length;
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 16, height: 12),
          const Radius.circular(6),
        );
        fill.color = labInk.withValues(alpha: r);
        canvas.drawRRect(rect, fill);
        paintLabel(
          canvas,
          _overflowText(shown),
          labelStyle.copyWith(color: labInk.withValues(alpha: r)),
          p + const Offset(12, 0),
          anchor: Alignment.centerLeft,
        );
        if (n.hiddenStoryIds.contains(selectedId)) {
          ring.color = labTerracotta;
          canvas.drawRRect(rect.inflate(2), ring);
        }
        continue;
      }

      fill.color = _nodeColor(n).withValues(alpha: r * dim);
      canvas.drawCircle(p, isLeafLike ? 4 : 6, fill);
      if (n.storyId != null) {
        final s = _stories[n.storyId]!;
        if (isOrigin(s, dataset)) {
          ring.color = labMoss.withValues(alpha: r);
          canvas.drawCircle(p, 7, ring);
        }
        if (n.storyId == selectedId) {
          ring.color = labTerracotta.withValues(alpha: r);
          canvas.drawCircle(p, 8, ring);
        }
      }

      final label = _label(n);
      // Leaves label to the right. Groups label above-right, inside their
      // own row band, so tightly packed sibling years never collide.
      final at = n.kind == TreeNodeKind.story
          ? p + Offset(10, -label.size.height / 2)
          : p + Offset(8, -label.size.height - 1);
      if (r < 1) {
        canvas.saveLayer(
          at & label.size,
          Paint()..color = labInk.withValues(alpha: r),
        );
        label.paint(canvas, at);
        canvas.restore();
      } else {
        label.paint(canvas, at);
      }
    }
  }

  @override
  bool shouldRepaint(TreePainter old) =>
      !identical(old.layout, layout) ||
      old.selectedId != selectedId ||
      old.playback != playback ||
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
