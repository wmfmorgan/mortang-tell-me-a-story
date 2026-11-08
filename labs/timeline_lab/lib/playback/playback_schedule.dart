import 'dart:math' as math;

import '../filter/timeline_filter.dart';

/// How the timeline plays out.
///
/// * [sweep]: a time cursor moves through the years (Gource / Gapminder).
///   Reveal times are proportional to story dates, with long empty stretches
///   compressed so playback never idles.
/// * [steps]: story by story (Obsidian Animate / TimelineJS). Every story
///   gets the same dwell; above [PlaybackSchedule.yearBatchThreshold] stories
///   a whole year reveals per step so 5k stays watchable.
enum PlaybackDesign { sweep, steps }

/// Pure reveal schedule over entries in ascending (canonical) order.
///
/// Every renderer lays out the full entry list and asks the schedule how
/// visible each story is at clock `t`. Nothing reflows during playback and
/// scrubbing backwards is free: reveal is a pure function of `t`.
class PlaybackSchedule {
  PlaybackSchedule._({
    required this.design,
    required this.revealAt,
    required this.years,
    required this.ids,
    required this.fade,
  }) : indexById = {for (final (i, id) in ids.indexed) id: i},
       duration = revealAt.isEmpty ? 0 : revealAt.last + fade;

  static const yearBatchThreshold = 500;

  /// Sweep: [secondsPerYear] of story time per year, any gap longer than
  /// [maxGapSeconds] is compressed to it, and stories sharing a date are
  /// staggered by at most [burstStagger] so bursts don't pop at once.
  factory PlaybackSchedule.sweep(
    List<TimelineEntry> entries, {
    double secondsPerYear = 0.6,
    double maxGapSeconds = 1.5,
    double burstStagger = 0.08,
    double fade = 0.4,
  }) {
    final years = [for (final e in entries) e.story.fractionalYear];
    final revealAt = List<double>.filled(entries.length, 0);
    var i = 1;
    while (i < years.length) {
      if (years[i] != years[i - 1]) {
        final gap = (years[i] - years[i - 1]) * secondsPerYear;
        revealAt[i] = revealAt[i - 1] + math.min(gap, maxGapSeconds);
        i++;
        continue;
      }
      // A burst of same-date stories starting at i-1. Spread it over at most
      // half a year of playback.
      var j = i;
      while (j < years.length && years[j] == years[i - 1]) {
        j++;
      }
      final burst = j - (i - 1);
      final step = math.min(burstStagger, 0.5 * secondsPerYear / burst);
      for (var k = i; k < j; k++) {
        revealAt[k] = revealAt[k - 1] + step;
      }
      i = j;
    }
    return PlaybackSchedule._(
      design: PlaybackDesign.sweep,
      revealAt: revealAt,
      years: years,
      ids: [for (final e in entries) e.story.id],
      fade: fade,
    );
  }

  /// Steps: one story per [dwell] (default `clamp(60 s / n, 0.6, 2.0)`), or
  /// one year per [yearDwell] above [yearBatchThreshold] stories.
  factory PlaybackSchedule.steps(
    List<TimelineEntry> entries, {
    double? dwell,
    double yearDwell = 0.6,
    double fade = 0.3,
  }) {
    final n = entries.length;
    final years = [for (final e in entries) e.story.fractionalYear];
    final revealAt = List<double>.filled(n, 0);
    if (n > yearBatchThreshold) {
      var step = 0;
      for (var i = 1; i < n; i++) {
        if (entries[i].story.start.year != entries[i - 1].story.start.year) {
          step++;
        }
        revealAt[i] = step * yearDwell;
      }
    } else {
      final d = dwell ?? (n == 0 ? 1.0 : (60 / n).clamp(0.6, 2.0));
      for (var i = 0; i < n; i++) {
        revealAt[i] = i * d;
      }
    }
    return PlaybackSchedule._(
      design: PlaybackDesign.steps,
      revealAt: revealAt,
      years: years,
      ids: [for (final e in entries) e.story.id],
      fade: fade,
    );
  }

  final PlaybackDesign design;

  /// Seconds at which each entry starts to appear. Non-decreasing.
  final List<double> revealAt;

  /// Fractional year of each entry. Non-decreasing.
  final List<double> years;
  final List<String> ids;
  final Map<String, int> indexById;

  /// Enter-animation length in seconds.
  final double fade;

  /// Seconds until the last story is fully visible.
  final double duration;

  /// Number of entries whose reveal has started at [t].
  int revealedCount(double t) {
    var lo = 0, hi = revealAt.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (revealAt[mid] <= t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Number of entries whose reveal starts strictly before [t].
  int startedBefore(double t) {
    var lo = 0, hi = revealAt.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (revealAt[mid] < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Visibility of story [id] at [t]: 0 hidden, 1 fully shown. Unknown ids
  /// (not in this schedule) are shown. [fade] 0 means instant.
  double reveal(String id, double t, {required double fade}) {
    final i = indexById[id];
    if (i == null) return 1;
    final since = t - revealAt[i];
    if (since < 0) return 0;
    if (fade <= 0 || t >= duration) return 1;
    return math.min(1, since / fade);
  }

  /// Most recently revealed entry index at [t], or -1 before the first.
  int currentIndex(double t) => revealedCount(t) - 1;

  /// Cursor position as a fractional year. Sweep interpolates between
  /// reveal knots; steps sits on the current story.
  double yearAt(double t) {
    if (years.isEmpty) return 0;
    final n = revealedCount(t);
    if (n == 0) return years.first;
    if (design == PlaybackDesign.steps || n == years.length) {
      return years[n - 1];
    }
    final t0 = revealAt[n - 1], t1 = revealAt[n];
    final f = t1 == t0 ? 0.0 : (t - t0) / (t1 - t0);
    return years[n - 1] + (years[n] - years[n - 1]) * f;
  }

  /// Inverse of [yearAt]: the earliest clock at which the cursor reaches
  /// [year]. Used to keep the cursor in place when the schedule is rebuilt.
  double timeForYear(double year) {
    if (years.isEmpty || year <= years.first) return 0;
    if (year > years.last) return duration;
    var lo = 0, hi = years.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (years[mid] < year) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // years[lo] >= year > years[lo - 1]
    if (design == PlaybackDesign.steps) return revealAt[lo];
    final y0 = years[lo - 1], y1 = years[lo];
    final f = (year - y0) / (y1 - y0);
    return revealAt[lo - 1] + (revealAt[lo] - revealAt[lo - 1]) * f;
  }
}
