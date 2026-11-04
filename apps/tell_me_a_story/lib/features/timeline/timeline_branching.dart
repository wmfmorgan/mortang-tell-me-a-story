import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/theme/album_theme.dart';
import '../../data/families_api.dart';
import '../../data/stories_api.dart';
import 'timeline_zoom.dart';

const calloutStroke = 2.0;
const calloutDotGap = 2.0;
const calloutLeaderGap = 2.0;
const calloutLabelGap = 6.0;
const calloutDiagonal = 16.0;
const calloutStackGap = 4.0;
const calloutHit = 44.0;
const calloutMinRun = 24.0;

/// Years and wide Days keep the card at least this far from the rail center.
const calloutFromRail = 75.0;

/// The side column starts this far from the rail center (half of [calloutGutter]).
const calloutLaneOffset = 28.0;

/// Gutter that holds the rail on Years and wide Days.
const calloutGutter = 56.0;

const calloutLabelWidthFar = 220.0;
const calloutLabelWidthDial = 460.0;

const farDotDiameter = 12.0;
const farDotHighlightedDiameter = 14.0;
const midDotDiameter = 16.0;
const midDotFocusedDiameter = 22.0;
const fullDotDiameter = 14.0;
const fullDotFocusedDiameter = 20.0;

/// Padding inside a Years branch card so the chip and title clear the border.
const calloutCardPadding = 16.0;

final class BranchCallout {
  const BranchCallout._({
    required this.familyId,
    required this.familyName,
    required this.label,
    required this.semanticsLabel,
  });

  final String familyId;
  final String familyName;
  final String label;
  final String semanticsLabel;
}

final class StoryFrame {
  const StoryFrame._({required this.story, required this.callouts});

  final Story story;
  final List<BranchCallout> callouts;

  bool get branchesStory => callouts.isNotEmpty;
}

final class RailBranching {
  RailBranching._(this._byStory);

  final Map<String, List<BranchCallout>> _byStory;

  StoryFrame frameFor(Story story) {
    return StoryFrame._(story: story, callouts: _byStory[story.id] ?? const []);
  }
}

RailBranching railBranching({
  required TreeFamily? open,
  required List<TreeFamily> tree,
  required List<Story> stories,
}) {
  final byStory = <String, List<BranchCallout>>{};
  final family = open;
  if (family != null) {
    final published = <String>{for (final story in stories) story.id};
    for (final row in relatedMarks(tree, family.id)) {
      final childOrigin = row.originStoryId;
      if (row.parentFamilyId != family.id ||
          childOrigin == null ||
          !published.contains(childOrigin)) {
        continue;
      }
      final callout = BranchCallout._(
        familyId: row.id,
        familyName: row.name,
        label: branchMarkLabel(row),
        semanticsLabel: 'Open ${row.name} timeline',
      );
      (byStory[childOrigin] ??= []).add(callout);
    }
  }
  for (final entry in byStory.entries) {
    final calls = [...entry.value]
      ..sort((a, b) {
        final name = a.familyName.toLowerCase().compareTo(
          b.familyName.toLowerCase(),
        );
        if (name != 0) return name;
        return a.familyId.compareTo(b.familyId);
      });
    byStory[entry.key] = List.unmodifiable(calls);
  }
  return RailBranching._(byStory);
}

enum CalloutSide { right, left }

class CalloutLeader {
  const CalloutLeader({
    required this.start,
    required this.elbow,
    required this.end,
  });

  final Offset start;
  final Offset elbow;
  final Offset end;
}

class CalloutGeometry {
  const CalloutGeometry({
    required this.ringDiameter,
    required this.leaders,
    required this.labelRects,
    required this.ringHit,
    required this.ringOpensFamily,
    required this.cardTop,
    required this.cardRailEdge,
  });

  final double ringDiameter;
  final List<CalloutLeader> leaders;
  final List<Rect> labelRects;
  final Rect ringHit;
  final bool ringOpensFamily;
  final double cardTop;
  final double cardRailEdge;
}

CalloutGeometry layoutCallouts({
  required CalloutSide side,
  required double dotDiameter,
  required double centerToLane,
  double? minCardFromRail,
  required List<Size> labelSizes,
}) {
  assert(labelSizes.isNotEmpty);
  final toward = side == CalloutSide.right ? 1.0 : -1.0;
  final ringDiameter = dotDiameter + 2 * calloutDotGap + 2 * calloutStroke;
  final outerRadius = ringDiameter / 2;
  final startRadius = outerRadius + calloutLeaderGap;
  final ray = startRadius / math.sqrt(2);
  final start = Offset(toward * ray, ray);
  final elbowX = start.dx + toward * calloutDiagonal;
  final minRail = elbowX.abs() + calloutMinRun + calloutLabelGap;
  final rail = math.max(minCardFromRail ?? centerToLane, minRail);
  final leaders = <CalloutLeader>[];
  final rects = <Rect>[];
  var centerY = start.dy + calloutDiagonal;
  for (final size in labelSizes) {
    final top = centerY - size.height / 2;
    final rect = side == CalloutSide.right
        ? Rect.fromLTWH(rail, top, size.width, size.height)
        : Rect.fromLTWH(-rail - size.width, top, size.width, size.height);
    final endX = side == CalloutSide.right
        ? rect.left - calloutLabelGap
        : rect.right + calloutLabelGap;
    leaders.add(
      CalloutLeader(
        start: start,
        elbow: Offset(elbowX, centerY),
        end: Offset(endX, centerY),
      ),
    );
    rects.add(rect);
    centerY += math.max(size.height, calloutHit) + calloutStackGap;
  }

  return CalloutGeometry(
    ringDiameter: ringDiameter,
    leaders: List.unmodifiable(leaders),
    labelRects: List.unmodifiable(rects),
    ringHit: Rect.fromCenter(
      center: Offset.zero,
      width: calloutHit,
      height: calloutHit,
    ),
    ringOpensFamily: rects.length == 1,
    cardTop: rects.last.bottom,
    cardRailEdge: side == CalloutSide.right
        ? rects.first.left
        : rects.first.right,
  );
}

class CalloutLeaderPainter extends CustomPainter {
  const CalloutLeaderPainter({required this.leaders, required this.color});

  final List<CalloutLeader> leaders;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = calloutStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final center = size.center(Offset.zero);
    for (final leader in leaders) {
      final path = Path()
        ..moveTo(center.dx + leader.start.dx, center.dy + leader.start.dy)
        ..lineTo(center.dx + leader.elbow.dx, center.dy + leader.elbow.dy)
        ..lineTo(center.dx + leader.end.dx, center.dy + leader.end.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CalloutLeaderPainter oldDelegate) {
    if (oldDelegate.color != color) return true;
    if (oldDelegate.leaders.length != leaders.length) return true;
    for (var i = 0; i < leaders.length; i++) {
      final previous = oldDelegate.leaders[i];
      final next = leaders[i];
      if (previous.start != next.start ||
          previous.elbow != next.elbow ||
          previous.end != next.end) {
        return true;
      }
    }
    return false;
  }
}

class PlacedBranch {
  const PlacedBranch({
    required this.dot,
    required this.ringHit,
    required this.lane,
    required this.push,
  });

  /// Ring, leader, and the story's own dot. Center taps stay on the dot.
  final Widget dot;

  /// Annulus over the ring. Empty when several families share the dot.
  final Widget ringHit;

  /// Labels, already pushed out to the leader. The card stays outside this.
  final Widget lane;

  /// How far the lane content sits past the column that starts at [centerToLane].
  final double push;
}

PlacedBranch placeBranchCallout({
  required BuildContext context,
  required StoryFrame frame,
  required CalloutSide side,
  required Widget dot,
  required double dotDiameter,
  required double centerToLane,
  double? minCardFromRail,
  required double maxLabelWidth,
  required void Function(String familyId) onOpen,
}) {
  assert(frame.branchesStory);
  final style = _calloutStyle(context);
  final sizes = [
    for (final callout in frame.callouts)
      _labelSize(context, callout.label, style, maxLabelWidth),
  ];
  final geometry = layoutCallouts(
    side: side,
    dotDiameter: dotDiameter,
    centerToLane: centerToLane,
    minCardFromRail: minCardFromRail,
    labelSizes: sizes,
  );
  final single = frame.callouts.length == 1 ? frame.callouts.single : null;
  final push = geometry.cardRailEdge.abs() - centerToLane;
  return PlacedBranch(
    dot: _CalloutVisuals(dot: dot, geometry: geometry),
    ringHit: geometry.ringOpensFamily && single != null
        ? _FocusOutline(
            circle: true,
            child: _AnnulusTap(
              key: Key('timeline-branch-callout-ring-${frame.story.id}'),
              innerRadius: dotDiameter / 2,
              onTap: () => onOpen(single.familyId),
              child: const SizedBox(width: calloutHit, height: calloutHit),
            ),
          )
        : const SizedBox.shrink(),
    lane: _CalloutLane(
      frame: frame,
      geometry: geometry,
      sizes: sizes,
      style: style,
      side: side,
      push: push,
      onOpen: onOpen,
    ),
    push: push,
  );
}

TextStyle _calloutStyle(BuildContext context) {
  return (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
    color: branchMoss,
    fontWeight: FontWeight.w500,
  );
}

Size _labelSize(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    ellipsis: '…',
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  final size = Size(painter.width, math.max(painter.height, calloutHit));
  painter.dispose();
  return size;
}

class _CalloutVisuals extends StatelessWidget {
  const _CalloutVisuals({required this.dot, required this.geometry});

  final Widget dot;
  final CalloutGeometry geometry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        const SizedBox(width: calloutHit, height: calloutHit),
        IgnorePointer(
          child: SizedBox(
            width: geometry.ringDiameter,
            height: geometry.ringDiameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: branchMoss, width: calloutStroke),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CalloutLeaderPainter(
                leaders: geometry.leaders,
                color: branchMoss,
              ),
            ),
          ),
        ),
        dot,
      ],
    );
  }
}

class _AnnulusTap extends SingleChildRenderObjectWidget {
  const _AnnulusTap({
    super.key,
    required this.innerRadius,
    required this.onTap,
    super.child,
  });

  final double innerRadius;
  final VoidCallback onTap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderAnnulusTap(innerRadius: innerRadius, onTap: onTap);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnnulusTap renderObject,
  ) {
    renderObject
      ..innerRadius = innerRadius
      ..onTap = onTap;
  }
}

class _RenderAnnulusTap extends RenderProxyBox {
  _RenderAnnulusTap({required this._innerRadius, required this._onTap});

  double _innerRadius;
  VoidCallback _onTap;

  set innerRadius(double value) {
    if (_innerRadius == value) return;
    _innerRadius = value;
  }

  set onTap(VoidCallback value) => _onTap = value;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final distance = (position - size.center(Offset.zero)).distance;
    if (distance < _innerRadius || distance > size.shortestSide / 2) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  int? _pointer;

  bool _containsLocal(Offset position) {
    if (!size.contains(position)) return false;
    final distance = (position - size.center(Offset.zero)).distance;
    return distance >= _innerRadius && distance <= size.shortestSide / 2;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _pointer = _containsLocal(event.localPosition) ? event.pointer : null;
      return;
    }
    if (_pointer != event.pointer) return;
    if (event is PointerMoveEvent) {
      if (!_containsLocal(event.localPosition)) _pointer = null;
      return;
    }
    if (event is PointerCancelEvent) {
      _pointer = null;
      return;
    }
    if (event is PointerUpEvent) {
      if (_containsLocal(event.localPosition)) _onTap();
      _pointer = null;
    }
  }
}

class _CalloutLane extends StatelessWidget {
  const _CalloutLane({
    required this.frame,
    required this.geometry,
    required this.sizes,
    required this.style,
    required this.side,
    required this.push,
    required this.onOpen,
  });

  final StoryFrame frame;
  final CalloutGeometry geometry;
  final List<Size> sizes;
  final TextStyle style;
  final CalloutSide side;
  final double push;
  final void Function(String familyId) onOpen;

  @override
  Widget build(BuildContext context) {
    final stack = math.max(geometry.ringDiameter, calloutHit);
    final drop = math.max(0.0, stack / 2 + geometry.labelRects.first.top);
    return Padding(
      padding: EdgeInsets.only(
        top: drop,
        left: side == CalloutSide.right ? push : 0,
        right: side == CalloutSide.left ? push : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: side == CalloutSide.right
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < frame.callouts.length; i++) ...[
            if (i > 0) const SizedBox(height: calloutStackGap),
            _CalloutLabel(
              callout: frame.callouts[i],
              size: sizes[i],
              style: style,
              side: side,
              onOpen: onOpen,
              announce: !geometry.ringOpensFamily,
            ),
          ],
        ],
      ),
    );
  }
}

class _CalloutLabel extends StatelessWidget {
  const _CalloutLabel({
    required this.callout,
    required this.size,
    required this.style,
    required this.side,
    required this.onOpen,
    required this.announce,
  });

  final BranchCallout callout;
  final Size size;
  final TextStyle style;
  final CalloutSide side;
  final void Function(String familyId) onOpen;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final hit = _FocusOutline(
      child: GestureDetector(
        key: Key('timeline-branch-callout-${callout.familyId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onOpen(callout.familyId),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Align(
              alignment: side == CalloutSide.right
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Text(
                callout.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
    if (!announce) return ExcludeSemantics(child: hit);
    return Semantics(button: true, label: callout.semanticsLabel, child: hit);
  }
}

class _CalloutFocus extends InheritedWidget {
  const _CalloutFocus({required this.focused, required super.child});

  final bool focused;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_CalloutFocus>()
            ?.focused ??
        false;
  }

  @override
  bool updateShouldNotify(_CalloutFocus oldWidget) =>
      focused != oldWidget.focused;
}

class _FocusOutline extends StatelessWidget {
  const _FocusOutline({required this.child, this.circle = false});

  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (!_CalloutFocus.of(context)) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(4),
        border: Border.all(color: branchMoss, width: calloutStroke),
      ),
      child: child,
    );
  }
}

/// Keyboard focus for one branch callout. Wrap the ring and the label only.
class BranchCalloutTarget extends StatefulWidget {
  const BranchCalloutTarget({
    super.key,
    required this.frame,
    required this.onOpen,
    required this.child,
  });

  final StoryFrame frame;
  final ValueChanged<String> onOpen;
  final Widget child;

  @override
  State<BranchCalloutTarget> createState() => _BranchCalloutTargetState();
}

class _BranchCalloutTargetState extends State<BranchCalloutTarget> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frame.callouts.length != 1) return widget.child;
    final callout = widget.frame.callouts.single;
    return Semantics(
      button: true,
      label: callout.semanticsLabel,
      onTap: () => widget.onOpen(callout.familyId),
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onOpen(callout.familyId);
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focus,
          key: Key('timeline-branch-callout-focus-${widget.frame.story.id}'),
          child: ListenableBuilder(
            listenable: _focus,
            builder: (context, _) {
              return _CalloutFocus(
                focused: _focus.hasPrimaryFocus,
                child: widget.child,
              );
            },
          ),
        ),
      ),
    );
  }
}
