/// Maps fractional years to pixels along one axis. Every renderer that
/// places stories in time goes through one of these.
class TimeScale {
  const TimeScale({
    required this.minYear,
    required this.maxYear,
    required this.pxPerYear,
    this.leading = 0,
    this.newestFirst = false,
  });

  final int minYear;
  final int maxYear;
  final double pxPerYear;

  /// Pixels before the first year boundary on the axis.
  final double leading;

  /// True when px grows toward older years (vertical, newest at the top).
  final bool newestFirst;

  /// Pixels covered by `[minYear, maxYear + 1)`, excluding [leading].
  double get span => (maxYear - minYear + 1) * pxPerYear;

  double toPx(double year) =>
      leading + (newestFirst ? maxYear + 1 - year : year - minYear) * pxPerYear;

  double toYear(double px) {
    final years = (px - leading) / pxPerYear;
    return newestFirst ? maxYear + 1 - years : minYear + years;
  }

  /// One tick per year boundary, `minYear..maxYear + 1`.
  Iterable<TimeTick> yearTicks() sync* {
    for (var y = minYear; y <= maxYear + 1; y++) {
      yield TimeTick(
        year: y,
        px: toPx(y.toDouble()),
        kind: y % 10 == 0 ? TickKind.decade : TickKind.year,
      );
    }
  }

  /// Eleven month boundaries inside each year, `minYear..maxYear`.
  Iterable<TimeTick> monthTicks() sync* {
    for (var y = minYear; y <= maxYear; y++) {
      for (var m = 1; m < 12; m++) {
        yield TimeTick(year: y, px: toPx(y + m / 12), kind: TickKind.month);
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TimeScale &&
      other.minYear == minYear &&
      other.maxYear == maxYear &&
      other.pxPerYear == pxPerYear &&
      other.leading == leading &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode =>
      Object.hash(minYear, maxYear, pxPerYear, leading, newestFirst);
}

enum TickKind { decade, year, month }

class TimeTick {
  const TimeTick({required this.year, required this.px, required this.kind});

  final int year;
  final double px;
  final TickKind kind;
}
