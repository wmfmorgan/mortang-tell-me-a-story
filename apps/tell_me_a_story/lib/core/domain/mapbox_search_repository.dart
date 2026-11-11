import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/mapbox_search_hit.dart';

part 'mapbox_search_repository.g.dart';

abstract class MapboxSearchRepository {
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5});
}

@Riverpod(keepAlive: true)
MapboxSearchRepository mapboxSearchRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
