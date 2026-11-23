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
import 'thread_focus.dart';

const _extent = 64.0;
const _phoneBreakpoint = 600.0;
const _phoneBandWidth = 16.0;
const _wideBandWidth = 24.0;
const _phoneLeadWidth = 32.0;
const _phoneMarkMaxWidth = 160.0;

class ThreadView extends StatefulWidget {
  const ThreadView({
    super.key,
    required this.stories,
    this.focusStoryId,
    this.onFocusChanged,
  });

  final List<Story> stories;

  /// Story to keep on the focus line. Null centres the newest story.
  final String? focusStoryId;

  /// Reports the story on the focus line when a scroll ends.
  final ValueChanged<String>? onFocusChanged;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  final _scroll = ScrollController();
  late ThreadBeatModel _model;
  late List<ThreadBeat> _beats;
  String? _focusId;
  var _focusIndex = 0;
  var _viewport = -1.0;
  var _centrePending = true;

  @override
  void initState() {
    super.initState();
    _bind(rebuildModel: true);
  }

  @override
  void didUpdateWidget(ThreadView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final storiesChanged = !identical(oldWidget.stories, widget.stories);
    final focusChanged = oldWidget.focusStoryId != widget.focusStoryId;
    if (!storiesChanged && !focusChanged) return;
    _bind(rebuildModel: storiesChanged);
    _centrePending = true;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _bind({required bool rebuildModel}) {
    if (rebuildModel) {
      _model = ThreadBeatModel.build(widget.stories);
      _beats = _model.beatsFor(FamilyThreadDensity.browse);
    }
    _focusId = widget.focusStoryId ?? _newestId(widget.stories);
    _focusIndex = _indexHolding(_focusId);
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
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.depth == 0) {
              _reportFocus();
            }
            return false;
          },
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
            _row(index, phone: width < _phoneBreakpoint),
      ),
    );
  }

  void _scheduleCentre() {
    if (!_centrePending || _viewport <= 0) return;
    final offset = _centerOffset(_focusIndex, _beats.length, _viewport);
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

  void _reportFocus() {
    if (!_scroll.hasClients || _beats.isEmpty || _viewport <= 0) return;
    final pad = math.max(0.0, (_viewport - _extent) / 2);
    final center = _scroll.offset + _viewport / 2;
    var index = ((center - pad - _extent / 2) / _extent).round();
    if (index < 0) index = 0;
    if (index >= _beats.length) index = _beats.length - 1;
    final id = _storyIdOn(_beats[index]);
    if (id == _focusId) return;
    _focusId = id;
    _focusIndex = index;
    widget.onFocusChanged?.call(id);
  }

  int _indexHolding(String? id) {
    if (id == null || _beats.isEmpty) return 0;
    final index = threadBeatIndex(_beats, id);
    return index < 0 ? _beats.length - 1 : index;
  }

  Widget _row(int index, {required bool phone}) {
    return switch (_beats[index]) {
      final YearBeat beat => _yearRow(
        _beats,
        beat,
        index,
        phone: phone,
        focusId: _focusId,
      ),
      DecadeBeat() || StoryBeat() => const SizedBox.shrink(),
    };
  }

  String _storyIdOn(ThreadBeat beat) {
    return switch (beat) {
      final YearBeat year => ThreadFocus.browseCardStory(
        year,
        focusId: _focusId,
      ).id,
      final StoryBeat story => story.story.id,
      final DecadeBeat decade => ThreadFocus.representative(
        decade,
        previousFocusId: _focusId,
      ).id,
    };
  }
}

String? _newestId(List<Story> stories) {
  if (stories.isEmpty) return null;
  return stories.last.id;
}

double _centerOffset(int index, int count, double viewport) {
  if (count == 0) return 0;
  final pad = math.max(0.0, (viewport - _extent) / 2);
  final raw = pad + index * _extent + _extent / 2 - viewport / 2;
  final maxScroll = math.max(0.0, pad * 2 + count * _extent - viewport);
  return raw.clamp(0.0, maxScroll);
}

Widget _yearRow(
  List<ThreadBeat> beats,
  YearBeat beat,
  int index, {
  required bool phone,
  required String? focusId,
}) {
  final card = ThreadFocus.browseCardStory(beat, focusId: focusId);
  final tile = ThreadBeatTile(year: beat.year, story: card);
  final mark = _startsDecade(beats, index)
      ? _decadeMark(threadDecadeOfYear(beat.year))
      : const SizedBox.shrink();
  final band = ThreadBand(
    bandWidth: phone ? _phoneBandWidth : _wideBandWidth,
    roundTop: index == 0,
    roundBottom: index == beats.length - 1,
    knot: index == 0,
  );
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
  final year = _yearOf(beats[index]);
  if (year == null) return false;
  if (index == 0) return true;
  final previous = _yearOf(beats[index - 1]);
  return previous == null ||
      threadDecadeOfYear(year) != threadDecadeOfYear(previous);
}

int? _yearOf(ThreadBeat beat) {
  return switch (beat) {
    YearBeat(:final year) => year,
    DecadeBeat() || StoryBeat() => null,
  };
}
