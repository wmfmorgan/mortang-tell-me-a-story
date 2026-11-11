import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';
import 'package:tell_me_a_story/core/data/server_stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/features/search/domain/search_facets.dart';
import 'package:tell_me_a_story/features/search/domain/search_repository.dart';
import 'package:tell_me_a_story/features/search/domain/search_request.dart';
import 'package:tell_me_a_story/features/search/domain/search_sort.dart';

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

/// [dto] as app [SearchFacets], keeping the server order.
SearchFacets searchFacetsFromDto(server.StoryFacetsDto dto) => SearchFacets(
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
    return [for (final dto in rows) storyFromDto(dto)];
  }

  @override
  Future<SearchFacets> facets(String familyId) async => searchFacetsFromDto(
    await withServerErrors(
      () => _client.story.facets(server.UuidValue.fromString(familyId)),
    ),
  );
}
