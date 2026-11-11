import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:tell_me_a_story/core/domain/mapbox_feature.dart';

part 'mapbox_search_hit.freezed.dart';

/// One Mapbox Geocoding feature, split for place persistence (label ≠ address).
@freezed
abstract class MapboxSearchHit with _$MapboxSearchHit {
  const factory MapboxSearchHit({
    /// Feature id → `places.mapbox_place_id`.
    required String id,

    /// Prefer feature `text` (short name) → `places.label`.
    required String label,

    /// Prefer full `place_name` → `places.address`.
    required String address,
    required double lat,
    required double lng,
  }) = _MapboxSearchHit;

  factory MapboxSearchHit.fromFeature(Map<String, dynamic> feature) =>
      MapboxSearchHit.fromMapboxFeature(MapboxFeature.fromJson(feature));

  factory MapboxSearchHit.fromMapboxFeature(MapboxFeature feature) {
    final text = feature.text;
    final placeName = feature.placeName;
    final label = (text != null && text.isNotEmpty) ? text : (placeName ?? '');
    final address = (placeName != null && placeName.isNotEmpty)
        ? placeName
        : label;

    final center = feature.center;
    late final double lng;
    late final double lat;
    if (center is List && center.length >= 2) {
      lng = (center[0] as num).toDouble();
      lat = (center[1] as num).toDouble();
    } else {
      final geometry = feature.geometry;
      final coords = geometry is Map ? geometry['coordinates'] : null;
      if (coords is! List || coords.length < 2) {
        throw const FormatException(
          'Mapbox feature missing center coordinates',
        );
      }
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }

    return MapboxSearchHit(
      id: feature.id,
      label: label,
      address: address,
      lat: lat,
      lng: lng,
    );
  }
}

/// Parses a Mapbox Geocoding FeatureCollection JSON object.
List<MapboxSearchHit> parseMapboxFeatureCollection(Map<String, dynamic> json) {
  final features = json['features'];
  if (features is! List) return const [];
  return features
      .whereType<Map<dynamic, dynamic>>()
      .map((f) => MapboxSearchHit.fromFeature(Map<String, dynamic>.from(f)))
      .toList();
}
