import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forui/forui.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_layout.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/core/widgets/story/story_title.dart';
import 'package:tell_me_a_story/core/widgets/timeline/empty_timeline.dart';
import 'package:tell_me_a_story/core/widgets/timeline/pointer_input.dart';
import 'package:tell_me_a_story/core/widgets/timeline/timeline_entry.dart';
import 'package:tell_me_a_story/core/widgets/timeline/view_switch.dart';

/// C9.
const emptyTreeMessage = 'No stories in this family tree yet.';

/// C19 (approved 2026-11-08): the action that opens a family's timeline,
/// after its treemap group or tree graph node is opened.
String openFamilyTimelineLabel(String family) => 'Open $family timeline';

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
    this.viewSwitch,
  });

  /// C2, the page heading. It is also the root crumb.
  final String title;

  /// Published stories of the tree, in timeline order.
  final List<Story> stories;
  final List<TreeFamily> tree;
  final ValueChanged<String> onStory;

  /// The drilled-in [openFamilyTimelineLabel] action (By family only).
  final ValueChanged<String> onFamily;

  /// The page's view switch (C3/C4), shown before the grouping switch in
  /// the same row (wrapping on narrow widths). Null in the treemap's own
  /// tests.
  final Widget? viewSwitch;

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

  void _select(TreemapBy by) => setState(() {
    _by = by;
    _groupId = null;
    _cellId = null;
  });

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return _EmptyTreemap(
        crumbs: _Crumbs(
          title: widget.title,
          by: _by,
          onOpen: _open,
          onFamily: widget.onFamily,
        ),
      );
    }
    final entries = timelineEntries(widget.stories);
    final groups = buildTreemap(entries, widget.tree, _by);
    final group = groups.where((g) => g.id == _groupId).firstOrNull;
    final cell = group?.cells.where((c) => c.id == _cellId).firstOrNull;
    final tints = treemapFamilyTints(widget.tree);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Crumbs(
          title: widget.title,
          group: group,
          cell: cell,
          by: _by,
          onOpen: _open,
          onFamily: widget.onFamily,
        ),
        _Switches(viewSwitch: widget.viewSwitch, by: _by, onBy: _select),
        _FamilyKey(tree: widget.tree, tints: tints),
        _TreemapBody(
          groups: groups,
          group: group,
          cell: cell,
          tints: tints,
          onOpen: _open,
          onStory: widget.onStory,
        ),
      ],
    );
  }
}

/// The page's view switch (if any), then the grouping switch, in one row.
class _Switches extends StatelessWidget {
  const _Switches({
    required this.viewSwitch,
    required this.by,
    required this.onBy,
  });

  final Widget? viewSwitch;
  final TreemapBy by;
  final ValueChanged<TreemapBy> onBy;

  @override
  Widget build(BuildContext context) {
    final bySwitch = ViewSwitch<TreemapBy>(
      key: const Key('treemap-by'),
      values: TreemapBy.values,
      labelOf: treemapByLabel,
      selected: by,
      onChanged: onBy,
    );
    if (viewSwitch case final viewSwitch?) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [viewSwitch, bySwitch],
      );
    }
    return bySwitch;
  }
}

typedef _OpenLevel = void Function({String? group, String? cell});

/// C9 under the heading.
class _EmptyTreemap extends StatelessWidget {
  const _EmptyTreemap({required this.crumbs});

  final Widget crumbs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      crumbs,
      const Expanded(child: EmptyTimeline(message: emptyTreeMessage)),
    ],
  );
}

/// The overview, a drilled group, or a drilled cell's story tiles.
class _TreemapBody extends StatelessWidget {
  const _TreemapBody({
    required this.groups,
    required this.group,
    required this.cell,
    required this.tints,
    required this.onOpen,
    required this.onStory,
  });

  final List<TreemapGroup> groups;
  final TreemapGroup? group;
  final TreemapCell? cell;
  final Map<String, Color> tints;
  final _OpenLevel onOpen;
  final ValueChanged<String> onStory;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    final cell = this.cell;
    final Widget content;
    if (cell != null) {
      content = _StoryTiles(cell: cell, tints: tints, onStory: onStory);
    } else if (group != null) {
      content = _CellGrid(
        group: group,
        tints: tints,
        large: true,
        onCell: (c) => onOpen(group: group.id, cell: c.id),
      );
    } else {
      content = _Overview(groups: groups, tints: tints, onOpen: onOpen);
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AlbumSpace.l,
          AlbumSpace.s,
          AlbumSpace.l,
          AlbumSpace.l,
        ),
        child: content,
      ),
    );
  }
}

/// The whole-tree overview: one [_GroupTile] per group.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.groups,
    required this.tints,
    required this.onOpen,
  });

  final List<TreemapGroup> groups;
  final Map<String, Color> tints;
  final _OpenLevel onOpen;

  @override
  Widget build(BuildContext context) => TreemapLayout(
    children: [
      for (final g in groups)
        TreemapSlot(
          weight: g.count.toDouble(),
          child: _GroupTile(
            group: g,
            tints: tints,
            onGroup: () => onOpen(group: g.id),
            onCell: (c) => onOpen(group: g.id, cell: c.id),
          ),
        ),
    ],
  );
}

/// The C2 heading, then › group › cell while drilled in. Every crumb but
/// the last goes back up.
class _Crumbs extends StatelessWidget {
  const _Crumbs({
    required this.title,
    required this.by,
    required this.onOpen,
    required this.onFamily,
    this.group,
    this.cell,
  });

  final String title;
  final TreemapGroup? group;
  final TreemapCell? cell;
  final TreemapBy by;
  final _OpenLevel onOpen;
  final ValueChanged<String> onFamily;

  @override
  Widget build(BuildContext context) {
    final group = this.group;
    final cell = this.cell;
    final crumbStyle = Theme.of(context).textTheme.titleMedium
        ?.copyWith(color: albumInk);
    final link = crumbStyle?.copyWith(color: albumTerracotta);
    final heading = TreeHeading(title);
    const chevron = Icon(Icons.chevron_right, size: 20, color: albumDimInk);
    return _CrumbRow(
      children: [
        if (group == null)
          KeyedSubtree(key: const Key('treemap-crumb-root'), child: heading)
        else
          InkWell(
            key: const Key('treemap-crumb-root'),
            onTap: () => onOpen(),
            child: heading,
          ),
        if (group != null) ...[
          chevron,
          FButton(
            key: const Key('treemap-crumb-group'),
            variant: FButtonVariant.ghost,
            mainAxisSize: MainAxisSize.min,
            onPress: cell == null ? null : () => onOpen(group: group.id),
            child: Text(group.label, style: cell == null ? crumbStyle : link),
          ),
        ],
        if (cell != null) ...[chevron, Text(cell.label, style: crumbStyle)],
        if (group != null && by == TreemapBy.family) ...[
          const SizedBox(width: AlbumSpace.m),
          OpenFamilyTimelineAction(
            key: const Key('treemap-open-family'),
            family: group.label,
            onPressed: () => onFamily(group.id),
          ),
        ],
      ],
    );
  }
}

/// The padded, wrapping row the crumbs sit in.
class _CrumbRow extends StatelessWidget {
  const _CrumbRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
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
      children: children,
    ),
  );
}

/// The C2 heading of the whole-tree views.
class TreeHeading extends StatelessWidget {
  const TreeHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    headingLevel: 1,
    child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
  );
}

/// The terracotta C19 action that opens [family]'s timeline.
class OpenFamilyTimelineAction extends StatelessWidget {
  const OpenFamilyTimelineAction({
    super.key,
    required this.family,
    required this.onPressed,
  });

  final String family;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FButton(
    variant: FButtonVariant.ghost,
    mainAxisSize: MainAxisSize.min,
    onPress: onPressed,
    prefix: const Icon(Icons.arrow_forward, size: 18, color: albumTerracotta),
    child: Text(
      openFamilyTimelineLabel(family),
      style: const TextStyle(color: albumTerracotta),
    ),
  );
}

/// Colour key: a swatch and the name of every family, in tree order, with
/// the tint its cells use. Wraps on narrow widths.
class _FamilyKey extends StatelessWidget {
  const _FamilyKey({required this.tree, required this.tints});

  final List<TreeFamily> tree;
  final Map<String, Color> tints;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: albumInk);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AlbumSpace.l,
        0,
        AlbumSpace.l,
        AlbumSpace.xs,
      ),
      child: Wrap(
        key: const Key('treemap-family-key'),
        spacing: AlbumSpace.m,
        runSpacing: AlbumSpace.xs,
        children: [
          for (final f in tree)
            _FamilyKeyEntry(family: f, tint: tints[f.id], style: style),
        ],
      ),
    );
  }
}

/// One family of the colour key: its swatch, then its name.
class _FamilyKeyEntry extends StatelessWidget {
  const _FamilyKeyEntry({
    required this.family,
    required this.tint,
    required this.style,
  });

  final TreeFamily family;
  final Color? tint;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    key: Key('treemap-key-${family.id}'),
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 14,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: tint,
            shape: albumContainerShape(
              AlbumRadius.tile,
              side: const BorderSide(color: albumRuleStrong),
            ),
          ),
        ),
      ),
      const SizedBox(width: AlbumSpace.xs),
      Flexible(
        child: Text(
          family.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    ],
  );
}

/// Overview tile: a header, then the group's cells as a nested treemap.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.tints,
    required this.onGroup,
    required this.onCell,
  });

  final TreemapGroup group;
  final Map<String, Color> tints;
  final VoidCallback onGroup;
  final ValueChanged<TreemapCell> onCell;

  @override
  Widget build(BuildContext context) {
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
              if (roomForHeader) _GroupHeader(group: group, onTap: onGroup),
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

/// An overview group's `label · count` header; it drills into the group.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.onTap});

  final TreemapGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: albumInk, fontWeight: FontWeight.w600);
    return InkWell(
      key: Key('treemap-group-${group.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 2),
        child: Text(
          '${group.label} · ${group.count}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
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
  Widget build(BuildContext context) => Semantics(
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
          onTapUp: (d) {
            final smallTap = onSmallTap;
            if (small && smallTap != null && isFingerLike(d.kind)) {
              smallTap();
            } else {
              onTap();
            }
          },
          child: _CellFace(cell: cell, tint: tint, large: large),
        );
      },
    ),
  );
}

/// A cell's tinted, bordered face; its label and count when they fit.
class _CellFace extends StatelessWidget {
  const _CellFace({
    required this.cell,
    required this.tint,
    required this.large,
  });

  final TreemapCell cell;
  final Color tint;
  final bool large;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: tint,
      shape: albumContainerShape(
        large ? AlbumRadius.group : AlbumRadius.tile,
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
        return _CellLabel(cell: cell, large: large, box: box);
      },
    ),
  );
}

/// A cell's label, then its story count when the cell is tall enough.
class _CellLabel extends StatelessWidget {
  const _CellLabel({
    required this.cell,
    required this.large,
    required this.box,
  });

  final TreemapCell cell;
  final bool large;
  final BoxConstraints box;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final shortest = math.min(box.maxWidth, box.maxHeight);
    final labelStyle =
        (large || shortest >= TreemapCellTile._bigLabelSide
                ? AlbumText.group(theme)
                // albumTheme() always sets labelSmall.
                : theme.labelSmall ?? const TextStyle())
            .copyWith(color: albumInk, fontWeight: FontWeight.w600);
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
    // albumTheme() always sets labelMedium.
    final style = (Theme.of(context).textTheme.labelMedium ?? const TextStyle())
        .copyWith(color: albumInk);
    return TreemapLayout(
      gap: 3,
      children: [
        for (final TimelineEntry(:story) in cell.entries)
          TreemapSlot(
            weight: 1,
            child: _StoryTile(
              story: story,
              tint: tints[story.familyId] ?? albumPillFill,
              style: style,
              onTap: () => onStory(story.id),
            ),
          ),
      ],
    );
  }
}

/// One story of a drilled cell: its date and title on its family's tint.
class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.story,
    required this.tint,
    required this.style,
    required this.onTap,
  });

  final Story story;
  final Color tint;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      key: Key('treemap-story-${story.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: tint,
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
  );
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
    final pd = renderObject.parentData as TreemapParentData;
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
      for (final c in children) (c.parentData as TreemapParentData).weight,
    ], Offset.zero & size);
    for (final (i, child) in children.indexed) {
      final r = rects[i].deflate(gap / 2);
      final w = math.max(0.0, r.width), h = math.max(0.0, r.height);
      child.layout(BoxConstraints.tight(Size(w, h)));
      (child.parentData as TreemapParentData).offset = r.topLeft;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
