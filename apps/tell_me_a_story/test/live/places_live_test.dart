@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server_places_repository.dart';

import 'support/live_server.dart';

void main() {
  setUpAll(waitForLiveServer);

  test(
    'places: create, favorite, markUsed, recents, list, find, get',
    () async {
      await signInLive(freshEmail('places'));
      final familyId = (await serverClient.family.createRoot('Places'))
          .toString();
      final api = ServerPlacesRepository();

      final park = await api.createPlace(
        familyId: familyId,
        label: '  Central Park  ',
        address: ' New York, NY ',
        lat: 40.78,
        lng: -73.96,
        mapboxPlaceId: 'poi.park',
      );
      expect(park.label, 'Central Park');
      expect(park.address, 'New York, NY');
      expect(park.mapboxPlaceId, 'poi.park');
      expect(park.isFavorite, isFalse);
      expect(park.lastUsedAt, isNotNull);

      final again = await api.createPlace(
        familyId: familyId,
        label: 'Park again',
        address: 'Elsewhere',
        lat: 1,
        lng: 2,
        mapboxPlaceId: 'poi.park',
      );
      expect(again.id, park.id);

      final home = await api.createPlace(
        familyId: familyId,
        label: 'Home',
        address: '1 Main St',
        lat: 1,
        lng: 2,
        isFavorite: true,
      );
      expect(home.isFavorite, isTrue);

      final favored = await api.setFavorite(placeId: park.id, isFavorite: true);
      expect(favored.isFavorite, isTrue);
      expect((await api.listFavorites(familyId)).map((p) => p.label), [
        'Central Park',
        'Home',
      ]);

      final used = await api.markUsed(park.id);
      expect(used.lastUsedAt!.isAfter(home.lastUsedAt!), isTrue);
      final recents = await api.listRecents(familyId, limit: 1);
      expect(recents.single.id, park.id);

      expect((await api.listPlaces(familyId)).map((p) => p.label), [
        'Central Park',
        'Home',
      ]);
      expect(
        (await api.findByMapboxPlaceId(familyId, 'poi.park'))!.id,
        park.id,
      );
      expect(await api.findByMapboxPlaceId(familyId, 'poi.none'), isNull);
      expect((await api.getPlace(home.id))!.address, '1 Main St');
    },
  );
}
