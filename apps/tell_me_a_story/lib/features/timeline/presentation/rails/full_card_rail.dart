import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/widgets/story/photo_frame.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/rail_scaffold.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/rail_spine.dart';
import 'package:tell_me_a_story/core/widgets/timeline/story_marker.dart';
import 'package:tell_me_a_story/core/widgets/controls/album_chip.dart';

class FullCardRail extends StatefulWidget {
  const FullCardRail({
    super.key,
    required this.stories,
    required this.focusedId,
    required this.branching,
    this.originStoryId,
    this.originTag,
    required this.anchorFor,
    required this.onOpen,
    required this.onEmpty,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMacro,
    required this.onMid,
    this.onPerson,
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
  final ValueChanged<Story> onOpen;
  final VoidCallback onEmpty;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMacro;
  final VoidCallback onMid;
  final void Function(({String id, String name}) person)? onPerson;

  /// Stories that miss the filter: dim ink and a hollow dot (Q4).
  final Set<String> dimmed;

  /// Beside the zoom switch: the subheader's action buttons.
  final Widget? toolbar;

  /// Pinned above the rows (the C17 no-match card).
  final Widget? notice;

  @override
  State<FullCardRail> createState() => _FullCardRailState();
}

class _FullCardRailState extends State<FullCardRail>
    with RailScaffold<FullCardRail, String> {
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
  bool get measureWithoutTarget => true;

  @override
  RowFade Function(RenderBox row) fadeFor(RenderBox viewport) =>
      edgeFade(viewport, fullCardOpacity);

  @override
  void didUpdateWidget(covariant FullCardRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.focusedId;
    if (next != null && next != oldWidget.focusedId) {
      centerKey = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final looks = [
      for (final story in widget.stories)
        (
          focused: story.id == centerKey,
          dimmed: widget.dimmed.contains(story.id),
          opacity: opacityOf(story.id, unmeasured: 0.4),
          originTag: story.id == widget.originStoryId ? widget.originTag : null,
        ),
    ];
    return buildRail(
      selected: TimelineZoom.near,
      onMacro: widget.onMacro,
      onMid: widget.onMid,
      onFullCards: () {},
      onEmpty: widget.onEmpty,
      action: widget.toolbar,
      notice: widget.notice,
      viewport: _FullCardViewport(
        viewportKey: viewportKey,
        scroll: scroll,
        rail: widget,
        looks: looks,
      ),
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

class _FullCardViewport extends StatelessWidget {
  const _FullCardViewport({
    required this.viewportKey,
    required this.scroll,
    required this.rail,
    required this.looks,
  });

  final Key viewportKey;
  final ScrollController scroll;
  final FullCardRail rail;
  final List<_RowLook> looks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AlbumBreakpoint.sidebar;
        final pad = constraints.maxHeight / 2;
        final gap = constraints.maxWidth < AlbumBreakpoint.sidebar
            ? AlbumSpace.xl
            : AlbumSpace.xl * 3;
        return Stack(
          key: viewportKey,
          children: [
            RailSpine(left: wide ? null : _narrowLeft + _narrowDotCenter),
            ListView(
              controller: scroll,
              scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : _narrowLeft,
                pad,
                24,
                pad,
              ),
              children: [
                for (var i = 0; i < rail.stories.length; i++)
                  _FullCardRow.at(rail, i, looks[i], wide: wide, gap: gap),
              ],
            ),
            const _EdgeFade(),
          ],
        );
      },
    );
  }
}

/// Parchment fade over the top and bottom of the rows.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                albumParchment,
                albumParchment.withAlpha(0),
                albumParchment.withAlpha(0),
                albumParchment,
              ],
              stops: const [0, 0.18, 0.82, 1],
            ),
          ),
        ),
      ),
    );
  }
}

const _narrowFullDotColumn = 28.0;

/// Narrow Days: the list's left inset, and the dot column's centre within a
/// row. The spine, the plain dots and the branch dot all sit on
/// `_narrowLeft + _narrowDotCenter`.
const _narrowLeft = 8.0;
const _narrowDotCenter = _narrowFullDotColumn / 2;

/// Layout facts for the story card, written by [_DaysCardProbe] during its
/// own layout. The row reads these fields instead of a descendant's size.
class _DaysCardSlot {
  Size layoutSize = Size.zero;
  double scale = 1;
  RenderBox? box;
}

/// Wraps the focused card so the parent callout can find its corner without
/// reading a descendant's [RenderBox.size] during layout.
class _DaysCardProbe extends SingleChildRenderObjectWidget {
  const _DaysCardProbe({
    required this.slot,
    required this.scale,
    required super.child,
  });

  final _DaysCardSlot slot;
  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDaysCardProbe(slot, scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDaysCardProbe renderObject,
  ) {
    renderObject
      ..slot = slot
      ..scale = scale;
  }
}

class _RenderDaysCardProbe extends RenderProxyBox {
  _RenderDaysCardProbe(this._slot, this._scale);

  _DaysCardSlot _slot;
  double _scale;

  set slot(_DaysCardSlot value) {
    if (_slot == value) return;
    if (_slot.box == this) _slot.box = null;
    _slot = value;
    markNeedsLayout();
  }

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    _slot
      ..layoutSize = size
      ..scale = _scale
      ..box = this;
  }

  @override
  void detach() {
    if (_slot.box == this) _slot.box = null;
    super.detach();
  }
}

/// Days parent callout. The leader matches the decade parent: 45°, then
/// horizontal. It meets the top center of the story card and runs to the
/// card's own side. A left card runs left. A right card runs right. Narrow
/// cards sit to the right of the spine, so the label runs right. The label is
/// larger than the years parent.
///
/// The label is a sibling of the row so the space above the card stays inside
/// the hit region. The row is not shifted in x, so the spine dot stays put.
class _DaysAttachedCallout extends StatefulWidget {
  const _DaysAttachedCallout({
    required this.anchor,
    required this.callout,
    required this.body,
  });

  /// Point in [callout] that sits on the top center of the card.
  final Offset anchor;
  final Widget callout;
  final Widget Function(_DaysCardSlot slot) body;

  @override
  State<_DaysAttachedCallout> createState() => _DaysAttachedCalloutState();
}

class _DaysAttachedCalloutState extends State<_DaysAttachedCallout> {
  final _slot = _DaysCardSlot();

  @override
  Widget build(BuildContext context) {
    return _DaysAttachedCalloutBox(
      slot: _slot,
      anchor: widget.anchor,
      callout: widget.callout,
      body: widget.body(_slot),
    );
  }
}

class _DaysAttachedCalloutBox extends MultiChildRenderObjectWidget {
  _DaysAttachedCalloutBox({
    required this.slot,
    required this.anchor,
    required Widget body,
    required Widget callout,
  }) : super(children: [body, callout]);

  final _DaysCardSlot slot;
  final Offset anchor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDaysAttachedCallout(slot: slot, anchor: anchor);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDaysAttachedCallout renderObject,
  ) {
    renderObject
      ..slot = slot
      ..anchor = anchor;
  }
}

class _RenderDaysAttachedCallout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, HangParentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, HangParentParentData> {
  _RenderDaysAttachedCallout({required this._slot, required this._anchor});

  _DaysCardSlot _slot;
  Offset _anchor;

  set slot(_DaysCardSlot value) {
    if (_slot == value) return;
    _slot = value;
    markNeedsLayout();
  }

  set anchor(Offset value) {
    if (_anchor == value) return;
    _anchor = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is HangParentParentData) return;
    child.parentData = HangParentParentData();
  }

  /// [target]'s top-left in [ancestor]'s coordinates. Sums parent offsets, so
  /// it does not read a descendant's size. Proxy boxes keep the base
  /// [ParentData] and paint the child at their own origin, which adds nothing.
  Offset? _offsetWithin(RenderBox target, RenderBox ancestor) {
    var offset = Offset.zero;
    RenderObject? node = target;
    while (node != null && node != ancestor) {
      final data = node.parentData;
      if (data is BoxParentData) offset += data.offset;
      node = node.parent;
    }
    if (node != ancestor) return null;
    return offset;
  }

  /// Painted top center of the card in [body]'s coordinates. Focus scale grows
  /// the card from its center, so the top edge sits above the layout box.
  Offset? _cardTop(RenderBox body) {
    final box = _slot.box;
    if (box == null || !box.attached) return null;
    final origin = _offsetWithin(box, body);
    if (origin == null) return null;
    final size = _slot.layoutSize;
    final scale = _slot.scale;
    final center = origin + Offset(size.width / 2, size.height / 2);
    final layoutTop = origin + Offset(size.width / 2, 0);
    return center + (layoutTop - center) * scale;
  }

  @override
  void performLayout() {
    final body = firstChild;
    final callout = body == null ? null : childAfter(body);
    if (body == null || callout == null) {
      size = constraints.smallest;
      return;
    }
    body.layout(constraints, parentUsesSize: true);
    callout.layout(const BoxConstraints(), parentUsesSize: true);

    final top = _cardTop(body);
    var bodyOffset = Offset.zero;
    var calloutOffset = Offset.zero;
    if (top != null) {
      calloutOffset = top - _anchor;
      // The focus scale and the leader both reach above the card. Drop the
      // row so that reach stays inside this box. Shift the row in y only:
      // an x shift would pull the spine dot off center.
      if (calloutOffset.dy < 0) {
        final dy = -calloutOffset.dy;
        calloutOffset = Offset(calloutOffset.dx, 0);
        bodyOffset = Offset(0, dy);
      }
    }
    final width = math.max(
      body.size.width,
      math.max(0.0, calloutOffset.dx) + callout.size.width,
    );
    final height = math.max(
      bodyOffset.dy + body.size.height,
      calloutOffset.dy + callout.size.height,
    );
    size = constraints.constrain(Size(width, height));
    (body.parentData as HangParentParentData).offset = bodyOffset;
    (callout.parentData as HangParentParentData).offset = calloutOffset;
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

class _FullCardRow extends StatelessWidget {
  _FullCardRow.at(
    FullCardRail rail,
    int index,
    _RowLook look, {
    required this.wide,
    required this.gap,
  }) : story = rail.stories[index],
       frame = rail.branching.frameFor(rail.stories[index]),
       cardOnLeft = index.isEven,
       originTag = look.originTag,
       onOpenBranch = rail.onOpenBranch,
       onPerson = rail.onPerson,
       focused = look.focused,
       dimmed = look.dimmed,
       opacity = look.opacity,
       onOpen = (() => rail.onOpen(rail.stories[index])),
       super(key: rail.anchorFor(rail.stories[index].id));

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final bool wide;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final void Function(({String id, String name}) person)? onPerson;
  final bool focused;
  final bool dimmed;
  final double opacity;
  final double gap;
  final VoidCallback onOpen;

  /// Side the callouts run to: the card's own side, always right when narrow.
  CalloutSide get side =>
      !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left;

  @override
  Widget build(BuildContext context) {
    if (frame.parent == null) return _FullCardRowBody(row: this, slot: null);
    // Same side as the card, matching the days child callout. The 45° run
    // leaves the top center toward that side.
    final overlay = parentCalloutOverlay(
      context: context,
      frame: frame,
      side: side,
      maxLabelWidth: calloutLabelWidthDial,
      onOpen: onOpenBranch,
      fontSize: calloutDaysParentFontSize,
      extraRun: 0,
    );
    return _DaysAttachedCallout(
      anchor: overlay.anchor,
      callout: Opacity(opacity: opacity.clamp(0, 1), child: overlay.child),
      body: (slot) => _FullCardRowBody(row: this, slot: slot),
    );
  }
}

/// The row under any parent callout: the dot, the card and, for a branch
/// story, its callout lane.
class _FullCardRowBody extends StatelessWidget {
  const _FullCardRowBody({required this.row, required this.slot});

  final _FullCardRow row;
  final _DaysCardSlot? slot;

  @override
  Widget build(BuildContext context) {
    final frame = row.frame;
    final card = _ScaledCard(row: row, slot: slot);
    final dot = _FullCardDot(
      key: Key('timeline-full-dot-${row.story.id}'),
      focused: row.focused,
      matched: !row.dimmed,
      ringed: !frame.branchesStory && frame.parent == null,
    );
    if (!frame.branchesStory) {
      return row.wide
          ? _PlainWideRow(row: row, card: card, dot: dot)
          : _PlainNarrowRow(gap: row.gap, card: card, dot: dot);
    }
    final placed = placeBranchCallout(
      context: context,
      frame: frame,
      side: row.side,
      dot: GestureDetector(onTap: row.onOpen, child: dot),
      dotDiameter: row.focused ? fullDotFocusedDiameter : fullDotDiameter,
      centerToLane: row.wide ? calloutLaneOffset : calloutHit / 2,
      minCardFromRail: row.wide ? calloutFromRail : null,
      maxLabelWidth: calloutLabelWidthDial,
      onOpen: row.onOpenBranch,
    );
    return row.wide
        ? _BranchWideRow(row: row, placed: placed, card: card)
        : _BranchNarrowRow(row: row, placed: placed, card: card);
  }
}

/// The story card at its focus scale and row fade, probed for the parent
/// callout when [slot] is set.
class _ScaledCard extends StatelessWidget {
  const _ScaledCard({required this.row, required this.slot});

  final _FullCardRow row;
  final _DaysCardSlot? slot;

  @override
  Widget build(BuildContext context) {
    final frame = row.frame;
    // Narrow rows skip the scale. A 1.05 card overflows the right edge,
    // and focus there is the 20px dot plus the focused card chrome.
    // A branch card and a parent-origin card stay at 1 so focus does not
    // shift them.
    final scale =
        row.wide && row.focused && !frame.branchesStory && frame.parent == null
        ? 1.05
        : 1.0;
    final scaled = Transform.scale(
      scale: scale,
      child: _FullCard(
        story: row.story,
        focused: row.focused,
        dimmed: row.dimmed,
        branched: frame.branchesStory,
        parentOrigin: frame.parent != null,
        originTag: row.originTag,
        onOpen: row.onOpen,
        onPerson: row.onPerson,
      ),
    );
    final probe = slot;
    return Opacity(
      opacity: row.opacity.clamp(0, 1),
      child: probe == null
          ? scaled
          : _DaysCardProbe(slot: probe, scale: scale, child: scaled),
    );
  }
}

class _PlainNarrowRow extends StatelessWidget {
  const _PlainNarrowRow({
    required this.gap,
    required this.card,
    required this.dot,
  });

  final double gap;
  final Widget card;
  final Widget dot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _narrowFullDotColumn,
            child: Align(alignment: Alignment.center, child: dot),
          ),
          Expanded(child: card),
        ],
      ),
    );
  }
}

class _PlainWideRow extends StatelessWidget {
  const _PlainWideRow({
    required this.row,
    required this.card,
    required this.dot,
  });

  final _FullCardRow row;
  final Widget card;
  final Widget dot;

  @override
  Widget build(BuildContext context) {
    final cardOnLeft = row.cardOnLeft;
    return Padding(
      padding: EdgeInsets.only(bottom: row.gap),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.92,
                    child: cardOnLeft ? card : const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: calloutGutter),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.92,
                    child: cardOnLeft ? const SizedBox.shrink() : card,
                  ),
                ),
              ),
            ],
          ),
          dot,
        ],
      ),
    );
  }
}

class _BranchNarrowRow extends StatelessWidget {
  const _BranchNarrowRow({
    required this.row,
    required this.placed,
    required this.card,
  });

  final _FullCardRow row;
  final PlacedBranch placed;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: row.gap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              _NarrowCalloutTarget(row: row, placed: placed),
              Padding(
                // The card starts under the label, after the ring.
                padding: EdgeInsets.only(
                  left: _narrowDotCenter + calloutHit / 2 + placed.push,
                ),
                child: card,
              ),
            ],
          ),
          Positioned(
            left: _narrowDotCenter - calloutHit / 2,
            top: 0,
            width: calloutHit,
            height: calloutHit,
            child: Center(child: placed.dot),
          ),
        ],
      ),
    );
  }
}

/// The branch ring and its lane, the ring shifted onto the spine like the
/// plain dots; the callout's own geometry is unchanged.
class _NarrowCalloutTarget extends StatelessWidget {
  const _NarrowCalloutTarget({required this.row, required this.placed});

  final _FullCardRow row;
  final PlacedBranch placed;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(_narrowDotCenter - calloutHit / 2, 0),
      child: BranchCalloutTarget(
        frame: row.frame,
        onOpen: row.onOpenBranch,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: calloutHit,
              height: calloutHit,
              child: placed.ringHit,
            ),
            Expanded(child: placed.lane),
          ],
        ),
      ),
    );
  }
}

class _BranchWideRow extends StatelessWidget {
  const _BranchWideRow({
    required this.row,
    required this.placed,
    required this.card,
  });

  final _FullCardRow row;
  final PlacedBranch placed;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final cardOnLeft = row.cardOnLeft;
    final pushPad = EdgeInsets.only(
      left: cardOnLeft ? 0 : placed.push,
      right: cardOnLeft ? placed.push : 0,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: row.gap),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WideCalloutTarget(row: row, placed: placed),
              _WideHalves(
                cardOnLeft: cardOnLeft,
                middle: const SizedBox(width: calloutGutter),
                child: Padding(padding: pushPad, child: card),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: placed.dot),
          ),
        ],
      ),
    );
  }
}

/// The branch ring in the gutter with its lane on the card's half.
class _WideCalloutTarget extends StatelessWidget {
  const _WideCalloutTarget({required this.row, required this.placed});

  final _FullCardRow row;
  final PlacedBranch placed;

  @override
  Widget build(BuildContext context) {
    return BranchCalloutTarget(
      frame: row.frame,
      onOpen: row.onOpenBranch,
      child: _WideHalves(
        cardOnLeft: row.cardOnLeft,
        middle: SizedBox(
          width: calloutGutter,
          height: calloutHit,
          child: Center(child: placed.ringHit),
        ),
        child: placed.lane,
      ),
    );
  }
}

/// Two top-aligned halves around [middle]; [child] sits at 92% width in the
/// card's half, the other half stays empty.
class _WideHalves extends StatelessWidget {
  const _WideHalves({
    required this.cardOnLeft,
    required this.middle,
    required this.child,
  });

  final bool cardOnLeft;
  final Widget middle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fraction = FractionallySizedBox(widthFactor: 0.92, child: child);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: cardOnLeft ? fraction : const SizedBox.shrink(),
          ),
        ),
        middle,
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: cardOnLeft ? const SizedBox.shrink() : fraction,
          ),
        ),
      ],
    );
  }
}

/// A Days story dot. A plain focused story takes the terracotta selected
/// ring; a branch or parent-origin dot never does, so nothing covers the
/// callout's moss ring and nothing glows (branch-callout.md Rules 1 and 8).
/// An unmatched dot is hollow.
class _FullCardDot extends StatelessWidget {
  const _FullCardDot({
    super.key,
    required this.focused,
    required this.matched,
    required this.ringed,
  });

  final bool focused;
  final bool matched;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    return StoryDot(
      reserveRings: false,
      spec: MarkerSpec(
        matched: matched,
        selected: focused && ringed,
        diameter: focused ? fullDotFocusedDiameter : fullDotDiameter,
      ),
    );
  }
}

class _FullCard extends StatelessWidget {
  const _FullCard({
    required this.story,
    required this.focused,
    required this.dimmed,
    required this.branched,
    required this.parentOrigin,
    required this.onOpen,
    this.originTag,
    this.onPerson,
  });

  final Story story;
  final bool focused;

  /// Misses the filter: every text in [albumDimInk] (Q4).
  final bool dimmed;
  final bool branched;
  final bool parentOrigin;
  final VoidCallback onOpen;
  final String? originTag;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paths = _cardPhotoPaths(story, focused: focused);
    return _CardSurface(
      storyId: story.id,
      focused: focused,
      branched: branched,
      parentOrigin: parentOrigin,
      onOpen: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            story: story,
            focused: focused,
            dimmed: dimmed,
            onPerson: onPerson,
          ),
          const SizedBox(height: AlbumSpace.s),
          if (originTag case final tag?)
            _OriginTag(tag: tag, storyId: story.id, dimmed: dimmed),
          Text(
            story.title ?? '',
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: dimmed ? albumDimInk : null,
            ),
          ),
          if (paths.isNotEmpty) _CardPhotos(paths: paths, focused: focused),
          if (focused) ...[
            const SizedBox(height: AlbumSpace.m),
            _CardFooter(story: story, dimmed: dimmed),
          ],
        ],
      ),
    );
  }
}

/// The focused card shows its first photo; the others show up to two.
List<String> _cardPhotoPaths(Story story, {required bool focused}) {
  if (!focused) return story.photoPaths.take(2).toList();
  return story.photoPaths.isEmpty ? const <String>[] : [story.photoPaths.first];
}

/// The sage origin tag above the title of the family's origin story.
class _OriginTag extends StatelessWidget {
  const _OriginTag({
    required this.tag,
    required this.storyId,
    required this.dimmed,
  });

  final String tag;
  final String storyId;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Text(
      tag,
      key: Key('timeline-origin-tag-$storyId'),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: dimmed ? albumDimInk : albumSage,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// The card's tappable shape, border and shadows around [child].
class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.storyId,
    required this.focused,
    required this.branched,
    required this.parentOrigin,
    required this.onOpen,
    required this.child,
  });

  final String storyId;
  final bool focused;
  final bool branched;
  final bool parentOrigin;
  final VoidCallback onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final moss = branched || (focused && parentOrigin);
    final shape = albumContainerShape(
      AlbumRadius.card,
      side: BorderSide(
        color: moss
            ? branchMoss
            : focused
            ? albumTerracotta
            : albumRule,
        width: branched ? 1 : (focused ? 2 : 1),
      ),
    );
    return Material(
      color: branched ? albumParchment : albumWhite,
      elevation: 0,
      shape: shape,
      child: InkWell(
        key: Key('timeline-card-$storyId'),
        onTap: onOpen,
        customBorder: shape,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: albumContainerShape(AlbumRadius.card),
            shadows: moss ? null : _cardShadows(focused, parentOrigin),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AlbumSpace.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}

List<BoxShadow> _cardShadows(bool focused, bool parentOrigin) {
  return [
    BoxShadow(
      color: albumInk.withValues(alpha: focused ? 0.08 : 0.04),
      blurRadius: focused ? 24 : 8,
      offset: Offset(0, focused ? 8 : 2),
    ),
    if (focused && !parentOrigin)
      BoxShadow(
        color: albumBlush.withValues(alpha: 0.3),
        spreadRadius: 4,
        blurRadius: 0,
      ),
  ];
}

/// Date label beside the person and place chips.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.story,
    required this.focused,
    required this.dimmed,
    required this.onPerson,
  });

  final Story story;
  final bool focused;
  final bool dimmed;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AlbumSpace.s,
      runSpacing: AlbumSpace.xs,
      children: [
        Text(
          storyDateLabelFor(story),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: dimmed ? albumDimInk : albumTerracotta,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        _CardChips(
          story: story,
          focused: focused,
          dimmed: dimmed,
          onPerson: onPerson,
        ),
      ],
    );
  }
}

/// The person chips (tappable when linked) and the place chip.
class _CardChips extends StatelessWidget {
  const _CardChips({
    required this.story,
    required this.focused,
    required this.dimmed,
    required this.onPerson,
  });

  final Story story;
  final bool focused;
  final bool dimmed;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  Widget build(BuildContext context) {
    final people = story.people.isNotEmpty
        ? story.people
        : [for (final name in story.personNames) (id: '', name: name)];
    final place = story.placeLabel ?? '';
    final tap = onPerson;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 6,
      runSpacing: AlbumSpace.xs,
      children: [
        for (final person in people)
          GestureDetector(
            key: Key('timeline-person-${story.id}-${person.name}'),
            onTap: person.id.isEmpty || tap == null ? null : () => tap(person),
            child: _CardChip(
              icon: Icons.person,
              label: person.name,
              focused: focused,
              dimmed: dimmed,
            ),
          ),
        if (place.isNotEmpty)
          _CardChip(
            icon: Icons.location_on,
            label: place,
            focused: focused,
            dimmed: dimmed,
          ),
      ],
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.icon,
    required this.label,
    required this.focused,
    required this.dimmed,
  });

  final IconData icon;
  final String label;
  final bool focused;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AlbumChip(
      avatar: Icon(
        icon,
        size: 12,
        color: dimmed
            ? albumDimInk
            : albumInk.withValues(alpha: focused ? 0.85 : 0.7),
      ),
      label: label,
      selected: focused,
      dimmed: dimmed,
    );
  }
}

/// Focused card's rule-topped author and counts line.
class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.story, required this.dimmed});

  final Story story;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelMedium;
    final name = story.authorDisplayName?.trim() ?? '';
    final author = name.isEmpty ? 'Member' : name;
    final notes = story.commentCount + story.perspectiveCount;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: albumRule)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: AlbumSpace.s),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: AlbumSpace.s,
          runSpacing: AlbumSpace.xs,
          children: [
            Text(
              'Added by $author',
              style: label?.copyWith(
                color: dimmed ? albumDimInk : albumInk.withValues(alpha: 0.7),
              ),
            ),
            Text(
              '${countWord(story.photoCount, 'photo', 'photos')} · ${countWord(notes, 'note', 'notes')}',
              style: label?.copyWith(
                fontWeight: FontWeight.w600,
                color: dimmed ? albumDimInk : albumTerracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardPhotos extends ConsumerStatefulWidget {
  const _CardPhotos({required this.paths, required this.focused});

  final List<String> paths;
  final bool focused;

  @override
  ConsumerState<_CardPhotos> createState() => _CardPhotosState();
}

class _CardPhotosState extends ConsumerState<_CardPhotos> {
  final Map<String, Uint8List> _bytes = {};
  final Map<String, double> _aspect = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = ref.read(photosRepositoryProvider);
    for (final path in widget.paths) {
      try {
        final bytes = await photos.downloadBytes(path);
        if (!mounted) return;
        setState(() {
          _bytes[path] = bytes;
          _aspect[path] = encodedPhotoAspect(bytes) ?? (16 / 9);
        });
      } on Object {
        // A photo that cannot be read stays out of the well.
        continue;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = [
      for (final path in widget.paths)
        if (_bytes[path] case final bytes?) (path: path, bytes: bytes),
    ];
    if (ready.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AlbumSpace.m),
      child: _PhotoRow(
        ready: ready,
        aspect: _aspect[ready.first.path] ?? (16 / 9),
        focused: widget.focused,
      ),
    );
  }
}

/// The loaded photos side by side, contained in a parchment well.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.ready,
    required this.aspect,
    required this.focused,
  });

  final List<({String path, Uint8List bytes})> ready;

  /// Aspect of the first photo; sizes a single-photo well.
  final double aspect;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gaps = 12.0 * (ready.length - 1);
        final cellWidth = ready.length == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gaps) / ready.length;
        final height = ready.length > 1
            ? cardPhotoRowHeight(focused: focused)
            : cardPhotoHeight(
                width: cellWidth,
                imageAspect: aspect,
                focused: focused,
              );
        return SizedBox(
          key: Key('timeline-card-photos-${ready.first.path}'),
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < ready.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : AlbumSpace.m),
                    child: _PhotoCell(bytes: ready[i].bytes, height: height),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One photo, contained in a rounded parchment well.
class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.bytes, required this.height});

  final Uint8List bytes;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AlbumRadius.group),
      child: ColoredBox(
        color: albumParchment,
        child: Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
