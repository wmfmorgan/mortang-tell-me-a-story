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

final class _ParentByYear extends _RailFate {
  const _ParentByYear(this.family);

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

  TreeFamily? parentRingOn(StoryFrame frame) {
    for (final fate in _fates.values) {
      if (fate is _ParentBesideOrigin && fate.storyId == frame.story.id) {
        return fate.family;
      }
    }
    return null;
  }

  List<TreeFamily> get yearMarks {
    for (final fate in _fates.values) {
      if (fate is _ParentByYear) return [fate.family];
    }
    return const [];
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
    if (fates.containsKey(id)) {
      throw StateError('family $id already has a rail fate');
    }
    fates[id] = fate;
  }

  final family = open;
  if (family != null) {
    final published = <String>{for (final story in stories) story.id};
    final related = relatedMarks(tree, family.id);
    final found = originParentMark(family, related);
    // originParentMark is null when the origin id itself is null.
    final parent = found ?? _parentById(family, related);
    if (parent != null) {
      final originId = family.originStoryId;
      if (originId != null && published.contains(originId)) {
        put(parent.id, _ParentBesideOrigin(storyId: originId, family: parent));
      } else {
        put(parent.id, _ParentByYear(parent));
      }
    }
    for (final row in related) {
      if (row.parentFamilyId != family.id) continue;
      final originId = row.originStoryId;
      if (originId == null || !published.contains(originId)) continue;
      put(
        row.id,
        _ChildCallout(
          storyId: originId,
          callout: BranchCallout._(
            familyId: row.id,
            familyName: row.name,
            label: branchMarkLabel(row),
            semanticsLabel: 'Open ${row.name} timeline',
          ),
        ),
      );
    }
  }
  return RailBranching._(fates);
}

TreeFamily? _parentById(TreeFamily open, List<TreeFamily> related) {
  final parentId = open.parentFamilyId;
  if (parentId == null) return null;
  for (final row in related) {
    if (row.id == parentId) return row;
  }
  return null;
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
  if (start.distance + 1e-6 < startRadius) {
    throw StateError('leader start enters the ring');
  }

  final railX = toward * centerToLane;
  final leaders = <CalloutLeader>[];
  final rects = <Rect>[];
  var centerY = start.dy + calloutDiagonal;
  for (final size in labelSizes) {
    final top = centerY - size.height / 2;
    final rect = side == CalloutSide.right
        ? Rect.fromLTWH(railX, top, size.width, size.height)
        : Rect.fromLTWH(railX - size.width, top, size.width, size.height);
    final labelRail = side == CalloutSide.right ? rect.left : rect.right;
    var endX = labelRail - toward * calloutLabelGap;
    if (toward > 0 && endX < start.dx) {
      final minGapEnd = labelRail - 2;
      endX = start.dx <= minGapEnd ? start.dx : minGapEnd;
    } else if (toward < 0 && endX > start.dx) {
      final minGapEnd = labelRail + 2;
      endX = start.dx >= minGapEnd ? start.dx : minGapEnd;
    }
    var elbowX = start.dx + toward * calloutDiagonal;
    if (toward > 0 && elbowX > endX) elbowX = endX;
    if (toward < 0 && elbowX < endX) elbowX = endX;
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
    cardRailEdge: railX,
  );
}

class CalloutLeaderPainter extends CustomPainter {
  const CalloutLeaderPainter({
    required this.leaders,
    required this.color,
    this.origin = Offset.zero,
  });

  final List<CalloutLeader> leaders;
  final Color color;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = calloutStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final leader in leaders) {
      final path = Path()
        ..moveTo(origin.dx + leader.start.dx, origin.dy + leader.start.dy)
        ..lineTo(origin.dx + leader.elbow.dx, origin.dy + leader.elbow.dy)
        ..lineTo(origin.dx + leader.end.dx, origin.dy + leader.end.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CalloutLeaderPainter oldDelegate) {
    if (oldDelegate.color != color || oldDelegate.origin != origin) {
      return true;
    }
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

final _dotSizes = <String, ValueNotifier<Size?>>{};

ValueNotifier<Size?> _dotSizeFor(String storyId) {
  return _dotSizes.putIfAbsent(storyId, () => ValueNotifier<Size?>(null));
}

PlacedBranch placeBranchCallout({
  required BuildContext context,
  required StoryFrame frame,
  required CalloutSide side,
  required Widget dot,
  required Widget? card,
  required double? centerToLane,
  required double maxLabelWidth,
  required void Function(String familyId) onOpen,
}) {
  if (!frame.branchesStory) {
    return PlacedBranch(dot: dot, lane: card ?? const SizedBox.shrink());
  }
  final storyId = frame.story.id;
  return PlacedBranch(
    dot: _MeasuredDot(
      storyId: storyId,
      dot: dot,
      frame: frame,
      side: side,
      centerToLane: centerToLane,
      maxLabelWidth: maxLabelWidth,
      onOpen: onOpen,
    ),
    lane: _CalloutLane(
      storyId: storyId,
      frame: frame,
      side: side,
      card: card,
      centerToLane: centerToLane,
      maxLabelWidth: maxLabelWidth,
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
  return Size(painter.width, math.max(painter.height, calloutHit));
}

({
  double effective,
  double flushInset,
  CalloutGeometry geometry,
  List<Size> sizes,
})
_geometryFor({
  required BuildContext context,
  required StoryFrame frame,
  required CalloutSide side,
  required Size dotSize,
  required double? centerToLane,
  required double maxLabelWidth,
}) {
  final style = _calloutStyle(context);
  final sizes = [
    for (final callout in frame.callouts)
      _labelSize(context, callout.label, style, maxLabelWidth),
  ];
  final half = dotSize.width / 2;
  final outer =
      (dotSize.shortestSide + 2 * calloutDotGap + 2 * calloutStroke) / 2;
  final startX = (outer + calloutLeaderGap) / math.sqrt(2);
  final effective = centerToLane ?? math.max(half, startX + calloutLabelGap);
  final geometry = layoutCallouts(
    side: side,
    dotDiameter: dotSize.shortestSide,
    centerToLane: effective,
    labelSizes: sizes,
  );
  final flushInset = centerToLane == null ? effective - half : 0.0;
  return (
    effective: effective,
    flushInset: flushInset,
    geometry: geometry,
    sizes: sizes,
  );
}

class _MeasuredDot extends StatefulWidget {
  const _MeasuredDot({
    required this.storyId,
    required this.dot,
    required this.frame,
    required this.side,
    required this.centerToLane,
    required this.maxLabelWidth,
    required this.onOpen,
  });

  final String storyId;
  final Widget dot;
  final StoryFrame frame;
  final CalloutSide side;
  final double? centerToLane;
  final double maxLabelWidth;
  final void Function(String familyId) onOpen;

  @override
  State<_MeasuredDot> createState() => _MeasuredDotState();
}

class _MeasuredDotState extends State<_MeasuredDot> {
  final _key = GlobalKey();
  Size? _size;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _MeasuredDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final next = box.size;
      if (_size == next) return;
      final sizes = _dotSizeFor(widget.storyId);
      if (sizes.value != next) sizes.value = next;
      setState(() => _size = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (size != null)
          Positioned.fill(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: _DotOverlay(
                frame: widget.frame,
                side: widget.side,
                dotSize: size,
                centerToLane: widget.centerToLane,
                maxLabelWidth: widget.maxLabelWidth,
                onOpen: widget.onOpen,
              ),
            ),
          ),
        KeyedSubtree(key: _key, child: widget.dot),
      ],
    );
  }
}

class _DotOverlay extends StatelessWidget {
  const _DotOverlay({
    required this.frame,
    required this.side,
    required this.dotSize,
    required this.centerToLane,
    required this.maxLabelWidth,
    required this.onOpen,
  });

  final StoryFrame frame;
  final CalloutSide side;
  final Size dotSize;
  final double? centerToLane;
  final double maxLabelWidth;
  final void Function(String familyId) onOpen;

  @override
  Widget build(BuildContext context) {
    final laid = _geometryFor(
      context: context,
      frame: frame,
      side: side,
      dotSize: dotSize,
      centerToLane: centerToLane,
      maxLabelWidth: maxLabelWidth,
    );
    final geometry = laid.geometry;
    const canvas = 2400.0;
    final origin = const Offset(canvas / 2, canvas / 2);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: geometry.ringDiameter,
          height: geometry.ringDiameter,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: branchMoss, width: calloutStroke),
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            size: const Size(canvas, canvas),
            painter: CalloutLeaderPainter(
              leaders: geometry.leaders,
              color: branchMoss,
              origin: origin,
            ),
          ),
        ),
        if (geometry.ringOpensFamily)
          Semantics(
            button: true,
            label: frame.callouts.single.semanticsLabel,
            child: GestureDetector(
              key: Key('timeline-branch-callout-ring-${frame.story.id}'),
              behavior: HitTestBehavior.translucent,
              onTap: () => onOpen(frame.callouts.single.familyId),
              child: const SizedBox(width: calloutHit, height: calloutHit),
            ),
          ),
      ],
    );
  }
}

class _CalloutLane extends StatefulWidget {
  const _CalloutLane({
    required this.storyId,
    required this.frame,
    required this.side,
    required this.card,
    required this.centerToLane,
    required this.maxLabelWidth,
    required this.onOpen,
  });

  final String storyId;
  final StoryFrame frame;
  final CalloutSide side;
  final Widget? card;
  final double? centerToLane;
  final double maxLabelWidth;
  final void Function(String familyId) onOpen;

  @override
  State<_CalloutLane> createState() => _CalloutLaneState();
}

class _CalloutLaneState extends State<_CalloutLane> {
  late ValueNotifier<Size?> _sizes;

  @override
  void initState() {
    super.initState();
    _sizes = _dotSizeFor(widget.storyId);
    _sizes.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _CalloutLane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId == widget.storyId) return;
    _sizes.removeListener(_changed);
    _sizes = _dotSizeFor(widget.storyId);
    _sizes.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sizes.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final dotSize = _sizes.value;
    if (dotSize == null) return card ?? const SizedBox.shrink();
    final style = _calloutStyle(context);
    final laid = _geometryFor(
      context: context,
      frame: widget.frame,
      side: widget.side,
      dotSize: dotSize,
      centerToLane: widget.centerToLane,
      maxLabelWidth: widget.maxLabelWidth,
    );
    final geometry = laid.geometry;
    final top = dotSize.height / 2 + geometry.labelRects.first.top;
    return Padding(
      padding: EdgeInsets.only(
        top: math.max(0, top),
        left: widget.side == CalloutSide.right ? laid.flushInset : 0,
        right: widget.side == CalloutSide.left ? laid.flushInset : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: widget.side == CalloutSide.right
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.frame.callouts.length; i++) ...[
            if (i > 0) const SizedBox(height: calloutStackGap),
            _CalloutLabel(
              callout: widget.frame.callouts[i],
              size: laid.sizes[i],
              style: style,
              side: widget.side,
              onOpen: widget.onOpen,
            ),
          ],
          if (card != null) card,
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
  });

  final BranchCallout callout;
  final Size size;
  final TextStyle style;
  final CalloutSide side;
  final void Function(String familyId) onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: callout.semanticsLabel,
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
  }
}
