import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
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

  @override
  Widget build(BuildContext context) {
    final looks = [
      for (final band in widget.bands)
        (
          focused: band.startYear == centerKey,
          opacity: opacityOf(band.startYear, unmeasured: 1),
          highlight: _highlight(band),
        ),
    ];
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
          _FarList(
            scroll: scroll,
            rail: widget,
            looks: looks,
            rowKey: _rowKey,
            dotKey: _dotKey,
          ),
        ],
      ),
    );
  }
}

/// Per-decade state the rail scaffold owns: focus, fade and the story the
/// decade highlights.
typedef _BandLook = ({bool focused, double opacity, Story? highlight});

class _FarList extends StatelessWidget {
  const _FarList({
    required this.scroll,
    required this.rail,
    required this.looks,
    required this.rowKey,
    required this.dotKey,
  });

  final ScrollController scroll;
  final FarRail rail;
  final List<_BandLook> looks;
  final GlobalKey Function(int year) rowKey;
  final GlobalKey Function(String id) dotKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxHeight / 2;
        return ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(24, pad, 24, pad),
          children: [
            for (var i = 0; i < rail.bands.length; i++)
              _FarDecadeRow.at(
                rail,
                rail.bands[i],
                looks[i],
                key: rowKey(rail.bands[i].startYear),
                dotKey: dotKey,
              ),
          ],
        );
      },
    );
  }
}

class _FarDecadeRow extends StatelessWidget {
  _FarDecadeRow.at(
    FarRail rail,
    this.band,
    _BandLook look, {
    required GlobalKey super.key,
    required this.dotKey,
  }) : focused = look.focused,
       opacity = look.opacity,
       highlight = look.highlight,
       branching = rail.branching,
       originStoryId = rail.originStoryId,
       onDot = rail.onDot,
       onEmpty = rail.onEmpty,
       onYear = rail.onYear,
       onOpenBranch = rail.onOpenBranch,
       dimmed = rail.dimmed,
       filtering = rail.filtering;

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
    return Opacity(
      opacity: opacity,
      child: Padding(
        key: Key('timeline-decade-row-${band.startYear}'),
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _DecadeLabel(row: this),
              ),
            ),
            _DecadeNode(year: band.startYear, focused: focused, onYear: onYear),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                supportedDevices: fingerDevices,
                onTapUp: (details) => _onFingerTap(context, details),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _DecadeDots(row: this, width: constraints.maxWidth),
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
}

/// Decade label and its story count, right-aligned against the spine.
class _DecadeLabel extends StatelessWidget {
  const _DecadeLabel({required this.row});

  final _FarDecadeRow row;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final band = row.band;
    final focused = row.focused;
    final stories = band.stories;
    final matched = stories.where((s) => !row.dimmed.contains(s.id)).length;
    final count = countWord(band.stories.length, 'story', 'stories');
    // A decade with no match keeps its row in the dim ink (Q4).
    final noMatch = row.filtering && matched == 0;
    final heading = focused
        ? text.headlineMedium?.copyWith(fontWeight: FontWeight.w700)
        : text.headlineSmall?.copyWith(fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: Key('timeline-decade-${band.startYear}'),
            onTap: () => row.onYear(band.startYear),
            child: Text(
              band.label,
              style: heading?.copyWith(color: noMatch ? albumDimInk : null),
            ),
          ),
        ),
        const SizedBox(height: 2),
        _DecadeCount(
          label: row.filtering
              ? decadeMatchCount(matched, stories.length)
              : focused
              ? '$count preserved'
              : count,
          focused: focused,
          noMatch: noMatch,
        ),
      ],
    );
  }
}

class _DecadeCount extends StatelessWidget {
  const _DecadeCount({
    required this.label,
    required this.focused,
    required this.noMatch,
  });

  final String label;
  final bool focused;
  final bool noMatch;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            label,
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
    );
  }
}

/// The decade's node on the spine; it opens the decade's year.
class _DecadeNode extends StatelessWidget {
  const _DecadeNode({
    required this.year,
    required this.focused,
    required this.onYear,
  });

  final int year;
  final bool focused;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: GestureDetector(
        key: Key('timeline-decade-node-$year'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onYear(year),
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
    );
  }
}

/// The decade's story dots: plain dots first, then branch and parent
/// callouts. The dots half is narrow on Split View and Slide Over, so a
/// branch label shortens (with an ellipsis) to fit [width].
class _DecadeDots extends StatelessWidget {
  const _DecadeDots({required this.row, required this.width});

  final _FarDecadeRow row;
  final double width;

  @override
  Widget build(BuildContext context) {
    final plain = <Widget>[];
    final branched = <Widget>[];
    for (final story in row.band.stories) {
      final frame = row.branching.frameFor(story);
      final highlighted = row.focused && story.id == row.highlight?.id;
      final origin = story.id == row.originStoryId;
      if (frame.parent != null) {
        branched.add(
          _FarParent(
            row: row,
            frame: frame,
            highlighted: highlighted,
            origin: origin,
          ),
        );
      } else if (frame.branchesStory) {
        branched.add(
          _FarBranch(
            row: row,
            frame: frame,
            highlighted: highlighted,
            origin: origin,
            width: width,
          ),
        );
      } else {
        plain.add(_FarDot.of(row, story, highlighted, origin, ringed: true));
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
}

class _FarParent extends StatelessWidget {
  const _FarParent({
    required this.row,
    required this.frame,
    required this.highlighted,
    required this.origin,
  });

  final _FarDecadeRow row;
  final StoryFrame frame;
  final bool highlighted;
  final bool origin;

  @override
  Widget build(BuildContext context) {
    final mark = decadeParentMark(
      context: context,
      frame: frame,
      dot: _FarDot.of(row, frame.story, highlighted, origin),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: calloutLabelWidthFar,
      onOpen: row.onOpenBranch,
    );
    return _CenterOnDot(
      dotExtent: calloutHit,
      dotTop: mark.dotTop,
      child: mark.child,
    );
  }
}

class _FarBranch extends StatelessWidget {
  const _FarBranch({
    required this.row,
    required this.frame,
    required this.highlighted,
    required this.origin,
    required this.width,
  });

  final _FarDecadeRow row;
  final StoryFrame frame;
  final bool highlighted;
  final bool origin;
  final double width;

  PlacedBranch _place(BuildContext context, double maxLabelWidth) {
    return placeBranchCallout(
      context: context,
      frame: frame,
      side: CalloutSide.right,
      dot: _FarDot.of(row, frame.story, highlighted, origin),
      dotDiameter: highlighted ? farDotHighlightedDiameter : farDotDiameter,
      centerToLane: calloutHit / 2,
      maxLabelWidth: maxLabelWidth,
      onOpen: row.onOpenBranch,
    );
  }

  @override
  Widget build(BuildContext context) {
    var placed = _place(context, calloutLabelWidthFar);
    final fit = width - calloutHit - placed.push;
    if (fit < calloutLabelWidthFar) placed = _place(context, math.max(0, fit));
    return _CenterOnDot(
      dotExtent: calloutHit,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          BranchCalloutTarget(
            frame: frame,
            onOpen: row.onOpenBranch,
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
    // The widget always passes a child.
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
    (child.parentData as BoxParentData).offset = Offset(0, extraAbove);
  }
}

/// One Decades story dot. A plain dot carries its own rings: terracotta when
/// highlighted, moss when it is an origin with no callout. A dot inside a
/// branch callout is never [ringed]: the callout's moss ring is the only
/// ring there (branch-callout.md Rule 1). An unmatched dot is hollow.
class _FarDot extends StatelessWidget {
  /// [story]'s dot in [row]: matched unless dimmed, tapping opens it.
  _FarDot.of(
    _FarDecadeRow row,
    this.story,
    this.highlighted,
    this.origin, {
    this.ringed = false,
  }) : matched = !row.dimmed.contains(story.id),
       anchor = row.dotKey(story.id),
       onTap = (() => row.onDot(story));

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
