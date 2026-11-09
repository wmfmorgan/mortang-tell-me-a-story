import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/ui/story/story_date.dart';
import 'package:tell_me_a_story/features/timeline/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';
import 'package:tell_me_a_story/ui/story/story_title.dart';
import 'package:tell_me_a_story/features/timeline/rails/rail_scaffold.dart';
import 'package:tell_me_a_story/features/timeline/rails/rail_spine.dart';
import 'package:tell_me_a_story/ui/timeline/pointer_input.dart';
import 'package:tell_me_a_story/ui/timeline/story_marker.dart';

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
          LayoutBuilder(
            builder: (context, constraints) {
              final pad = constraints.maxHeight / 2;
              return ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                children: [
                  for (var i = 0; i < widget.stories.length; i++)
                    _DialRow(
                      key: widget.anchorFor(widget.stories[i].id),
                      story: widget.stories[i],
                      frame: widget.branching.frameFor(widget.stories[i]),
                      originTag: widget.stories[i].id == widget.originStoryId
                          ? widget.originTag
                          : null,
                      onOpenBranch: widget.onOpenBranch,
                      cardOnLeft: i.isEven,
                      focused: widget.stories[i].id == centerKey,
                      dimmed: widget.dimmed.contains(widget.stories[i].id),
                      opacity: opacityOf(
                        widget.stories[i].id,
                        unmeasured: 0.35,
                      ),
                      onTap: () => widget.onStub(widget.stories[i]),
                      onNode: () => widget.onNode(widget.stories[i]),
                    ),
                ],
              );
            },
          ),
          const _DialFade(top: true),
          const _DialFade(top: false),
        ],
      ),
    );
  }
}

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
  const _DialRow({
    super.key,
    required this.story,
    required this.frame,
    required this.cardOnLeft,
    required this.focused,
    required this.dimmed,
    required this.opacity,
    required this.onTap,
    required this.onNode,
    this.originTag,
    required this.onOpenBranch,
  });

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
    final year = storyDateLabelFor(story);
    final place = (story.placeLabel ?? '').trim();
    final photos = story.photoCount > 0
        ? countWord(story.photoCount, 'photo', 'photos')
        : null;
    // A dimmed row keeps the focus ring and border but not the terracotta
    // ink, so its text stays in the dim ink.
    final lit = focused && !dimmed;
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
    final card = InkWell(
      key: Key('timeline-stub-${story.id}'),
      onTap: onTap,
      customBorder: shape,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: frame.branchesStory || focused
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
            padding: EdgeInsets.all(
              frame.branchesStory || focused ? calloutCardPadding : 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: cardOnLeft
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AlbumSpace.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: cardOnLeft
                      ? WrapAlignment.end
                      : WrapAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AlbumSpace.s,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: lit ? albumTerracotta : albumWatermark,
                        borderRadius: BorderRadius.circular(AlbumRadius.tile),
                      ),
                      child: Text(
                        year,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: dimmed
                              ? albumDimInk
                              : lit
                              ? albumParchment
                              : albumInk,
                        ),
                      ),
                    ),
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
                    if (photos != null)
                      Row(
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
                            photos,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: dimmed ? albumDimInk : null),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (originTag != null)
                  Text(
                    originTag!,
                    key: Key('timeline-origin-tag-${story.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: dimmed ? albumDimInk : albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  storyTitle(story),
                  textAlign: cardOnLeft ? TextAlign.end : TextAlign.start,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: dimmed ? albumDimInk : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final mark = StoryDot(
      reserveRings: false,
      spec: MarkerSpec(
        matched: !dimmed,
        selected: focused && !frame.branchesStory && frame.parent == null,
        diameter: focused ? midDotFocusedDiameter : midDotDiameter,
      ),
    );
    // The branch ring sits just outside the dot. Extra slop belongs only on
    // a plain node, where it cannot cover that stroke: 8 pt for a pointer,
    // and the finger radius as a disk for a finger.
    Widget nodeHit({required bool slop}) {
      final hit = GestureDetector(
        key: Key('timeline-mid-node-${story.id}'),
        behavior: HitTestBehavior.opaque,
        supportedDevices: slop ? preciseDevices : null,
        onTap: onNode,
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
          onTap: onNode,
          child: SizedBox.square(
            dimension: 2 * AlbumTarget.fingerRadius,
            child: Center(child: hit),
          ),
        ),
      );
    }

    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: cardOnLeft ? CalloutSide.left : CalloutSide.right,
            dot: nodeHit(slop: false),
            dotDiameter: focused ? midDotFocusedDiameter : midDotDiameter,
            centerToLane: calloutLaneOffset,
            minCardFromRail: calloutFromRail,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    final pushPad = placed == null
        ? EdgeInsets.zero
        : EdgeInsets.only(
            left: cardOnLeft ? 0 : placed.push,
            right: cardOnLeft ? placed.push : 0,
          );
    final parentOverlay = frame.parent == null
        ? null
        : parentCalloutOverlay(
            context: context,
            frame: frame,
            side: cardOnLeft ? CalloutSide.left : CalloutSide.right,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          );
    Widget sideCard(bool show) {
      if (!show) return const SizedBox.shrink();
      final shown = parentOverlay == null
          ? card
          : _HangParentCallout(
              anchor: parentOverlay.anchor,
              cardOnLeft: cardOnLeft,
              balance: placed == null,
              callout: parentOverlay.child,
              card: card,
            );
      if (placed == null) return shown;
      return Padding(padding: pushPad, child: shown);
    }

    Widget sideLabel(bool show) {
      if (!show || placed == null) return const SizedBox.shrink();
      return placed.lane;
    }

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Stack(
          alignment: placed == null ? Alignment.center : Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            if (placed == null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: sideCard(cardOnLeft),
                    ),
                  ),
                  const SizedBox(width: calloutGutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: sideCard(!cardOnLeft),
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BranchCalloutTarget(
                    frame: frame,
                    onOpen: onOpenBranch,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: sideLabel(cardOnLeft),
                          ),
                        ),
                        SizedBox(
                          width: calloutGutter,
                          height: calloutHit,
                          child: Center(child: placed.ringHit),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: sideLabel(!cardOnLeft),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: sideCard(cardOnLeft),
                        ),
                      ),
                      const SizedBox(width: calloutGutter),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: sideCard(!cardOnLeft),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (placed != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(child: placed.dot),
              )
            else
              nodeHit(slop: true),
          ],
        ),
      ),
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
    (card.parentData! as HangParentParentData).offset = Offset(cardX, cardY);
    (callout.parentData! as HangParentParentData).offset = Offset(calloutX, 0);
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
