import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';

/// A place shared by the families of one tree (favorites + recents via
/// [isFavorite] / [lastUsedAt]).
class Place {
  const Place({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    required this.isFavorite,
    this.lastUsedAt,
  });

  final String id;
  final String label;
  final String address;
  final double lat;
  final double lng;
  final String? mapboxPlaceId;
  final bool isFavorite;
  final DateTime? lastUsedAt;

  factory Place.fromDto(server.PlaceDto dto) => Place(
    id: dto.id.toString(),
    label: dto.label,
    address: dto.address,
    lat: dto.lat,
    lng: dto.lng,
    mapboxPlaceId: dto.mapboxPlaceId,
    isFavorite: dto.isFavorite,
    lastUsedAt: dto.lastUsedAt,
  );
}

/// Rejects empty / whitespace-only label or address before network.
void ensureValidPlaceCreate({required String label, required String address}) {
  if (label.trim().isEmpty) {
    throw ArgumentError.value(label, 'label', 'must not be empty');
  }
  if (address.trim().isEmpty) {
    throw ArgumentError.value(address, 'address', 'must not be empty');
  }
}

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
    return rows.map(Place.fromDto).toList();
  }

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    final rows = await withServerErrors(
      () => _client.place.favorites(_uuid(familyId)),
    );
    return rows.map(Place.fromDto).toList();
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    final rows = await withServerErrors(
      () => _client.place.recents(_uuid(familyId), limit: limit),
    );
    return rows.map(Place.fromDto).toList();
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
    return Place.fromDto(row);
  }

  @override
  Future<Place> markUsed(String placeId) async {
    final row = await withServerErrors(
      () => _client.place.markUsed(_uuid(placeId)),
    );
    return Place.fromDto(row);
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    final row = await withServerErrors(
      () => _client.place.setFavorite(_uuid(placeId), isFavorite),
    );
    return Place.fromDto(row);
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async {
    final row = await withServerErrors(
      () => _client.place.findByMapboxId(_uuid(familyId), mapboxPlaceId),
    );
    return row == null ? null : Place.fromDto(row);
  }

  @override
  Future<Place?> getPlace(String id) async {
    final row = await withServerErrors(() => _client.place.get(_uuid(id)));
    return row == null ? null : Place.fromDto(row);
  }
}

server.UuidValue _uuid(String id) => server.UuidValue.fromString(id);
