import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/place.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';

/// [dto] as an app [Place].
Place placeFromDto(server.PlaceDto dto) => Place(
  id: dto.id.toString(),
  label: dto.label,
  address: dto.address,
  lat: dto.lat,
  lng: dto.lng,
  mapboxPlaceId: dto.mapboxPlaceId,
  isFavorite: dto.isFavorite,
  lastUsedAt: dto.lastUsedAt,
);

/// Create payload for `place.create`. Keeps [label] and [address] separate.
server.PlaceInputDto placeInput({
  required String label,
  required String address,
  required double lat,
  required double lng,
  String? mapboxPlaceId,
  bool isFavorite = false,
}) => server.PlaceInputDto(
  label: label.trim(),
  address: address.trim(),
  lat: lat,
  lng: lng,
  mapboxPlaceId: mapboxPlaceId,
  isFavorite: isFavorite,
);

/// Places of [familyId]'s tree through the `place` endpoint.
class ServerPlacesRepository implements PlacesRepository {
  ServerPlacesRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Place>> listPlaces(String familyId) async {
    final rows = await withServerErrors(
      () => _client.place.list(_uuid(familyId)),
    );
    return rows.map(placeFromDto).toList();
  }

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    final rows = await withServerErrors(
      () => _client.place.favorites(_uuid(familyId)),
    );
    return rows.map(placeFromDto).toList();
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    final rows = await withServerErrors(
      () => _client.place.recents(_uuid(familyId), limit: limit),
    );
    return rows.map(placeFromDto).toList();
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
    ensureValidPlaceCreate(label: label, address: address);
    final input = placeInput(
      label: label,
      address: address,
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
    );
    final row = await withServerErrors(
      () => _client.place.create(_uuid(familyId), input),
    );
    return placeFromDto(row);
  }

  @override
  Future<Place> markUsed(String placeId) async {
    final row = await withServerErrors(
      () => _client.place.markUsed(_uuid(placeId)),
    );
    return placeFromDto(row);
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    final row = await withServerErrors(
      () => _client.place.setFavorite(_uuid(placeId), isFavorite),
    );
    return placeFromDto(row);
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async {
    final row = await withServerErrors(
      () => _client.place.findByMapboxId(_uuid(familyId), mapboxPlaceId),
    );
    return row == null ? null : placeFromDto(row);
  }

  @override
  Future<Place?> getPlace(String id) async {
    final row = await withServerErrors(() => _client.place.get(_uuid(id)));
    return row == null ? null : placeFromDto(row);
  }
}

server.UuidValue _uuid(String id) => server.UuidValue.fromString(id);
