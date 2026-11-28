import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/album_theme.dart';
import '../../data/family_thread_density.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'no_match_card.dart';
import 'thread_band.dart';
import 'thread_beat.dart';
import 'thread_beat_model.dart';
import 'thread_beat_tile.dart';
import 'thread_focus.dart';
import 'thread_focus_controller.dart';
import 'thread_keyboard.dart';
import 'thread_photo_cache.dart';
import 'thread_filter.dart';
import 'thread_pointer_handler.dart';
import 'thread_rows.dart';

const threadPhoneBreakpoint = 600.0;
const _phoneBandWidth = 16.0;
const _wideBandWidth = 24.0;
const _phoneLeadWidth = 32.0;
const _phoneMarkMaxWidth = 160.0;
const _fadeDuration = Duration(milliseconds: 150);

class ThreadView extends StatefulWidget {
  const ThreadView({
    super.key,
    required this.stories,
    this.density = FamilyThreadDensity.browse,
    this.focusStoryId,
    this.onFocusChanged,
    this.onDensityDelta,
    this.onBeat,
    this.onCard,
    this.onOpen,
    this.onMore,
    this.ringToken = 0,
    this.focusRequest = 0,
    this.now,
    this.filter = ThreadFilter.cleared,
    this.onClearFilter,
    this.photos,
    this.photoCache,
  });

  final List<Story> stories;

  /// Overview, Browse, or Read. Defaults to Browse.
  final FamilyThreadDensity density;

  /// Story to keep on the focus line. Null centres the newest story.
  final String? focusStoryId;

  /// Reports the story on the focus line when a scroll ends.
  final ValueChanged<String>? onFocusChanged;

  final ValueChanged<int>? onDensityDelta;
  final void Function(ThreadBeat beat, {required bool focused})? onBeat;
  final ValueChanged<ThreadBeat>? onCard;
  final VoidCallback? onOpen;
  final ValueChanged<ThreadBeat>? onMore;
  final int ringToken;
  final int focusRequest;
  final Duration Function()? now;
  final ThreadFilter filter;
  final VoidCallback? onClearFilter;
  final PhotosGateway Function()? photos;
  final ThreadPhotoCache? photoCache;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _centerKey = GlobalKey();
  BuildContext? _focusContext;
  late final ThreadFocusController _focus;
  late final AnimationController _fade;
  late ThreadBeatModel _model;
  late List<ThreadBeat> _beats;
  late ThreadRows _rows;
  String? _focusId;
  String? _announcement;
  var _focusIndex = 0;
  var _viewport = -1.0;
  var _nudgePending = true;
  var _noneMatch = false;

  @override
  void initState() {
    super.initState();
    _focus = ThreadFocusController(scroll: _scroll, onSettled: _onSettled);
    _bind(rebuildModel: true, regroup: true);
    _fade = AnimationController(vsync: this, duration: _fadeDuration, value: 1);
  }

  @override
  void didUpdateWidget(ThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final storiesChanged = !identical(oldWidget.stories, widget.stories);
    final densityChanged = oldWidget.density != widget.density;
    final focusChanged = oldWidget.focusStoryId != widget.focusStoryId;
    final filterChanged = oldWidget.filter != widget.filter;
    if (!storiesChanged && !densityChanged && !focusChanged && !filterChanged) {
      return;
    }
    _bind(
      rebuildModel: storiesChanged,
      regroup: storiesChanged || densityChanged,
    );
    if (densityChanged) _fadeIn();
  }

  @override
  void dispose() {
    _fade.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _bind({required bool rebuildModel, required bool regroup}) {
    if (rebuildModel) _model = ThreadBeatModel.build(widget.stories);
    if (regroup) _beats = _model.beatsFor(widget.density);
    _rows = ThreadRows.build(_beats, widget.density, widget.filter);
    _focusId = widget.focusStoryId ?? _newestId(widget.stories);
    _noneMatch = _noStoriesMatch();
    _retargetFocus();
    if (_beats.isEmpty) {
      _focusIndex = 0;
      _nudgePending = true;
      return;
    }
    _reanchor(target: _beats[_indexOfFocus()]);
  }

  /// New anchor is [target], then the same half-height nudge. Used before the
  /// first paint (restore), on a far jump, and when density changes.
  void _reanchor({required ThreadBeat target}) {
    final index = _beats.indexOf(target);
    _focusIndex = index < 0 ? _indexOfFocus() : index;
    _nudgePending = true;
    if (_scroll.hasClients && _scroll.offset != 0) _focus.place(0);
  }

  void _retargetFocus() {
    final current = _storyById(_focusId);
    if (current == null || widget.filter.matches(current)) return;
    final matched = <Story>[
      for (final story in widget.stories)
        if (widget.filter.matches(story)) story,
    ];
    if (matched.isEmpty) return;
    final anchor = current.publishedStart;
    final nearest = ThreadFocus.nearestInTime(matched, anchor);
    if (nearest == null) return;
    _focusId = nearest.id;
    final id = nearest.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFocusChanged?.call(id);
    });
  }

  Story? _storyById(String? id) {
    if (id == null) return null;
    for (final story in widget.stories) {
      if (story.id == id) return story;
    }
    return null;
  }

  void _fadeIn() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
      return;
    }
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_noneMatch) {
      return NoMatchCard(onClear: widget.onClearFilter);
    }
    return ThreadKeyboard(
      onBeat: _moveBeat,
      beatCount: _beats.length,
      currentIndex: () => _focusIndex,
      matches: _matchesIndex,
      onDensityDelta: widget.onDensityDelta,
      onDrill: widget.onBeat == null ? null : _drill,
      focusRequest: widget.focusRequest,
      child: _scene(),
    );
  }

  bool _noStoriesMatch() {
    if (!widget.filter.isActive) return false;
    return widget.filter.countStories(widget.stories).n == 0;
  }

  void _drill() {
    if (_beats.isEmpty) return;
    widget.onBeat?.call(_beats[_focusIndex], focused: true);
  }

  Widget _scene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (height != _viewport) {
          _viewport = height;
          _nudgePending = true;
        }
        _scheduleCentre();
        return Stack(
          children: [
            FadeTransition(
              opacity: _fade,
              child: _list(height, constraints.maxWidth),
            ),
            if (_announcement != null) _FocusAnnouncement(_announcement!),
          ],
        );
      },
    );
  }

  Widget _list(double height, double width) {
    if (_rows.rows.isEmpty) return const SizedBox.shrink();
    final phone = width < threadPhoneBreakpoint;
    final anchor = _rows.rowOfBeat(_focusIndex);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: FamilyThreadCopy.threadList(widget.stories.length),
      child: _ThreadScroll(
        controller: _scroll,
        center: _centerKey,
        anchor: 0.5,
        onDensityDelta: widget.onDensityDelta,
        now: widget.now,
        slivers: _slivers(anchor, height, phone, _columnWidth(width, phone)),
      ),
    );
  }

  double _columnWidth(double width, bool phone) {
    final band = phone ? _phoneBandWidth : _wideBandWidth;
    if (phone) return width - _phoneLeadWidth - band;
    return (width - band) / 2;
  }

  List<Widget> _slivers(
    int anchor,
    double height,
    bool phone,
    double columnWidth,
  ) {
    return [
      if (anchor > 0)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _rowAt(
              anchor - 1 - index,
              phone: phone,
              columnWidth: columnWidth,
            ),
            childCount: anchor,
          ),
        ),
      SliverList(
        key: _centerKey,
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _rowAt(anchor + index, phone: phone, columnWidth: columnWidth),
          childCount: _rows.rows.length - anchor,
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: height)),
    ];
  }

  void _scheduleCentre() {
    if (!_nudgePending || _viewport <= 0) return;
    _nudgePending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nudgeToCentre());
  }

  void _nudgeToCentre() {
    if (!mounted) return;
    final focus = _focusContext;
    if (focus == null || !focus.mounted || !_scroll.hasClients) return;
    final target = focus.findRenderObject();
    if (target is! RenderBox || !target.hasSize) return;
    final half = target.size.height / 2;
    if ((_scroll.offset - half).abs() < 0.5) return;
    _focus.place(half);
  }

  bool _matchesIndex(int index) {
    if (index < 0 || index >= _beats.length) return false;
    return widget.filter.matchesBeat(_beats[index]);
  }

  void _moveBeat(int index) {
    if (_beats.isEmpty) return;
    final landed = _landOn(index);
    final id = ThreadFocus.representative(
      _beats[landed],
      previousFocusId: _focusId,
      filter: widget.filter,
    ).id;
    final changed = id != _focusId;
    setState(() {
      _focusId = id;
      _reanchor(target: _beats[landed]);
      if (changed) _announcement = _settledLabel();
    });
    if (changed) widget.onFocusChanged?.call(id);
  }

  // TODO(T1a-2): merge with ThreadFocusController._landOn.
  int _landOn(int index) {
    final beats = _beats;
    final filter = widget.filter;
    final clamped = index.clamp(0, beats.length - 1);
    if (filter.matchesBeat(beats[clamped])) return clamped;
    for (var distance = 1; distance < beats.length; distance++) {
      final later = clamped + distance;
      final earlier = clamped - distance;
      if (later < beats.length && filter.matchesBeat(beats[later])) {
        return later;
      }
      if (earlier >= 0 && filter.matchesBeat(beats[earlier])) return earlier;
    }
    return clamped;
  }

  void _onSettled(String storyId) {
    if (!mounted || storyId == _focusId) return;
    setState(() {
      _focusId = storyId;
      _reanchor(target: _beats[_indexOfFocus()]);
      _announcement = _settledLabel();
    });
    widget.onFocusChanged?.call(storyId);
  }

  String _settledLabel() {
    final beat = _beats[_focusIndex];
    switch (beat) {
      case DecadeBeat(:final decadeStart, :final stories):
        return FamilyThreadCopy.focusedDecade(decadeStart, stories.length);
      case YearBeat() || StoryBeat():
        final story = ThreadFocus.representative(
          beat,
          previousFocusId: _focusId,
        );
        return FamilyThreadCopy.focusedStory(
          story.publishedStart.year,
          story.title ?? '',
        );
    }
  }

  int _indexOfFocus() {
    final id = _focusId;
    if (id == null || _beats.isEmpty) return 0;
    final index = threadBeatIndex(_beats, id);
    return index < 0 ? _beats.length - 1 : index;
  }

  Widget _rowAt(
    int rowIndex, {
    required bool phone,
    required double columnWidth,
  }) {
    final row = _rows.rows[rowIndex];
    final band = _band(rowIndex, phone: phone);
    return switch (row) {
      ThreadLandmarkRow(:final decadeStart) => _LandmarkRow(
        key: ValueKey('landmark-$decadeStart'),
        decade: decadeStart,
        phone: phone,
        contentOnLeft: _contentOnLeft(rowIndex),
        band: band,
      ),
      ThreadBeatRow(:final beat, :final beatIndex) => _beatRow(
        beat,
        beatIndex,
        phone: phone,
        columnWidth: columnWidth,
        band: band,
      ),
    };
  }

  bool _contentOnLeft(int landmarkIndex) {
    final next = landmarkIndex + 1;
    if (next >= _rows.rows.length) return true;
    final row = _rows.rows[next];
    return row is ThreadBeatRow && row.beatIndex.isEven;
  }

  Widget _band(int rowIndex, {required bool phone}) {
    final last = _rows.rows.length - 1;
    return ThreadBand(
      bandWidth: phone ? _phoneBandWidth : _wideBandWidth,
      roundTop: rowIndex == 0,
      roundBottom: rowIndex == last,
      knot: rowIndex == 0,
    );
  }

  Widget _beatRow(
    ThreadBeat beat,
    int beatIndex, {
    required bool phone,
    required double columnWidth,
    required Widget band,
  }) {
    final focused = beatIndex == _focusIndex;
    final row = _BeatRow(
      phone: phone,
      index: beatIndex,
      tile: _tile(beat, beatIndex, columnWidth),
      mark: _markFor(beat, beatIndex),
      band: band,
    );
    return KeyedSubtree(
      key: ValueKey(_beatId(beat)),
      child: Builder(
        builder: (context) {
          if (focused) _focusContext = context;
          return row;
        },
      ),
    );
  }

  Widget _tile(ThreadBeat beat, int index, double columnWidth) {
    final focused = index == _focusIndex;
    final onBeat = widget.onBeat;
    return ThreadBeatTile(
      beat: beat,
      columnWidth: columnWidth,
      focusStoryId: _focusId,
      distance: (index - _focusIndex).abs(),
      ringToken: widget.ringToken,
      filter: widget.filter,
      photos: widget.photos,
      cache: widget.photoCache,
      onBeat: onBeat == null
          ? null
          : ({required bool focused}) => onBeat(beat, focused: focused),
      onCard: widget.onCard == null ? null : () => widget.onCard!(beat),
      onOpen: focused ? widget.onOpen : null,
      onMore: focused && widget.onMore != null
          ? () => widget.onMore!(beat)
          : null,
    );
  }

  Widget _markFor(ThreadBeat beat, int index) {
    return switch (beat) {
      DecadeBeat() => const SizedBox.shrink(),
      YearBeat() || StoryBeat() =>
        _startsDecade(_beats, index)
            ? _decadeMark(threadDecadeOfYear(_yearOf(beat)))
            : const SizedBox.shrink(),
    };
  }
}

class _ThreadScroll extends CustomScrollView {
  const _ThreadScroll({
    required ScrollController super.controller,
    required super.center,
    required super.anchor,
    required super.slivers,
    required this.onDensityDelta,
    required this.now,
  });

  final ValueChanged<int>? onDensityDelta;
  final Duration Function()? now;

  @override
  Widget buildViewport(
    BuildContext context,
    ViewportOffset offset,
    AxisDirection axisDirection,
    List<Widget> slivers,
  ) {
    return ThreadPointerHandler(
      onDensityDelta: onDensityDelta,
      now: now,
      child: super.buildViewport(context, offset, axisDirection, slivers),
    );
  }
}

class _FocusAnnouncement extends StatelessWidget {
  const _FocusAnnouncement(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: const SizedBox.shrink(),
    );
  }
}

class _BeatRow extends StatelessWidget {
  const _BeatRow({
    required this.phone,
    required this.index,
    required this.tile,
    required this.mark,
    required this.band,
  });

  final bool phone;
  final int index;
  final Widget tile;
  final Widget mark;
  final Widget band;

  @override
  Widget build(BuildContext context) {
    final leading = phone
        ? SizedBox(
            width: _phoneLeadWidth,
            child: OverflowBox(
              maxWidth: _phoneMarkMaxWidth,
              alignment: Alignment.centerRight,
              child: mark,
            ),
          )
        : Expanded(child: index.isEven ? tile : mark);
    final trailing = phone
        ? Expanded(child: tile)
        : Expanded(child: index.isEven ? mark : tile);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [leading, band, trailing],
      ),
    );
  }
}

class _LandmarkRow extends StatelessWidget {
  const _LandmarkRow({
    super.key,
    required this.decade,
    required this.phone,
    required this.contentOnLeft,
    required this.band,
  });

  final int decade;
  final bool phone;
  final bool contentOnLeft;
  final Widget band;

  @override
  Widget build(BuildContext context) {
    final label = _LandmarkLabel(decade);
    final leading = phone
        ? const SizedBox(width: _phoneLeadWidth)
        : Expanded(child: contentOnLeft ? const SizedBox.shrink() : label);
    final trailing = phone
        ? Expanded(
            child: Align(alignment: Alignment.centerLeft, child: label),
          )
        : Expanded(child: contentOnLeft ? label : const SizedBox.shrink());
    return SizedBox(
      height: threadLandmarkRowExtent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [leading, band, trailing],
      ),
    );
  }
}

class _LandmarkLabel extends StatelessWidget {
  const _LandmarkLabel(this.decade);

  final int decade;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        '${decade}s',
        maxLines: 1,
        // TODO(T1a-2): take this Newsreader italic from thread_row_metrics.dart.
        style: GoogleFonts.newsreader(
          fontSize: 28,
          fontStyle: FontStyle.italic,
          height: 1,
          color: albumInkDim,
        ),
      ),
    );
  }
}

String? _newestId(List<Story> stories) {
  if (stories.isEmpty) return null;
  return stories.last.id;
}

String _beatId(ThreadBeat beat) {
  return switch (beat) {
    DecadeBeat(:final decadeStart) => 'd$decadeStart',
    YearBeat(:final year) => 'y$year',
    StoryBeat(:final story) => story.id,
  };
}

Widget _decadeMark(int decade) {
  return Builder(
    builder: (context) => ExcludeSemantics(
      child: Text(
        '${decade}s',
        maxLines: 1,
        style: Theme.of(context).textTheme.headlineLarge
            ?.copyWith(fontSize: 40, height: 1, color: albumInkDim),
      ),
    ),
  );
}

bool _startsDecade(List<ThreadBeat> beats, int index) {
  if (index == 0) return true;
  return threadDecadeOfYear(_yearOf(beats[index])) !=
      threadDecadeOfYear(_yearOf(beats[index - 1]));
}

int _yearOf(ThreadBeat beat) {
  return switch (beat) {
    YearBeat(:final year) => year,
    StoryBeat(:final story) => story.publishedStart.year,
    DecadeBeat(:final decadeStart) => decadeStart,
  };
}
