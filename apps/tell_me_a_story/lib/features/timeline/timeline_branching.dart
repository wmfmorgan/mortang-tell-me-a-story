import 'dart:math' as math;

import 'package:flutter/material.dart';

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

/// Years and wide Days keep the card about this far from the rail center.
const calloutFromRail = 75.0;

const farDotDiameter = 12.0;
const farDotHighlightedDiameter = 14.0;
const midDotDiameter = 16.0;
const midDotFocusedDiameter = 22.0;
const fullDotDiameter = 14.0;
const fullDotFocusedDiameter = 20.0;

/// Padding inside a Years branch card so the chip and title clear the border.
const calloutCardPadding = 16.0;

sealed class _RailFate {
  const _RailFate();
}

final class _ChildCallout extends _RailFate {
  const _ChildCallout({required this.storyId, required this.callout});

  final String storyId;
  final BranchCallout callout;
}

final class _ParentBesideOrigin extends _RailFate {
  const _ParentBesideOrigin({required this.storyId, required this.family});

  final String storyId;
  final TreeFamily family;
}

final class _YearMark extends _RailFate {
  const _YearMark(this.family);

  final TreeFamily family;
}

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
  RailBranching._(this._fates) : _byStory = _group(_fates);

  final Map<String, _RailFate> _fates;
  final Map<String, List<BranchCallout>> _byStory;

  StoryFrame frameFor(Story story) {
    return StoryFrame._(story: story, callouts: _byStory[story.id] ?? const []);
  }

  /// The parent ring beside the open family's origin, when that origin is published.
  TreeFamily? get parentRing {
    for (final fate in _fates.values) {
      if (fate is _ParentBesideOrigin) return fate.family;
    }
    return null;
  }

  TreeFamily? parentRingOn(StoryFrame frame) {
    for (final fate in _fates.values) {
      if (fate is _ParentBesideOrigin && fate.storyId == frame.story.id) {
        return fate.family;
      }
    }
    return null;
  }

  List<TreeFamily> get yearMarks {
    return [
      for (final fate in _fates.values)
        if (fate is _YearMark) fate.family,
    ];
  }

  static Map<String, List<BranchCallout>> _group(Map<String, _RailFate> fates) {
    final byStory = <String, List<BranchCallout>>{};
    for (final fate in fates.values) {
      if (fate is! _ChildCallout) continue;
      (byStory[fate.storyId] ??= []).add(fate.callout);
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
    return byStory;
  }
}

RailBranching railBranching({
  required TreeFamily? open,
  required List<TreeFamily> tree,
  required List<Story> stories,
}) {
  final fates = <String, _RailFate>{};
  void put(String id, _RailFate fate) {
    assert(!fates.containsKey(id), 'family $id already has a rail fate');
    fates[id] = fate;
  }

  final family = open;
  if (family != null) {
    final published = <String>{for (final story in stories) story.id};
    final related = relatedMarks(tree, family.id);
    final originId = family.originStoryId;
    final originOnRail = originId != null && published.contains(originId);
    final beside = originOnRail ? originParentMark(family, related) : null;
    for (final row in related) {
      if (beside != null && row.id == beside.id) {
        put(row.id, _ParentBesideOrigin(storyId: originId!, family: row));
        continue;
      }
      final childOrigin = row.originStoryId;
      if (row.parentFamilyId == family.id &&
          childOrigin != null &&
          published.contains(childOrigin)) {
        put(
          row.id,
          _ChildCallout(
            storyId: childOrigin,
            callout: BranchCallout._(
              familyId: row.id,
              familyName: row.name,
              label: branchMarkLabel(row),
              semanticsLabel: 'Open ${row.name} timeline',
            ),
          ),
        );
        continue;
      }
      if (row.id == family.parentFamilyId) {
        put(row.id, _YearMark(row));
      }
    }
  }
  return RailBranching._(fates);
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
  required List<Size> labelSizes,
}) {
  final toward = side == CalloutSide.right ? 1.0 : -1.0;
  final ringDiameter = dotDiameter + 2 * calloutDotGap + 2 * calloutStroke;
  final outerRadius = ringDiameter / 2;
  final startRadius = outerRadius + calloutLeaderGap;
  final ray = startRadius / math.sqrt(2);
  final start = Offset(toward * ray, ray);
  final leaders = <CalloutLeader>[];
  final rects = <Rect>[];
  var centerY = start.dy + calloutDiagonal;
  for (final size in labelSizes) {
    final elbowX = start.dx + toward * calloutDiagonal;
    final minRail = elbowX.abs() + calloutMinRun + calloutLabelGap;
    final rail = math.max(centerToLane, minRail);
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
    cardTop: rects.isEmpty ? 0 : rects.last.bottom,
    cardRailEdge: rects.isEmpty
        ? toward * centerToLane
        : (side == CalloutSide.right ? rects.first.left : rects.first.right),
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
  const PlacedBranch({required this.dot, required this.lane});

  final Widget dot;
  final Widget lane;
}

PlacedBranch placeBranchCallout({
  required BuildContext context,
  required StoryFrame frame,
  required CalloutSide side,
  required Widget dot,
  required double dotDiameter,
  required Widget? card,
  required double centerToLane,
  required double maxLabelWidth,
  required void Function(String familyId) onOpen,
}) {
  if (!frame.branchesStory) {
    return PlacedBranch(dot: dot, lane: card ?? const SizedBox.shrink());
  }
  final style = _calloutStyle(context);
  final sizes = [
    for (final callout in frame.callouts)
      _labelSize(context, callout.label, style, maxLabelWidth),
  ];
  final geometry = layoutCallouts(
    side: side,
    dotDiameter: dotDiameter,
    centerToLane: centerToLane,
    labelSizes: sizes,
  );
  return PlacedBranch(
    dot: _CalloutDot(
      frame: frame,
      dot: dot,
      geometry: geometry,
      onOpen: onOpen,
    ),
    lane: _CalloutLane(
      frame: frame,
      geometry: geometry,
      sizes: sizes,
      style: style,
      side: side,
      card: card,
      centerToLane: centerToLane,
      onOpen: onOpen,
    ),
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

class _CalloutDot extends StatelessWidget {
  const _CalloutDot({
    required this.frame,
    required this.dot,
    required this.geometry,
    required this.onOpen,
  });

  final StoryFrame frame;
  final Widget dot;
  final CalloutGeometry geometry;
  final void Function(String familyId) onOpen;

  @override
  Widget build(BuildContext context) {
    final single = frame.callouts.length == 1 ? frame.callouts.single : null;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
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
        if (geometry.ringOpensFamily && single != null)
          ExcludeSemantics(
            child: GestureDetector(
              key: Key('timeline-branch-callout-ring-${frame.story.id}'),
              behavior: HitTestBehavior.translucent,
              onTap: () => onOpen(single.familyId),
              child: SizedBox(
                width: geometry.ringHit.width,
                height: geometry.ringHit.height,
              ),
            ),
          ),
      ],
    );
  }
}

class _CalloutLane extends StatelessWidget {
  const _CalloutLane({
    required this.frame,
    required this.geometry,
    required this.sizes,
    required this.style,
    required this.side,
    required this.card,
    required this.centerToLane,
    required this.onOpen,
  });

  final StoryFrame frame;
  final CalloutGeometry geometry;
  final List<Size> sizes;
  final TextStyle style;
  final CalloutSide side;
  final Widget? card;
  final double centerToLane;
  final void Function(String familyId) onOpen;

  @override
  Widget build(BuildContext context) {
    final stack = math.max(
      geometry.ringDiameter,
      geometry.ringOpensFamily ? geometry.ringHit.height : 0,
    );
    final drop = math.max(0.0, stack / 2 + geometry.labelRects.first.top);
    final push = math.max(0.0, geometry.cardRailEdge.abs() - centerToLane);
    final cardGap = math.max(
      0.0,
      geometry.cardTop - geometry.labelRects.last.bottom,
    );
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
          if (cardGap > 0) SizedBox(height: cardGap),
          ?card,
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
    final hit = GestureDetector(
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
    );
    if (!announce) return ExcludeSemantics(child: hit);
    return Semantics(button: true, label: callout.semanticsLabel, child: hit);
  }
}

/// One keyboard-focusable control for a single branch callout.
class BranchCalloutTarget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (frame.callouts.length != 1) return child;
    final callout = frame.callouts.single;
    return Semantics(
      button: true,
      label: callout.semanticsLabel,
      onTap: () => onOpen(callout.familyId),
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onOpen(callout.familyId);
              return null;
            },
          ),
        },
        child: Focus(child: child),
      ),
    );
  }
}
