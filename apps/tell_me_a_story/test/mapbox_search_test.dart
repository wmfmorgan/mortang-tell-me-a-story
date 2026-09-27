import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';

/// Minimal Mapbox Geocoding FeatureCollection fixture (no live network).
final Map<String, dynamic> _fixtureFeatureCollection = {
  'type': 'FeatureCollection',
  'features': <Map<String, dynamic>>[
    {
      'id': 'poi.123',
      'type': 'Feature',
      'text': 'Central Park',
      'place_name': 'Central Park, New York, New York 10024, United States',
      'center': <double>[-73.9654, 40.7829],
      'geometry': {
        'type': 'Point',
        'coordinates': <double>[-73.9654, 40.7829],
      },
    },
    {
      'id': 'place.456',
      'type': 'Feature',
      'text': 'Brooklyn',
      'place_name': 'Brooklyn, New York, United States',
      'center': <double>[-73.9442, 40.6782],
    },
  ],
};

void main() {
  group('MapboxSearchHit.fromFeature', () {
    test('maps id, text→label, place_name→address, center→lng/lat', () {
      final features =
          _fixtureFeatureCollection['features'] as List<Map<String, dynamic>>;
      final hit = MapboxSearchHit.fromFeature(features[0]);

      expect(hit.id, 'poi.123');
      expect(hit.label, 'Central Park');
      expect(hit.address, 'Central Park, New York, New York 10024, United States');
      expect(hit.label, isNot(hit.address));
      expect(hit.lng, -73.9654);
      expect(hit.lat, 40.7829);
    });

    test('falls back address to text when place_name missing', () {
      final hit = MapboxSearchHit.fromFeature({
        'id': 'poi.1',
        'text': 'Park',
        'center': [1.0, 2.0],
      });

      expect(hit.label, 'Park');
      expect(hit.address, 'Park');
    });

    test('falls back label to place_name when text missing', () {
      final hit = MapboxSearchHit.fromFeature({
        'id': 'poi.2',
        'place_name': 'Full Name, City',
        'center': [3.0, 4.0],
      });

      expect(hit.label, 'Full Name, City');
      expect(hit.address, 'Full Name, City');
    });
  });

  group('parseMapboxFeatureCollection', () {
    test('parses fixture features into separate label/address hits', () {
      final hits = parseMapboxFeatureCollection(_fixtureFeatureCollection);

      expect(hits, hasLength(2));
      expect(hits[0].id, 'poi.123');
      expect(hits[0].label, 'Central Park');
      expect(hits[0].address,
          'Central Park, New York, New York 10024, United States');
      expect(hits[1].id, 'place.456');
      expect(hits[1].label, 'Brooklyn');
      expect(hits[1].address, 'Brooklyn, New York, United States');
    });

    test('returns empty list when features is empty', () {
      expect(
        parseMapboxFeatureCollection({
          'type': 'FeatureCollection',
          'features': <dynamic>[],
        }),
        isEmpty,
      );
    });
  });

  group('MapboxSearchApi', () {
    test('GETs geocoding URL with encoded query, token, and limit', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(_fixtureFeatureCollection), 200);
      });

      final api = MapboxSearchApi(
        client: client,
        accessToken: 'pk.test_token_value_long_enough',
      );
      final hits = await api.search('Central Park', limit: 5);

      expect(requested, isNotNull);
      expect(
        requested!.path,
        '/geocoding/v5/mapbox.places/Central%20Park.json',
      );
      expect(requested!.scheme, 'https');
      expect(requested!.host, 'api.mapbox.com');
      expect(requested!.queryParameters['access_token'],
          'pk.test_token_value_long_enough');
      expect(requested!.queryParameters['limit'], '5');
      expect(hits, hasLength(2));
      expect(hits.first.label, 'Central Park');
      expect(hits.first.address,
          'Central Park, New York, New York 10024, United States');
    });

    test('returns empty list for blank query without calling network',
        () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });

      final api = MapboxSearchApi(
        client: client,
        accessToken: 'pk.test_token_value_long_enough',
      );
      final hits = await api.search('   ');

      expect(called, isFalse);
      expect(hits, isEmpty);
    });

    test('throws MapboxSearchException on missing/implausible token', () async {
      final api = MapboxSearchApi(
        client: MockClient((_) async => http.Response('{}', 200)),
        accessToken: '...',
      );

      expect(
        () => api.search('park'),
        throwsA(isA<MapboxSearchException>()),
      );
    });

    test('throws MapboxSearchException on empty token', () async {
      final api = MapboxSearchApi(
        client: MockClient((_) async => http.Response('{}', 200)),
        accessToken: '',
      );

      expect(
        () => api.search('park'),
        throwsA(isA<MapboxSearchException>()),
      );
    });

    test('throws MapboxSearchException on non-200', () async {
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final api = MapboxSearchApi(
        client: client,
        accessToken: 'pk.test_token_value_long_enough',
      );

      expect(
        () => api.search('park'),
        throwsA(
          isA<MapboxSearchException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });
}
