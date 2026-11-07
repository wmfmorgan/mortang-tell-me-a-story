import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../filter/timeline_filter.dart';
import '../playback/playback_controller.dart';
import '../theme/lab_theme.dart';
import '../widgets/story_card.dart';
import 'renderer_contract.dart';
import 'story_marker.dart';

enum ZoomLod { decades, years, cards }

ZoomLod lodForScale(double s) => s < 1.5
    ? ZoomLod.decades
    : s < 6
    ? ZoomLod.years
    : ZoomLod.cards;

const _pxPerYear = 40.0;
const _worldHeight = 480.0;
const _bubbleY = 240.0;
const laneGap = 120.0;

/// Screen px reserved per card row at the cards LOD.
const cardRowExtent = 64.0;

/// Screen px of the lane label drawn above each lane.
const _laneLabelExtent = 22.0;

double zoomLaneY(int lane) => laneGap + lane * laneGap;

/// Card rows (including the overflow-chip row) that fit in one lane band at
/// [scale] without spilling into the next lane's label.
int zoomRowsPerLane(double scale) =>
    math.max(1, ((laneGap * scale - _laneLabelExtent) / cardRowExtent).floor());

/// D: fixed-size world inside an `InteractiveViewer`. Markers keep constant
/// screen size (scaled by `1 / scale`) and swap representation by LOD.
class ZoomCanvasTimeline extends StatefulWidget {
  const ZoomCanvasTimeline({
    super.key,
    required this.data,
    this.initialScale = 1,
  });

  final TimelineViewData data;
  final double initialScale;

  @override
  State<ZoomCanvasTimeline> createState() => _ZoomCanvasTimelineState();
}

/// One lane's packed cards at the cards LOD.
typedef _Packed = ({TimelineEntry entry, int lane, int row, double x});

/// Collapsed stories at the bottom row of a lane band.
class _Overflow {
  _Overflow(this.lane, this.x, this.end);
  final int lane;
  final double x;
  double end;
  final List<String> storyIds = [];
}

class _ZoomCanvasTimelineState extends State<ZoomCanvasTimeline>
    with SingleTickerProviderStateMixin {
  TransformationController? _tc;
  late final AnimationController _anim;
  Matrix4Tween? _tween;
  Size _viewport = Size.zero;

  TimelineViewData get data => widget.data;
  PlaybackController? get _playback => data.playback;
  int get minYear => data.dataset.minYear;
  int get maxYear => data.dataset.maxYear;
  double get worldWidth => (maxYear - minYear + 1) * _pxPerYear;

  double _xFor(double fractionalYear) =>
      (fractionalYear - minYear) * _pxPerYear;

  double _reveal(String id) => _playback?.reveal(id) ?? 1;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onAnimate);
    _playback?.addListener(_follow);
  }

  @override
  void didUpdateWidget(ZoomCanvasTimeline old) {
    super.didUpdateWidget(old);
    if (old.data.playback != _playback) {
      old.data.playback?.removeListener(_follow);
      _playback?.addListener(_follow);
    }
  }

  /// Scene → screen matrix that maps [focus] to [screen] at [scale].
  static Matrix4 _matrix(double scale, Offset focus, Offset screen) =>
      Matrix4.identity()
        ..scaleByDouble(scale, scale, 1, 1)
        ..setTranslationRaw(
          screen.dx - scale * focus.dx,
          screen.dy - scale * focus.dy,
          0,
        );

  TransformationController _controllerFor(Size viewport) {
    final newest = data.newestMatched;
    final focusX = newest == null
        ? worldWidth / 2
        : _xFor(newest.fractionalYear);
    // Newest matched story at three quarters across, lane 0 in the upper
    // third, at every initial scale.
    return TransformationController(
      _matrix(
        widget.initialScale,
        Offset(focusX, zoomLaneY(0)),
        Offset(viewport.width * 0.75, viewport.height * 0.3),
      ),
    );
  }

  void _onAnimate() {
    final tween = _tween;
    final tc = _tc;
    if (tween == null || tc == null) return;
    tc.value = tween.evaluate(_anim);
  }

  void _zoomToDecade(int decade) {
    final cx = _xFor(decade + 5);
    _tween = Matrix4Tween(
      begin: _tc!.value.clone(),
      // Middle lane slightly below centre so lane 0 clears the pinned axis.
      end: _matrix(
        2,
        Offset(cx, _bubbleY),
        _viewport.center(Offset.zero) + const Offset(0, 48),
      ),
    );
    _anim.forward(from: 0);
  }

  /// Camera follow: pan horizontally so the cursor sits at 65% width.
  void _follow() {
    final pb = _playback!;
    final year = pb.cursorYear;
    final tc = _tc;
    if (!pb.follow || year == null || tc == null || _anim.isAnimating) {
      return;
    }
    final m = tc.value;
    final s = m.getMaxScaleOnAxis();
    final tx = _viewport.width * 0.65 - s * _xFor(year);
    if ((m.getTranslation().x - tx).abs() < 0.5) return;
    tc.value = m.clone()..setTranslationRaw(tx, m.getTranslation().y, 0);
  }

  @override
  void dispose() {
    _playback?.removeListener(_follow);
    _anim.dispose();
    _tc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewport = constraints.biggest;
      final tc = _tc ??= _controllerFor(_viewport);
      return InteractiveViewer(
        transformationController: tc,
        constrained: false,
        minScale: 0.25,
        maxScale: 24,
        boundaryMargin: const EdgeInsets.all(200),
        onInteractionStart: (_) {
          // A user gesture wins over the decade animation and camera follow.
          _anim.stop();
          if (_playback?.active ?? false) _playback!.setFollow(false);
        },
        child: SizedBox(
          width: worldWidth,
          height: _worldHeight,
          child: ListenableBuilder(
            listenable: Listenable.merge([tc, ?_playback]),
            builder: (context, _) {
              final scale = tc.value.getMaxScaleOnAxis();
              final topLeft = tc.toScene(Offset.zero);
              final bottomRight = tc.toScene(
                _viewport.bottomRight(Offset.zero),
              );
              final visible = Rect.fromPoints(topLeft, bottomRight);
              final lod = lodForScale(scale);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ZoomAxisPainter(
                        scale: scale,
                        axisY: visible.top + 28 / scale,
                        bottomY: visible.bottom,
                        minYear: minYear,
                        maxYear: maxYear,
                        lod: lod,
                        labelStyle: Theme.of(context).textTheme.labelSmall!,
                        cursorX: _playback?.cursorYear == null
                            ? null
                            : _xFor(_playback!.cursorYear!),
                      ),
                    ),
                  ),
                  if (lod != ZoomLod.decades)
                    ..._laneLabels(context, scale, visible),
                  ...switch (lod) {
                    ZoomLod.decades => _decadeBubbles(context, scale),
                    ZoomLod.years => _yearDots(scale, visible),
                    ZoomLod.cards => _cards(context, scale, visible),
                  },
                ],
              );
            },
          ),
        ),
      );
    },
  );

  /// Wraps [child] so it renders at constant screen size anchored at [at].
  Widget _pin(
    Offset at,
    double scale,
    Widget child, {
    Key? key,
    Offset? anchor,
    double opacity = 1,
  }) => Positioned(
    key: key,
    left: at.dx,
    top: at.dy,
    child: Transform.scale(
      scale: 1 / scale,
      alignment: Alignment.topLeft,
      child: FractionalTranslation(
        translation: anchor ?? Offset.zero,
        child: opacity >= 1 ? child : Opacity(opacity: opacity, child: child),
      ),
    ),
  );

  bool _laneVisible(int lane, Rect visible) =>
      zoomLaneY(lane) + laneGap > visible.top &&
      zoomLaneY(lane) - laneGap * 0.25 < visible.bottom;

  List<Widget> _laneLabels(BuildContext context, double scale, Rect visible) {
    final lanes = familyLaneOrder(data.dataset);
    final style = Theme.of(context).textTheme.labelMedium;
    final left = math.max(0.0, visible.left) + 8 / scale;
    return [
      for (final (i, id) in lanes.indexed)
        if (_laneVisible(i, visible))
          _pin(
            key: ValueKey('lane-$id'),
            Offset(left, zoomLaneY(i) - _laneLabelExtent / scale),
            scale,
            Text(data.dataset.families[id]?.name ?? id, style: style),
          ),
    ];
  }

  List<Widget> _decadeBubbles(BuildContext context, double scale) {
    final counts = <int, ({int all, int matched})>{};
    for (final e in data.entries) {
      if (_reveal(e.story.id) == 0) continue;
      final c = counts[e.story.decade] ?? (all: 0, matched: 0);
      counts[e.story.decade] = (
        all: c.all + 1,
        matched: c.matched + (e.matched ? 1 : 0),
      );
    }
    final style = Theme.of(context).textTheme.labelMedium;
    return [
      for (final MapEntry(key: decade, value: c) in counts.entries)
        _pin(
          key: ValueKey('decade-$decade'),
          Offset(_xFor(decade + 5), _bubbleY),
          scale,
          anchor: const Offset(-0.5, -0.5),
          GestureDetector(
            key: Key('decade-bubble-$decade'),
            onTap: () => _zoomToDecade(decade),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2 * (8 + math.sqrt(c.all) * 3),
                  height: 2 * (8 + math.sqrt(c.all) * 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: labTerracotta.withValues(
                      alpha: c.matched > 0 ? 0.85 : labDimOpacity,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${decade}s · ${c.matched}', style: style),
              ],
            ),
          ),
        ),
    ];
  }

  /// Entries whose year lies in `[fromYear, toYear)`, by binary search on
  /// the ascending entries.
  Iterable<TimelineEntry> _entriesBetween(double fromYear, double toYear) {
    final entries = data.entries;
    int lowerBound(double y) {
      var lo = 0, hi = entries.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (entries[mid].story.fractionalYear < y) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo;
    }

    return entries.getRange(lowerBound(fromYear), lowerBound(toYear));
  }

  double _yearAt(double worldX) => worldX / _pxPerYear + minYear;

  List<Widget> _yearDots(double scale, Rect visible) {
    final lanes = familyLaneOrder(data.dataset);
    return [
      for (final e in _entriesBetween(
        _yearAt(visible.left) - 1,
        _yearAt(visible.right) + 1,
      ))
        if (_laneVisible(
              math.max(0, lanes.indexOf(e.story.familyId)),
              visible,
            ) &&
            _reveal(e.story.id) > 0)
          _pin(
            key: ValueKey(e.story.id),
            Offset(
              _xFor(e.story.fractionalYear),
              zoomLaneY(math.max(0, lanes.indexOf(e.story.familyId))),
            ),
            scale,
            anchor: const Offset(-0.5, -0.5),
            opacity: _reveal(e.story.id),
            GestureDetector(
              onTap: () => data.onSelect(e.story.id),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: markerColor(
                    e.story,
                    data.dataset,
                  ).withValues(alpha: entryOpacity(e)),
                  border: e.story.id == data.selectedId
                      ? Border.all(color: labInk, width: 2)
                      : null,
                ),
              ),
            ),
          ),
    ];
  }

  /// Greedy row packing per lane in screen px over **all** entries, so a
  /// card's row never depends on the pan position. Rows are capped to the
  /// lane band; what doesn't fit collapses into a `+N` chip on the last row.
  ({List<_Packed> cards, List<_Overflow> overflow}) _pack(double scale) {
    final lanes = familyLaneOrder(data.dataset);
    final cardRows = zoomRowsPerLane(scale) - 1;
    const cardGap = 8.0;
    const chipWidth = 56.0;
    final rowEnds = <int, List<double>>{};
    final open = <int, _Overflow>{};
    final cards = <_Packed>[];
    final overflow = <_Overflow>[];
    for (final e in data.entries) {
      final lane = math.max(0, lanes.indexOf(e.story.familyId));
      final x = _xFor(e.story.fractionalYear);
      final ends = rowEnds[lane] ??= [];
      var row = ends.indexWhere((end) => end <= x);
      if (row < 0 && ends.length < cardRows) row = ends.length;
      if (row >= 0) {
        final right = x + (StoryCard.width + cardGap) / scale;
        if (row == ends.length) {
          ends.add(right);
        } else {
          ends[row] = right;
        }
        cards.add((entry: e, lane: lane, row: row, x: x));
        continue;
      }
      var chip = open[lane];
      if (chip == null || x >= chip.end) {
        chip = open[lane] = _Overflow(lane, x, x + chipWidth / scale);
        overflow.add(chip);
      }
      chip.storyIds.add(e.story.id);
    }
    return (cards: cards, overflow: overflow);
  }

  List<Widget> _cards(BuildContext context, double scale, Rect visible) {
    final packed = _pack(scale);
    final chipRow = zoomRowsPerLane(scale) - 1;
    // Cards are anchored at their left edge, so include anything whose card
    // still reaches into view.
    final left = visible.left - (StoryCard.width + 8) / scale;
    bool inView(double x, int lane) =>
        x >= left - 1 && x <= visible.right + 1 && _laneVisible(lane, visible);

    final out = <Widget>[];
    for (final c in packed.cards) {
      final id = c.entry.story.id;
      final r = _reveal(id);
      if (r == 0 || !inView(c.x, c.lane)) continue;
      out.add(
        _pin(
          key: ValueKey(id),
          Offset(c.x, zoomLaneY(c.lane) + c.row * cardRowExtent / scale),
          scale,
          opacity: r,
          StoryCard(
            story: c.entry.story,
            dataset: data.dataset,
            matched: c.entry.matched,
            selected: id == data.selectedId,
            compact: true,
            onTap: () => data.onSelect(id),
          ),
        ),
      );
    }
    final chipStyle = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: labParchment);
    for (final chip in packed.overflow) {
      if (!inView(chip.x, chip.lane)) continue;
      final shown = [
        for (final id in chip.storyIds)
          if (_reveal(id) > 0) id,
      ];
      if (shown.isEmpty) continue;
      out.add(
        _pin(
          key: ValueKey('overflow-${chip.storyIds.first}'),
          Offset(
            chip.x,
            zoomLaneY(chip.lane) + chipRow * cardRowExtent / scale,
          ),
          scale,
          GestureDetector(
            key: Key('zoom-overflow-${chip.storyIds.first}'),
            onTap: () {
              final i = shown.indexOf(data.selectedId ?? '');
              data.onSelect(shown[(i + 1) % shown.length]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: labInk,
                borderRadius: BorderRadius.circular(labCardRadius),
              ),
              child: Text('+${shown.length}', style: chipStyle),
            ),
          ),
        ),
      );
    }
    return out;
  }
}

class _ZoomAxisPainter extends CustomPainter {
  _ZoomAxisPainter({
    required this.scale,
    required this.axisY,
    required this.bottomY,
    required this.minYear,
    required this.maxYear,
    required this.lod,
    required this.labelStyle,
    required this.cursorX,
  });

  final double scale;

  /// World y of the baseline; tracks the viewport top so the axis stays
  /// on screen at every zoom.
  final double axisY;

  /// World y of the viewport bottom (cursor line end).
  final double bottomY;
  final int minYear;
  final int maxYear;
  final ZoomLod lod;
  final TextStyle labelStyle;

  /// World x of the playback cursor, or null when idle.
  final double? cursorX;

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(1 / scale);
    tp.paint(canvas, Offset(2, -tp.height - 2));
    canvas.restore();
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = labInk.withValues(alpha: 0.6)
      ..strokeWidth = 1 / scale;
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), paint);
    for (var y = minYear; y <= maxYear + 1; y++) {
      final x = (y - minYear) * _pxPerYear;
      final decade = y % 10 == 0;
      if (decade) {
        canvas.drawLine(Offset(x, axisY), Offset(x, axisY + 12 / scale), paint);
        _label(canvas, '$y', Offset(x, axisY));
        continue;
      }
      if (lod == ZoomLod.decades) continue;
      canvas.drawLine(Offset(x, axisY), Offset(x, axisY + 6 / scale), paint);
      if (_pxPerYear * scale >= 48) _label(canvas, '$y', Offset(x, axisY));
    }
    if (lod == ZoomLod.cards) {
      for (var y = minYear; y <= maxYear; y++) {
        for (var m = 1; m < 12; m++) {
          final x = (y - minYear + m / 12) * _pxPerYear;
          canvas.drawLine(
            Offset(x, axisY),
            Offset(x, axisY + 3 / scale),
            paint,
          );
        }
      }
    }
    final cx = cursorX;
    if (cx != null) {
      canvas.drawLine(
        Offset(cx, axisY - 4 / scale),
        Offset(cx, bottomY),
        Paint()
          ..color = labTerracotta
          ..strokeWidth = 2 / scale,
      );
    }
  }

  @override
  bool shouldRepaint(_ZoomAxisPainter old) =>
      old.scale != scale ||
      old.axisY != axisY ||
      old.bottomY != bottomY ||
      old.minYear != minYear ||
      old.maxYear != maxYear ||
      old.lod != lod ||
      old.labelStyle != labelStyle ||
      old.cursorX != cursorX;
}
