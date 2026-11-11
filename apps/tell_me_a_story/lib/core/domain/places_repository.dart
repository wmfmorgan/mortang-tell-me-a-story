import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/place.dart';

part 'places_repository.g.dart';

abstract class PlacesRepository {
  Future<List<Place>> listPlaces(String familyId);
  Future<List<Place>> listFavorites(String familyId);
  Future<List<Place>> listRecents(String familyId, {int limit = 10});
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  });
  Future<Place> markUsed(String placeId);
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  });
  Future<Place?> findByMapboxPlaceId(String familyId, String mapboxPlaceId);
  Future<Place?> getPlace(String id);
}

@Riverpod(keepAlive: true)
PlacesRepository placesRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
