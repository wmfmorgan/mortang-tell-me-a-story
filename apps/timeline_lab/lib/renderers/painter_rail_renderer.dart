import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../filter/timeline_filter.dart';
import '../model/lab_models.dart';
import '../playback/playback_controller.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
import 'renderer_contract.dart';
import 'story_marker.dart';

class RailPoint {
  const RailPoint({
    required this.storyId,
    required this.center,
    required this.matched,
  });

  final String storyId;
  final Offset center;
  final bool matched;
}

/// Stories that didn't fit a cluster's stack. Drawn as `+N`; tapping it
/// cycles through [storyIds], so every story stays reachable.
class RailBadge {
  const RailBadge({required this.at, required this.storyIds});

  final Offset at;

  /// Ascending date order.
  final List<String> storyIds;

  int get count => storyIds.length;
}

sealed class RailHit {
  const RailHit();
}

class RailPointHit extends RailHit {
  const RailPointHit(this.storyId);
  final String storyId;
}

class RailBadgeHit extends RailHit {
  const RailBadgeHit(this.badge);
  final RailBadge badge;
}

/// Pure layout for the painter rail: horizontal time axis, one lane per
/// family, near-coincident dots stacked up to [maxStack], the rest collected
/// into a [RailBadge].
class PainterRailGeometry {
  PainterRailGeometry(
    List<TimelineEntry> entries,
    LabDataset d, {
    this.pxPerYear = 48,
    this.laneHeight = 28,
    this.top = 56,
  }) : minYear = d.minYear,
       maxYear = d.maxYear,
       laneIds = familyLaneOrder(d) {
    final byLane = <int, List<TimelineEntry>>{};
    for (final e in entries) {
      final lane = laneIds.indexOf(e.story.familyId);
      (byLane[lane < 0 ? 0 : lane] ??= []).add(e);
    }
    for (final MapEntry(key: lane, value: laneEntries) in byLane.entries) {
      _layoutLane(lane, laneEntries);
    }
  }

  static const stackGap = 14.0;
  static const stackStep = 10.0;
  static const maxStack = 4;
  static const hitRadius = 12.0;
  static const leftPad = 24.0;

  final double pxPerYear;
  final double laneHeight;
  final double top;
  final int minYear;
  final int maxYear;
  final List<String> laneIds;

  final List<RailPoint> points = [];
  final List<RailBadge> overflowBadges = [];

  int get lanes => laneIds.length;

  double laneTop(int lane) => top + lane * laneHeight * 3;

  double xForYear(double fractionalYear) =>
      (fractionalYear - minYear) * pxPerYear + leftPad;

  double xFor(LabStory s) => xForYear(s.fractionalYear);

  double _stackY(int lane, int k) =>
      laneTop(lane) + laneHeight * 2 - k * stackStep;

  Size get size => Size(
    (maxYear - minYear + 1) * pxPerYear + 48,
    top + lanes * laneHeight * 3,
  );

  void _layoutLane(int lane, List<TimelineEntry> laneEntries) {
    // Entries arrive in ascending date order, so x is non-decreasing.
    var i = 0;
    while (i < laneEntries.length) {
      final anchorX = xFor(laneEntries[i].story);
      var j = i;
      while (j < laneEntries.length &&
          xFor(laneEntries[j].story) - anchorX < stackGap) {
        j++;
      }
      final cluster = laneEntries.sublist(i, j);
      for (var k = 0; k < cluster.length && k < maxStack; k++) {
        final e = cluster[k];
        points.add(
          RailPoint(
            storyId: e.story.id,
            center: Offset(xFor(e.story), _stackY(lane, k)),
            matched: e.matched,
          ),
        );
      }
      if (cluster.length > maxStack) {
        overflowBadges.add(
          RailBadge(
            at: Offset(anchorX, _stackY(lane, maxStack)),
            storyIds: [for (final e in cluster.skip(maxStack)) e.story.id],
          ),
        );
      }
      i = j;
    }
  }

  /// Nearest point or badge within [hitRadius]; on a tie the later one wins.
  RailHit? hitTest(Offset local) {
    RailHit? best;
    var bestDist = double.infinity;
    for (final p in points) {
      final dist = (p.center - local).distance;
      if (dist <= hitRadius && dist <= bestDist) {
        best = RailPointHit(p.storyId);
        bestDist = dist;
      }
    }
    for (final b in overflowBadges) {
      final dist = (b.at - local).distance;
      if (dist <= hitRadius && dist <= bestDist) {
        best = RailBadgeHit(b);
        bestDist = dist;
      }
    }
    return best;
  }
}

/// Badge tap: select the badge's first story, or the one after the current
/// selection when it is already inside the badge.
String nextInBadge(RailBadge badge, String? selectedId) {
  final i = selectedId == null ? -1 : badge.storyIds.indexOf(selectedId);
  return badge.storyIds[(i + 1) % badge.count];
}

/// B: the whole rail on one canvas; tap and a11y come from the geometry.
class PainterRailTimeline extends StatefulWidget {
  const PainterRailTimeline({super.key, required this.data});

  final TimelineViewData data;

  @override
  State<PainterRailTimeline> createState() => _PainterRailTimelineState();
}

class _PainterRailTimelineState extends State<PainterRailTimeline> {
  final _hCtl = ScrollController();
  late PainterRailGeometry _geometry;

  PlaybackController? get _playback => widget.data.playback;

  @override
  void initState() {
    super.initState();
    _geometry = PainterRailGeometry(widget.data.entries, widget.data.dataset);
    _playback?.addListener(_follow);
    // Start with the newest matched story near the right edge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newest = widget.data.newestMatched;
      if (!mounted || !_hCtl.hasClients || newest == null) return;
      _scrollTo(_geometry.xFor(newest), 0.9);
    });
  }

  @override
  void didUpdateWidget(PainterRailTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(old.data.entries, widget.data.entries) ||
        !identical(old.data.dataset, widget.data.dataset)) {
      _geometry = PainterRailGeometry(widget.data.entries, widget.data.dataset);
    }
    if (old.data.playback != _playback) {
      old.data.playback?.removeListener(_follow);
      _playback?.addListener(_follow);
    }
  }

  /// Puts content x at [fraction] of the viewport width.
  void _scrollTo(double x, double fraction) {
    final p = _hCtl.position;
    _hCtl.jumpTo(
      (x - p.viewportDimension * fraction).clamp(0, p.maxScrollExtent),
    );
  }

  void _follow() {
    final pb = _playback!;
    final year = pb.cursorYear;
    if (!pb.follow || year == null || !_hCtl.hasClients) return;
    _scrollTo(_geometry.xForYear(year), 0.65);
  }

  void _select(RailHit hit) => widget.data.onSelect(switch (hit) {
    RailPointHit(:final storyId) => storyId,
    RailBadgeHit(:final badge) => nextInBadge(badge, widget.data.selectedId),
  });

  @override
  void dispose() {
    _playback?.removeListener(_follow);
    _hCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final label = Theme.of(context).textTheme.labelSmall!;
    return NotificationListener<ScrollStartNotification>(
      onNotification: (n) => disableFollowOnUserScroll(n, _playback),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _hCtl,
          child: GestureDetector(
            onTapUp: (details) {
              final hit = _geometry.hitTest(details.localPosition);
              if (hit != null) _select(hit);
            },
            child: CustomPaint(
              size: _geometry.size,
              painter: RailPainter(
                geometry: _geometry,
                entries: data.entries,
                dataset: data.dataset,
                selectedId: data.selectedId,
                onSelect: data.onSelect,
                onSelectHit: _select,
                labelStyle: label,
                playback: data.playback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RailPainter extends CustomPainter {
  RailPainter({
    required this.geometry,
    required this.entries,
    required this.dataset,
    required this.selectedId,
    required this.onSelect,
    required this.onSelectHit,
    required this.labelStyle,
    this.playback,
  }) : super(repaint: playback);

  final PainterRailGeometry geometry;
  final List<TimelineEntry> entries;
  final LabDataset dataset;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final ValueChanged<RailHit> onSelectHit;
  final TextStyle labelStyle;

  /// Repaints (no rebuild) on every playback tick.
  final PlaybackController? playback;

  late final Map<String, LabStory> _stories = {
    for (final e in entries) e.story.id: e.story,
  };

  double _reveal(String id) => playback?.reveal(id) ?? 1;

  void _text(Canvas canvas, String s, Offset at, {TextStyle? style}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style ?? labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final axisPaint = Paint()
      ..color = labInk.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    final baseY = g.top - 16;
    canvas.drawLine(
      Offset(PainterRailGeometry.leftPad, baseY),
      Offset(size.width - 24, baseY),
      axisPaint,
    );
    for (var y = g.minYear; y <= g.maxYear + 1; y++) {
      final x = g.xForYear(y.toDouble());
      final decade = y % 10 == 0;
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x, baseY + (decade ? 10 : 4)),
        axisPaint,
      );
      if (decade) _text(canvas, '$y', Offset(x + 2, baseY - 16));
    }

    final sepPaint = Paint()
      ..color = labBorder
      ..strokeWidth = 1;
    for (var lane = 0; lane < g.lanes; lane++) {
      final t = g.laneTop(lane);
      if (lane > 0) {
        canvas.drawLine(Offset(0, t), Offset(size.width, t), sepPaint);
      }
      final fam = dataset.families[g.laneIds[lane]];
      _text(canvas, fam?.name ?? g.laneIds[lane], Offset(4, t + 2));
    }

    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in g.points) {
      final r = _reveal(p.storyId);
      if (r == 0) continue;
      final s = _stories[p.storyId]!;
      fill.color = markerColor(
        s,
        dataset,
      ).withValues(alpha: (p.matched ? 1 : labDimOpacity) * r);
      canvas.drawCircle(p.center, 5, fill);
      if (isOrigin(s, dataset)) {
        ring.color = labMoss.withValues(alpha: r);
        canvas.drawCircle(p.center, 7, ring);
      }
      if (p.storyId == selectedId) {
        ring.color = labTerracotta.withValues(alpha: r);
        canvas.drawCircle(p.center, 8, ring);
      }
    }

    final badgeFill = Paint()..color = labInk;
    for (final b in g.overflowBadges) {
      // Count only revealed stories so the badge never leaks the future.
      final shown = playback == null
          ? b.count
          : b.storyIds.where((id) => _reveal(id) > 0).length;
      if (shown == 0) continue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: b.at, width: 22, height: 12),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, badgeFill);
      if (b.storyIds.contains(selectedId)) {
        ring.color = labTerracotta;
        canvas.drawRRect(rect.inflate(2), ring);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '+$shown',
          style: labelStyle.copyWith(color: labParchment, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, b.at - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }

    final cursor = playback?.cursorYear;
    if (cursor != null) {
      final x = g.xForYear(cursor);
      canvas.drawLine(
        Offset(x, baseY - 4),
        Offset(x, size.height),
        Paint()
          ..color = labTerracotta
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(RailPainter old) =>
      !identical(old.entries, entries) ||
      old.selectedId != selectedId ||
      !identical(old.geometry, geometry) ||
      old.playback != playback;

  /// Semantics cover every story (points and badges) regardless of playback:
  /// playback ticks repaint only, and a screen reader user gets the full
  /// timeline rather than a moving subset.
  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final p in geometry.points)
          CustomPainterSemantics(
            rect: Rect.fromCircle(
              center: p.center,
              radius: PainterRailGeometry.hitRadius,
            ),
            properties: SemanticsProperties(
              label:
                  '${_stories[p.storyId]!.title}, '
                  '${dataset.dateLabel(_stories[p.storyId]!)}',
              button: true,
              textDirection: TextDirection.ltr,
              onTap: () => onSelect(p.storyId),
            ),
          ),
        for (final b in geometry.overflowBadges)
          CustomPainterSemantics(
            rect: Rect.fromCircle(
              center: b.at,
              radius: PainterRailGeometry.hitRadius,
            ),
            properties: SemanticsProperties(
              label:
                  '${b.count} more stories, '
                  '${dataset.dateLabel(_stories[b.storyIds.first]!)} to '
                  '${dataset.dateLabel(_stories[b.storyIds.last]!)}',
              button: true,
              textDirection: TextDirection.ltr,
              onTap: () => onSelectHit(RailBadgeHit(b)),
            ),
          ),
      ];

  @override
  bool shouldRebuildSemantics(RailPainter oldDelegate) =>
      !identical(oldDelegate.geometry, geometry) ||
      !identical(oldDelegate.entries, entries);
}
