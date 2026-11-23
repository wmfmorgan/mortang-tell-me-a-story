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

class ThreadView extends StatefulWidget {
  const ThreadView({super.key, required this.stories});

  final List<Story> stories;

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  ScrollController? _scroll;
  var _placed = false;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ThreadBeatModel.build(widget.stories);
    final beats = model.beatsFor(FamilyThreadDensity.browse);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final offset = _offset(model, beats.length, height);
        _scroll ??= ScrollController(initialScrollOffset: offset);
        _place(offset);
        return _list(beats, height, constraints.maxWidth);
      },
    );
  }

  Widget _list(List<ThreadBeat> beats, double height, double width) {
    final pad = math.max(0.0, (height - _extent) / 2);
    final focusId = widget.stories.isEmpty ? null : widget.stories.last.id;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: FamilyThreadCopy.threadList(widget.stories.length),
      child: ListView.builder(
        controller: _scroll,
        itemExtent: _extent,
        padding: EdgeInsets.symmetric(vertical: pad),
        itemCount: beats.length,
        itemBuilder: (context, index) =>
            _row(beats, index, phone: width < 600, focusId: focusId),
      ),
    );
  }

  double _offset(ThreadBeatModel model, int count, double viewport) {
    if (widget.stories.isEmpty || count == 0) return 0;
    final index = model.indexOfStory(
      widget.stories.last.id,
      FamilyThreadDensity.browse,
    );
    final focus = index < 0 ? count - 1 : index;
    return _centerOffset(focus, count, viewport);
  }

  void _place(double offset) {
    if (_placed) return;
    _placed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = _scroll;
      if (!mounted || scroll == null || !scroll.hasClients) return;
      final target = offset.clamp(0.0, scroll.position.maxScrollExtent);
      if ((scroll.offset - target).abs() < 0.5) return;
      scroll.jumpTo(target);
    });
  }

  Widget _row(
    List<ThreadBeat> beats,
    int index, {
    required bool phone,
    required String? focusId,
  }) {
    return switch (beats[index]) {
      final YearBeat beat => _yearRow(
        beats,
        beat,
        index,
        phone: phone,
        focusId: focusId,
      ),
      DecadeBeat() || StoryBeat() => const SizedBox.shrink(),
    };
  }
}

double _centerOffset(int index, int count, double viewport) {
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
      ? _decadeMark(_decade(beat.year))
      : const SizedBox.shrink();
  final band = ThreadBand(
    bandWidth: phone ? 16 : 24,
    roundTop: index == 0,
    roundBottom: index == beats.length - 1,
    knot: index == 0,
  );
  final leading = phone
      ? SizedBox(
          width: 32,
          child: OverflowBox(
            maxWidth: 160,
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
  return previous == null || _decade(year) != _decade(previous);
}

int? _yearOf(ThreadBeat beat) {
  return switch (beat) {
    YearBeat(:final year) => year,
    DecadeBeat() || StoryBeat() => null,
  };
}

int _decade(int year) => (year ~/ 10) * 10;
