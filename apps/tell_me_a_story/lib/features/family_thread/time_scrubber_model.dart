import 'package:flutter/services.dart';

import '../../data/stories_api.dart';
import 'thread_beat_model.dart';
import 'thread_filter.dart';
import 'thread_focus.dart';

/// Decade ticks and the story a tap, drag, or key step lands on.
///
/// Decades are ordered oldest to newest. The caller can pass stories in any
/// order. Stories inside one decade keep the order they arrived in.
class TimeScrubberModel {
  TimeScrubberModel._({
    required List<_Tick> ticks,
    required List<Story> ordered,
    required List<Story> matched,
    required this.span,
  }) : _ticks = ticks,
       _ordered = ordered,
       _matched = matched;

  factory TimeScrubberModel.build(List<Story> stories, ThreadFilter filter) {
    final grouped = <int, List<Story>>{};
    for (final story in stories) {
      (grouped[threadDecadeOf(story)] ??= <Story>[]).add(story);
    }
    final decades = grouped.keys.toList()..sort();
    final ticks = <_Tick>[];
    final ordered = <Story>[];
    final matched = <Story>[];
    var span = 0;
    for (final decade in decades) {
      final tick = _Tick(decade, grouped[decade]!, filter);
      ticks.add(tick);
      ordered.addAll(tick.stories);
      matched.addAll(tick.matchedStories);
      span += tick.total;
    }
    return TimeScrubberModel._(
      ticks: ticks,
      ordered: ordered,
      matched: matched,
      span: span,
    );
  }

  final List<_Tick> _ticks;
  final List<Story> _ordered;
  final List<Story> _matched;
  final int span;

  int get tickCount => _ticks.length;

  bool get isEmpty => _ticks.isEmpty;

  int decadeAt(int index) => _ticks[index].decade;

  int totalAt(int index) => _ticks[index].total;

  int matchedAt(int index) => _ticks[index].matched;

  int showingDecade(String? focusId) => _ticks[_decadeIndex(focusId)].decade;

  /// Middle of a decade. 1990 becomes 1 Jan 1995, the anchor when that
  /// decade has no story the filter keeps.
  static DateTime decadeMidpoint(int decade) => DateTime.utc(decade + 5);

  Story? tapPick(double t, String? focusId) {
    if (_ticks.isEmpty) return null;
    final tick = _ticks[_tickSpot(t)];
    final inside = ThreadFocus.nearestInTime(
      tick.matchedStories,
      _anchor(focusId),
    );
    if (inside != null) return inside;
    return ThreadFocus.nearestInTime(_matched, decadeMidpoint(tick.decade));
  }

  Story? dragPick(double t) {
    if (_ordered.isEmpty) return null;
    final story = _ordered[_spot(t, _ordered.length)];
    for (final match in _matched) {
      if (match.id == story.id) return story;
    }
    return ThreadFocus.nearestInTime(_matched, story.publishedStart);
  }

  String? stepId(String? focusId, int delta) {
    if (_ticks.isEmpty || delta == 0) return null;
    var index = _decadeIndex(focusId);
    final toward = delta < 0 ? -1 : 1;
    var left = delta.abs();
    while (left > 0) {
      final next = _matchingStep(index, toward);
      if (next == null) break;
      index = next;
      left -= 1;
    }
    return ThreadFocus.nearestInTime(
      _ticks[index].matchedStories,
      _anchor(focusId),
    )?.id;
  }

  double centerFraction(int decade) {
    if (span == 0) return 0;
    var before = 0;
    for (final tick in _ticks) {
      if (tick.decade == decade) return (before + tick.total / 2) / span;
      before += tick.total;
    }
    return 1;
  }

  static double handleStart(double span, double fraction) {
    final room = span - _handleExtent;
    if (room <= 0) return 0;
    return (span * fraction - _handleExtent / 2).clamp(0.0, room);
  }

  static int? keyDelta(LogicalKeyboardKey key) {
    return switch (key) {
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.pageUp => -2,
      LogicalKeyboardKey.pageDown => 2,
      _ => null,
    };
  }

  int _decadeIndex(String? focusId) {
    for (var i = 0; i < _ticks.length; i++) {
      if (_ticks[i].stories.any((story) => story.id == focusId)) return i;
    }
    return _ticks.length - 1;
  }

  int? _matchingStep(int index, int toward) {
    var next = index + toward;
    while (next >= 0 && next < _ticks.length && _ticks[next].matched == 0) {
      next += toward;
    }
    if (next < 0 || next >= _ticks.length) return null;
    return next;
  }

  int _tickSpot(double t) {
    if (_ticks.length <= 1 || span <= 1) return 0;
    var cursor = 0;
    final target = t.clamp(0.0, 1.0) * span;
    for (var i = 0; i < _ticks.length; i++) {
      cursor += _ticks[i].total;
      if (target < cursor || i == _ticks.length - 1) return i;
    }
    return 0;
  }

  DateTime _anchor(String? focusId) {
    for (final story in _ordered) {
      if (story.id == focusId) return story.publishedStart;
    }
    return _ordered.last.publishedStart;
  }
}

class _Tick {
  _Tick(this.decade, this.stories, ThreadFilter filter)
    : matchedStories = [
        for (final story in stories)
          if (filter.matches(story)) story,
      ];

  final int decade;
  final List<Story> stories;
  final List<Story> matchedStories;

  int get total => stories.length;

  int get matched => matchedStories.length;
}

const _handleExtent = 44.0;

int _spot(double t, int count) {
  if (count <= 1) return 0;
  return (t.clamp(0.0, 1.0) * (count - 1)).round().clamp(0, count - 1);
}
