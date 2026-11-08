import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/ui/story/photo_frame.dart';
import 'package:tell_me_a_story/ui/story/story_date.dart';
import 'package:tell_me_a_story/features/timeline/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';
import 'package:tell_me_a_story/features/timeline/rails/rail_scaffold.dart';
import 'package:tell_me_a_story/features/timeline/rails/rail_spine.dart';
import 'package:tell_me_a_story/ui/timeline/story_marker.dart';

class FullCardRail extends StatefulWidget {
  const FullCardRail({
    super.key,
    required this.stories,
    required this.focusedId,
    required this.photos,
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
  });

  final List<Story> stories;
  final String? focusedId;
  final PhotosGateway? photos;
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
    return buildRail(
      selected: TimelineZoom.near,
      onMacro: widget.onMacro,
      onMid: widget.onMid,
      onFullCards: () {},
      onEmpty: widget.onEmpty,
      viewport: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          final pad = constraints.maxHeight / 2;
          final gap = constraints.maxWidth < 720 ? 32.0 : 80.0;
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
                  for (var i = 0; i < widget.stories.length; i++)
                    _FullCardRow(
                      key: widget.anchorFor(widget.stories[i].id),
                      story: widget.stories[i],
                      frame: widget.branching.frameFor(widget.stories[i]),
                      cardOnLeft: i.isEven,
                      wide: wide,
                      originTag: widget.stories[i].id == widget.originStoryId
                          ? widget.originTag
                          : null,
                      onOpenBranch: widget.onOpenBranch,
                      onPerson: widget.onPerson,
                      focused: widget.stories[i].id == centerKey,
                      opacity: opacityOf(widget.stories[i].id, unmeasured: 0.4),
                      gap: gap,
                      photos: widget.photos,
                      onOpen: () => widget.onOpen(widget.stories[i]),
                    ),
                ],
              ),
              Positioned.fill(
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
              ),
            ],
          );
        },
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
    if (child.parentData is! HangParentParentData) {
      child.parentData = HangParentParentData();
    }
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
    (body.parentData! as HangParentParentData).offset = bodyOffset;
    (callout.parentData! as HangParentParentData).offset = calloutOffset;
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
  const _FullCardRow({
    super.key,
    required this.story,
    required this.frame,
    required this.cardOnLeft,
    required this.wide,
    required this.focused,
    required this.opacity,
    required this.gap,
    required this.photos,
    required this.onOpen,
    this.originTag,
    required this.onOpenBranch,
    this.onPerson,
  });

  final Story story;
  final StoryFrame frame;
  final bool cardOnLeft;
  final bool wide;
  final String? originTag;
  final ValueChanged<String> onOpenBranch;
  final void Function(({String id, String name}) person)? onPerson;
  final bool focused;
  final double opacity;
  final double gap;
  final PhotosGateway? photos;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (frame.parent == null) return _row(context, null);
    // Same side as the card, matching the days child callout. The 45° run
    // leaves the top center toward that side.
    final side = !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left;
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
      body: (slot) => _row(context, slot),
    );
  }

  Widget _row(BuildContext context, _DaysCardSlot? slot) {
    final storyCard = _FullCard(
      story: story,
      focused: focused,
      branched: frame.branchesStory,
      parentOrigin: frame.parent != null,
      photos: photos,
      originTag: originTag,
      onOpen: onOpen,
      onPerson: onPerson,
    );
    // Narrow rows skip the scale. A 1.05 card overflows the right edge,
    // and focus there is the 20px dot plus the focused card chrome.
    // A branch card and a parent-origin card stay at 1 so focus does not
    // shift them.
    final scale =
        wide && focused && !frame.branchesStory && frame.parent == null
        ? 1.05
        : 1.0;
    final scaled = Transform.scale(scale: scale, child: storyCard);
    final card = Opacity(
      opacity: opacity.clamp(0, 1),
      child: slot == null
          ? scaled
          : _DaysCardProbe(slot: slot, scale: scale, child: scaled),
    );
    final dot = _FullCardDot(
      key: Key('timeline-full-dot-${story.id}'),
      focused: focused,
      ringed: !frame.branchesStory && frame.parent == null,
    );
    final placed = frame.branchesStory
        ? placeBranchCallout(
            context: context,
            frame: frame,
            side: !wide || !cardOnLeft ? CalloutSide.right : CalloutSide.left,
            dot: GestureDetector(onTap: onOpen, child: dot),
            dotDiameter: focused ? fullDotFocusedDiameter : fullDotDiameter,
            centerToLane: wide ? calloutLaneOffset : calloutHit / 2,
            minCardFromRail: wide ? calloutFromRail : null,
            maxLabelWidth: calloutLabelWidthDial,
            onOpen: onOpenBranch,
          )
        : null;
    if (placed == null) {
      if (!wide) {
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
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
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
    final pushPad = EdgeInsets.only(
      left: cardOnLeft ? 0 : placed.push,
      right: cardOnLeft ? placed.push : 0,
    );
    if (!wide) {
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                // Shift the ring so the dot sits on the spine, like the
                // plain dots; the callout's own geometry is unchanged.
                Transform.translate(
                  offset: const Offset(_narrowDotCenter - calloutHit / 2, 0),
                  child: BranchCalloutTarget(
                    frame: frame,
                    onOpen: onOpenBranch,
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
                ),
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
    Widget fraction(Widget child) {
      return FractionallySizedBox(widthFactor: 0.92, child: child);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
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
                        child: cardOnLeft
                            ? fraction(placed.lane)
                            : const SizedBox.shrink(),
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
                        child: cardOnLeft
                            ? const SizedBox.shrink()
                            : fraction(placed.lane),
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
                      child: cardOnLeft
                          ? fraction(Padding(padding: pushPad, child: card))
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: calloutGutter),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: cardOnLeft
                          ? const SizedBox.shrink()
                          : fraction(Padding(padding: pushPad, child: card)),
                    ),
                  ),
                ],
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

/// A Days story dot. A plain focused story takes the terracotta selected
/// ring; a branch or parent-origin dot never does, so nothing covers the
/// callout's moss ring and nothing glows (branch-callout.md Rules 1 and 8).
class _FullCardDot extends StatelessWidget {
  const _FullCardDot({super.key, required this.focused, required this.ringed});

  final bool focused;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    return StoryDot(
      reserveRings: false,
      spec: MarkerSpec(
        matched: true,
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
    required this.branched,
    required this.parentOrigin,
    required this.photos,
    required this.onOpen,
    this.originTag,
    this.onPerson,
  });

  final Story story;
  final bool focused;
  final bool branched;
  final bool parentOrigin;
  final PhotosGateway? photos;
  final VoidCallback onOpen;
  final String? originTag;
  final void Function(({String id, String name}) person)? onPerson;

  @override
  Widget build(BuildContext context) {
    final notes = story.commentCount + story.perspectiveCount;
    final author = (story.authorDisplayName ?? '').trim().isEmpty
        ? 'Member'
        : story.authorDisplayName!.trim();
    final paths = focused
        ? (story.photoPaths.isEmpty
              ? const <String>[]
              : [story.photoPaths.first])
        : story.photoPaths.take(2).toList();
    final shape = albumContainerShape(
      AlbumRadius.card,
      side: BorderSide(
        color: branched || (focused && parentOrigin)
            ? branchMoss
            : focused
            ? albumTerracotta
            : albumInk.withValues(alpha: 0.2),
        width: branched ? 1 : (focused ? 2 : 1),
      ),
    );
    return Material(
      color: branched ? albumParchment : albumWhite,
      elevation: 0,
      shape: shape,
      child: InkWell(
        key: Key('timeline-card-${story.id}'),
        onTap: onOpen,
        customBorder: shape,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: albumContainerShape(AlbumRadius.card),
            shadows: branched || (focused && parentOrigin)
                ? null
                : [
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
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      storyDateLabelFor(story),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: albumTerracotta,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final person
                            in story.people.isNotEmpty
                                ? story.people
                                : [
                                    for (final name in story.personNames)
                                      (id: '', name: name),
                                  ])
                          GestureDetector(
                            key: Key(
                              'timeline-person-${story.id}-${person.name}',
                            ),
                            onTap: person.id.isEmpty || onPerson == null
                                ? null
                                : () => onPerson!(person),
                            child: _FullChip(
                              icon: Icons.person,
                              label: person.name,
                              filled: focused,
                            ),
                          ),
                        if ((story.placeLabel ?? '').isNotEmpty)
                          _FullChip(
                            icon: Icons.location_on,
                            label: story.placeLabel!,
                            filled: focused,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (originTag != null)
                  Text(
                    originTag!,
                    key: Key('timeline-origin-tag-${story.id}'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  story.title ?? '',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    height: 1.15,
                  ),
                ),
                if (paths.isNotEmpty && photos != null)
                  _CardPhotos(paths: paths, photos: photos!, focused: focused),
                if (focused) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: albumInk.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Added by $author',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  color: albumInk.withValues(alpha: 0.7),
                                ),
                          ),
                          Text(
                            '${countWord(story.photoCount, 'photo', 'photos')} · ${countWord(notes, 'note', 'notes')}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: albumTerracotta,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullChip extends StatelessWidget {
  const _FullChip({
    required this.icon,
    required this.label,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 12, color: albumInk.withValues(alpha: 0.75));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? albumBlush : albumBlushPale,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textMax = constraints.maxWidth.isFinite
              ? (constraints.maxWidth - 26)
                    .clamp(0.0, constraints.maxWidth)
                    .toDouble()
              : double.infinity;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: albumInk.withValues(alpha: filled ? 0.85 : 0.7),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textMax),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CardPhotos extends StatefulWidget {
  const _CardPhotos({
    required this.paths,
    required this.photos,
    required this.focused,
  });

  final List<String> paths;
  final PhotosGateway photos;
  final bool focused;

  @override
  State<_CardPhotos> createState() => _CardPhotosState();
}

class _CardPhotosState extends State<_CardPhotos> {
  final Map<String, Uint8List> _bytes = {};
  final Map<String, double> _aspect = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final path in widget.paths) {
      try {
        final bytes = await widget.photos.downloadBytes(path);
        if (!mounted) return;
        setState(() {
          _bytes[path] = bytes;
          _aspect[path] = encodedPhotoAspect(bytes) ?? (16 / 9);
        });
      } catch (_) {
        // A photo that cannot be read stays out of the well.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = [
      for (final path in widget.paths)
        if (_bytes[path] != null) path,
    ];
    if (ready.isEmpty) return const SizedBox.shrink();
    final shared = ready.length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gaps = 12.0 * (ready.length - 1);
          final cellWidth = ready.length == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - gaps) / ready.length;
          final height = shared
              ? cardPhotoRowHeight(focused: widget.focused)
              : cardPhotoHeight(
                  width: cellWidth,
                  imageAspect: _aspect[ready.first] ?? (16 / 9),
                  focused: widget.focused,
                );
          return SizedBox(
            key: Key('timeline-card-photos-${ready.first}'),
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < ready.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: albumParchment,
                          child: Image.memory(
                            _bytes[ready[i]]!,
                            height: height,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
