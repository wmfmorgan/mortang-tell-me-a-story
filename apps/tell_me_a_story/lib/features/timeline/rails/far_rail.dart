import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';
import 'package:tell_me_a_story/features/timeline/rails/rail_scaffold.dart';
import 'package:tell_me_a_story/features/timeline/zoom_switch.dart';

class FarRail extends StatefulWidget {
  const FarRail({
    super.key,
    required this.bands,
    required this.focusedId,
    required this.branching,
    this.originStoryId,
    required this.onDot,
    required this.onEmpty,
    required this.onYear,
    required this.onFocus,
    required this.onOpenBranch,
    required this.onMid,
    required this.onFullCards,
  });

  final List<DecadeBand> bands;
  final String? focusedId;
  final RailBranching branching;
  final String? originStoryId;
  final ValueChanged<Story> onDot;
  final VoidCallback onEmpty;
  final ValueChanged<int> onYear;
  final ValueChanged<String> onFocus;
  final ValueChanged<String> onOpenBranch;
  final VoidCallback onMid;
  final VoidCallback onFullCards;

  @override
  State<FarRail> createState() => _FarRailState();
}

class _FarRailState extends State<FarRail> {
  final _viewportKey = GlobalKey();
  final _scroll = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  int? _centerYear;
  Map<int, double> _opacities = const {};
  var _centered = false;

  GlobalKey _rowKey(int year) => _rowKeys.putIfAbsent(year, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _centerYear = _yearOf(widget.focusedId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerInitial());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final bands = widget.bands;
    if (bands.isEmpty) return;
    final current = _centerYear ?? bands[bands.length ~/ 2].startYear;
    var index = bands.indexWhere((band) => band.startYear == current);
    if (index < 0) index = 0;
    final next = index + direction;
    final target = next < 0 || next >= bands.length
        ? null
        : _rowKey(bands[next].startYear).currentContext;
    scrollDialStep(controller: _scroll, direction: direction, target: target);
  }

  @override
  void didUpdateWidget(covariant FarRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final year = _yearOf(widget.focusedId);
    if (year != null &&
        year != _yearOf(oldWidget.focusedId) &&
        year != _centerYear) {
      _centerYear = year;
      _centerOn(year);
    }
  }

  int? _yearOf(String? id) {
    if (id == null) return null;
    for (final band in widget.bands) {
      for (final story in band.stories) {
        if (story.id == id) return band.startYear;
      }
    }
    return null;
  }

  Story? _highlight(DecadeBand band) {
    for (final story in band.stories) {
      if (story.id == widget.focusedId) return story;
    }
    if (band.stories.isEmpty) return null;
    return band.stories[band.stories.length ~/ 2];
  }

  void _centerInitial() {
    if (!mounted || _centered || widget.bands.isEmpty) return;
    _centered = true;
    final year =
        _centerYear ?? widget.bands[widget.bands.length ~/ 2].startYear;
    _centerYear = year;
    _centerOn(year);
  }

  void _centerOn(int year) {
    final target = _rowKey(year).currentContext;
    if (target == null || !target.mounted) return;
    Scrollable.ensureVisible(target, alignment: 0.5, duration: Duration.zero);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final centerY = viewportTop + viewport.size.height / 2;
    int? bestYear;
    var best = double.infinity;
    final opacities = <int, double>{};
    for (final band in widget.bands) {
      final row =
          _rowKey(band.startYear).currentContext?.findRenderObject()
              as RenderBox?;
      if (row == null || !row.hasSize) continue;
      final rowTop = row.localToGlobal(Offset.zero).dy;
      final mid = rowTop + row.size.height / 2;
      final distance = (mid - centerY).abs();
      opacities[band.startYear] = farEdgeOpacity(
        rowTop: rowTop,
        rowHeight: row.size.height,
        viewportTop: viewportTop,
        viewportHeight: viewport.size.height,
      );
      if (distance < best) {
        best = distance;
        bestYear = band.startYear;
      }
    }
    final yearChanged = bestYear != null && bestYear != _centerYear;
    if (!yearChanged && _sameOpacity(opacities)) return;
    setState(() {
      if (bestYear != null) _centerYear = bestYear;
      _opacities = opacities;
    });
    DecadeBand? band;
    for (final candidate in widget.bands) {
      if (candidate.startYear == bestYear) band = candidate;
    }
    final story = band == null ? null : _highlight(band);
    final id = story?.id;
    if (!yearChanged) return;
    if (id != null && id != widget.focusedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && id != widget.focusedId) widget.onFocus(id);
      });
    }
  }

  bool _sameOpacity(Map<int, double> next) {
    if (next.length != _opacities.length) return false;
    for (final entry in next.entries) {
      final previous = _opacities[entry.key];
      if (previous == null || (previous - entry.value).abs() > 0.01) {
        return false;
      }
    }
    return true;
  }

  List<Widget> _farChildren() {
    return [
      for (final band in widget.bands)
        _FarDecadeRow(
          key: _rowKey(band.startYear),
          band: band,
          branching: widget.branching,
          originStoryId: widget.originStoryId,
          onOpenBranch: widget.onOpenBranch,
          focused: band.startYear == _centerYear,
          opacity: _opacities[band.startYear] ?? 1,
          highlight: _highlight(band),
          onDot: widget.onDot,
          onYear: widget.onYear,
        ),
    ];
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
              selected: TimelineZoom.far,
              onMacro: () {},
              onMid: widget.onMid,
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
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            width: 2,
                            child: ColoredBox(color: albumRule),
                          ),
                        ),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final pad = constraints.maxHeight / 2;
                        return ListView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                          children: _farChildren(),
                        );
                      },
                    ),
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

class _FarDecadeRow extends StatelessWidget {
  const _FarDecadeRow({
    super.key,
    required this.band,
    required this.focused,
    required this.opacity,
    required this.highlight,
    required this.branching,
    this.originStoryId,
    required this.onDot,
    required this.onYear,
    required this.onOpenBranch,
  });

  final DecadeBand band;
  final bool focused;
  final double opacity;
  final Story? highlight;
  final RailBranching branching;
  final String? originStoryId;
  final ValueChanged<Story> onDot;
  final ValueChanged<int> onYear;
  final ValueChanged<String> onOpenBranch;

  @override
  Widget build(BuildContext context) {
    final stories = band.stories;
    final count = countWord(band.stories.length, 'story', 'stories');
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: Key('timeline-decade-${band.startYear}'),
            onTap: () => onYear(band.startYear),
            child: Text(
              band.label,
              style: focused
                  ? Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                  : Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (focused)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: albumTerracotta,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              focused ? '$count preserved' : count,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: focused
                    ? albumTerracotta
                    : albumInk.withValues(alpha: 0.6),
                fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
    final plain = <Widget>[];
    final branched = <Widget>[];
    for (final story in stories) {
      final frame = branching.frameFor(story);
      final highlighted = focused && story.id == highlight?.id;
      final origin = story.id == originStoryId;
      if (frame.parent != null) {
        branched.add(
          _farParent(context, frame, highlighted: highlighted, origin: origin),
        );
      } else if (frame.branchesStory) {
        branched.add(
          _farBranch(context, frame, highlighted: highlighted, origin: origin),
        );
      } else {
        final dot = _FarDot(
          story: story,
          highlighted: highlighted,
          origin: origin,
          onTap: () => onDot(story),
        );
        plain.add(
          origin ? _OriginDot(highlighted: highlighted, child: dot) : dot,
        );
      }
    }
    final dots = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [...plain, ...branched],
        ),
      ],
    );
    return Opacity(
      opacity: opacity,
      child: Padding(
        key: Key('timeline-decade-row-${band.startYear}'),
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: label),
            ),
            SizedBox(
              width: 48,
              child: GestureDetector(
                key: Key('timeline-decade-node-${band.startYear}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onYear(band.startYear),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Center(
                    child: Container(
                      width: focused ? 28 : 14,
                      height: focused ? 28 : 14,
                      decoration: BoxDecoration(
                        color: focused
                            ? albumTerracotta.withValues(alpha: 0.2)
                            : albumDialogSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: focused
                              ? albumTerracotta
                              : albumInk.withValues(alpha: 0.35),
                          width: focused ? 1.5 : 2,
                        ),
                      ),
                      child: focused
                          ? Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: albumTerracotta,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: dots,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _farParent(
    BuildContext context,
    StoryFrame frame, {
    required bool highlighted,
    required bool origin,
  }) {
    final story = frame.story;
    final mark = decadeParentMark(
      context: context,
      frame: frame,
      dot: _FarDot(
        story: story,
        highlighted: highlighted,
        origin: origin,
        onTap: () => onDot(story),
      ),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: calloutLabelWidthFar,
      onOpen: onOpenBranch,
    );
    return _CenterOnDot(
      dotExtent: calloutHit,
      dotTop: mark.dotTop,
      child: mark.child,
    );
  }

  Widget _farBranch(
    BuildContext context,
    StoryFrame frame, {
    required bool highlighted,
    required bool origin,
  }) {
    final story = frame.story;
    final placed = placeBranchCallout(
      context: context,
      frame: frame,
      side: CalloutSide.right,
      dot: _FarDot(
        story: story,
        highlighted: highlighted,
        origin: origin,
        onTap: () => onDot(story),
      ),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: calloutLabelWidthFar,
      onOpen: onOpenBranch,
    );
    return _CenterOnDot(
      dotExtent: calloutHit,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          BranchCalloutTarget(
            frame: frame,
            onOpen: onOpenBranch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: calloutHit,
                  height: calloutHit,
                  child: placed.ringHit,
                ),
                placed.lane,
              ],
            ),
          ),
          placed.dot,
        ],
      ),
    );
  }
}

class _CenterOnDot extends SingleChildRenderObjectWidget {
  const _CenterOnDot({
    required this.dotExtent,
    this.dotTop = 0,
    required super.child,
  });

  final double dotExtent;

  /// Where the dot box starts in the child. Zero when the callout hangs below.
  final double dotTop;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCenterOnDot(dotExtent, dotTop);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCenterOnDot renderObject,
  ) {
    renderObject
      ..dotExtent = dotExtent
      ..dotTop = dotTop;
  }
}

class _RenderCenterOnDot extends RenderShiftedBox {
  _RenderCenterOnDot(this._dotExtent, this._dotTop) : super(null);

  double _dotExtent;
  double _dotTop;

  set dotExtent(double value) {
    if (_dotExtent == value) return;
    _dotExtent = value;
    markNeedsLayout();
  }

  set dotTop(double value) {
    if (_dotTop == value) return;
    _dotTop = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    final childSize = child.size;
    // A downward callout hangs under a top-aligned dot, so the spare space
    // goes above it. An upward parent callout hangs over the dot, so the
    // spare space goes below it. Either way the dot stays on the row center.
    final below = childSize.height - (_dotTop + _dotExtent);
    final extraAbove = below > _dotTop ? below - _dotTop : 0.0;
    final extraBelow = _dotTop > below ? _dotTop - below : 0.0;
    size = constraints.constrain(
      Size(childSize.width, extraAbove + childSize.height + extraBelow),
    );
    (child.parentData! as BoxParentData).offset = Offset(0, extraAbove);
  }
}

/// Moss ring for an origin story that has no callout of its own.
class _OriginDot extends StatelessWidget {
  const _OriginDot({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final diameter = highlighted ? farDotHighlightedDiameter : farDotDiameter;
    final ring = diameter + 2 * calloutDotGap + 2 * calloutStroke;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: branchMoss, width: calloutStroke),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _FarDot extends StatelessWidget {
  const _FarDot({
    required this.story,
    required this.highlighted,
    required this.onTap,
    this.origin = false,
  });

  final Story story;
  final bool highlighted;
  final VoidCallback onTap;
  final bool origin;

  @override
  Widget build(BuildContext context) {
    final dot = GestureDetector(
      key: Key('timeline-dot-${story.id}'),
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: highlighted ? farDotHighlightedDiameter : farDotDiameter,
          height: highlighted ? farDotHighlightedDiameter : farDotDiameter,
          decoration: BoxDecoration(
            color: albumTerracotta,
            shape: BoxShape.circle,
            border: highlighted
                ? Border.all(color: albumTerracotta, width: 2)
                : null,
          ),
        ),
      ),
    );
    return Tooltip(
      message: dotTooltip(story, origin: origin),
      child: dot,
    );
  }
}
