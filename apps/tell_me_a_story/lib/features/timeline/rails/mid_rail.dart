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
import 'package:tell_me_a_story/features/timeline/zoom_switch.dart';

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

  @override
  State<MidRail> createState() => _MidRailState();
}

class _MidRailState extends State<MidRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  String? _centerId;
  Map<String, double> _opacities = const {};
  var _centered = false;

  @override
  void initState() {
    super.initState();
    _centerId = widget.focusedId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final stories = widget.stories;
    if (stories.isEmpty) return;
    final current = _centerId ?? widget.focusedId ?? stories.first.id;
    var index = stories.indexWhere((story) => story.id == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= stories.length
        ? null
        : widget.anchorFor(stories[next].id).currentContext;
    scrollDialStep(controller: _scroll, direction: direction, target: target);
  }

  @override
  void didUpdateWidget(covariant MidRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.focusedId;
    if (next != null && next != oldWidget.focusedId && next != _centerId) {
      _centerId = next;
      _centerOn(next);
    }
  }

  void _centerInitial() {
    if (!mounted || _centered) return;
    _centered = true;
    final id =
        _centerId ?? (widget.stories.isEmpty ? null : widget.stories.first.id);
    if (id == null) return;
    _centerId = id;
    _centerOn(id);
  }

  void _centerOn(String id) {
    final target = widget.anchorFor(id).currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  bool _sameOpacity(Map<String, double> next) {
    if (next.length != _opacities.length) return false;
    for (final entry in next.entries) {
      final previous = _opacities[entry.key];
      if (previous == null || (previous - entry.value).abs() > 0.02) {
        return false;
      }
    }
    return true;
  }

  void _measure() {
    if (!mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final centerY = viewport
        .localToGlobal(Offset(0, viewport.size.height / 2))
        .dy;
    final half = viewport.size.height / 2;
    String? bestId;
    var best = double.infinity;
    final opacities = <String, double>{};
    for (final story in widget.stories) {
      final row =
          widget.anchorFor(story.id).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final mid = row.localToGlobal(Offset(0, row.size.height / 2)).dy;
      final distance = (mid - centerY).abs();
      opacities[story.id] = dialOpacity(distance: distance, halfExtent: half);
      if (distance < best) {
        best = distance;
        bestId = story.id;
      }
    }
    final idChanged = bestId != null && bestId != _centerId;
    if (!idChanged && _sameOpacity(opacities)) return;
    setState(() {
      if (bestId != null) _centerId = bestId;
      _opacities = opacities;
    });
    final id = bestId;
    if (idChanged && id != null && id != widget.focusedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != widget.focusedId) widget.onFocus(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArrowKeys(
      onStep: _step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: DialSubheader(
              selected: TimelineZoom.mid,
              onMacro: widget.onMacro,
              onMid: () {},
              onFullCards: widget.onFullCards,
            ),
          ),
          Expanded(
            child: EmptyTap(
              onTap: widget.onEmpty,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification ||
                      notification is ScrollEndNotification) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _measure();
                    });
                  }
                  return false;
                },
                child: Stack(
                  key: _viewportKey,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final pad = constraints.maxHeight / 2;
                        return ListView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                          children: [
                            for (var i = 0; i < widget.stories.length; i++)
                              _DialRow(
                                key: widget.anchorFor(widget.stories[i].id),
                                story: widget.stories[i],
                                frame: widget.branching.frameFor(
                                  widget.stories[i],
                                ),
                                originTag:
                                    widget.stories[i].id == widget.originStoryId
                                    ? widget.originTag
                                    : null,
                                onOpenBranch: widget.onOpenBranch,
                                cardOnLeft: i.isEven,
                                focused: widget.stories[i].id == _centerId,
                                opacity:
                                    _opacities[widget.stories[i].id] ??
                                    (widget.stories[i].id == _centerId
                                        ? 1
                                        : 0.35),
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
              ),
            ),
          ),
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
    final card = InkWell(
      key: Key('timeline-stub-${story.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        frame.branchesStory
            ? albumCardRadius
            : focused
            ? 12
            : 4,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: DecoratedBox(
          decoration: frame.branchesStory
              ? BoxDecoration(
                  color: albumParchment,
                  borderRadius: BorderRadius.circular(albumCardRadius),
                  border: Border.all(color: branchMoss, width: 1),
                )
              : focused
              ? BoxDecoration(
                  color: albumDialogSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: frame.parent != null ? branchMoss : albumTerracotta,
                    width: 2,
                  ),
                  boxShadow: frame.parent != null
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
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: cardOnLeft
                      ? WrapAlignment.end
                      : WrapAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: focused
                            ? albumTerracotta
                            : albumInk.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        year,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: focused ? albumParchment : albumInk,
                        ),
                      ),
                    ),
                    if (place.isNotEmpty)
                      Text(
                        place,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: focused
                              ? albumTerracotta
                              : albumInk.withValues(alpha: 0.55),
                          fontWeight: focused ? FontWeight.w700 : null,
                        ),
                      ),
                    if (photos != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library,
                            size: 14,
                            color: focused
                                ? albumTerracotta
                                : albumInk.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            photos,
                            style: Theme.of(context).textTheme.labelSmall,
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
                      color: albumSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  storyTitle(story),
                  textAlign: cardOnLeft ? TextAlign.end : TextAlign.start,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final mark = Container(
      width: focused ? midDotFocusedDiameter : midDotDiameter,
      height: focused ? midDotFocusedDiameter : midDotDiameter,
      decoration: BoxDecoration(
        color: focused
            ? albumTerracotta.withValues(alpha: 0.22)
            : albumDialogSurface,
        shape: BoxShape.circle,
        border: Border.all(color: albumTerracotta, width: focused ? 2 : 1.5),
      ),
      child: Center(
        child: Container(
          width: focused ? 8 : 6,
          height: focused ? 8 : 6,
          decoration: const BoxDecoration(
            color: albumTerracotta,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    // The branch ring sits just outside the dot. Extra slop belongs only on
    // a plain node, where it cannot cover that stroke.
    Widget nodeHit({required bool slop}) {
      final hit = GestureDetector(
        key: Key('timeline-mid-node-${story.id}'),
        behavior: HitTestBehavior.opaque,
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
      return slop ? hit : ClipOval(child: hit);
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
            const Positioned.fill(child: _RailGutter()),
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

class _RailGutter extends StatelessWidget {
  const _RailGutter();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: SizedBox.shrink()),
        SizedBox(
          width: calloutGutter,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 27,
                width: 2,
                child: ColoredBox(color: albumInk.withValues(alpha: 0.16)),
              ),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
