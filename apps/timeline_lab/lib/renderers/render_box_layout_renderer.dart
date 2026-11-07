import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../playback/playback_controller.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
import '../widgets/story_card.dart';
import 'renderer_contract.dart';
import 'time_axis_painter.dart';
import 'time_scale.dart';

enum AxisSide { left, right }

/// C: real widget cards at time-proportional y on a vertical axis, newest at
/// the top, with per-side collision avoidance. Not lazy: every card is built.
class RenderBoxTimeline extends StatefulWidget {
  const RenderBoxTimeline({super.key, required this.data});

  final TimelineViewData data;

  @override
  State<RenderBoxTimeline> createState() => _RenderBoxTimelineState();
}

class _RenderBoxTimelineState extends State<RenderBoxTimeline> {
  final _scroll = ScrollController();
  final _registry = StoryContextRegistry();
  FollowCurrentStory? _follow;

  /// Side per story from its position in the whole dataset, so filtering
  /// or toggling hide/dim never flips a card to the other side.
  late Map<String, AxisSide> _sideOf;

  @override
  void initState() {
    super.initState();
    _indexSides();
    _attach();
    // Start with the newest matched card near the top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.data.newestMatched?.id;
      final ctx = id == null ? null : _registry[id];
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(ctx, alignment: 0.05);
    });
  }

  @override
  void didUpdateWidget(RenderBoxTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(old.data.dataset, widget.data.dataset)) _indexSides();
    if (old.data.playback != widget.data.playback) {
      _follow?.dispose();
      _attach();
    }
  }

  void _indexSides() {
    final stories = widget.data.dataset.stories;
    _sideOf = {
      for (final (i, s) in stories.indexed)
        s.id: (stories.length - 1 - i).isEven ? AxisSide.left : AxisSide.right,
    };
  }

  void _attach() {
    final pb = widget.data.playback;
    _follow = pb == null
        ? null
        : FollowCurrentStory(
            playback: pb,
            registry: _registry,
            scroll: _scroll,
            // Every card is built, so the estimate is never used.
            estimateFraction: (_) => 0,
          );
  }

  @override
  void dispose() {
    _follow?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return NotificationListener<ScrollStartNotification>(
      onNotification: (n) => disableFollowOnUserScroll(n, data.playback),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: TimeAxisLayout(
          minYear: data.dataset.minYear,
          maxYear: data.dataset.maxYear,
          labelStyle: LabText.axis(Theme.of(context).textTheme),
          playback: data.playback,
          children: [
            for (final e in data.entries.reversed)
              TimeSlot(
                storyId: e.story.id,
                yearFraction: e.story.fractionalYear,
                side: _sideOf[e.story.id] ?? AxisSide.left,
                // Repaint boundary: playback repaints the axis every tick
                // without repainting thousands of cards.
                child: RepaintBoundary(
                  child: RegisterStory(
                    registry: _registry,
                    storyId: e.story.id,
                    child: RevealOpacity(
                      playback: data.playback,
                      storyId: e.story.id,
                      child: StoryCard(
                        story: e.story,
                        dataset: data.dataset,
                        matched: e.matched,
                        selected: e.story.id == data.selectedId,
                        compact: true,
                        onTap: () => data.onSelect(e.story.id),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TimeAxisParentData extends ContainerBoxParentData<RenderBox> {
  String storyId = '';
  double yearFraction = 0;
  AxisSide side = AxisSide.left;

  /// Axis y the child belongs at; set during layout.
  double idealY = 0;
}

class TimeSlot extends ParentDataWidget<TimeAxisParentData> {
  const TimeSlot({
    super.key,
    required this.storyId,
    required this.yearFraction,
    required this.side,
    required super.child,
  });

  final String storyId;
  final double yearFraction;
  final AxisSide side;

  @override
  void applyParentData(RenderObject renderObject) {
    final pd = renderObject.parentData! as TimeAxisParentData;
    pd.storyId = storyId;
    if (pd.yearFraction == yearFraction && pd.side == side) return;
    pd
      ..yearFraction = yearFraction
      ..side = side;
    final target = renderObject.parent;
    if (target is RenderObject) target.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => TimeAxisLayout;
}

class TimeAxisLayout extends MultiChildRenderObjectWidget {
  const TimeAxisLayout({
    super.key,
    required this.minYear,
    required this.maxYear,
    required this.labelStyle,
    this.playback,
    this.pxPerYear = 80,
    this.gap = 8,
    super.children,
  });

  final int minYear;
  final int maxYear;
  final double pxPerYear;
  final double gap;
  final TextStyle labelStyle;
  final PlaybackController? playback;

  @override
  RenderTimeAxisLayout createRenderObject(BuildContext context) =>
      RenderTimeAxisLayout(
        minYear: minYear,
        maxYear: maxYear,
        pxPerYear: pxPerYear,
        gap: gap,
        labelStyle: labelStyle,
      )..playback = playback;

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTimeAxisLayout renderObject,
  ) {
    renderObject
      ..minYear = minYear
      ..maxYear = maxYear
      ..pxPerYear = pxPerYear
      ..gap = gap
      ..labelStyle = labelStyle
      ..playback = playback;
  }
}

class RenderTimeAxisLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TimeAxisParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TimeAxisParentData> {
  RenderTimeAxisLayout({
    required this._minYear,
    required this._maxYear,
    required this._pxPerYear,
    required this._gap,
    required this._labelStyle,
  });

  int _minYear;
  int get minYear => _minYear;
  set minYear(int v) {
    if (v == _minYear) return;
    _minYear = v;
    markNeedsLayout();
  }

  int _maxYear;
  int get maxYear => _maxYear;
  set maxYear(int v) {
    if (v == _maxYear) return;
    _maxYear = v;
    markNeedsLayout();
  }

  double _pxPerYear;
  double get pxPerYear => _pxPerYear;
  set pxPerYear(double v) {
    if (v == _pxPerYear) return;
    _pxPerYear = v;
    markNeedsLayout();
  }

  double _gap;
  double get gap => _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  TextStyle _labelStyle;
  TextStyle get labelStyle => _labelStyle;
  set labelStyle(TextStyle v) {
    if (v == _labelStyle) return;
    _labelStyle = v;
    markNeedsPaint();
  }

  double _axisX = 0;

  PlaybackController? _playback;
  PlaybackController? get playback => _playback;

  /// Playback ticks only repaint (connectors + cursor); layout never changes.
  set playback(PlaybackController? v) {
    if (v == _playback) return;
    if (attached) _playback?.removeListener(markNeedsPaint);
    _playback = v;
    if (attached) _playback?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _playback?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _playback?.removeListener(markNeedsPaint);
    super.detach();
  }

  TimeScale get _scale => TimeScale(
    minYear: minYear,
    maxYear: maxYear,
    pxPerYear: pxPerYear,
    newestFirst: true,
  );

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TimeAxisParentData) {
      child.parentData = TimeAxisParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(
      debugCannotComputeDryLayout(
        reason: 'Card positions depend on laid-out child heights.',
      ),
    );
    return Size.zero;
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth, 'TimeAxisLayout needs a bounded width');
    final width = constraints.maxWidth;
    _axisX = width / 2;
    final childConstraints = BoxConstraints(maxWidth: math.max(0, _axisX - 32));
    final lastBottom = {AxisSide.left: -gap, AxisSide.right: -gap};
    var maxBottom = 0.0;

    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as TimeAxisParentData;
      child.layout(childConstraints, parentUsesSize: true);
      final h = child.size.height;
      pd.idealY = _scale.toPx(pd.yearFraction);
      final y = math.max(pd.idealY - h / 2, lastBottom[pd.side]! + gap);
      final x = pd.side == AxisSide.left
          ? _axisX - 16 - child.size.width
          : _axisX + 16;
      pd.offset = Offset(x, y);
      lastBottom[pd.side] = y + h;
      maxBottom = math.max(maxBottom, y + h);
      child = pd.nextSibling;
    }

    size = constraints.constrain(
      Size(width, math.max(_scale.span, maxBottom) + 24),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final scale = _scale;
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    // docs/ux/uxd-handoff.md R3: a solid 2 px line runs through the centre.
    paintTimeAxis(
      canvas,
      scale,
      direction: Axis.vertical,
      cross: _axisX,
      labelStyle: labelStyle,
      labels: false,
      side: TickSide.both,
      spineWidth: LabStroke.mark,
    );

    final connector = Paint()..strokeWidth = LabStroke.hairline;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as TimeAxisParentData;
      final r = _playback?.reveal(pd.storyId) ?? 1;
      if (r > 0) {
        connector.color = labRule.withValues(alpha: labRule.a * r);
        final from = Offset(_axisX, pd.idealY);
        final edgeX = pd.side == AxisSide.left
            ? pd.offset.dx + child.size.width
            : pd.offset.dx;
        canvas
          ..drawLine(
            from,
            Offset(edgeX, pd.offset.dy + child.size.height / 2),
            connector,
          )
          ..drawCircle(from, 2, connector);
      }
      child = pd.nextSibling;
    }

    final cursor = _playback?.cursorYear;
    if (cursor != null) {
      final cy = scale.toPx(cursor);
      paintPlaybackCursor(canvas, Offset(0, cy), Offset(size.width, cy));
    }
    canvas.restore();

    defaultPaint(context, offset);

    // Decade pills go last, so cards never cover them. Children may have
    // pushed layers, so re-read the canvas.
    final top = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    paintSpineLabels(top, scale, spineX: _axisX, labelStyle: labelStyle);
    top.restore();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
