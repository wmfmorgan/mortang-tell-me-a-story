import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/env.dart';

/// One Mapbox Geocoding feature, split for place persistence (label ≠ address).
class MapboxSearchHit {
  const MapboxSearchHit({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
  });

  /// Feature id → `places.mapbox_place_id`.
  final String id;

  /// Prefer feature `text` (short name) → `places.label`.
  final String label;

  /// Prefer full `place_name` → `places.address`.
  final String address;

  final double lat;
  final double lng;

  factory MapboxSearchHit.fromFeature(Map<String, dynamic> feature) {
    final text = feature['text'] as String?;
    final placeName = feature['place_name'] as String?;
    final label = (text != null && text.isNotEmpty)
        ? text
        : (placeName ?? '');
    final address = (placeName != null && placeName.isNotEmpty)
        ? placeName
        : label;

    final center = feature['center'];
    late final double lng;
    late final double lat;
    if (center is List && center.length >= 2) {
      lng = (center[0] as num).toDouble();
      lat = (center[1] as num).toDouble();
    } else {
      final geometry = feature['geometry'];
      final coords = geometry is Map ? geometry['coordinates'] : null;
      if (coords is! List || coords.length < 2) {
        throw FormatException('Mapbox feature missing center coordinates');
      }
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }

    return MapboxSearchHit(
      id: feature['id'] as String,
      label: label,
      address: address,
      lat: lat,
      lng: lng,
    );
  }
}

/// Typed failure for missing token or non-200 geocode responses.
class MapboxSearchException implements Exception {
  MapboxSearchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (status $statusCode)';
}

/// Parses a Mapbox Geocoding FeatureCollection JSON object.
List<MapboxSearchHit> parseMapboxFeatureCollection(Map<String, dynamic> json) {
  final features = json['features'];
  if (features is! List) return const [];
  return features
      .whereType<Map>()
      .map((f) => MapboxSearchHit.fromFeature(Map<String, dynamic>.from(f)))
      .toList();
}

abstract class MapboxSearchGateway {
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5});
}

/// HTTP client for Mapbox Geocoding API v5 (public token).
class MapboxSearchApi implements MapboxSearchGateway {
  MapboxSearchApi({
    http.Client? client,
    String? accessToken,
  })  : _client = client ?? http.Client(),
        _accessToken = accessToken ?? Env.mapboxAccessToken;

  final http.Client _client;
  final String _accessToken;

  static const _baseHost = 'api.mapbox.com';

  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    if (!Env.isPlausibleMapboxToken(_accessToken)) {
      throw MapboxSearchException(
        'Mapbox access token missing or implausible',
      );
    }

    // encodeComponent so `/` and spaces stay a single path segment (not Uri.https).
    final uri = Uri.parse(
      'https://$_baseHost/geocoding/v5/mapbox.places/'
      '${Uri.encodeComponent(trimmed)}.json',
    ).replace(
      queryParameters: {
        'access_token': _accessToken,
        'limit': '$limit',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw MapboxSearchException(
        'Mapbox geocoding failed',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw MapboxSearchException('Unexpected Mapbox geocoding response');
    }
    return parseMapboxFeatureCollection(Map<String, dynamic>.from(decoded));
  }
}
