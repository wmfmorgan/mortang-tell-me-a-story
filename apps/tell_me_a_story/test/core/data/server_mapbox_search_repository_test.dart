import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tell_me_a_story/core/data/server_mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_exception.dart';

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
  group('ServerMapboxSearchRepository', () {
    test('GETs geocoding URL with encoded query, token, and limit', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(_fixtureFeatureCollection), 200);
      });

      final api = ServerMapboxSearchRepository(
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
      expect(
        requested!.queryParameters['access_token'],
        'pk.test_token_value_long_enough',
      );
      expect(requested!.queryParameters['limit'], '5');
      expect(hits, hasLength(2));
      expect(hits.first.label, 'Central Park');
      expect(
        hits.first.address,
        'Central Park, New York, New York 10024, United States',
      );
    });

    test(
      'returns empty list for blank query without calling network',
      () async {
        var called = false;
        final client = MockClient((request) async {
          called = true;
          return http.Response('[]', 200);
        });

        final api = ServerMapboxSearchRepository(
          client: client,
          accessToken: 'pk.test_token_value_long_enough',
        );
        final hits = await api.search('   ');

        expect(called, isFalse);
        expect(hits, isEmpty);
      },
    );

    test('throws MapboxSearchException on missing/implausible token', () async {
      final api = ServerMapboxSearchRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
        accessToken: '...',
      );

      expect(() => api.search('park'), throwsA(isA<MapboxSearchException>()));
    });

    test('throws MapboxSearchException on empty token', () async {
      final api = ServerMapboxSearchRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
        accessToken: '',
      );

      expect(() => api.search('park'), throwsA(isA<MapboxSearchException>()));
    });

    test('throws MapboxSearchException on non-200', () async {
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      final api = ServerMapboxSearchRepository(
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
