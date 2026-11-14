import 'package:tell_me_a_story/data/mapbox_search.dart';

class FakeMapboxSearch implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}
