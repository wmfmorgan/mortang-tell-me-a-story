import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:tell_me_a_story/core/env.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_exception.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_hit.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_repository.dart';

/// HTTP client for Mapbox Geocoding API v5 (public token).
class ServerMapboxSearchRepository implements MapboxSearchRepository {
  ServerMapboxSearchRepository({http.Client? client, String? accessToken})
    : _client = client ?? http.Client(),
      _accessToken = accessToken ?? Env.mapboxAccessToken;

  final http.Client _client;
  final String _accessToken;

  static const _baseHost = 'api.mapbox.com';

  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    if (!Env.isPlausibleMapboxToken(_accessToken)) {
      throw MapboxSearchException('Mapbox access token missing or implausible');
    }

    // encodeComponent so `/` and spaces stay a single path segment (not Uri.https).
    final uri =
        Uri.parse(
          'https://$_baseHost/geocoding/v5/mapbox.places/'
          '${Uri.encodeComponent(trimmed)}.json',
        ).replace(
          queryParameters: {'access_token': _accessToken, 'limit': '$limit'},
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
