import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/family_thread_density.dart';
import '../../data/stories_api.dart';
import 'family_thread_copy.dart';
import 'thread_band.dart';
import 'thread_beat.dart';
import 'thread_beat_model.dart';
import 'thread_beat_tile.dart';

const threadPhoneBreakpoint = 600.0;
const _browseExtent = 64.0;
const _overviewExtent = 112.0;
const _readExtent = 64.0;
const _phoneBandWidth = 16.0;
const _wideBandWidth = 24.0;
const _phoneLeadWidth = 32.0;
const _phoneMarkMaxWidth = 160.0;
const _fadeDuration = Duration(milliseconds: 150);

double _extentFor(FamilyThreadDensity density) {
  return switch (density) {
    FamilyThreadDensity.overview => _overviewExtent,
    FamilyThreadDensity.browse => _browseExtent,
    FamilyThreadDensity.read => _readExtent,
  };
}

class ThreadView extends StatefulWidget {
  const ThreadView({
    super.key,
    required this.stories,
    this.density = FamilyThreadDensity.browse,
    this.focusStoryId,
  });

  final List<Story> stories;
  final FamilyThreadDensity density;
  final String? focusStoryId;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _fade;
  late ThreadBeatModel _model;
  late List<ThreadBeat> _beats;
  String? _focusId;
  var _focusIndex = 0;
  var _extent = _browseExtent;
  var _viewport = -1.0;
  var _centrePending = true;

  @override
  void initState() {
    super.initState();
    _bind(rebuildModel: true, regroup: true);
    _fade = AnimationController(vsync: this, duration: _fadeDuration, value: 1);
  }

  @override
  void didUpdateWidget(ThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final storiesChanged = !identical(oldWidget.stories, widget.stories);
    final densityChanged = oldWidget.density != widget.density;
    final focusChanged = oldWidget.focusStoryId != widget.focusStoryId;
    if (!storiesChanged && !densityChanged && !focusChanged) return;
    _bind(
      rebuildModel: storiesChanged,
      regroup: storiesChanged || densityChanged,
    );
    _centrePending = true;
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
    _extent = _extentFor(widget.density);
    _focusId = widget.focusStoryId ?? _newestId(widget.stories);
    _focusIndex = _indexOfFocus();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (height != _viewport) {
          _viewport = height;
          _centrePending = true;
        }
        _scheduleCentre();
        return FadeTransition(
          opacity: _fade,
          child: _list(height, constraints.maxWidth),
        );
      },
    );
  }

  Widget _list(double height, double width) {
    final pad = math.max(0.0, (height - _extent) / 2);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: FamilyThreadCopy.threadList(widget.stories.length),
      child: ListView.builder(
        controller: _scroll,
        itemExtent: _extent,
        padding: EdgeInsets.symmetric(vertical: pad),
        itemCount: _beats.length,
        itemBuilder: (context, index) =>
            _row(index, phone: width < threadPhoneBreakpoint),
      ),
    );
  }

  void _scheduleCentre() {
    if (!_centrePending || _viewport <= 0) return;
    final offset = _centerOffset(
      _focusIndex,
      _beats.length,
      _viewport,
      _extent,
    );
    _centrePending = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        _centrePending = true;
        return;
      }
      final target = offset.clamp(0.0, _scroll.position.maxScrollExtent);
      if ((_scroll.offset - target).abs() < 0.5) return;
      _scroll.jumpTo(target);
    });
  }

  int _indexOfFocus() {
    final id = _focusId;
    if (id == null || _beats.isEmpty) return 0;
    for (var index = 0; index < _beats.length; index++) {
      if (_holds(_beats[index], id)) return index;
    }
    return _beats.length - 1;
  }

  Widget _row(int index, {required bool phone}) {
    final beat = _beats[index];
    return _BeatRow(
      phone: phone,
      index: index,
      tile: ThreadBeatTile(beat: beat, focusStoryId: _focusId),
      mark: _markFor(beat, index),
      band: ThreadBand(
        bandWidth: phone ? _phoneBandWidth : _wideBandWidth,
        roundTop: index == 0,
        roundBottom: index == _beats.length - 1,
        knot: index == 0,
      ),
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
    return Row(children: [leading, band, trailing]);
  }
}

String? _newestId(List<Story> stories) {
  if (stories.isEmpty) return null;
  return stories.last.id;
}

double _centerOffset(int index, int count, double viewport, double extent) {
  if (count == 0) return 0;
  final pad = math.max(0.0, (viewport - extent) / 2);
  final raw = pad + index * extent + extent / 2 - viewport / 2;
  final maxScroll = math.max(0.0, pad * 2 + count * extent - viewport);
  return raw.clamp(0.0, maxScroll);
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

bool _holds(ThreadBeat beat, String storyId) {
  return switch (beat) {
    DecadeBeat(:final stories) => stories.any((story) => story.id == storyId),
    YearBeat(:final stories) => stories.any((story) => story.id == storyId),
    StoryBeat(:final story) => story.id == storyId,
  };
}
