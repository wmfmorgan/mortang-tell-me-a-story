import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/model/lab_models.dart';

LabStory _s(
  String id, {
  required DateTime start,
  DatePrecision precision = DatePrecision.day,
  List<String> people = const [],
  String? place,
  String family = 'fam-root',
  String title = 'Untitled',
}) => LabStory(
  id: id,
  familyId: family,
  title: title,
  body: 'A plain sentence.',
  start: start,
  precision: precision,
  createdAt: DateTime.utc(2025),
  placeId: place,
  personIds: people,
  photoCount: 0,
);

final _data = LabDataset(
  stories: [
    _s('a', start: DateTime.utc(1960, 5, 1), people: ['p-1'], place: 'pl-0'),
    _s('b', start: DateTime.utc(1970, 5, 1), people: ['p-4']),
    _s('c', start: DateTime.utc(1940, 5, 1), people: ['p-1']),
    _s('d', start: DateTime.utc(1980, 5, 1), people: ['p-2']),
    _s('y49', start: DateTime.utc(1949), precision: DatePrecision.year),
    _s('fam', start: DateTime.utc(1990), family: 'fam-reyes', place: 'pl-0'),
  ],
  people: const {
    'p-1': LabPerson(id: 'p-1', name: 'Ada Morgan'),
    'p-2': LabPerson(id: 'p-2', name: 'Clara Reyes'),
    'p-4': LabPerson(id: 'p-4', name: 'Esther Morgan'),
  },
  places: const {'pl-0': LabPlace(id: 'pl-0', label: 'Lake Tahoe')},
  families: const {
    'fam-root': LabFamily(id: 'fam-root', name: 'Morgan'),
    'fam-reyes': LabFamily(id: 'fam-reyes', name: 'Reyes'),
  },
);

Set<String> _ids(TimelineFilter f) => {
  for (final e in applyFilter(_data, f))
    if (e.matched) e.story.id,
};

void main() {
  test('people within the category combine with OR', () {
    expect(_ids(const TimelineFilter(personIds: {'p-1', 'p-4'})), {
      'a',
      'b',
      'c',
    });
  });

  test('people and era combine with AND', () {
    expect(
      _ids(
        const TimelineFilter(
          personIds: {'p-1', 'p-4'},
          fromYear: 1950,
          toYear: 1999,
        ),
      ),
      {'a', 'b'},
    );
  });

  test('era overlap uses the story span', () {
    expect(_ids(const TimelineFilter(fromYear: 1949, toYear: 1949)), {'y49'});
    expect(_ids(const TimelineFilter(fromYear: 1950)), isNot(contains('y49')));
  });

  test('place filter fails stories without a place', () {
    expect(_ids(const TimelineFilter(placeIds: {'pl-0'})), {'a', 'fam'});
  });

  test('family filter', () {
    expect(_ids(const TimelineFilter(familyIds: {'fam-reyes'})), {'fam'});
  });

  test('query matches person names but not place labels', () {
    expect(_ids(const TimelineFilter(query: 'esther')), {'b'});
    expect(_ids(const TimelineFilter(query: 'tahoe')), isEmpty);
  });

  test('hide drops non-matches; dim keeps them unmatched', () {
    const f = TimelineFilter(personIds: {'p-2'});
    final hidden = applyFilter(_data, f.copyWith(mode: FilterMode.hide));
    expect(hidden.map((e) => e.story.id), ['d']);

    final dimmed = applyFilter(_data, f.copyWith(mode: FilterMode.dim));
    expect(dimmed, hasLength(_data.stories.length));
    expect(dimmed.where((e) => !e.matched), hasLength(5));
  });

  test('inactive filter matches everything in either mode', () {
    for (final mode in FilterMode.values) {
      final entries = applyFilter(_data, TimelineFilter(mode: mode));
      expect(entries, hasLength(_data.stories.length));
      expect(entries.every((e) => e.matched), isTrue);
    }
    expect(const TimelineFilter(query: '   ').isActive, isFalse);
  });

  test('copyWith can clear year bounds', () {
    const f = TimelineFilter(fromYear: 1950, toYear: 1999);
    final cleared = f.copyWith(fromYear: () => null, toYear: () => null);
    expect(cleared.isActive, isFalse);
  });

  test('statusLine', () {
    expect(statusLine(120, 120, const TimelineFilter()), '120 stories');
    expect(
      statusLine(7, 120, const TimelineFilter(query: 'x')),
      '7 of 120 stories match',
    );
  });
}
