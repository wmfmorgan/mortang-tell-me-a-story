import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/server_places_repository.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _placeId = '0190d7a0-0000-7000-8000-000000000001';
const _treeId = '0190d7a0-0000-7000-8000-000000000002';

server.PlaceDto _dto({
  String? mapboxPlaceId,
  bool isFavorite = false,
  DateTime? lastUsedAt,
}) => server.PlaceDto(
  id: server.UuidValue.fromString(_placeId),
  treeId: server.UuidValue.fromString(_treeId),
  label: 'Central Park',
  address: 'New York, NY, USA',
  lat: 40.7829,
  lng: -73.9654,
  mapboxPlaceId: mapboxPlaceId,
  isFavorite: isFavorite,
  lastUsedAt: lastUsedAt,
);

void main() {
  group('Place.fromDto', () {
    test('maps every field and keeps label/address distinct', () {
      final used = DateTime.utc(2026, 9, 26, 12);
      final place = placeFromDto(
        _dto(mapboxPlaceId: 'poi.123', isFavorite: true, lastUsedAt: used),
      );

      expect(place.id, _placeId);
      expect(place.label, 'Central Park');
      expect(place.address, 'New York, NY, USA');
      expect(place.label, isNot(place.address));
      expect(place.lat, 40.7829);
      expect(place.lng, -73.9654);
      expect(place.mapboxPlaceId, 'poi.123');
      expect(place.isFavorite, isTrue);
      expect(place.lastUsedAt, used);
    });

    test('allows null mapbox id and last used', () {
      final place = placeFromDto(_dto());

      expect(place.mapboxPlaceId, isNull);
      expect(place.lastUsedAt, isNull);
      expect(place.isFavorite, isFalse);
    });
  });

  group('placeInput', () {
    test('writes label and address as separate fields', () {
      final input = placeInput(
        label: 'Central Park',
        address: 'New York, NY, USA',
        lat: 40.78,
        lng: -73.96,
        mapboxPlaceId: 'poi.1',
      );

      expect(input.label, 'Central Park');
      expect(input.address, 'New York, NY, USA');
      expect(input.lat, 40.78);
      expect(input.lng, -73.96);
      expect(input.mapboxPlaceId, 'poi.1');
      expect(input.isFavorite, isFalse);
    });

    test('trims label and address without collapsing them', () {
      final input = placeInput(
        label: '  Short  ',
        address: '  Full Address Line  ',
        lat: 1,
        lng: 2,
        isFavorite: true,
      );

      expect(input.label, 'Short');
      expect(input.address, 'Full Address Line');
      expect(input.mapboxPlaceId, isNull);
      expect(input.isFavorite, isTrue);
    });
  });
}
