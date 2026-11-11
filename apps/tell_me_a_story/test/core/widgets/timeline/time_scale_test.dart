import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/widgets/timeline/time_scale.dart';

void main() {
  const oldestFirst = TimeScale(
    minYear: 1950,
    maxYear: 1959,
    pxPerYear: 40,
    leading: 24,
  );
  const newestFirst = TimeScale(
    minYear: 1950,
    maxYear: 1959,
    pxPerYear: 80,
    newestFirst: true,
  );

  test('oldest-first maps year boundaries left to right after the pad', () {
    expect(oldestFirst.toPx(1950), 24);
    expect(oldestFirst.toPx(1951.5), 24 + 60);
    expect(oldestFirst.toPx(1960), 24 + 400);
    expect(oldestFirst.span, 400);
  });

  test('newest-first puts the end of maxYear at the leading edge', () {
    expect(newestFirst.toPx(1960), 0);
    expect(newestFirst.toPx(1959), 80);
    expect(newestFirst.toPx(1950), 800);
  });

  test('toYear inverts toPx in both directions', () {
    for (final y in [1950.0, 1953.25, 1959.9]) {
      expect(oldestFirst.toYear(oldestFirst.toPx(y)), closeTo(y, 1e-9));
      expect(newestFirst.toYear(newestFirst.toPx(y)), closeTo(y, 1e-9));
    }
  });

  test('year ticks cover every boundary and flag decades', () {
    final ticks = oldestFirst.yearTicks().toList();
    expect(ticks.map((t) => t.year), [for (var y = 1950; y <= 1960; y++) y]);
    expect(ticks.where((t) => t.kind == TickKind.decade).map((t) => t.year), [
      1950,
      1960,
    ]);
  });

  test('month ticks: eleven per year, strictly inside the span', () {
    final months = oldestFirst.monthTicks().toList();
    expect(months, hasLength(10 * 11));
    expect(months.first.px, greaterThan(oldestFirst.toPx(1950)));
    expect(months.last.px, lessThan(oldestFirst.toPx(1960)));
  });

  test('equal parameters compare equal (painters repaint on change only)', () {
    expect(
      const TimeScale(minYear: 1950, maxYear: 1959, pxPerYear: 40, leading: 24),
      oldestFirst,
    );
    expect(oldestFirst == newestFirst, isFalse);
  });

  test('fractionalYear starts each year at the year itself', () {
    expect(fractionalYear(DateTime(1987)), 1987);
    expect(fractionalYear(DateTime.utc(1987)), 1987);
  });

  test('fractionalYear divides by the real day count and stays < year+1', () {
    // July 2 of a leap year is 183 days in: exactly half-way. 1987 has 365.
    expect(fractionalYear(DateTime(2000, 7, 2)), 2000.5);
    expect(fractionalYear(DateTime(1987, 7, 2)), 1987 + 182 / 365);
    for (final y in [1987, 1988, 2000]) {
      final f = fractionalYear(DateTime(y, 12, 31));
      expect(f, lessThan(y + 1));
      expect(f, greaterThan(y + 0.99));
    }
  });

  test('fractionalYear ignores the time of day and the zone', () {
    // A local date across a DST change still lands on its calendar day.
    expect(
      fractionalYear(DateTime(1987, 10, 30, 23, 30)),
      fractionalYear(DateTime.utc(1987, 10, 30)),
    );
  });
}
