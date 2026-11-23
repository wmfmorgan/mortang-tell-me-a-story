import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';

void main() {
  test('person filter matches personIds when people is empty', () {
    const filter = ThreadFilter(personIds: {'ada'});
    expect(
      filter.matches(_s('origin', 1984, personIds: const ['ada'])),
      isTrue,
    );
    expect(filter.matches(_s('other', 1984, personIds: const ['cy'])), isFalse);
  });

  test('or within people', () {
    const filter = ThreadFilter(personIds: {'ada', 'ben'});
    expect(filter.matches(_s('1', 1990, people: [_p('ada')])), isTrue);
    expect(filter.matches(_s('2', 1991, people: [_p('ben')])), isTrue);
    expect(
      filter.matches(_s('3', 1992, people: [_p('ada'), _p('cy')])),
      isTrue,
    );
    expect(filter.matches(_s('4', 1993, people: [_p('cy')])), isFalse);
  });

  test('and across categories', () {
    const filter = ThreadFilter(personIds: {'ada'}, placeIds: {'farm'});
    expect(
      filter.matches(_s('1', 1990, people: [_p('ada')], placeId: 'farm')),
      isTrue,
    );
    expect(
      filter.matches(_s('2', 1990, people: [_p('ada')], placeId: 'town')),
      isFalse,
    );
    expect(
      filter.matches(_s('3', 1990, people: [_p('cy')], placeId: 'farm')),
      isFalse,
    );
  });

  test('search is anded', () {
    const filter = ThreadFilter(personIds: {'ada'}, search: 'tractor');
    expect(
      filter.matches(_s('1', 1990, title: 'The tractor', people: [_p('ada')])),
      isTrue,
    );
    expect(
      filter.matches(_s('2', 1990, title: 'The barn', people: [_p('ada')])),
      isFalse,
    );
    expect(
      filter.matches(_s('3', 1990, title: 'The tractor', people: [_p('cy')])),
      isFalse,
    );
  });

  test('decade range inclusive', () {
    const filter = ThreadFilter(decadeFrom: 1990, decadeTo: 2000);
    expect(filter.matches(_s('a', 1990)), isTrue);
    expect(filter.matches(_s('b', 1999)), isTrue);
    expect(filter.matches(_s('c', 2000)), isTrue);
    expect(filter.matches(_s('d', 2009)), isTrue);
    expect(filter.matches(_s('e', 1989)), isFalse);
    expect(filter.matches(_s('f', 2010)), isFalse);
  });

  test('activeCount counts a range as one', () {
    const range = ThreadFilter(
      personIds: {'ada', 'ben'},
      decadeFrom: 1960,
      decadeTo: 1990,
    );
    expect(range.activeCount, 3);
    expect(ThreadFilter(decadeFrom: 1960, decadeTo: 1990).activeCount, 1);
  });

  test('cleared has no active filters', () {
    expect(ThreadFilter.cleared.activeCount, 0);
    expect(ThreadFilter.cleared.isActive, isFalse);
    expect(
      ThreadFilter.cleared.matches(_s('a', 1972, title: 'Picnic')),
      isTrue,
    );
  });

  test('n of N counts matches over all stories', () {
    const filter = ThreadFilter(decadeFrom: 1980, decadeTo: 1980);
    final stories = [
      _s('1', 1982),
      _s('2', 1988),
      _s('3', 1991),
      _s('4', 1979),
      _s('5', 1980),
    ];
    expect(filter.countStories(stories), (n: 3, total: 5));
  });
}

({String id, String name}) _p(String id) => (id: id, name: id);

Story _s(
  String id,
  int year, {
  String? title,
  String? placeId,
  List<String>? personIds,
  List<({String id, String name})> people = const [],
}) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    title: title,
    placeId: placeId,
    personIds: personIds ?? [for (final person in people) person.id],
    people: people,
  );
}
