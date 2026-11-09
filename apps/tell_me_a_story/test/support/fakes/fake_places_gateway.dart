import 'package:tell_me_a_story/data/places_api.dart';

/// In-memory [PlacesGateway] for widget tests. [places] is the store (one
/// tree); every call is appended to [calls] as its method name. Set
/// [createError] to make [createPlace] throw it. Subclass and override a
/// method for anything else.
class FakePlacesGateway implements PlacesGateway {
  FakePlacesGateway({Iterable<Place> places = const [], DateTime? now})
    : places = [...places],
      now = now ?? DateTime.utc(2026, 11, 1);

  final List<Place> places;

  /// `lastUsedAt` that [markUsed] stamps.
  final DateTime now;

  final calls = <String>[];
  Object? createError;

  @override
  Future<List<Place>> listPlaces(String familyId) async {
    calls.add('listPlaces');
    return [...places];
  }

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    calls.add('listFavorites');
    return [
      for (final place in places)
        if (place.isFavorite) place,
    ];
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    calls.add('listRecents');
    final used = [
      for (final place in places)
        if (place.lastUsedAt != null) place,
    ]..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return used.take(limit).toList();
  }

  @override
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  }) async {
    calls.add('createPlace');
    final error = createError;
    if (error != null) throw error;
    final place = Place(
      id: 'place-${places.length + 1}',
      label: label,
      address: address,
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
    );
    places.add(place);
    return place;
  }

  @override
  Future<Place> markUsed(String placeId) async {
    calls.add('markUsed');
    return _replace(placeId, lastUsedAt: now);
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    calls.add('setFavorite');
    return _replace(placeId, isFavorite: isFavorite);
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async {
    calls.add('findByMapboxPlaceId');
    for (final place in places) {
      if (place.mapboxPlaceId == mapboxPlaceId) return place;
    }
    return null;
  }

  @override
  Future<Place?> getPlace(String id) async {
    calls.add('getPlace');
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  Place _replace(String placeId, {DateTime? lastUsedAt, bool? isFavorite}) {
    final index = places.indexWhere((place) => place.id == placeId);
    if (index == -1) throw StateError('no place $placeId');
    final old = places[index];
    return places[index] = Place(
      id: old.id,
      label: old.label,
      address: old.address,
      lat: old.lat,
      lng: old.lng,
      mapboxPlaceId: old.mapboxPlaceId,
      isFavorite: isFavorite ?? old.isFavorite,
      lastUsedAt: lastUsedAt ?? old.lastUsedAt,
    );
  }
}
