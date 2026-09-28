import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/places_api.dart';

void main() {
  group('Place.fromJson', () {
    test('parses required columns and keeps label/address distinct', () {
      final place = Place.fromJson({
        'id': 'pl1',
        'family_id': 'f1',
        'label': 'Central Park',
        'address': 'New York, NY, USA',
        'lat': 40.7829,
        'lng': -73.9654,
        'mapbox_place_id': 'poi.123',
        'is_favorite': true,
        'last_used_at': '2026-09-26T12:00:00.000Z',
      });

      expect(place.id, 'pl1');
      expect(place.familyId, 'f1');
      expect(place.label, 'Central Park');
      expect(place.address, 'New York, NY, USA');
      expect(place.label, isNot(place.address));
      expect(place.lat, 40.7829);
      expect(place.lng, -73.9654);
      expect(place.mapboxPlaceId, 'poi.123');
      expect(place.isFavorite, isTrue);
      expect(place.lastUsedAt, DateTime.parse('2026-09-26T12:00:00.000Z'));
    });

    test('allows null mapbox_place_id and last_used_at', () {
      final place = Place.fromJson({
        'id': 'pl2',
        'family_id': 'f1',
        'label': 'Home',
        'address': '1 Main St',
        'lat': 1.0,
        'lng': 2.0,
        'mapbox_place_id': null,
        'is_favorite': false,
        'last_used_at': null,
      });

      expect(place.mapboxPlaceId, isNull);
      expect(place.lastUsedAt, isNull);
      expect(place.isFavorite, isFalse);
    });

    test('parses numeric lat/lng from JSON numbers', () {
      final place = Place.fromJson({
        'id': 'pl3',
        'family_id': 'f1',
        'label': 'A',
        'address': 'B',
        'lat': 10,
        'lng': 20,
        'is_favorite': false,
      });

      expect(place.lat, 10.0);
      expect(place.lng, 20.0);
    });
  });

  group('buildPlaceInsert', () {
    test('writes label and address as separate columns', () {
      final payload = buildPlaceInsert(
        familyId: 'f1',
        label: 'Central Park',
        address: 'New York, NY, USA',
        lat: 40.78,
        lng: -73.96,
        mapboxPlaceId: 'poi.1',
        isFavorite: false,
        lastUsedAt: DateTime.utc(2026, 9, 26, 15),
      );

      expect(payload['family_id'], 'f1');
      expect(payload['label'], 'Central Park');
      expect(payload['address'], 'New York, NY, USA');
      expect(payload['label'], isNot(payload['address']));
      expect(payload['lat'], 40.78);
      expect(payload['lng'], -73.96);
      expect(payload['mapbox_place_id'], 'poi.1');
      expect(payload['is_favorite'], isFalse);
      expect(payload['last_used_at'], '2026-09-26T15:00:00.000Z');
    });

    test('omits mapbox_place_id when null', () {
      final payload = buildPlaceInsert(
        familyId: 'f1',
        label: 'Park',
        address: 'Somewhere',
        lat: 1,
        lng: 2,
        lastUsedAt: DateTime.utc(2026, 1, 1),
      );

      expect(payload.containsKey('mapbox_place_id'), isFalse);
    });

    test('trims label and address without collapsing them', () {
      final payload = buildPlaceInsert(
        familyId: 'f1',
        label: '  Short  ',
        address: '  Full Address Line  ',
        lat: 1,
        lng: 2,
        lastUsedAt: DateTime.utc(2026, 1, 1),
      );

      expect(payload['label'], 'Short');
      expect(payload['address'], 'Full Address Line');
    });
  });

  group('ensureValidPlaceCreate', () {
    test('accepts non-empty label and address', () {
      expect(
        () => ensureValidPlaceCreate(label: 'Park', address: '1 Park Ave'),
        returnsNormally,
      );
    });

    test('rejects empty label', () {
      expect(
        () => ensureValidPlaceCreate(label: '', address: 'Addr'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects whitespace-only address', () {
      expect(
        () => ensureValidPlaceCreate(label: 'Park', address: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('FakePlacesGateway', () {
    late FakePlacesGateway gateway;

    setUp(() {
      gateway = FakePlacesGateway(now: () => DateTime.utc(2026, 9, 26, 12));
    });

    test(
      'createPlace persists distinct label and address + last_used_at',
      () async {
        final place = await gateway.createPlace(
          familyId: 'f1',
          label: 'Central Park',
          address: 'New York, NY, USA',
          lat: 40.78,
          lng: -73.96,
          mapboxPlaceId: 'poi.1',
        );

        expect(place.label, 'Central Park');
        expect(place.address, 'New York, NY, USA');
        expect(place.label, isNot(place.address));
        expect(place.lastUsedAt, DateTime.utc(2026, 9, 26, 12));
        expect(place.isFavorite, isFalse);
        expect(place.mapboxPlaceId, 'poi.1');
        expect(gateway.lastCreatePayload?['label'], 'Central Park');
        expect(gateway.lastCreatePayload?['address'], 'New York, NY, USA');
      },
    );

    test('createPlace rejects empty label before insert', () async {
      await expectLater(
        () => gateway.createPlace(
          familyId: 'f1',
          label: '',
          address: 'Addr',
          lat: 1,
          lng: 2,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(gateway.rows, isEmpty);
    });

    test('listFavorites filters is_favorite and orders by label', () async {
      await gateway.createPlace(
        familyId: 'f1',
        label: 'Zoo',
        address: 'A',
        lat: 1,
        lng: 1,
        isFavorite: true,
      );
      await gateway.createPlace(
        familyId: 'f1',
        label: 'Arcade',
        address: 'B',
        lat: 2,
        lng: 2,
        isFavorite: true,
      );
      await gateway.createPlace(
        familyId: 'f1',
        label: 'Cafe',
        address: 'C',
        lat: 3,
        lng: 3,
      );
      await gateway.createPlace(
        familyId: 'f2',
        label: 'Other Fav',
        address: 'D',
        lat: 4,
        lng: 4,
        isFavorite: true,
      );

      final favs = await gateway.listFavorites('f1');
      expect(favs.map((p) => p.label), ['Arcade', 'Zoo']);
    });

    test(
      'listRecents orders by last_used_at desc and respects limit',
      () async {
        var tick = 0;
        gateway = FakePlacesGateway(
          now: () => DateTime.utc(2026, 9, 26, tick++),
        );

        final older = await gateway.createPlace(
          familyId: 'f1',
          label: 'Older',
          address: 'A',
          lat: 1,
          lng: 1,
        );
        final newer = await gateway.createPlace(
          familyId: 'f1',
          label: 'Newer',
          address: 'B',
          lat: 2,
          lng: 2,
        );
        await gateway.createPlace(
          familyId: 'f2',
          label: 'OtherFamily',
          address: 'C',
          lat: 3,
          lng: 3,
        );

        // Clear last_used_at on one row to exclude from recents.
        gateway.rows[gateway.rows.indexWhere((p) => p.id == older.id)] = Place(
          id: older.id,
          familyId: older.familyId,
          label: older.label,
          address: older.address,
          lat: older.lat,
          lng: older.lng,
          mapboxPlaceId: older.mapboxPlaceId,
          isFavorite: older.isFavorite,
          lastUsedAt: null,
        );

        final recents = await gateway.listRecents('f1', limit: 10);
        expect(recents.map((p) => p.id), [newer.id]);
      },
    );

    test('listRecents default limit is 10', () async {
      var tick = 0;
      gateway = FakePlacesGateway(now: () => DateTime.utc(2026, 1, 1, tick++));
      for (var i = 0; i < 12; i++) {
        await gateway.createPlace(
          familyId: 'f1',
          label: 'P$i',
          address: 'A$i',
          lat: i.toDouble(),
          lng: i.toDouble(),
        );
      }

      final recents = await gateway.listRecents('f1');
      expect(recents, hasLength(10));
      expect(recents.first.label, 'P11');
      expect(recents.last.label, 'P2');
    });

    test('markUsed updates last_used_at', () async {
      final place = await gateway.createPlace(
        familyId: 'f1',
        label: 'Park',
        address: 'Addr',
        lat: 1,
        lng: 2,
      );

      gateway.now = () => DateTime.utc(2026, 10, 1, 8);
      final updated = await gateway.markUsed(place.id);
      expect(updated.lastUsedAt, DateTime.utc(2026, 10, 1, 8));
    });

    test('setFavorite updates is_favorite', () async {
      final place = await gateway.createPlace(
        familyId: 'f1',
        label: 'Park',
        address: 'Addr',
        lat: 1,
        lng: 2,
      );

      final favorited = await gateway.setFavorite(
        placeId: place.id,
        isFavorite: true,
      );
      expect(favorited.isFavorite, isTrue);

      final unfavorited = await gateway.setFavorite(
        placeId: place.id,
        isFavorite: false,
      );
      expect(unfavorited.isFavorite, isFalse);
    });

    test('findByMapboxPlaceId returns matching family row', () async {
      await gateway.createPlace(
        familyId: 'f1',
        label: 'Park',
        address: 'Addr',
        lat: 1,
        lng: 2,
        mapboxPlaceId: 'poi.abc',
      );
      await gateway.createPlace(
        familyId: 'f2',
        label: 'Other',
        address: 'Addr2',
        lat: 3,
        lng: 4,
        mapboxPlaceId: 'poi.abc',
      );

      final found = await gateway.findByMapboxPlaceId('f1', 'poi.abc');
      expect(found?.label, 'Park');
      expect(await gateway.findByMapboxPlaceId('f1', 'missing'), isNull);
    });

    test('getPlace returns row by id or null', () async {
      final created = await gateway.createPlace(
        familyId: 'f1',
        label: 'Park',
        address: 'Addr',
        lat: 1,
        lng: 2,
      );

      expect((await gateway.getPlace(created.id))?.label, 'Park');
      expect(await gateway.getPlace('missing'), isNull);
    });
  });
}

/// In-memory [PlacesGateway] that mirrors PlacesApi create/list rules.
class FakePlacesGateway implements PlacesGateway {
  FakePlacesGateway({DateTime Function()? now}) : now = now ?? DateTime.now;

  DateTime Function() now;
  final List<Place> rows = [];
  Map<String, dynamic>? lastCreatePayload;
  var _seq = 0;

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    final filtered =
        rows.where((p) => p.familyId == familyId && p.isFavorite).toList()
          ..sort((a, b) => a.label.compareTo(b.label));
    return filtered;
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    final filtered =
        rows
            .where((p) => p.familyId == familyId && p.lastUsedAt != null)
            .toList()
          ..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return filtered.take(limit).toList();
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
    final usedAt = now().toUtc();
    final payload = buildPlaceInsert(
      familyId: familyId,
      label: label,
      address: address,
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
      lastUsedAt: usedAt,
    );
    lastCreatePayload = payload;
    final place = Place(
      id: 'pl${++_seq}',
      familyId: familyId,
      label: payload['label'] as String,
      address: payload['address'] as String,
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
      lastUsedAt: usedAt,
    );
    rows.add(place);
    return place;
  }

  @override
  Future<Place> markUsed(String placeId) async {
    final i = rows.indexWhere((p) => p.id == placeId);
    if (i < 0) {
      throw StateError('place not found: $placeId');
    }
    final existing = rows[i];
    final updated = Place(
      id: existing.id,
      familyId: existing.familyId,
      label: existing.label,
      address: existing.address,
      lat: existing.lat,
      lng: existing.lng,
      mapboxPlaceId: existing.mapboxPlaceId,
      isFavorite: existing.isFavorite,
      lastUsedAt: now().toUtc(),
    );
    rows[i] = updated;
    return updated;
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    final i = rows.indexWhere((p) => p.id == placeId);
    if (i < 0) {
      throw StateError('place not found: $placeId');
    }
    final existing = rows[i];
    final updated = Place(
      id: existing.id,
      familyId: existing.familyId,
      label: existing.label,
      address: existing.address,
      lat: existing.lat,
      lng: existing.lng,
      mapboxPlaceId: existing.mapboxPlaceId,
      isFavorite: isFavorite,
      lastUsedAt: existing.lastUsedAt,
    );
    rows[i] = updated;
    return updated;
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async {
    for (final p in rows) {
      if (p.familyId == familyId && p.mapboxPlaceId == mapboxPlaceId) {
        return p;
      }
    }
    return null;
  }

  @override
  Future<Place?> getPlace(String id) async {
    for (final p in rows) {
      if (p.id == id) return p;
    }
    return null;
  }
}
