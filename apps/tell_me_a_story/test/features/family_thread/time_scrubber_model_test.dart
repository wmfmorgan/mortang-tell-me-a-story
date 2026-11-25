import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';
import 'package:tell_me_a_story/features/family_thread/time_scrubber_model.dart';

void main() {
  test('ticks run oldest to newest whatever the input order', () {
    final model = TimeScrubberModel.build([
      _story('now', 2021),
      _story('early', 1952),
      _story('mid', 1964),
    ], ThreadFilter.cleared);

    expect(
      [model.decadeAt(0), model.decadeAt(1), model.decadeAt(2)],
      [1950, 1960, 2020],
    );
  });

  test(
    'a tap in a decade with no matches picks the nearest story to its midpoint',
    () {
      const filter = ThreadFilter(personIds: {'ada'});
      final model = TimeScrubberModel.build([
        _story('far', 1951, personId: 'ada'),
        _story('mid', 1955, personId: 'ada'),
        _story('other', 1964, personId: 'bea'),
        _story('now', 2022, personId: 'ada'),
      ], filter);

      final picked = model.tapPick(0.625, 'now');

      expect(picked?.id, 'mid');
      expect(TimeScrubberModel.decadeMidpoint(1960), DateTime.utc(1965));
    },
  );

  test('a drag that lands on an unmatched story picks the nearest match', () {
    const filter = ThreadFilter(personIds: {'ada'});
    final model = TimeScrubberModel.build([
      _story('early', 1952, personId: 'ada'),
      _story('middle', 1994, personId: 'bea'),
      _story('now', 2022, personId: 'ada'),
    ], filter);

    expect(model.dragPick(0.5)?.id, 'now');
  });
}

Story _story(String id, int year, {String personId = 'ada'}) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: id,
    personIds: [personId],
  );
}
