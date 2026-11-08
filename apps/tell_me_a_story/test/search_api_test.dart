import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/search_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

server.UuidValue _uuid(int n) => server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-${n.toString().padLeft(12, '0')}',
);

void main() {
  group('searchDto', () {
    test('sends ids, the range as wire dates, decades and sort', () {
      final dto = searchDto(
        SearchRequest(
          familyId: _uuid(1).toString(),
          text: ' porch ',
          personIds: [_uuid(2).toString(), _uuid(3).toString()],
          placeId: _uuid(4).toString(),
          rangeStart: DateTime(1980),
          rangeEnd: DateTime(1989, 12, 31),
          decades: const [1980, 1990],
          sort: SearchSort.recentlyAdded,
        ),
      );

      expect(dto.familyId, _uuid(1));
      expect(dto.text, ' porch ');
      expect(dto.personIds, [_uuid(2), _uuid(3)]);
      expect(dto.placeId, _uuid(4));
      expect(dto.rangeStart, DateTime.utc(1980));
      expect(dto.rangeEnd, DateTime.utc(1989, 12, 31));
      expect(dto.decades, [1980, 1990]);
      expect(dto.sort, server.SearchSort.recentlyAdded);
    });

    test('an empty request has no filters and sorts by relevance', () {
      final dto = searchDto(SearchRequest(familyId: _uuid(1).toString()));

      expect(dto.text, '');
      expect(dto.personIds, isEmpty);
      expect(dto.placeId, isNull);
      expect(dto.rangeStart, isNull);
      expect(dto.rangeEnd, isNull);
      expect(dto.decades, isEmpty);
      expect(dto.sort, server.SearchSort.relevant);
    });

    test('each sort maps to the server sort', () {
      server.SearchSort sent(SearchSort sort) =>
          searchDto(SearchRequest(familyId: _uuid(1).toString(), sort: sort))
              .sort;

      expect(sent(SearchSort.relevant), server.SearchSort.relevant);
      expect(sent(SearchSort.chronological), server.SearchSort.chronological);
      expect(sent(SearchSort.recentlyAdded), server.SearchSort.recentlyAdded);
    });
  });

  test('SearchFacets.fromDto keeps the server order', () {
    final facets = SearchFacets.fromDto(
      server.StoryFacetsDto(
        decades: [
          server.DecadeFacetDto(decade: 1960, storyCount: 1),
          server.DecadeFacetDto(decade: 1980, storyCount: 3),
        ],
        people: [
          server.PersonFacetDto(personId: _uuid(2), name: 'Ada', storyCount: 2),
          server.PersonFacetDto(personId: _uuid(3), name: 'Bea', storyCount: 1),
        ],
        places: [
          server.PlaceFacetDto(
            placeId: _uuid(4),
            label: 'Back Porch',
            storyCount: 2,
          ),
        ],
      ),
    );

    expect(facets.decades, [1960, 1980]);
    expect(facets.people, [
      (id: _uuid(2).toString(), name: 'Ada'),
      (id: _uuid(3).toString(), name: 'Bea'),
    ]);
    expect(facets.places, [(id: _uuid(4).toString(), label: 'Back Porch')]);
  });

  test('decade chip label uses an en dash for a span', () {
    expect(decadeChipLabel(const [1980]), '1980s');
    expect(decadeChipLabel(const [1990, 1980]), '1980s–1990s');
  });

  test('a blank title is stored as absent', () {
    expect(storedStoryTitle(null), isNull);
    expect(storedStoryTitle('  '), isNull);
    expect(storedStoryTitle(' Porch '), 'Porch');
  });
}
