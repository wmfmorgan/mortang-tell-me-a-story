import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/filter/timeline_filter.dart';

// 7.5: the lab's filter_test, ported without hide or families. Decades are
// keyed by the story's start decade, the same key as its Decades row.

const _people = {
  'p-1': 'Ada Morgan',
  'p-2': 'Clara Reyes',
  'p-4': 'Esther Morgan',
};

Story _s(
  String id, {
  required DateTime start,
  DateTime? end,
  List<String> people = const [],
  String? place,
  String? placeLabel,
  String title = 'Untitled',
}) => Story(
  id: id,
  familyId: 'fam-root',
  authorId: 'u1',
  title: title,
  body: 'A plain sentence.',
  timeframeStart: start,
  timeframeEnd: end ?? start,
  status: StoryStatus.published,
  placeId: place,
  placeLabel: place == null ? null : (placeLabel ?? 'Lake Tahoe'),
  personIds: people,
  people: [for (final p in people) (id: p, name: _people[p]!)],
  personNames: [for (final p in people) _people[p]!],
);

final _stories = [
  _s('a', start: DateTime(1960, 5, 1), people: ['p-1'], place: 'pl-0'),
  _s('b', start: DateTime(1970, 5, 1), people: ['p-4']),
  _s('c', start: DateTime(1940, 5, 1), people: ['p-1']),
  _s('d', start: DateTime(1980, 5, 1), people: ['p-2']),
  _s('y49', start: DateTime(1949), end: DateTime(1952)),
  _s('e', start: DateTime(1990), place: 'pl-1', placeLabel: 'Harbour Street'),
];

Set<String> _ids(TimelineFilter f) => {
  for (final s in _stories)
    if (f.matches(s)) s.id,
};

void main() {
  test('people within the category combine with OR', () {
    expect(_ids(const TimelineFilter(personIds: {'p-1', 'p-4'})), {
      'a',
      'b',
      'c',
    });
  });

  test('people and decades combine with AND', () {
    expect(
      _ids(
        const TimelineFilter(
          personIds: {'p-1', 'p-4'},
          fromDecade: 1950,
          toDecade: 1990,
        ),
      ),
      {'a', 'b'},
    );
  });

  test('decade bounds use the start decade, its Decades row', () {
    expect(_ids(const TimelineFilter(fromDecade: 1940, toDecade: 1940)), {
      'c',
      'y49',
    });
    // y49 runs into 1952 but sits in the 1940s row.
    expect(_ids(const TimelineFilter(fromDecade: 1950)), {'a', 'b', 'd', 'e'});
    expect(_ids(const TimelineFilter(toDecade: 1960)), {'a', 'c', 'y49'});
  });

  test('place filter fails stories without a place', () {
    expect(_ids(const TimelineFilter(placeIds: {'pl-0'})), {'a'});
    expect(_ids(const TimelineFilter(placeIds: {'pl-0', 'pl-1'})), {'a', 'e'});
  });

  test('query matches person names but not place labels', () {
    expect(_ids(const TimelineFilter(query: 'esther')), {'b'});
    expect(_ids(const TimelineFilter(query: 'tahoe')), isEmpty);
    expect(_ids(const TimelineFilter(query: '  PLAIN ')), hasLength(6));
  });

  test('an inactive filter matches everything', () {
    expect(_ids(const TimelineFilter()), hasLength(_stories.length));
    expect(const TimelineFilter(query: '   ').isActive, isFalse);
    expect(const TimelineFilter(query: 'x').isActive, isTrue);
    expect(const TimelineFilter(personIds: {'p-1'}).isActive, isTrue);
    expect(const TimelineFilter(placeIds: {'pl-0'}).isActive, isTrue);
    expect(const TimelineFilter(fromDecade: 1950).isActive, isTrue);
    expect(const TimelineFilter(toDecade: 1950).isActive, isTrue);
  });

  test('copyWith can clear decade bounds', () {
    const f = TimelineFilter(fromDecade: 1950, toDecade: 1990);
    final cleared = f.copyWith(fromDecade: () => null, toDecade: () => null);
    expect(cleared.isActive, isFalse);
    expect(f.copyWith(query: 'x').fromDecade, 1950);
  });

  test('options come from the loaded stories, sorted and deduplicated', () {
    final options = filterOptions(_stories);
    expect(options.people.map((p) => p.id), ['p-1', 'p-2', 'p-4']);
    expect(options.people.map((p) => p.name), [
      'Ada Morgan',
      'Clara Reyes',
      'Esther Morgan',
    ]);
    expect(options.places.map((p) => p.id), ['pl-1', 'pl-0']);
    expect(options.places.map((p) => p.label), [
      'Harbour Street',
      'Lake Tahoe',
    ]);
    expect(options.decades, [1940, 1960, 1970, 1980, 1990]);
  });

  test('status line (C16) and decade count (C18)', () {
    expect(filterStatusLine(7, 120), '7 of 120 stories match');
    expect(decadeMatchCount(1, 3), '1 of 3');
  });
}
