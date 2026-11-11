import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/features/search/domain/search_facets.dart';
import 'package:tell_me_a_story/features/search/domain/search_request.dart';

part 'search_repository.g.dart';

abstract class SearchRepository {
  /// Published stories of `request.familyId` matching every filter and the
  /// text, in the requested order.
  Future<List<Story>> search(SearchRequest request);

  /// The decades, people and places of [familyId]'s published stories.
  Future<SearchFacets> facets(String familyId);
}

@Riverpod(keepAlive: true)
SearchRepository searchRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
