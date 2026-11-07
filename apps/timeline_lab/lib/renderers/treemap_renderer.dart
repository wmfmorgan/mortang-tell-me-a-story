import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../filter/timeline_filter.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
import '../widgets/view_switch.dart';
import 'renderer_contract.dart';
import 'treemap_layout.dart';

/// G: squarified treemap of story counts. Overview nests groups (decade,
/// family or person) → cells; tapping drills into a group, then into a cell
/// whose stories become tiles. The layout is computed from all entries and
/// never moves during playback: cells fill as their stories reveal.
class TreemapTimeline extends StatefulWidget {
  const TreemapTimeline({super.key, required this.data});

  final TimelineViewData data;

  @override
  State<TreemapTimeline> createState() => _TreemapTimelineState();
}

class _TreemapTimelineState extends State<TreemapTimeline> {
  TreemapBy _by = TreemapBy.decade;
  String? _groupId;
  String? _cellId;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final groups = buildTreemap(data.entries, data.dataset, _by);
    final group = groups.where((g) => g.id == _groupId).firstOrNull;
    final cell = group?.cells.where((c) => c.id == _cellId).firstOrNull;

    final Widget body;
    if (groups.isEmpty) {
      body = const Center(child: Text('No stories'));
    } else if (cell != null) {
      body = _StoryTiles(cell: cell, data: data);
    } else if (group != null) {
      body = _CellGrid(
        group: group,
        data: data,
        onCell: (c) => setState(() => _cellId = c.id),
        large: true,
      );
    } else {
      body = TreemapLayout(
        children: [
          for (final g in groups)
            TreemapSlot(
              weight: g.count.toDouble(),
              child: _GroupTile(
                group: g,
                data: data,
                onGroup: () => setState(() {
                  _groupId = g.id;
                  _cellId = null;
                }),
                onCell: (c) => setState(() {
                  _groupId = g.id;
                  _cellId = c.id;
                }),
              ),
            ),
        ],
      );
    }

    final crumbStyle = Theme.of(context).textTheme.labelLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ViewSwitch<TreemapBy>(
          switchKey: const Key('treemap-by'),
          label: 'Group by',
          values: TreemapBy.values,
          labelOf: (v) => switch (v) {
            TreemapBy.decade => 'Decade',
            TreemapBy.family => 'Family',
            TreemapBy.person => 'Person',
          },
          selected: _by,
          onChanged: (v) => setState(() {
            _by = v;
            _groupId = null;
            _cellId = null;
          }),
          trailing: [
            const SizedBox(width: 16),
            TextButton(
              key: const Key('treemap-crumb-root'),
              onPressed: () => setState(() {
                _groupId = null;
                _cellId = null;
              }),
              child: Text('All', style: crumbStyle),
            ),
            if (group != null) ...[
              const Text('›'),
              TextButton(
                key: const Key('treemap-crumb-group'),
                onPressed: () => setState(() => _cellId = null),
                child: Text(group.label, style: crumbStyle),
              ),
            ],
            if (cell != null) ...[
              const Text('›'),
              TextButton(
                onPressed: null,
                child: Text(cell.label, style: crumbStyle),
              ),
            ],
          ],
        ),
        Expanded(
          child: Padding(padding: const EdgeInsets.all(8), child: body),
        ),
      ],
    );
  }
}

/// Overview tile: header + nested cell treemap.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.data,
    required this.onGroup,
    required this.onCell,
  });

  final TreemapGroup group;
  final TimelineViewData data;
  final VoidCallback onGroup;
  final ValueChanged<TreemapCell> onCell;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: labBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final roomForHeader = box.maxHeight >= 40 && box.maxWidth >= 48;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (roomForHeader)
                InkWell(
                  key: Key('treemap-group-${group.id}'),
                  onTap: onGroup,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
                    child: Text(
                      '${group.label} · ${_countLabel(group.count, group.matchedCount, data.mode)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
              Expanded(
                child: _CellGrid(group: group, data: data, onCell: onCell),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _countLabel(int count, int matched, FilterMode mode) =>
    mode == FilterMode.dim && matched != count ? '$matched/$count' : '$count';

class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.group,
    required this.data,
    required this.onCell,
    this.large = false,
  });

  final TreemapGroup group;
  final TimelineViewData data;
  final ValueChanged<TreemapCell> onCell;
  final bool large;

  @override
  Widget build(BuildContext context) => TreemapLayout(
    gap: 2,
    children: [
      for (final c in group.cells)
        TreemapSlot(
          weight: c.count.toDouble(),
          child: TreemapCellTile(
            key: Key('treemap-cell-${c.id}'),
            cell: c,
            data: data,
            large: large,
            onTap: () => onCell(c),
          ),
        ),
    ],
  );
}

/// One cell. Its shade shows the matched share (dim); during playback the
/// filled part rises from the bottom as its stories reveal, so the layout
/// never moves.
class TreemapCellTile extends StatelessWidget {
  const TreemapCellTile({
    super.key,
    required this.cell,
    required this.data,
    required this.onTap,
    this.large = false,
  });

  final TreemapCell cell;
  final TimelineViewData data;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final pb = data.playback;
    if (pb == null) return _build(context, 1);
    return ListenableBuilder(
      listenable: pb,
      builder: (context, _) => _build(
        context,
        pb.active
            ? cell.entries.where((e) => pb.reveal(e.story.id) > 0).length /
                  cell.count
            : 1,
      ),
    );
  }

  Widget _build(BuildContext context, double revealed) {
    final share = cell.count == 0 ? 0.0 : cell.matchedCount / cell.count;
    final fill = labTerracotta.withValues(alpha: treemapFillAlpha(share));
    final theme = Theme.of(context).textTheme;
    final selected = cell.entries.any((e) => e.story.id == data.selectedId);
    return Semantics(
      button: true,
      label:
          '${cell.label}, ${cell.count} stories'
          '${data.mode == FilterMode.dim ? ', ${cell.matchedCount} matching' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: labTerracotta.withValues(alpha: 0.05),
            border: Border.all(
              color: selected ? labTerracotta : labPillBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: revealed.clamp(0, 1),
                  widthFactor: 1,
                  child: ColoredBox(color: fill),
                ),
              ),
              LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth < 34 || box.maxHeight < 18) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      large || box.maxHeight >= 34
                          ? '${cell.label}\n${_countLabel(cell.count, cell.matchedCount, data.mode)}'
                          : cell.label,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      // Label and count are separate lines; never break
                      // "1920s" mid-word in a narrow cell.
                      softWrap: false,
                      style: (large ? theme.titleSmall : theme.labelSmall)
                          ?.copyWith(color: share > 0 ? labInk : labDimmedInk),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deepest level: one equal-area tile per story, in date order.
class _StoryTiles extends StatelessWidget {
  const _StoryTiles({required this.cell, required this.data});

  final TreemapCell cell;
  final TimelineViewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return TreemapLayout(
      gap: 3,
      children: [
        for (final e in cell.entries)
          TreemapSlot(
            weight: 1,
            child: RevealOpacity(
              playback: data.playback,
              storyId: e.story.id,
              child: GestureDetector(
                key: Key('treemap-story-${e.story.id}'),
                onTap: () => data.onSelect(e.story.id),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: labTerracotta.withValues(
                      alpha: e.matched ? 0.18 : 0.06,
                    ),
                    border: Border.all(
                      color: e.story.id == data.selectedId
                          ? labTerracotta
                          : labPillBorder,
                      width: e.story.id == data.selectedId ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(labCardRadius / 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '${data.dataset.dateLabel(e.story)}\n${e.story.title}',
                      overflow: TextOverflow.fade,
                      style: theme.labelMedium?.copyWith(
                        color: e.matched ? labInk : labDimmedInk,
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

class TreemapParentData extends ContainerBoxParentData<RenderBox> {
  double weight = 0;
}

class TreemapSlot extends ParentDataWidget<TreemapParentData> {
  const TreemapSlot({super.key, required this.weight, required super.child});

  final double weight;

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData! as TreemapParentData;
    if (pd.weight == weight) return;
    pd.weight = weight;
    final parent = renderObject.parent;
    if (parent is RenderObject) parent.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => TreemapLayout;
}

/// Lays children out with [squarify] by their [TreemapSlot.weight]. Children
/// must come in descending weight order. Fills the incoming constraints.
class TreemapLayout extends MultiChildRenderObjectWidget {
  const TreemapLayout({super.key, this.gap = 4, super.children});

  final double gap;

  @override
  RenderTreemapLayout createRenderObject(BuildContext context) =>
      RenderTreemapLayout(gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTreemapLayout renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class RenderTreemapLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TreemapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TreemapParentData> {
  RenderTreemapLayout({required this._gap});

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TreemapParentData) {
      child.parentData = TreemapParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth && constraints.hasBoundedHeight);
    size = constraints.biggest;
    final children = getChildrenAsList();
    final rects = squarify([
      for (final c in children) (c.parentData! as TreemapParentData).weight,
    ], Offset.zero & size);
    for (final (i, child) in children.indexed) {
      final r = rects[i].deflate(gap / 2);
      final w = math.max(0.0, r.width), h = math.max(0.0, r.height);
      child.layout(BoxConstraints.tight(Size(w, h)));
      (child.parentData! as TreemapParentData).offset = r.topLeft;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
