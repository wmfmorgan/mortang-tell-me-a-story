import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/tree/treemap_layout.dart';
import 'package:tell_me_a_story/ui/story/story_date.dart';
import 'package:tell_me_a_story/ui/story/story_title.dart';
import 'package:tell_me_a_story/ui/timeline/empty_timeline.dart';
import 'package:tell_me_a_story/ui/timeline/pointer_input.dart';
import 'package:tell_me_a_story/ui/timeline/timeline_entry.dart';
import 'package:tell_me_a_story/ui/timeline/view_switch.dart';

/// C9.
const emptyTreeMessage = 'No stories in this family tree yet.';

/// C5–C7.
String treemapByLabel(TreemapBy by) => switch (by) {
  TreemapBy.family => 'By family',
  TreemapBy.decade => 'By decade',
  TreemapBy.person => 'By person',
};

/// All Stories' count wording (`groupCountLabel`).
String _storyCount(int n) => n == 1 ? '1 story' : '$n stories';

/// The whole-tree overview: a squarified treemap of story counts. The
/// overview nests groups (family, decade or person) → cells; tapping drills
/// into a group, then into a cell whose stories become tiles. Every story is
/// shown undimmed (O6).
class TreemapView extends StatefulWidget {
  const TreemapView({
    super.key,
    required this.title,
    required this.stories,
    required this.tree,
    required this.onStory,
    required this.onFamily,
  });

  /// C2, the page heading. It is also the root crumb.
  final String title;

  /// Published stories of the tree, in timeline order.
  final List<Story> stories;
  final List<TreeFamily> tree;
  final ValueChanged<String> onStory;

  /// A family's title in the By family grouping.
  final ValueChanged<String> onFamily;

  @override
  State<TreemapView> createState() => _TreemapViewState();
}

class _TreemapViewState extends State<TreemapView> {
  TreemapBy _by = TreemapBy.family;
  String? _groupId;
  String? _cellId;

  void _open({String? group, String? cell}) => setState(() {
    _groupId = group;
    _cellId = cell;
  });

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _crumbs(context, null, null),
          const Expanded(child: EmptyTimeline(message: emptyTreeMessage)),
        ],
      );
    }
    final groups = buildTreemap(
      timelineEntries(widget.stories),
      widget.tree,
      _by,
    );
    final group = groups.where((g) => g.id == _groupId).firstOrNull;
    final cell = group?.cells.where((c) => c.id == _cellId).firstOrNull;
    final tints = treemapFamilyTints(widget.tree);

    final Widget body;
    if (cell != null) {
      body = _StoryTiles(cell: cell, tints: tints, onStory: widget.onStory);
    } else if (group != null) {
      body = _CellGrid(
        group: group,
        tints: tints,
        large: true,
        onCell: (c) => _open(group: group.id, cell: c.id),
      );
    } else {
      body = TreemapLayout(
        children: [
          for (final g in groups)
            TreemapSlot(
              weight: g.count.toDouble(),
              child: _GroupTile(
                group: g,
                tints: tints,
                onHeader: _by == TreemapBy.family
                    ? () => widget.onFamily(g.id)
                    : () => _open(group: g.id),
                onGroup: () => _open(group: g.id),
                onCell: (c) => _open(group: g.id, cell: c.id),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _crumbs(context, group, cell),
        ViewSwitch<TreemapBy>(
          switchKey: const Key('treemap-by'),
          values: TreemapBy.values,
          labelOf: treemapByLabel,
          selected: _by,
          onChanged: (v) => setState(() {
            _by = v;
            _groupId = null;
            _cellId = null;
          }),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AlbumSpace.l,
              AlbumSpace.s,
              AlbumSpace.l,
              AlbumSpace.l,
            ),
            child: body,
          ),
        ),
      ],
    );
  }

  /// The C2 heading, then › group › cell while drilled in. Every crumb but
  /// the last goes back up.
  Widget _crumbs(BuildContext context, TreemapGroup? group, TreemapCell? cell) {
    final crumbStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: albumInk);
    final link = crumbStyle?.copyWith(color: albumTerracotta);
    final heading = Semantics(
      header: true,
      headingLevel: 1,
      child: Text(
        widget.title,
        style: GoogleFonts.newsreader(
          color: albumInk,
          fontSize: 32,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    const chevron = Icon(Icons.chevron_right, size: 20, color: albumDimInk);
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
          if (group == null)
            KeyedSubtree(key: const Key('treemap-crumb-root'), child: heading)
          else
            InkWell(
              key: const Key('treemap-crumb-root'),
              onTap: () => _open(),
              child: heading,
            ),
          if (group != null) ...[
            chevron,
            TextButton(
              key: const Key('treemap-crumb-group'),
              onPressed: cell == null ? null : () => _open(group: group.id),
              child: Text(group.label, style: cell == null ? crumbStyle : link),
            ),
          ],
          if (cell != null) ...[chevron, Text(cell.label, style: crumbStyle)],
        ],
      ),
    );
  }
}

/// Overview tile: a header, then the group's cells as a nested treemap.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.tints,
    required this.onHeader,
    required this.onGroup,
    required this.onCell,
  });

  final TreemapGroup group;
  final Map<String, Color> tints;
  final VoidCallback onHeader;
  final VoidCallback onGroup;
  final ValueChanged<TreemapCell> onCell;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: albumInk, fontWeight: FontWeight.w600);
    // Cells sit 2 px inside the group's 1 px border, so their tile radius
    // (4) follows the group's 8 px curve.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: albumContainerShape(
          AlbumRadius.group,
          side: const BorderSide(color: albumRuleStrong),
        ),
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
                  onTap: onHeader,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
                    child: Text(
                      '${group.label} · ${group.count}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
              Expanded(
                child: _CellGrid(
                  group: group,
                  tints: tints,
                  onCell: onCell,
                  onSmallTap: onGroup,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CellGrid extends StatelessWidget {
  const _CellGrid({
    required this.group,
    required this.tints,
    required this.onCell,
    this.large = false,
    this.onSmallTap,
  });

  final TreemapGroup group;
  final Map<String, Color> tints;
  final ValueChanged<TreemapCell> onCell;
  final bool large;
  final VoidCallback? onSmallTap;

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
            tint: tints[treemapDominantFamily(c)] ?? albumPillFill,
            large: large,
            onTap: () => onCell(c),
            onSmallTap: onSmallTap,
          ),
        ),
    ],
  );
}

/// One cell: its label and story count on its family's tint. In the decade
/// and person groupings the tint is the cell's dominant family.
class TreemapCellTile extends StatelessWidget {
  const TreemapCellTile({
    super.key,
    required this.cell,
    required this.tint,
    required this.onTap,
    this.large = false,
    this.onSmallTap,
  });

  final TreemapCell cell;
  final Color tint;
  final VoidCallback onTap;

  /// Drill-down cells stand alone; overview cells sit inside a group.
  final bool large;

  /// Tap target for fingers when this cell is under [AlbumTarget.min] in
  /// either axis. Null means [onTap] for every input.
  final VoidCallback? onSmallTap;

  /// Cells at least this big on their shorter side get the group label size.
  static const _bigLabelSide = 96.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final radius = large ? AlbumRadius.group : AlbumRadius.tile;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${cell.label}, ${_storyCount(cell.count)}',
      child: LayoutBuilder(
        builder: (context, box) {
          final small =
              box.maxWidth < AlbumTarget.min || box.maxHeight < AlbumTarget.min;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            // A finger can't aim at a sub-44 pt cell. It opens the whole
            // group instead, where cells are large.
            onTapUp: (d) =>
                (small && onSmallTap != null && isFingerLike(d.kind)
                        ? onSmallTap!
                        : onTap)
                    .call(),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: tint,
                shape: albumContainerShape(
                  radius,
                  side: const BorderSide(
                    color: albumModalBorder,
                    width: AlbumStroke.hairline,
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth < 34 || box.maxHeight < 18) {
                    return const SizedBox.shrink();
                  }
                  final shortest = math.min(box.maxWidth, box.maxHeight);
                  final labelStyle =
                      (large || shortest >= _bigLabelSide
                              ? AlbumText.group(theme)
                              : theme.labelSmall!)
                          .copyWith(
                            color: albumInk,
                            fontWeight: FontWeight.w600,
                          );
                  final count = AlbumText.count(theme);
                  return Padding(
                    padding: const EdgeInsets.all(AlbumSpace.xs),
                    // Never overflow a short cell: shrink the pair instead.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cell.label, softWrap: false, style: labelStyle),
                          if (large || box.maxHeight >= 34)
                            Text(
                              '${cell.count}',
                              key: const Key('treemap-count'),
                              softWrap: false,
                              style: count.copyWith(
                                color: albumInk,
                                height: 1.1,
                                fontSize: treemapCountSize(
                                  shortest,
                                  base: count.fontSize ?? 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Deepest level: one equal-area tile per story, in date order.
class _StoryTiles extends StatelessWidget {
  const _StoryTiles({
    required this.cell,
    required this.tints,
    required this.onStory,
  });

  final TreemapCell cell;
  final Map<String, Color> tints;
  final ValueChanged<String> onStory;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!
        .copyWith(color: albumInk);
    return TreemapLayout(
      gap: 3,
      children: [
        for (final TimelineEntry(:story) in cell.entries)
          TreemapSlot(
            weight: 1,
            child: Semantics(
              button: true,
              child: GestureDetector(
                key: Key('treemap-story-${story.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onStory(story.id),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: tints[story.familyId] ?? albumPillFill,
                    shape: albumContainerShape(
                      AlbumRadius.group,
                      side: const BorderSide(color: albumPillBorder),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _FitText(
                      '${storyDateLabelFor(story)}\n${storyTitle(story)}',
                      style: style,
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

/// Multi-line text that shows as many whole lines as fit and ends the last
/// one in "…", instead of fading out at the bottom.
class _FitText extends StatelessWidget {
  const _FitText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final probe = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final lineHeight = probe.height;
      probe.dispose();
      final lines = (box.maxHeight / lineHeight).floor();
      if (lines < 1) return const SizedBox.shrink();
      return Text(
        text,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    },
  );
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
