import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/features/timeline/presentation/filter/timeline_filter.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_branching.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/rail_scaffold.dart';
import 'package:tell_me_a_story/features/timeline/presentation/rails/rail_spine.dart';
import 'package:tell_me_a_story/core/widgets/timeline/story_marker.dart';
import 'package:tell_me_a_story/core/widgets/timeline/pointer_input.dart';
import 'package:tell_me_a_story/core/widgets/timeline/story_chooser.dart';

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
    this.dimmed = const {},
    this.filtering = false,
    this.toolbar,
    this.notice,
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

  /// Stories that miss the filter: drawn hollow, never hidden (Q4).
  final Set<String> dimmed;

  /// A filter is active: decade counts read "matched of total" (C18).
  final bool filtering;

  /// Beside the zoom switch: the subheader's action buttons.
  final Widget? toolbar;

  /// Pinned above the rows (the C17 no-match card).
  final Widget? notice;

  @override
  State<FarRail> createState() => _FarRailState();
}

class _FarRailState extends State<FarRail> with RailScaffold<FarRail, int> {
  final _rowKeys = <int, GlobalKey>{};

  GlobalKey _rowKey(int year) => _rowKeys.putIfAbsent(year, GlobalKey.new);

  final _dotKeys = <String, GlobalKey>{};

  GlobalKey _dotKey(String id) => _dotKeys.putIfAbsent(id, GlobalKey.new);

  @override
  Iterable<int> get rowKeys => widget.bands.map((band) => band.startYear);

  @override
  BuildContext? rowContext(int year) => _rowKey(year).currentContext;

  @override
  int? get initialCenterKey => _yearOf(widget.focusedId);

  @override
  int? get fallbackCenterKey {
    final bands = widget.bands;
    return bands.isEmpty ? null : bands[bands.length ~/ 2].startYear;
  }

  @override
  double get opacityTolerance => 0.01;

  @override
  RowFade Function(RenderBox row) fadeFor(RenderBox viewport) =>
      edgeFade(viewport, farEdgeOpacity);

  @override
  String? focusIdFor(int year) {
    DecadeBand? band;
    for (final candidate in widget.bands) {
      if (candidate.startYear == year) band = candidate;
    }
    return band == null ? null : _highlight(band)?.id;
  }

  @override
  String? get focusedStoryId => widget.focusedId;

  @override
  void onCenterStory(String id) => widget.onFocus(id);

  @override
  void didUpdateWidget(covariant FarRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    followFocus(_yearOf(widget.focusedId), _yearOf(oldWidget.focusedId));
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

  List<Widget> _farChildren() {
    return [
      for (final band in widget.bands)
        _FarDecadeRow(
          key: _rowKey(band.startYear),
          band: band,
          branching: widget.branching,
          originStoryId: widget.originStoryId,
          onOpenBranch: widget.onOpenBranch,
          focused: band.startYear == centerKey,
          opacity: opacityOf(band.startYear, unmeasured: 1),
          highlight: _highlight(band),
          onDot: widget.onDot,
          dotKey: _dotKey,
          onEmpty: widget.onEmpty,
          onYear: widget.onYear,
          dimmed: widget.dimmed,
          filtering: widget.filtering,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return buildRail(
      selected: TimelineZoom.far,
      onMacro: () {},
      onMid: widget.onMid,
      onFullCards: widget.onFullCards,
      onEmpty: widget.onEmpty,
      action: widget.toolbar,
      notice: widget.notice,
      viewport: Stack(
        key: viewportKey,
        children: [
          const RailSpine(),
          LayoutBuilder(
            builder: (context, constraints) {
              final pad = constraints.maxHeight / 2;
              return ListView(
                controller: scroll,
                padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
                children: _farChildren(),
              );
            },
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
    required this.dotKey,
    required this.onEmpty,
    required this.onYear,
    required this.onOpenBranch,
    required this.dimmed,
    required this.filtering,
  });

  final DecadeBand band;
  final bool focused;
  final double opacity;
  final Story? highlight;
  final RailBranching branching;
  final String? originStoryId;
  final ValueChanged<Story> onDot;

  /// Finds each story's painted dot, so a finger tap can measure to it.
  final GlobalKey Function(String id) dotKey;

  /// A finger tap that reaches no dot is an empty tap: it zooms out.
  final VoidCallback onEmpty;
  final ValueChanged<int> onYear;
  final ValueChanged<String> onOpenBranch;
  final Set<String> dimmed;
  final bool filtering;

  @override
  Widget build(BuildContext context) {
    final stories = band.stories;
    final matched = stories.where((s) => !dimmed.contains(s.id)).length;
    final count = countWord(band.stories.length, 'story', 'stories');
    // A decade with no match keeps its row in the dim ink (Q4).
    final noMatch = filtering && matched == 0;
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
              style:
                  (focused
                          ? Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700)
                          : Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w500))
                      ?.copyWith(color: noMatch ? albumDimInk : null),
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
            Flexible(
              child: Text(
                filtering
                    ? decadeMatchCount(matched, stories.length)
                    : focused
                    ? '$count preserved'
                    : count,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: noMatch
                      ? albumDimInk
                      : focused
                      ? albumTerracotta
                      : albumInk.withValues(alpha: 0.6),
                  fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    // The dots half is narrow on Split View and Slide Over, so a branch
    // label shortens (with an ellipsis) to fit it.
    Widget dots(double width) {
      final plain = <Widget>[];
      final branched = <Widget>[];
      for (final story in stories) {
        final frame = branching.frameFor(story);
        final highlighted = focused && story.id == highlight?.id;
        final origin = story.id == originStoryId;
        if (frame.parent != null) {
          branched.add(
            _farParent(
              context,
              frame,
              highlighted: highlighted,
              origin: origin,
            ),
          );
        } else if (frame.branchesStory) {
          branched.add(
            _farBranch(
              context,
              frame,
              highlighted: highlighted,
              origin: origin,
              width: width,
            ),
          );
        } else {
          plain.add(
            _FarDot(
              story: story,
              highlighted: highlighted,
              matched: !dimmed.contains(story.id),
              origin: origin,
              ringed: true,
              anchor: dotKey(story.id),
              onTap: () => onDot(story),
            ),
          );
        }
      }
      return Column(
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
    }

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
                          color: focused ? albumTerracotta : albumRuleStrong,
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                supportedDevices: fingerDevices,
                onTapUp: (details) => _onFingerTap(context, details),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        dots(constraints.maxWidth),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A finger reaches every dot within [hitRadiusFor] of the tap. One dot
  /// opens its story; several (a stacked year) open the chooser; none is an
  /// empty tap, which zooms out (owner, 7.4 sign-off). Pointers never get
  /// here: the dots answer them directly.
  Future<void> _onFingerTap(BuildContext context, TapUpDetails details) async {
    final covered = <Story>[];
    for (final story in band.stories) {
      final box = dotKey(story.id).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final centre = box.localToGlobal(box.size.center(Offset.zero));
      final reach = hitRadiusFor(
        details.kind,
        precise: box.size.shortestSide / 2,
      );
      if ((centre - details.globalPosition).distance <= reach) {
        covered.add(story);
      }
    }
    if (covered.isEmpty) return onEmpty();
    if (covered.length == 1) return onDot(covered.single);
    final id = await showStoryChooser(
      context,
      globalPosition: details.globalPosition,
      stories: covered,
    );
    for (final story in covered) {
      if (story.id == id) return onDot(story);
    }
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
        anchor: dotKey(story.id),
        story: story,
        highlighted: highlighted,
        matched: !dimmed.contains(story.id),
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
    required double width,
  }) {
    final story = frame.story;
    PlacedBranch place(double maxLabelWidth) => placeBranchCallout(
      context: context,
      frame: frame,
      side: CalloutSide.right,
      dot: _FarDot(
        anchor: dotKey(story.id),
        story: story,
        matched: !dimmed.contains(story.id),
        highlighted: highlighted,
        origin: origin,
        onTap: () => onDot(story),
      ),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: maxLabelWidth,
      onOpen: onOpenBranch,
    );
    var placed = place(calloutLabelWidthFar);
    final fit = width - calloutHit - placed.push;
    if (fit < calloutLabelWidthFar) placed = place(math.max(0, fit));
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

/// One Decades story dot. A plain dot carries its own rings: terracotta when
/// highlighted, moss when it is an origin with no callout. A dot inside a
/// branch callout is never [ringed]: the callout's moss ring is the only
/// ring there (branch-callout.md Rule 1). An unmatched dot is hollow.
class _FarDot extends StatelessWidget {
  const _FarDot({
    required this.story,
    required this.highlighted,
    required this.matched,
    required this.anchor,
    required this.onTap,
    this.origin = false,
    this.ringed = false,
  });

  final Story story;
  final bool highlighted;
  final bool matched;
  final GlobalKey anchor;
  final VoidCallback onTap;
  final bool origin;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final dot = GestureDetector(
      key: Key('timeline-dot-${story.id}'),
      supportedDevices: preciseDevices,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: StoryDot(
          key: anchor,
          reserveRings: false,
          spec: MarkerSpec(
            matched: matched,
            selected: ringed && highlighted,
            origin: ringed && origin,
            diameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
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
