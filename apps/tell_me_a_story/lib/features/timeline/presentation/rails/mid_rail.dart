import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';
import 'package:tell_me_a_story/core/widgets/story/story_title.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/rail_scaffold.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/rail_spine.dart';
import 'package:tell_me_a_story/core/widgets/timeline/pointer_input.dart';
import 'package:tell_me_a_story/core/widgets/timeline/story_marker.dart';

class MidRail extends StatefulWidget {
  const MidRail({
    super.key,
    required this.stories,
    required this.focusedId,
    required this.branching,
    this.originStoryId,
    this.originTag,
    required this.anchorFor,
    required this.onStub,
    required this.onNode,
    required this.onEmpty,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMacro,
    required this.onFullCards,
    this.dimmed = const {},
    this.toolbar,
    this.notice,
  });

  final List<Story> stories;
  final String? focusedId;
  final RailBranching branching;
  final String? originStoryId;
  final String? originTag;
  final GlobalKey Function(String id) anchorFor;
  final ValueChanged<Story> onStub;
  final ValueChanged<Story> onNode;
  final VoidCallback onEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMacro;
  final VoidCallback onFullCards;

  /// Stories that miss the filter: dim ink and a hollow node (Q4).
  final Set<String> dimmed;

  /// Beside the zoom switch: the subheader's action buttons.
  final Widget? toolbar;

  /// Pinned above the rows (the C17 no-match card).
  final Widget? notice;

  @override
  State<MidRail> createState() => _MidRailState();
}

class _MidRailState extends State<MidRail> with RailScaffold<MidRail, String> {
  @override
  Iterable<String> get rowKeys => widget.stories.map((story) => story.id);

  @override
  BuildContext? rowContext(String id) => widget.anchorFor(id).currentContext;

  @override
  String? get initialCenterKey => widget.focusedId;

  @override
  String? get stepFallbackKey =>
      widget.focusedId ??
      (widget.stories.isEmpty ? null : widget.stories.first.id);

  @override
  double get opacityTolerance => 0.02;

  @override
  String? focusIdFor(String id) => id;

  @override
  String? get focusedStoryId => widget.focusedId;

  @override
  void onCenterStory(String id) => widget.onFocus(id);

  @override
  String? get fallbackCenterKey =>
      widget.stories.isEmpty ? null : widget.stories.first.id;

  @override
  RowFade Function(RenderBox row) fadeFor(RenderBox viewport) {
    final centerY = viewport
        .localToGlobal(Offset(0, viewport.size.height / 2))
        .dy;
    final half = viewport.size.height / 2;
    return (row) {
      final mid = row.localToGlobal(Offset(0, row.size.height / 2)).dy;
      final distance = (mid - centerY).abs();
      return (
        opacity: dialOpacity(distance: distance, halfExtent: half),
        distance: distance,
      );
    };
  }

  @override
  void didUpdateWidget(covariant MidRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    followFocus(widget.focusedId, oldWidget.focusedId);
  }

  @override
  Widget build(BuildContext context) {
    final looks = [
      for (final story in widget.stories)
        (
          focused: story.id == centerKey,
          dimmed: widget.dimmed.contains(story.id),
          opacity: opacityOf(story.id, unmeasured: 0.35),
          originTag: story.id == widget.originStoryId ? widget.originTag : null,
        ),
    ];
    return buildRail(
      selected: TimelineZoom.mid,
      onMacro: widget.onMacro,
      onMid: () {},
      onFullCards: widget.onFullCards,
      onEmpty: widget.onEmpty,
      action: widget.toolbar,
      notice: widget.notice,
      viewport: Stack(
        key: viewportKey,
        children: [
          const RailSpine(),
          _MidList(scroll: scroll, rail: widget, looks: looks),
          const _DialFade(top: true),
          const _DialFade(top: false),
        ],
      ),
    );
  }
}

class _MidList extends StatelessWidget {
  const _MidList({
    required this.scroll,
    required this.rail,
    required this.looks,
  });

  final ScrollController scroll;
  final MidRail rail;
  final List<_RowLook> looks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxHeight / 2;
        return ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
          children: [
            for (var i = 0; i < rail.stories.length; i++)
              _DialRow.at(rail, i, looks[i]),
          ],
        );
      },
    );
  }
}

/// Per-row state the rail scaffold owns: focus, filter, fade and origin tag.
typedef _RowLook = ({
  bool focused,
  bool dimmed,
  double opacity,
  String? originTag,
});

class _DialFade extends StatelessWidget {
  const _DialFade({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: 120,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [
                albumParchment,
                albumParchment.withValues(alpha: 0.85),
                albumParchment.withValues(alpha: 0),
              ],
              stops: const [0.15, 0.45, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialRow extends StatelessWidget {
  _DialRow.at(MidRail rail, int index, _RowLook look)
    : story = rail.stories[index],
      frame = rail.branching.frameFor(rail.stories[index]),
      cardOnLeft = index.isEven,
      originTag = look.originTag,
      onOpenBranch = rail.onOpenBranch,
      focused = look.focused,
      dimmed = look.dimmed,
      opacity = look.opacity,
      onTap = (() => rail.onStub(rail.stories[index])),
      onNode = (() => rail.onNode(rail.stories[index])),
      super(key: rail.anchorFor(rail.stories[index].id));

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final bool focused;

  /// Misses the filter: every text in [albumDimInk], a hollow node (Q4).
  final bool dimmed;
  final double opacity;
  final VoidCallback onTap;
  final VoidCallback onNode;

  @override
  Widget build(BuildContext context) {
    final side = cardOnLeft ? CalloutSide.left : CalloutSide.right;
    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: side,
            dot: _NodeHit(row: this, slop: false),
            dotDiameter: focused ? midDotFocusedDiameter : midDotDiameter,
            centerToLane: calloutLaneOffset,
            minCardFromRail: calloutFromRail,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    final parentOverlay = frame.parent == null
        ? null
        : parentCalloutOverlay(
            context: context,
            frame: frame,
            side: side,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          );
    return _DialRowLayout(row: this, placed: placed, overlay: parentOverlay);
  }
}

class _DialRowLayout extends StatelessWidget {
  const _DialRowLayout({
    required this.row,
    required this.placed,
    required this.overlay,
  });

  final _DialRow row;
  final PlacedBranch? placed;
  final ParentCalloutOverlay? overlay;

  @override
  Widget build(BuildContext context) {
    final card = _DialCard(row: row);
    final branch = placed;
    _DialSide sideCard(bool show) => _DialSide(
      show: show,
      card: card,
      overlay: overlay,
      cardOnLeft: row.cardOnLeft,
      placed: branch,
    );
    return Opacity(
      opacity: row.opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: branch == null
            ? _PlainDialRow(
                left: sideCard(row.cardOnLeft),
                right: sideCard(!row.cardOnLeft),
                node: _NodeHit(row: row, slop: true),
              )
            : _BranchDialRow(
                frame: row.frame,
                cardOnLeft: row.cardOnLeft,
                placed: branch,
                onOpenBranch: row.onOpenBranch,
                left: sideCard(row.cardOnLeft),
                right: sideCard(!row.cardOnLeft),
              ),
      ),
    );
  }
}

/// The row's story dot.
class _MidDot extends StatelessWidget {
  const _MidDot({required this.row});

  final _DialRow row;

  @override
  Widget build(BuildContext context) {
    final frame = row.frame;
    final focused = row.focused;
    return StoryDot(
      reserveRings: false,
      spec: MarkerSpec(
        matched: !row.dimmed,
        selected: focused && !frame.branchesStory && frame.parent == null,
        diameter: focused ? midDotFocusedDiameter : midDotDiameter,
      ),
    );
  }
}

/// The story's node. The branch ring sits just outside the dot. Extra slop
/// belongs only on a plain node, where it cannot cover that stroke: 8 pt for
/// a pointer, and the finger radius as a disk for a finger.
class _NodeHit extends StatelessWidget {
  const _NodeHit({required this.row, required this.slop});

  final _DialRow row;
  final bool slop;

  @override
  Widget build(BuildContext context) {
    final mark = _MidDot(row: row);
    final hit = GestureDetector(
      key: Key('timeline-mid-node-${row.story.id}'),
      behavior: HitTestBehavior.opaque,
      supportedDevices: slop ? preciseDevices : null,
      onTap: row.onNode,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: slop
            ? Padding(padding: const EdgeInsets.all(8), child: mark)
            : mark,
      ),
    );
    // The square bounds cover the ring on the diagonals. Only the disk
    // should open the story.
    if (!slop) return ClipOval(child: hit);
    return ClipOval(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        supportedDevices: fingerDevices,
        onTap: row.onNode,
        child: SizedBox.square(
          dimension: 2 * AlbumTarget.fingerRadius,
          child: Center(child: hit),
        ),
      ),
    );
  }
}

/// One half of a row: the card (under its parent callout, pushed past a
/// branch lane) when [show], else nothing.
class _DialSide extends StatelessWidget {
  const _DialSide({
    required this.show,
    required this.card,
    required this.overlay,
    required this.cardOnLeft,
    required this.placed,
  });

  final bool show;
  final Widget card;
  final ParentCalloutOverlay? overlay;
  final bool cardOnLeft;
  final PlacedBranch? placed;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final parent = overlay;
    final branch = placed;
    final shown = parent == null
        ? card
        : _HangParentCallout(
            anchor: parent.anchor,
            cardOnLeft: cardOnLeft,
            balance: branch == null,
            callout: parent.child,
            card: card,
          );
    if (branch == null) return shown;
    return Padding(
      padding: EdgeInsets.only(
        left: cardOnLeft ? 0 : branch.push,
        right: cardOnLeft ? branch.push : 0,
      ),
      child: shown,
    );
  }
}

class _PlainDialRow extends StatelessWidget {
  const _PlainDialRow({
    required this.left,
    required this.right,
    required this.node,
  });

  final Widget left;
  final Widget right;
  final Widget node;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: left),
            ),
            const SizedBox(width: calloutGutter),
            Expanded(
              child: Align(alignment: Alignment.centerLeft, child: right),
            ),
          ],
        ),
        node,
      ],
    );
  }
}

class _BranchDialRow extends StatelessWidget {
  const _BranchDialRow({
    required this.frame,
    required this.cardOnLeft,
    required this.placed,
    required this.onOpenBranch,
    required this.left,
    required this.right,
  });

  final StoryFrame frame;
  final bool cardOnLeft;
  final PlacedBranch placed;
  final ValueChanged<String> onOpenBranch;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BranchCalloutTarget(
              frame: frame,
              onOpen: onOpenBranch,
              child: _TopHalves(
                left: cardOnLeft ? placed.lane : const SizedBox.shrink(),
                middle: SizedBox(
                  width: calloutGutter,
                  height: calloutHit,
                  child: Center(child: placed.ringHit),
                ),
                right: cardOnLeft ? const SizedBox.shrink() : placed.lane,
              ),
            ),
            _TopHalves(
              left: left,
              middle: const SizedBox(width: calloutGutter),
              right: right,
            ),
          ],
        ),
        Positioned(top: 0, left: 0, right: 0, child: Center(child: placed.dot)),
      ],
    );
  }
}

/// [left] and [right] top-aligned toward [middle].
class _TopHalves extends StatelessWidget {
  const _TopHalves({
    required this.left,
    required this.middle,
    required this.right,
  });

  final Widget left;
  final Widget middle;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(alignment: Alignment.topRight, child: left),
        ),
        middle,
        Expanded(
          child: Align(alignment: Alignment.topLeft, child: right),
        ),
      ],
    );
  }
}

/// The tappable story stub; a focused or branch card gets its surface.
class _DialCard extends StatelessWidget {
  const _DialCard({required this.row});

  final _DialRow row;

  @override
  Widget build(BuildContext context) {
    final frame = row.frame;
    final focused = row.focused;
    // Branch and parent-origin cards are moss-edged and never glow
    // (branch-callout.md Rules 1 and 8).
    final moss = frame.branchesStory || (focused && frame.parent != null);
    final shape = albumContainerShape(
      AlbumRadius.card,
      side: frame.branchesStory
          ? const BorderSide(color: branchMoss)
          : focused
          ? BorderSide(color: moss ? branchMoss : albumTerracotta, width: 2)
          : BorderSide.none,
    );
    final surfaced = frame.branchesStory || focused;
    return InkWell(
      key: Key('timeline-stub-${row.story.id}'),
      onTap: row.onTap,
      customBorder: shape,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: surfaced
              ? ShapeDecoration(
                  color: frame.branchesStory
                      ? albumParchment
                      : albumDialogSurface,
                  shape: shape,
                  shadows: moss
                      ? null
                      : [
                          BoxShadow(
                            color: albumInk.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                )
              : const BoxDecoration(),
          child: Padding(
            padding: EdgeInsets.all(surfaced ? calloutCardPadding : 0),
            child: _DialCardBody(row: row),
          ),
        ),
      ),
    );
  }
}

class _DialCardBody extends StatelessWidget {
  const _DialCardBody({required this.row});

  final _DialRow row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final story = row.story;
    final dimmed = row.dimmed;
    final cardOnLeft = row.cardOnLeft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cardOnLeft
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        _DialMeta(row: row),
        const SizedBox(height: 4),
        if (row.originTag case final tag?)
          Text(
            tag,
            key: Key('timeline-origin-tag-${story.id}'),
            style: text.labelLarge?.copyWith(
              color: dimmed ? albumDimInk : albumSage,
              fontWeight: FontWeight.w600,
            ),
          ),
        Text(
          storyTitle(story),
          textAlign: cardOnLeft ? TextAlign.end : TextAlign.start,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: dimmed ? albumDimInk : null,
          ),
        ),
      ],
    );
  }
}

/// Year pill, place and photo count above the title.
class _DialMeta extends StatelessWidget {
  const _DialMeta({required this.row});

  final _DialRow row;

  @override
  Widget build(BuildContext context) {
    final story = row.story;
    final dimmed = row.dimmed;
    final place = (story.placeLabel ?? '').trim();
    // A dimmed row keeps the focus ring and border but not the terracotta
    // ink, so its text stays in the dim ink.
    final lit = row.focused && !dimmed;
    return Wrap(
      spacing: AlbumSpace.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: row.cardOnLeft ? WrapAlignment.end : WrapAlignment.start,
      children: [
        _YearPill(label: storyDateLabelFor(story), lit: lit, dimmed: dimmed),
        if (place.isNotEmpty)
          Text(
            place,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: dimmed
                  ? albumDimInk
                  : lit
                  ? albumTerracotta
                  : albumInk.withValues(alpha: 0.55),
              fontWeight: lit ? FontWeight.w700 : null,
            ),
          ),
        if (story.photoCount > 0)
          _PhotoCount(
            label: countWord(story.photoCount, 'photo', 'photos'),
            lit: lit,
            dimmed: dimmed,
          ),
      ],
    );
  }
}

class _YearPill extends StatelessWidget {
  const _YearPill({
    required this.label,
    required this.lit,
    required this.dimmed,
  });

  final String label;
  final bool lit;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AlbumSpace.s,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: lit ? albumTerracotta : albumWatermark,
        borderRadius: BorderRadius.circular(AlbumRadius.tile),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: dimmed
              ? albumDimInk
              : lit
              ? albumParchment
              : albumInk,
        ),
      ),
    );
  }
}

class _PhotoCount extends StatelessWidget {
  const _PhotoCount({
    required this.label,
    required this.lit,
    required this.dimmed,
  });

  final String label;
  final bool lit;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.photo_library,
          size: 14,
          color: dimmed
              ? albumDimInk
              : lit
              ? albumTerracotta
              : albumInk.withValues(alpha: 0.45),
        ),
        const SizedBox(width: AlbumSpace.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: dimmed ? albumDimInk : null),
        ),
      ],
    );
  }
}

/// Places [callout] so [anchor] sits on the top center of [card].
///
/// A left card stays flush with the right edge, and a right card stays flush
/// with the left edge, so the rail alignment does not move. [balance] adds
/// the same space below the card that the callout takes above it, which keeps
/// a centered rail dot on the card.
class _HangParentCallout extends MultiChildRenderObjectWidget {
  _HangParentCallout({
    required this.anchor,
    required this.cardOnLeft,
    required this.balance,
    required Widget card,
    required Widget callout,
  }) : super(children: [card, callout]);

  final Offset anchor;
  final bool cardOnLeft;
  final bool balance;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHangParentCallout(anchor, cardOnLeft, balance);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHangParentCallout renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..cardOnLeft = cardOnLeft
      ..balance = balance;
  }
}

class _RenderHangParentCallout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, HangParentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, HangParentParentData> {
  _RenderHangParentCallout(this._anchor, this._cardOnLeft, this._balance);

  Offset _anchor;
  bool _cardOnLeft;
  bool _balance;

  set anchor(Offset value) {
    if (_anchor == value) return;
    _anchor = value;
    markNeedsLayout();
  }

  set cardOnLeft(bool value) {
    if (_cardOnLeft == value) return;
    _cardOnLeft = value;
    markNeedsLayout();
  }

  set balance(bool value) {
    if (_balance == value) return;
    _balance = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! HangParentParentData) {
      child.parentData = HangParentParentData();
    }
  }

  @override
  void performLayout() {
    final card = firstChild;
    final callout = card == null ? null : childAfter(card);
    if (card == null || callout == null) {
      size = constraints.smallest;
      return;
    }
    final maxWidth = constraints.maxWidth;
    card.layout(
      BoxConstraints(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity),
      parentUsesSize: true,
    );
    callout.layout(const BoxConstraints(), parentUsesSize: true);

    final rawCalloutX = card.size.width / 2 - _anchor.dx;
    var cardX = _cardOnLeft && rawCalloutX < 0 ? -rawCalloutX : 0.0;
    var calloutX = rawCalloutX + cardX;
    final cardY = _anchor.dy;
    final contentWidth = math.max(
      cardX + card.size.width,
      math.max(calloutX, 0) + callout.size.width,
    );
    final contentHeight = math.max(
      cardY + card.size.height,
      callout.size.height,
    );
    final spaceBelow = contentHeight - cardY - card.size.height;
    final extraBelow = _balance ? math.max(0.0, cardY - spaceBelow) : 0.0;
    size = constraints.constrain(
      Size(contentWidth, contentHeight + extraBelow),
    );
    if (_cardOnLeft && size.width + 0.01 < contentWidth) {
      final shift = size.width - contentWidth;
      cardX += shift;
      calloutX += shift;
    }
    (card.parentData as HangParentParentData).offset = Offset(cardX, cardY);
    (callout.parentData as HangParentParentData).offset = Offset(calloutX, 0);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
