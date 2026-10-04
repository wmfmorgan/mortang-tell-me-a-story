import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/search_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

const _family = 'family-1';

SearchRecord _record({
  String id = 's1',
  String familyId = _family,
  String? title,
  String? body,
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
  String? placeId,
  String? placeLabel,
  String? placeAddress,
  List<String> personIds = const [],
  List<String> personNames = const [],
  StoryStatus status = StoryStatus.published,
  DateTime? publishedAt,
  String? authorDisplayName,
}) {
  return SearchRecord(
    placeAddress: placeAddress,
    story: Story(
      id: id,
      familyId: familyId,
      authorId: 'author',
      title: title,
      body: body,
      timeframeStart: timeframeStart ?? DateTime(1984, 6, 1),
      timeframeEnd: timeframeEnd,
      placeId: placeId,
      placeLabel: placeLabel,
      personIds: personIds,
      personNames: personNames,
      status: status,
      publishedAt: publishedAt,
      authorDisplayName: authorDisplayName,
    ),
  );
}

void main() {
  test('person, place, and decade chips are AND', () {
    final rows = [
      _record(
        id: 'all',
        title: 'Porch',
        personIds: const ['clara', 'robert'],
        placeId: 'porch',
        timeframeStart: DateTime(1984, 1, 1),
      ),
      _record(
        id: 'person-only',
        personIds: const ['clara'],
        placeId: 'mill',
        timeframeStart: DateTime(1984, 1, 1),
      ),
      _record(
        id: 'other-decade',
        personIds: const ['clara'],
        placeId: 'porch',
        timeframeStart: DateTime(1972, 1, 1),
      ),
    ];

    final matched = filterSearchRecords(
      rows,
      const SearchRequest(
        familyId: _family,
        personIds: ['clara'],
        placeId: 'porch',
        rangeStart: null,
      ),
    );
    expect(matched.map((r) => r.story.id), ['all', 'other-decade']);

    final ranged = filterSearchRecords(
      rows,
      SearchRequest(
        familyId: _family,
        personIds: const ['clara'],
        placeId: 'porch',
        rangeStart: DateTime(1980, 1, 1),
        rangeEnd: DateTime(1999, 12, 31),
      ),
    );
    expect(ranged.map((r) => r.story.id), ['all']);
  });

  test('text matches title, body, person, place, year, and decade', () {
    final row = _record(
      title: 'Lemonade',
      body: 'cicadas in the elm',
      personNames: const ['Clara'],
      placeLabel: 'Back Porch',
      placeAddress: '12 Lane',
      timeframeStart: DateTime(1984, 7, 1),
    );
    expect(searchTextMatches(row, 'lemonade'), isTrue);
    expect(searchTextMatches(row, 'elm'), isTrue);
    expect(searchTextMatches(row, 'clara'), isTrue);
    expect(searchTextMatches(row, 'porch'), isTrue);
    expect(searchTextMatches(row, 'lane'), isTrue);
    expect(searchTextMatches(row, '1984'), isTrue);
    expect(searchTextMatches(row, '1980s'), isTrue);
    expect(searchTextMatches(row, 'subway'), isFalse);
  });

  test('drafts and other families stay out', () {
    final rows = [
      _record(id: 'pub', title: 'Jam'),
      _record(id: 'draft', title: 'Jam', status: StoryStatus.draft),
      _record(id: 'other', title: 'Jam', familyId: 'family-2'),
    ];
    final matched = filterSearchRecords(
      rows,
      const SearchRequest(familyId: _family, text: 'Jam'),
    );
    expect(matched.map((r) => r.story.id), ['pub']);
  });

  test('sorts by relevance, chronology, and published time', () {
    final rows = [
      _record(
        id: 'body',
        title: 'Quiet',
        body: 'porch',
        timeframeStart: DateTime(1999),
        publishedAt: DateTime(2020),
      ),
      _record(
        id: 'title',
        title: 'Porch story',
        body: 'other',
        timeframeStart: DateTime(1950),
        publishedAt: DateTime(2010),
      ),
      _record(
        id: 'late-publish',
        title: 'Plain',
        timeframeStart: DateTime(1960),
        publishedAt: DateTime(2024),
      ),
      _record(
        id: 'unpublished-time',
        title: 'Plain',
        timeframeStart: DateTime(1970),
      ),
    ];

    final relevant = filterSearchRecords(
      rows,
      const SearchRequest(familyId: _family, text: 'porch'),
    );
    expect(relevant.map((r) => r.story.id), ['title', 'body']);

    final chronological = filterSearchRecords(
      rows,
      const SearchRequest(familyId: _family, sort: SearchSort.chronological),
    );
    expect(chronological.map((r) => r.story.id), [
      'body',
      'unpublished-time',
      'late-publish',
      'title',
    ]);

    final recent = filterSearchRecords(
      rows,
      const SearchRequest(familyId: _family, sort: SearchSort.recentlyAdded),
    );
    expect(recent.map((r) => r.story.id), [
      'late-publish',
      'body',
      'title',
      'unpublished-time',
    ]);
  });

  test('decade chip label uses an en dash for a span', () {
    expect(decadeChipLabel(const [1980]), '1980s');
    expect(decadeChipLabel(const [1990, 1980]), '1980s–1990s');
    final bounds = decadeBounds(const [1980, 1990]);
    expect(bounds?.$1, DateTime(1980, 1, 1));
    expect(bounds?.$2, DateTime(1999, 12, 31));
  });

  test('a blank title is stored as absent', () {
    expect(storedStoryTitle(null), isNull);
    expect(storedStoryTitle('  '), isNull);
    expect(storedStoryTitle(' Porch '), 'Porch');
  });
}
