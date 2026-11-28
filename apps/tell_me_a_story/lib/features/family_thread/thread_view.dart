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
import 'thread_center.dart';
import 'thread_focus.dart';
import 'thread_focus_controller.dart';
import 'thread_keyboard.dart';
import 'thread_photo_cache.dart';
import 'thread_filter.dart';
import 'thread_pointer_handler.dart';
import 'thread_row_metrics.dart';
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
  late final ThreadFocusController _focus;
  late final AnimationController _fade;
  late ThreadBeatModel _model;
  late List<ThreadBeat> _beats;
  late ThreadRows _rows;
  final _cache = ThreadRowExtentCache();
  List<double> _extents = const [];
  List<double> _offsets = const [];
  String? _focusId;
  String? _announcement;
  var _focusRow = 0;
  var _viewport = -1.0;
  var _width = 0.0;
  var _height = 0.0;
  var _scale = 1.0;
  TextScaler _scaler = TextScaler.noScaling;
  var _token = 0;
  var _appliedToken = -1;
  var _centrePending = true;
  var _noneMatch = false;
  ({double offset, String storyId, String? focusId})? _pendingAnimate;
  ({double offset, String storyId, String? focusId})? _pendingJump;

  @override
  void initState() {
    super.initState();
    _focus = ThreadFocusController(scroll: _scroll, onSettled: _onSettled);
    _bind(rebuildModel: true);
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
    _bind(rebuildModel: storiesChanged);
    _centrePending = true;
    if (densityChanged) _fadeIn();
  }

  @override
  void dispose() {
    _fade.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _bind({required bool rebuildModel}) {
    if (rebuildModel) {
      _model = ThreadBeatModel.build(widget.stories);
      _cache.clear();
    }
    _beats = _model.beatsFor(widget.density);
    _rows = ThreadRows.build(_beats, widget.density, widget.filter);
    _focusId = widget.focusStoryId ?? _newestId(widget.stories);
    _noneMatch = _noStoriesMatch();
    _retargetFocus();
    _focusRow = _indexOfFocus();
    _token += 1;
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
      beatCount: _rows.rows.length,
      currentIndex: _nearestIndex,
      matches: _rows.eligible,
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
    if (_rows.rows.isEmpty) return;
    final row = _rows.rows[_focusRow];
    if (row is! ThreadBeatRow) return;
    widget.onBeat?.call(row.beat, focused: true);
  }

  Widget _scene() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _syncExtents(constraints);
        _applyMotion();
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: [
              FadeTransition(opacity: _fade, child: _list(constraints)),
              if (_announcement != null) _FocusAnnouncement(_announcement!),
            ],
          ),
        );
      },
    );
  }

  Widget _list(BoxConstraints constraints) {
    final height = constraints.maxHeight;
    final width = constraints.maxWidth;
    final top = _extents.isEmpty
        ? 0.0
        : ThreadCenter.topPad(height, _extents.first);
    final bottom = _extents.isEmpty
        ? 0.0
        : ThreadCenter.bottomPad(height, _extents.last);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: FamilyThreadCopy.threadList(widget.stories.length),
      child: _ThreadList(
        controller: _scroll,
        itemExtentBuilder: (index, _) => _extents[index],
        padding: EdgeInsets.only(top: top, bottom: bottom),
        itemCount: _extents.length,
        onDensityDelta: widget.onDensityDelta,
        now: widget.now,
        itemBuilder: (context, index) =>
            _item(index, phone: width < threadPhoneBreakpoint),
      ),
    );
  }

  void _syncExtents(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return;
    }
    final scaler = MediaQuery.textScalerOf(context);
    final scale = scaler.scale(1);
    _viewport = height;
    if (width == _width &&
        height == _height &&
        scale == _scale &&
        _token == _appliedToken &&
        _extents.isNotEmpty) {
      return;
    }
    _width = width;
    _height = height;
    _scale = scale;
    _scaler = scaler;
    _appliedToken = _token;
    _recompute();
    _centrePending = true;
  }

  void _recompute() {
    if (_width <= 0 || _height <= 0) return;
    final table = threadExtentTable(
      rows: _rows.rows,
      density: widget.density,
      focusIndex: _focusRow,
      width: _width,
      threadHeight: _height,
      textScaler: _scaler,
      cache: _cache,
      measureBeat: _measureBeat,
    );
    _extents = table.extents;
    _offsets = table.offsets;
  }

  void _applyMotion() {
    final animate = _pendingAnimate;
    final jump = _pendingJump;
    _pendingAnimate = null;
    _pendingJump = null;
    if (animate != null) {
      _centrePending = false;
      _afterFrame(() {
        if (!_scroll.hasClients) return;
        _focus.moveToOffset(
          offset: animate.offset,
          storyId: animate.storyId,
          focusId: animate.focusId,
          reducedMotion: false,
        );
      });
      return;
    }
    if (!_centrePending && jump == null) return;
    final offset = jump?.offset ?? _focusOffset();
    final settle = jump;
    if (_scroll.hasClients) {
      _centrePending = false;
      _pin(offset);
      if (settle != null && settle.storyId != settle.focusId) {
        _afterFrame(() => _onSettled(settle.storyId));
      }
      return;
    }
    _afterFrame(() {
      if (!_scroll.hasClients) return;
      _centrePending = false;
      _focus.place(offset);
      if (settle != null && settle.storyId != settle.focusId) {
        _onSettled(settle.storyId);
      }
    });
  }

  void _pin(double offset) {
    if ((_scroll.offset - offset).abs() < 0.5) return;
    _scroll.position.correctPixels(offset);
  }

  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  int _nearestIndex() {
    if (_extents.isEmpty) return _focusRow;
    return ThreadCenter.nearestRow(
      offset: _scroll.hasClients ? _scroll.offset : 0,
      extents: _extents,
      offsets: _offsets,
      viewport: _viewport,
      eligible: _rows.eligible,
    );
  }

  void _moveBeat(int index) => _scheduleMove(index);

  void _scheduleMove(int index) {
    if (_centrePending || _rows.rows.isEmpty || _extents.isEmpty) return;
    final landed = _land(index);
    final row = _rows.rows[landed];
    if (row is! ThreadBeatRow) return;
    final storyId = ThreadFocus.representative(
      row.beat,
      previousFocusId: _focusId,
      filter: widget.filter,
    ).id;
    if (landed != _focusRow) {
      _focusRow = landed;
      _token += 1;
      _recompute();
      _appliedToken = _token;
    }
    final motion = (
      offset: _focusOffset(),
      storyId: storyId,
      focusId: _focusId,
    );
    _centrePending = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pendingJump = motion;
    } else {
      _pendingAnimate = motion;
    }
    setState(() {});
  }

  int _land(int index) {
    final count = _rows.rows.length;
    final clamped = index.clamp(0, count - 1);
    if (_rows.eligible(clamped)) return clamped;
    for (var distance = 1; distance < count; distance++) {
      final later = clamped + distance;
      final earlier = clamped - distance;
      if (later < count && _rows.eligible(later)) return later;
      if (earlier >= 0 && _rows.eligible(earlier)) return earlier;
    }
    return clamped;
  }

  bool _onScroll(ScrollNotification notification) {
    _focus.onNotification(
      notification: notification,
      extents: _extents,
      offsets: _offsets,
      viewport: _viewport,
      reducedMotion: MediaQuery.disableAnimationsOf(context),
      eligible: _rows.eligible,
      onMove: _scheduleMove,
    );
    return false;
  }

  void _onSettled(String storyId) {
    if (!mounted || storyId == _focusId) return;
    setState(() {
      _focusId = storyId;
      _announcement = _settledLabel();
    });
    widget.onFocusChanged?.call(storyId);
  }

  String _settledLabel() {
    final row = _rows.rows[_focusRow];
    if (row is! ThreadBeatRow) return '';
    switch (row.beat) {
      case DecadeBeat(:final decadeStart, :final stories):
        return FamilyThreadCopy.focusedDecade(decadeStart, stories.length);
      case YearBeat() || StoryBeat():
        final story = ThreadFocus.representative(
          row.beat,
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
    if (id == null || _beats.isEmpty || _rows.rows.isEmpty) return 0;
    final index = threadBeatIndex(_beats, id);
    if (index < 0) return _rows.rows.length - 1;
    return _rows.rowOfBeat(index);
  }

  double _focusOffset() {
    if (_extents.isEmpty) return 0;
    final index = _focusRow.clamp(0, _extents.length - 1);
    final align = threadRowTopAligns(
      density: widget.density,
      focused: true,
      matches: _rows.eligible(index),
      rowExtent: _extents[index],
      threadHeight: _viewport,
    );
    return ThreadCenter.centreOffset(
      index: index,
      extents: _extents,
      offsets: _offsets,
      viewport: _viewport,
      alignCardTop: align ? threadExpandedLead : null,
      alignViewportY: threadExpandedTopInset,
    );
  }

  ThreadBeat _measureBeat(ThreadBeat beat) {
    if (beat is! YearBeat || beat.stories.isEmpty) return beat;
    final card = ThreadFocus.browseCardStory(beat, focusId: _focusId);
    if (card.id == beat.stories.first.id) return beat;
    return YearBeat(
      year: beat.year,
      stories: [
        card,
        for (final story in beat.stories)
          if (story.id != card.id) story,
      ],
    );
  }

  Widget _item(int index, {required bool phone}) {
    final row = _rows.rows[index];
    return switch (row) {
      ThreadLandmarkRow(:final decadeStart) => _landmark(
        index,
        decadeStart,
        phone: phone,
      ),
      ThreadBeatRow(:final beat) => _row(index, beat, phone: phone),
    };
  }

  Widget _row(int index, ThreadBeat beat, {required bool phone}) {
    return _BeatRow(
      key: ValueKey<String>('thread-row-$index'),
      phone: phone,
      index: index,
      tile: _tile(beat, index),
      mark: const SizedBox.shrink(),
      band: _band(index, phone: phone),
    );
  }

  Widget _landmark(int index, int decade, {required bool phone}) {
    return _BeatRow(
      key: ValueKey<String>('thread-row-$index'),
      phone: phone,
      index: index,
      tile: const SizedBox.shrink(),
      mark: _landmarkLabel(decade),
      band: _band(index, phone: phone),
    );
  }

  Widget _band(int index, {required bool phone}) {
    final last = _rows.rows.length - 1;
    return ThreadBand(
      bandWidth: phone ? _phoneBandWidth : _wideBandWidth,
      roundTop: index == 0,
      roundBottom: index == last,
      knot: index == 0,
    );
  }

  Widget _landmarkLabel(int decade) {
    return ExcludeSemantics(
      child: Text(
        '${decade}s',
        maxLines: 1,
        style: GoogleFonts.newsreader(
          fontSize: threadLandmarkFont,
          height: 1,
          fontStyle: FontStyle.italic,
          color: albumInkDim,
        ),
      ),
    );
  }

  Widget _tile(ThreadBeat beat, int index) {
    final focused = index == _focusRow;
    final onBeat = widget.onBeat;
    final row = _rows.rows[index];
    final beatIndex = row is ThreadBeatRow ? row.beatIndex : index;
    return ThreadBeatTile(
      beat: beat,
      focusStoryId: _focusId,
      distance: (beatIndex - _focusBeat()).abs(),
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

  int _focusBeat() {
    final row = _rows.rows[_focusRow];
    return row is ThreadBeatRow ? row.beatIndex : 0;
  }
}

/// A [Listener] outside the list loses the pointer-signal race, because the
/// inner [Scrollable] registers first. The handler has to sit under that
/// scrollable, which means this list builds the viewport itself.
class _ThreadList extends ListView {
  _ThreadList({
    required ScrollController super.controller,
    required super.itemExtentBuilder,
    required super.padding,
    required int super.itemCount,
    required super.itemBuilder,
    required this.onDensityDelta,
    required this.now,
  }) : super.builder();

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
    super.key,
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
    return Row(children: [leading, band, trailing]);
  }
}

String? _newestId(List<Story> stories) {
  if (stories.isEmpty) return null;
  return stories.last.id;
}
