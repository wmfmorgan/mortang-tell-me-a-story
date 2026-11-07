import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../filter/timeline_filter.dart';
import '../model/lab_models.dart';
import '../playback/playback_controller.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
import '../widgets/story_chooser.dart';
import '../widgets/view_switch.dart';
import 'renderer_contract.dart';
import 'story_marker.dart';
import 'time_scale.dart';

enum LaneBy { person, family }

const _colWidth = 96.0;
const _rowHeight = 72.0;
const _laneLabelWidth = 120.0;
const _yearStripHeight = 32.0;
const untaggedLane = 'Untagged';

/// Lane keys in row order: person ids then [untaggedLane], or family ids.
List<String> laneKeys(LabDataset d, LaneBy by) => switch (by) {
  LaneBy.person => [...(d.people.keys.toList()..sort()), untaggedLane],
  LaneBy.family => familyLaneOrder(d),
};

String laneLabel(LabDataset d, String key) =>
    d.people[key]?.name ?? d.families[key]?.name ?? key;

/// Buckets entries into (row, col) cells. Columns are years from
/// `d.minYear`. A story with k people lands in k person lanes.
Map<(int, int), List<TimelineEntry>> bucketLanes(
  List<TimelineEntry> entries,
  LabDataset d,
  LaneBy by,
) {
  final rowOf = {for (final (i, k) in laneKeys(d, by).indexed) k: i};
  final out = <(int, int), List<TimelineEntry>>{};
  void add(String key, TimelineEntry e) {
    final row = rowOf[key];
    if (row == null) return;
    (out[(row, e.story.start.year - d.minYear)] ??= []).add(e);
  }

  for (final e in entries) {
    switch (by) {
      case LaneBy.person:
        if (e.story.personIds.isEmpty) {
          add(untaggedLane, e);
        } else {
          for (final p in e.story.personIds) {
            add(p, e);
          }
        }
      case LaneBy.family:
        add(e.story.familyId, e);
    }
  }
  return out;
}

/// E: year × lane grid on a custom `TwoDimensionalScrollView`; only visible
/// cells (plus cache extent) are built.
class SwimlanesTimeline extends StatefulWidget {
  const SwimlanesTimeline({super.key, required this.data});

  final TimelineViewData data;

  @override
  State<SwimlanesTimeline> createState() => _SwimlanesTimelineState();
}

class _SwimlanesTimelineState extends State<SwimlanesTimeline> {
  LaneBy _laneBy = LaneBy.person;
  final _hCtl = ScrollController();
  final _vCtl = ScrollController();
  final _yearCtl = ScrollController();
  final _laneCtl = ScrollController();

  PlaybackController? get _playback => widget.data.playback;

  @override
  void initState() {
    super.initState();
    _hCtl.addListener(() {
      if (_yearCtl.hasClients) _yearCtl.jumpTo(_hCtl.offset);
    });
    _vCtl.addListener(() {
      if (_laneCtl.hasClients) _laneCtl.jumpTo(_vCtl.offset);
    });
    _playback?.addListener(_follow);
    // Start with the newest matched story's year near the right edge.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newest = widget.data.newestMatched;
      if (!mounted || !_hCtl.hasClients || newest == null) return;
      final right = _scale.toPx(newest.start.year + 1.0);
      _hCtl.jumpTo(scrollOffsetToPlace(right, _hCtl.position, 1));
    });
  }

  @override
  void didUpdateWidget(SwimlanesTimeline old) {
    super.didUpdateWidget(old);
    if (old.data.playback != _playback) {
      old.data.playback?.removeListener(_follow);
      _playback?.addListener(_follow);
    }
  }

  TimeScale get _scale => TimeScale(
    minYear: widget.data.dataset.minYear,
    maxYear: widget.data.dataset.maxYear,
    pxPerYear: _colWidth,
  );

  /// Camera follow: keep the cursor column at 65% of the grid width.
  void _follow() {
    final pb = _playback!;
    final year = pb.cursorYear;
    if (!pb.follow || year == null || !_hCtl.hasClients) return;
    _hCtl.jumpTo(
      scrollOffsetToPlace(_scale.toPx(year), _hCtl.position, kFollowAt),
    );
  }

  @override
  void dispose() {
    _playback?.removeListener(_follow);
    _hCtl.dispose();
    _vCtl.dispose();
    _yearCtl.dispose();
    _laneCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data.dataset;
    final lanes = laneKeys(d, _laneBy);
    final cols = d.maxYear - d.minYear + 1;
    final buckets = bucketLanes(widget.data.entries, d, _laneBy);
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ViewSwitch<LaneBy>(
          switchKey: const Key('lane-by'),
          label: 'Lanes',
          values: LaneBy.values,
          labelOf: (v) => switch (v) {
            LaneBy.person => 'Person',
            LaneBy.family => 'Family',
          },
          selected: _laneBy,
          onChanged: (v) => setState(() => _laneBy = v),
        ),
        Row(
          children: [
            const SizedBox(width: _laneLabelWidth),
            Expanded(
              child: SizedBox(
                height: _yearStripHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _yearCtl,
                  itemExtent: _colWidth,
                  itemCount: cols,
                  itemBuilder: (context, i) => Center(
                    child: Text('${d.minYear + i}', style: LabText.axis(theme)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: _laneLabelWidth,
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _laneCtl,
                  itemExtent: _rowHeight,
                  itemCount: lanes.length,
                  itemBuilder: (context, i) => Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: labBorder)),
                    ),
                    child: Text(
                      laneLabel(d, lanes[i]),
                      style: LabText.lane(theme),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (n) =>
                      disableFollowOnUserScroll(n, _playback),
                  child: Stack(
                    children: [
                      LaneGridView(
                        colWidth: _colWidth,
                        rowHeight: _rowHeight,
                        diagonalDragBehavior: DiagonalDragBehavior.free,
                        horizontalDetails: ScrollableDetails.horizontal(
                          controller: _hCtl,
                        ),
                        verticalDetails: ScrollableDetails.vertical(
                          controller: _vCtl,
                        ),
                        delegate: TwoDimensionalChildBuilderDelegate(
                          maxXIndex: cols - 1,
                          maxYIndex: lanes.length - 1,
                          builder: (context, vicinity) => LaneCell(
                            entries:
                                buckets[(vicinity.yIndex, vicinity.xIndex)] ??
                                const [],
                            data: widget.data,
                          ),
                        ),
                      ),
                      if (_playback != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CursorPainter(
                                playback: _playback!,
                                scroll: _hCtl,
                                xForYear: (y) => _scale.toPx(y),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cursor column line, repainted from playback and horizontal scroll
/// without rebuilding the grid.
class _CursorPainter extends CustomPainter {
  _CursorPainter({
    required this.playback,
    required this.scroll,
    required this.xForYear,
  }) : super(repaint: Listenable.merge([playback, scroll]));

  final PlaybackController playback;
  final ScrollController scroll;
  final double Function(double year) xForYear;

  @override
  void paint(Canvas canvas, Size size) {
    final year = playback.cursorYear;
    if (year == null || !scroll.hasClients) return;
    final x = xForYear(year) - scroll.offset;
    if (x < 0 || x > size.width) return;
    paintPlaybackCursor(canvas, Offset(x, 0), Offset(x, size.height));
  }

  @override
  bool shouldRepaint(_CursorPainter old) =>
      old.playback != playback || old.scroll != scroll;
}

class LaneCell extends StatelessWidget {
  const LaneCell({super.key, required this.entries, required this.data});

  static const maxDots = 4;

  final List<TimelineEntry> entries;
  final TimelineViewData data;

  @override
  Widget build(BuildContext context) {
    final playback = data.playback;
    if (playback == null || entries.isEmpty) {
      return _build(context, entries, (_) => 1);
    }
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) => _build(context, [
        for (final e in entries)
          if (playback.reveal(e.story.id) > 0) e,
      ], (e) => playback.reveal(e.story.id)),
    );
  }

  /// [shown] are the revealed entries; counts and the single-title form use
  /// only those, so a cell never leaks stories the cursor hasn't reached.
  Widget _build(
    BuildContext context,
    List<TimelineEntry> shown,
    double Function(TimelineEntry) reveal,
  ) {
    final selected = shown.any((e) => e.story.id == data.selectedId);
    Widget content;
    if (shown.isEmpty) {
      content = const SizedBox.shrink();
    } else if (shown.length == 1) {
      final e = shown.single;
      content = Opacity(
        opacity: reveal(e),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: StoryDot(
                spec: MarkerSpec(matched: e.matched, diameter: LabMarker.small),
                reserveRings: false,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                e.story.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: e.matched ? labInk : labDimmedInk),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final e in shown.take(maxDots))
            Opacity(
              opacity: reveal(e),
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: StoryDot(
                  spec: MarkerSpec(
                    matched: e.matched,
                    diameter: LabMarker.small,
                  ),
                  reserveRings: false,
                ),
              ),
            ),
          if (shown.length > maxDots)
            Text(
              '+${shown.length - maxDots}',
              style: LabText.count(Theme.of(context).textTheme),
            ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: shown.isEmpty
          ? null
          : (details) => _onTapUp(context, details, shown),
      child: Container(
        padding: const EdgeInsets.all(LabSpace.s),
        decoration: BoxDecoration(
          color: selected ? labPillFill : null,
          border: Border(
            right: const BorderSide(color: labBorder),
            bottom: const BorderSide(color: labBorder),
            left: selected
                ? const BorderSide(color: labTerracotta, width: 2)
                : BorderSide.none,
          ),
        ),
        child: content,
      ),
    );
  }

  /// One story selects directly. Several open the chooser, so no story in
  /// the cell is unreachable (F6).
  Future<void> _onTapUp(
    BuildContext context,
    TapUpDetails details,
    List<TimelineEntry> shown,
  ) async {
    if (shown.length == 1) {
      data.onSelect(shown.single.story.id);
      return;
    }
    final id = await showStoryChooser(
      context,
      globalPosition: details.globalPosition,
      stories: [for (final e in shown) e.story],
      dataset: data.dataset,
    );
    if (id != null) data.onSelect(id);
  }
}

class LaneGridView extends TwoDimensionalScrollView {
  const LaneGridView({
    super.key,
    super.primary,
    super.mainAxis,
    super.verticalDetails,
    super.horizontalDetails,
    required TwoDimensionalChildBuilderDelegate super.delegate,
    super.scrollCacheExtent,
    super.diagonalDragBehavior,
    super.dragStartBehavior = DragStartBehavior.start,
    super.keyboardDismissBehavior,
    super.clipBehavior,
    required this.colWidth,
    required this.rowHeight,
  });

  final double colWidth;
  final double rowHeight;

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset verticalOffset,
    ViewportOffset horizontalOffset,
  ) => LaneGridViewport(
    horizontalOffset: horizontalOffset,
    horizontalAxisDirection: horizontalDetails.direction,
    verticalOffset: verticalOffset,
    verticalAxisDirection: verticalDetails.direction,
    mainAxis: mainAxis,
    delegate: delegate,
    scrollCacheExtent: scrollCacheExtent,
    clipBehavior: clipBehavior,
    colWidth: colWidth,
    rowHeight: rowHeight,
  );
}

class LaneGridViewport extends TwoDimensionalViewport {
  const LaneGridViewport({
    super.key,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    super.scrollCacheExtent,
    super.clipBehavior = Clip.hardEdge,
    required this.colWidth,
    required this.rowHeight,
  });

  final double colWidth;
  final double rowHeight;

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) =>
      RenderLaneGridViewport(
        horizontalOffset: horizontalOffset,
        horizontalAxisDirection: horizontalAxisDirection,
        verticalOffset: verticalOffset,
        verticalAxisDirection: verticalAxisDirection,
        mainAxis: mainAxis,
        delegate: delegate,
        childManager: context as TwoDimensionalChildManager,
        scrollCacheExtent: scrollCacheExtent,
        clipBehavior: clipBehavior,
        colWidth: colWidth,
        rowHeight: rowHeight,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLaneGridViewport renderObject,
  ) {
    renderObject
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..mainAxis = mainAxis
      ..delegate = delegate
      ..scrollCacheExtent = scrollCacheExtent
      ..clipBehavior = clipBehavior
      ..colWidth = colWidth
      ..rowHeight = rowHeight;
  }
}

class RenderLaneGridViewport extends RenderTwoDimensionalViewport {
  RenderLaneGridViewport({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.delegate,
    required super.mainAxis,
    required super.childManager,
    super.scrollCacheExtent,
    super.clipBehavior = Clip.hardEdge,
    required this._colWidth,
    required this._rowHeight,
  });

  double _colWidth;
  double get colWidth => _colWidth;
  set colWidth(double v) {
    if (v == _colWidth) return;
    _colWidth = v;
    markNeedsLayout();
  }

  double _rowHeight;
  double get rowHeight => _rowHeight;
  set rowHeight(double v) {
    if (v == _rowHeight) return;
    _rowHeight = v;
    markNeedsLayout();
  }

  @override
  void layoutChildSequence() {
    final builder = delegate as TwoDimensionalChildBuilderDelegate;
    final maxX = builder.maxXIndex!;
    final maxY = builder.maxYIndex!;
    final hPixels = horizontalOffset.pixels;
    final vPixels = verticalOffset.pixels;

    int clampIndex(int i, int max) => i < 0 ? 0 : (i > max ? max : i);
    double cachePx(double extent) =>
        scrollCacheExtent.style == CacheExtentStyle.pixel
        ? scrollCacheExtent.value
        : scrollCacheExtent.value * extent;

    // The cache extent applies on both sides so the first scroll back
    // (left/up) hits pre-built cells.
    final firstCol = clampIndex(
      ((hPixels - cachePx(viewportDimension.width)) / colWidth).floor(),
      maxX,
    );
    final lastCol = clampIndex(
      ((hPixels + viewportDimension.width + cachePx(viewportDimension.width)) /
              colWidth)
          .ceil(),
      maxX,
    );
    final firstRow = clampIndex(
      ((vPixels - cachePx(viewportDimension.height)) / rowHeight).floor(),
      maxY,
    );
    final lastRow = clampIndex(
      ((vPixels +
                  viewportDimension.height +
                  cachePx(viewportDimension.height)) /
              rowHeight)
          .ceil(),
      maxY,
    );

    final cellConstraints = BoxConstraints.tight(Size(colWidth, rowHeight));
    if (maxX >= 0 && maxY >= 0) {
      for (var c = firstCol; c <= lastCol; c++) {
        for (var r = firstRow; r <= lastRow; r++) {
          final vicinity = ChildVicinity(xIndex: c, yIndex: r);
          final child = buildOrObtainChildFor(vicinity);
          if (child == null) continue;
          child.layout(cellConstraints);
          parentDataOf(child).layoutOffset = Offset(
            c * colWidth - hPixels,
            r * rowHeight - vPixels,
          );
        }
      }
    }

    verticalOffset.applyContentDimensions(
      0,
      math.max(0, (maxY + 1) * rowHeight - viewportDimension.height),
    );
    horizontalOffset.applyContentDimensions(
      0,
      math.max(0, (maxX + 1) * colWidth - viewportDimension.width),
    );
  }
}
