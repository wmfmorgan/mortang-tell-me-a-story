import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_hit.dart';

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
      expect(
        hit.address,
        'Central Park, New York, New York 10024, United States',
      );
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
      expect(
        hits[0].address,
        'Central Park, New York, New York 10024, United States',
      );
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
}
