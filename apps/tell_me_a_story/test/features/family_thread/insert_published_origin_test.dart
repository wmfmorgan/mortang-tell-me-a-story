import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/insert_published_origin.dart';

void main() {
  test('an older origin lands at index 0', () {
    final rows = [_story('mid', 1990), _story('late', 2000)];

    final placed = insertPublishedOrigin(rows, _story('old', 1980));

    expect(placed.map((story) => story.id), ['old', 'mid', 'late']);
    expect(rows.map((story) => story.id), ['mid', 'late']);
  });

  test('an origin between two rows lands between them', () {
    final rows = [_story('early', 1980), _story('late', 2000)];

    final placed = insertPublishedOrigin(rows, _story('mid', 1990));

    expect(placed.map((story) => story.id), ['early', 'mid', 'late']);
  });

  test('a tied timeframe start uses precision, then created_at, then id', () {
    final day = _story('day', 1982, precision: StoryDatePrecision.day);
    final decade = insertPublishedOrigin([
      day,
    ], _story('decade', 1982, precision: StoryDatePrecision.decade));
    expect(decade.map((story) => story.id), ['decade', 'day']);

    final later = _story(
      'later',
      1982,
      precision: StoryDatePrecision.year,
      createdAt: DateTime.utc(2021),
    );
    final earlier = insertPublishedOrigin([
      later,
    ], _story('earlier', 1982, createdAt: DateTime.utc(2020)));
    expect(earlier.map((story) => story.id), ['earlier', 'later']);

    final bee = _story('b', 1982, createdAt: DateTime.utc(2020));
    final ay = insertPublishedOrigin([
      bee,
    ], _story('a', 1982, createdAt: DateTime.utc(2020)));
    expect(ay.map((story) => story.id), ['a', 'b']);
  });

  test('an origin already in the rows stays deduped', () {
    final rows = [_story('a', 1980), _story('origin', 1990), _story('z', 2000)];

    final placed = insertPublishedOrigin(rows, _story('origin', 1970));

    expect(placed.map((story) => story.id), ['a', 'origin', 'z']);
  });
}

Story _story(
  String id,
  int year, {
  StoryDatePrecision precision = StoryDatePrecision.year,
  DateTime? createdAt,
}) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year),
    datePrecision: precision,
    createdAt: createdAt ?? DateTime.utc(2020),
  );
}
