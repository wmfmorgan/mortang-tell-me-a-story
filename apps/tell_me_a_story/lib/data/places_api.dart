import 'package:supabase_flutter/supabase_flutter.dart';

/// Family-scoped place row (favorites + recents via [isFavorite] / [lastUsedAt]).
class Place {
  const Place({
    required this.id,
    required this.familyId,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    this.mapboxPlaceId,
    required this.isFavorite,
    this.lastUsedAt,
  });

  final String id;
  final String familyId;
  final String label;
  final String address;
  final double lat;
  final double lng;
  final String? mapboxPlaceId;
  final bool isFavorite;
  final DateTime? lastUsedAt;

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      label: json['label'] as String,
      address: json['address'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      mapboxPlaceId: json['mapbox_place_id'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.parse(json['last_used_at'] as String)
          : null,
    );
  }
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

/// Insert payload for `places`. Keeps [label] and [address] as separate columns.
Map<String, dynamic> buildPlaceInsert({
  required String familyId,
  required String label,
  required String address,
  required double lat,
  required double lng,
  String? mapboxPlaceId,
  bool isFavorite = false,
  required DateTime lastUsedAt,
}) {
  return {
    'family_id': familyId,
    'label': label.trim(),
    'address': address.trim(),
    'lat': lat,
    'lng': lng,
    if (mapboxPlaceId != null) 'mapbox_place_id': mapboxPlaceId,
    'is_favorite': isFavorite,
    'last_used_at': lastUsedAt.toUtc().toIso8601String(),
  };
}

abstract class PlacesGateway {
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

/// PostgREST CRUD gateway for family-scoped `places` rows.
class PlacesApi implements PlacesGateway {
  PlacesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _columns =
      'id, family_id, label, address, lat, lng, mapbox_place_id, is_favorite, last_used_at';

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    final rows = await _client
        .from('places')
        .select(_columns)
        .eq('family_id', familyId)
        .eq('is_favorite', true)
        .order('label');
    return rows.map(Place.fromJson).toList();
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    final rows = await _client
        .from('places')
        .select(_columns)
        .eq('family_id', familyId)
        .not('last_used_at', 'is', null)
        .order('last_used_at', ascending: false)
        .limit(limit);
    return rows.map(Place.fromJson).toList();
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
    final payload = buildPlaceInsert(
      familyId: familyId,
      label: label,
      address: address,
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
      lastUsedAt: DateTime.now().toUtc(),
    );
    final row = await _client
        .from('places')
        .insert(payload)
        .select(_columns)
        .single();
    return Place.fromJson(row);
  }

  @override
  Future<Place> markUsed(String placeId) async {
    final row = await _client
        .from('places')
        .update({'last_used_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', placeId)
        .select(_columns)
        .single();
    return Place.fromJson(row);
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    final row = await _client
        .from('places')
        .update({'is_favorite': isFavorite})
        .eq('id', placeId)
        .select(_columns)
        .single();
    return Place.fromJson(row);
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async {
    final row = await _client
        .from('places')
        .select(_columns)
        .eq('family_id', familyId)
        .eq('mapbox_place_id', mapboxPlaceId)
        .maybeSingle();
    if (row == null) return null;
    return Place.fromJson(row);
  }

  @override
  Future<Place?> getPlace(String id) async {
    final row = await _client
        .from('places')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Place.fromJson(row);
  }
}
