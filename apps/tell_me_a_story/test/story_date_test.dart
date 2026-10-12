import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/stories/story_date.dart';

void main() {
  test('StoryDate round-trips each precision', () {
    final day = const StoryDate(year: 1987, month: 3, day: 14);
    final dayRange = day.toRange();
    expect(day.precision, StoryDatePrecision.day);
    expect(dayRange.start, DateTime(1987, 3, 14));
    expect(dayRange.end, DateTime(1987, 3, 14));
    expect(
      StoryDate.fromRow(dayRange.start, dayRange.end, dayRange.precision).day,
      14,
    );

    final month = const StoryDate(year: 1987, month: 3);
    final monthRange = month.toRange();
    expect(month.precision, StoryDatePrecision.month);
    expect(monthRange.start, DateTime(1987, 3, 1));
    expect(monthRange.end, DateTime(1987, 3, 31));

    final year = const StoryDate(year: 1987);
    final yearRange = year.toRange();
    expect(year.precision, StoryDatePrecision.year);
    expect(yearRange.end, DateTime(1987, 12, 31));

    final decade = const StoryDate(year: 1980, legacyDecade: true);
    final decadeRange = decade.toRange();
    expect(decade.precision, StoryDatePrecision.decade);
    expect(decadeRange.start, DateTime(1980, 1, 1));
    expect(decadeRange.end, DateTime(1989, 12, 31));
    expect(
      StoryDate.fromRow(
        decadeRange.start,
        decadeRange.end,
        StoryDatePrecision.decade,
      ).legacyDecade,
      isTrue,
    );
  });

  test('storyDateLabel uses the precision', () {
    expect(
      storyDateLabel(const StoryDate(year: 1980, legacyDecade: true)),
      '1980s',
    );
    expect(storyDateLabel(const StoryDate(year: 1987)), '1987');
    expect(storyDateLabel(const StoryDate(year: 1987, month: 3)), 'March 1987');
    expect(
      storyDateLabel(const StoryDate(year: 1987, month: 3, day: 14)),
      'March 14, 1987',
    );
  });

  test('decadeStartYear uses the start year for every precision', () {
    expect(decadeStartYear(DateTime(1987, 3, 14)), 1980);
    expect(decadeStartYear(DateTime(1980, 1, 1)), 1980);
    expect(decadeStartYear(DateTime(1990, 6, 1)), 1990);
  });

  test('compareStories orders precision then created_at, and reverses', () {
    Story row(String id, StoryDatePrecision precision, DateTime created) {
      return Story(
        id: id,
        familyId: 'f',
        authorId: 'a',
        timeframeStart: DateTime(1960, 1, 1),
        status: StoryStatus.published,
        datePrecision: precision,
        createdAt: created,
      );
    }

    final rows = [
      row('day', StoryDatePrecision.day, DateTime(2020)),
      row('year-late', StoryDatePrecision.year, DateTime(2020, 1, 2)),
      row('decade', StoryDatePrecision.decade, DateTime(2020)),
      row('month', StoryDatePrecision.month, DateTime(2020)),
      row('year-early', StoryDatePrecision.year, DateTime(2020, 1, 1)),
    ];
    rows.sort(compareStories);
    expect(
      rows.map((story) => story.id).toList(),
      ['decade', 'year-early', 'year-late', 'month', 'day'],
    );
    final newest = [...rows]..sort((a, b) => compareStories(b, a));
    expect(newest.first.id, 'day');
    expect(newest.last.id, 'decade');
  });
}
