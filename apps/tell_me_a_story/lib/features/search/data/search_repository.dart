import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';

enum SearchSort { relevant, chronological, recentlyAdded }

class SearchRequest {
  const SearchRequest({
    required this.familyId,
    this.text = '',
    this.personIds = const [],
    this.placeId,
    this.rangeStart,
    this.rangeEnd,
    this.decades = const [],
    this.sort = SearchSort.relevant,
  });

  final String familyId;
  final String text;
  final List<String> personIds;
  final String? placeId;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final List<int> decades;
  final SearchSort sort;
}

/// [request] as the server's search query.
server.StorySearchDto searchDto(SearchRequest request) {
  final placeId = request.placeId;
  return server.StorySearchDto(
    familyId: server.UuidValue.fromString(request.familyId),
    text: request.text,
    personIds: [
      for (final id in request.personIds) server.UuidValue.fromString(id),
    ],
    placeId: placeId == null ? null : server.UuidValue.fromString(placeId),
    rangeStart: toWireDate(request.rangeStart),
    rangeEnd: toWireDate(request.rangeEnd),
    decades: request.decades,
    sort: switch (request.sort) {
      SearchSort.relevant => server.SearchSort.relevant,
      SearchSort.chronological => server.SearchSort.chronological,
      SearchSort.recentlyAdded => server.SearchSort.recentlyAdded,
    },
  );
}

/// What a family's published stories can be filtered by. Each entry has at
/// least one story: decade starts ascending, people by name, places by label.
class SearchFacets {
  const SearchFacets({
    this.decades = const [],
    this.people = const [],
    this.places = const [],
  });

  factory SearchFacets.fromDto(server.StoryFacetsDto dto) => SearchFacets(
    decades: [for (final facet in dto.decades) facet.decade],
    people: [
      for (final facet in dto.people)
        (id: facet.personId.toString(), name: facet.name),
    ],
    places: [
      for (final facet in dto.places)
        (id: facet.placeId.toString(), label: facet.label),
    ],
  );

  final List<int> decades;
  final List<({String id, String name})> people;
  final List<({String id, String label})> places;
}

/// Chip label for one decade or a span, using an en dash between the ends.
String decadeChipLabel(List<int> startYears) {
  if (startYears.isEmpty) return '';
  final sorted = [...startYears]..sort();
  if (sorted.length == 1) return '${sorted.first}s';
  return '${sorted.first}s–${sorted.last}s';
}

abstract class SearchRepository {
  /// Published stories of `request.familyId` matching every filter and the
  /// text, in the requested order.
  Future<List<Story>> search(SearchRequest request);

  /// The decades, people and places of [familyId]'s published stories.
  Future<SearchFacets> facets(String familyId);
}

/// Search on the server's `story.search` and `story.facets`.
class ServerSearchRepository implements SearchRepository {
  ServerSearchRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Story>> search(SearchRequest request) async {
    final rows = await withServerErrors(
      () => _client.story.search(searchDto(request)),
    );
    return [for (final dto in rows) Story.fromDto(dto)];
  }

  @override
  Future<SearchFacets> facets(String familyId) async => SearchFacets.fromDto(
    await withServerErrors(
      () => _client.story.facets(server.UuidValue.fromString(familyId)),
    ),
  );
}
