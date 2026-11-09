import 'package:tell_me_a_story/data/mapbox_search.dart';

/// [MapboxSearchGateway] that returns [hits] (at most `limit`) for every
/// query and records the queries. Set [error] to make [search] throw it.
class FakeMapboxSearch implements MapboxSearchGateway {
  FakeMapboxSearch({this.hits = const []});

  List<MapboxSearchHit> hits;
  Object? error;
  final queries = <String>[];

  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async {
    queries.add(query);
    final thrown = error;
    if (thrown != null) throw thrown;
    return hits.take(limit).toList();
  }
}
