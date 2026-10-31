import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/all_stories/all_stories_logic.dart';

void main() {
  test('U-01 fromJson keeps address and person user ids', () {
    final story = Story.fromJson({
      'id': 's1',
      'family_id': 'F',
      'author_id': 'author',
      'title': 'Harbor',
      'body': 'A day on the water',
      'timeframe_start': '1987-03-04',
      'date_precision': 'day',
      'status': 'published',
      'place_id': 'p1',
      'places': {'label': ' Pier ', 'address': '  12 Dock St  '},
      'story_people': [
        {
          'person_id': 'a',
          'people': {'name': 'Ada', 'user_id': ' user-a '},
        },
        {
          'person_id': 'b',
          'people': {'name': 'Bea', 'user_id': '   '},
        },
        {
          'person_id': 'c',
          'people': {'name': 'Cy', 'user_id': null},
        },
        {
          'person_id': '',
          'people': {'name': 'Blank', 'user_id': 'user-blank'},
        },
      ],
    });

    expect(story.placeAddress, '12 Dock St');
    expect(story.placeLabel, 'Pier');
    expect(story.personUserIds, {'a': 'user-a'});
    expect(story.title, 'Harbor');
    expect(story.people.map((person) => person.id), ['a', 'b', 'c']);
  });

  test('U-02 decadeOf', () {
    expect(decadeOf(DateTime(1980, 1, 1)), 1980);
    expect(decadeOf(DateTime(1987, 3, 4)), 1980);
    expect(decadeOf(DateTime(1989, 12, 31)), 1980);
    expect(decadeOf(DateTime(2020, 5, 5)), 2020);
  });

  test('U-03 compareAllStories', () {
    final newer = _story('b', start: DateTime(1990), published: DateTime(2020));
    final older = _story('a', start: DateTime(1980), published: DateTime(2024));
    final tieLater = _story(
      'd',
      start: DateTime(1990),
      published: DateTime(2021),
    );
    final tieId = _story('c', start: DateTime(1990), published: DateTime(2021));
    final undated = _story('z', published: DateTime(2030));

    final sorted = [older, newer, tieId, tieLater, undated]
      ..sort(compareAllStories);
    expect(sorted.map((story) => story.id), ['c', 'd', 'b', 'a', 'z']);
  });

  test('U-04 decade precision sorts after a later year in the same decade', () {
    final decade = _story(
      'decade',
      start: DateTime(1980, 1, 1),
      precision: StoryDatePrecision.decade,
    );
    final year = _story(
      'year',
      start: DateTime(1987),
      precision: StoryDatePrecision.year,
    );
    final sorted = [decade, year]..sort(compareAllStories);
    expect(sorted.map((story) => story.id), ['year', 'decade']);
  });

  test('U-05 a null date is a last No date yet group', () {
    final groups = groupStories([_story('bare')], AllStoriesGroupBy.date);
    expect(groups, hasLength(1));
    expect(groups.single.key, '__none__');
    expect(groups.single.heading, 'No date yet');
  });

  test('U-06 date groups run newest decade first', () {
    final groups = groupStories([
      _story('old', start: DateTime(1991, 2, 2)),
      _story('new', start: DateTime(2020, 5, 5)),
    ], AllStoriesGroupBy.date);
    expect(groups.map((group) => group.heading), ['2020s', '1990s']);
    expect(groups.map((group) => group.key), ['2020', '1990']);
  });

  test('U-07 a story repeats under each person, A to Z', () {
    final shared = _story(
      'shared',
      people: const [(id: 'b', name: 'Bea'), (id: 'a', name: 'ada')],
      personUserIds: const {'a': 'user-a'},
    );
    final groups = groupStories([shared], AllStoriesGroupBy.member);
    expect(groups.map((group) => group.heading), ['ada', 'Bea']);
    expect(groups.map((group) => group.key), ['a', 'b']);
    expect(
      groups.every((group) => group.stories.single.id == 'shared'),
      isTrue,
    );
    expect(groups.first.personUserId, 'user-a');
  });

  test('U-08 stories with no people are last', () {
    final groups = groupStories([
      _story('none'),
      _story('tagged', people: const [(id: 'z', name: 'Zoe')]),
    ], AllStoriesGroupBy.member);
    expect(groups.last.heading, 'No one tagged');
    expect(groups.last.key, '__none__');
    expect(groups.last.stories.single.id, 'none');
  });

  test('U-09 places stay separate and No place yet is last', () {
    final groups = groupStories([
      _story('none'),
      _story(
        'same-b',
        placeId: 'p2',
        placeLabel: 'Pier',
        placeAddress: '2 Dock',
      ),
      _story(
        'same-a',
        placeId: 'p1',
        placeLabel: 'Pier',
        placeAddress: '1 Dock',
      ),
      _story('address-only', placeId: 'p3', placeAddress: '12 Oak'),
    ], AllStoriesGroupBy.place);
    expect(groups.map((group) => group.key), ['p3', 'p1', 'p2', '__none__']);
    expect(groups.map((group) => group.heading), [
      '12 Oak',
      'Pier',
      'Pier',
      'No place yet',
    ]);
    expect(groups[1].address, '1 Dock');
    expect(groups[2].address, '2 Dock');
    expect(groups.last.heading, 'No place yet');
  });

  test('U-10 two live branches sort A to Z and count as a spawn', () {
    final story = _story('s');
    final marks = spawnMarks(
      familyId: 'F',
      tree: [
        _tree('F', name: 'Morgans'),
        _tree('north', name: 'North', parent: 'F', origin: 's'),
        _tree('east', name: 'East', parent: 'F', origin: 's'),
      ],
      stories: [story],
    );
    final mark = marks['s']!;
    expect(mark.branches.map((row) => row.name), ['East', 'North']);
    expect(mark.startedTimeline, isTrue);
    expect(mark.isOrigin, isFalse);
  });

  test('U-11 the family origin is not inherited', () {
    final story = _story('origin', familyId: 'F');
    final marks = spawnMarks(
      familyId: 'F',
      tree: [_tree('F', name: 'Morgans', origin: 'origin')],
      stories: [story],
    );
    expect(marks['origin']!.isOrigin, isTrue);
    expect(marks['origin']!.inheritedFromName, isNull);
  });

  test('U-12 an inherited origin names the parent', () {
    final story = _story('origin', familyId: 'parent');
    final marks = spawnMarks(
      familyId: 'F',
      tree: [
        _tree('parent', name: 'Hart'),
        _tree('F', name: 'Morgans', parent: 'parent', origin: 'origin'),
      ],
      stories: [story],
    );
    expect(marks['origin']!.isOrigin, isTrue);
    expect(marks['origin']!.inheritedFromName, 'Hart');
  });

  test('U-13 a deleted branch is absent', () {
    final story = _story('s');
    final marks = spawnMarks(
      familyId: 'F',
      tree: [_tree('F', name: 'Morgans')],
      stories: [story],
    );
    expect(marks['s']!.branches, isEmpty);
    expect(marks['s']!.startedTimeline, isFalse);
  });

  test('U-14 search matches title, body, and people only', () {
    final story = _story(
      's',
      title: 'Harbor',
      body: 'Sarah walked',
      people: const [(id: 'p', name: 'Ada')],
      placeLabel: 'Pier',
      placeAddress: '1980s dock',
    );
    expect(matchesSearch(story, '  '), isTrue);
    expect(matchesSearch(story, 'harb'), isTrue);
    expect(matchesSearch(story, 'SARAH'), isTrue);
    expect(matchesSearch(story, 'ada'), isTrue);
    expect(matchesSearch(story, 'pier'), isFalse);
    expect(matchesSearch(story, '1980s'), isFalse);
  });

  test('U-15 a story stays undimmed only when every active filter passes', () {
    final story = _story('s', title: 'Ada');
    final spawn = const SpawnMark(isOrigin: true);
    final plain = const SpawnMark();

    bool undimmed({
      required String query,
      required bool toggle,
      required SpawnMark mark,
    }) {
      return isUndimmed(
        story,
        AllStoriesViewState(query: query, startedTimelineOnly: toggle),
        mark,
      );
    }

    expect(undimmed(query: '', toggle: false, mark: plain), isTrue);
    expect(undimmed(query: '', toggle: false, mark: spawn), isTrue);
    expect(undimmed(query: 'ada', toggle: false, mark: plain), isTrue);
    expect(undimmed(query: 'nope', toggle: false, mark: spawn), isFalse);
    expect(undimmed(query: '', toggle: true, mark: spawn), isTrue);
    expect(undimmed(query: '', toggle: true, mark: plain), isFalse);
    expect(undimmed(query: 'ada', toggle: true, mark: spawn), isTrue);
    expect(undimmed(query: 'ada', toggle: true, mark: plain), isFalse);
    expect(undimmed(query: 'nope', toggle: true, mark: spawn), isFalse);
  });

  test('U-16 status line uses the stamped strings', () {
    expect(
      statusLine(n: 1, total: 4, query: '', startedTimelineOnly: false),
      isNull,
    );
    expect(
      statusLine(n: 2, total: 4, query: ' sarah ', startedTimelineOnly: false),
      '2 of 4 stories match "sarah"',
    );
    expect(
      statusLine(n: 1, total: 4, query: '', startedTimelineOnly: true),
      '1 of 4 stories started a timeline',
    );
    expect(
      statusLine(n: 0, total: 4, query: 'sarah', startedTimelineOnly: true),
      '0 of 4 stories match "sarah" and started a timeline',
    );
  });
}

Story _story(
  String id, {
  String familyId = 'F',
  String? title,
  String? body,
  DateTime? start,
  DateTime? published,
  StoryDatePrecision precision = StoryDatePrecision.day,
  String? placeId,
  String? placeLabel,
  String? placeAddress,
  List<({String id, String name})> people = const [],
  Map<String, String> personUserIds = const {},
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'author',
    title: title,
    body: body,
    status: StoryStatus.published,
    timeframeStart: start,
    publishedAt: published,
    datePrecision: precision,
    placeId: placeId,
    placeLabel: placeLabel,
    placeAddress: placeAddress,
    people: people,
    personNames: [for (final person in people) person.name],
    personUserIds: personUserIds,
  );
}

TreeFamily _tree(
  String id, {
  required String name,
  String? parent,
  String? origin,
}) {
  return TreeFamily(
    id: id,
    name: name,
    parentFamilyId: parent,
    originStoryId: origin,
  );
}
