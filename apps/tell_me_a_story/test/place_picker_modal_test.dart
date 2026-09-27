import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/features/places/place_picker_modal.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

const _mapFailureCopy =
    'Couldn’t load the map. Check your connection and try again.';

Place _place({
  required String id,
  required String label,
  required String address,
  bool isFavorite = false,
  DateTime? lastUsedAt,
  String? mapboxPlaceId,
}) {
  return Place(
    id: id,
    familyId: _familyId,
    label: label,
    address: address,
    lat: 40.78,
    lng: -73.96,
    mapboxPlaceId: mapboxPlaceId,
    isFavorite: isFavorite,
    lastUsedAt: lastUsedAt,
  );
}

class _FakePlacesGateway implements PlacesGateway {
  _FakePlacesGateway({List<Place>? seed}) : rows = [...?seed];

  final List<Place> rows;
  var markUsedCalls = 0;
  String? lastMarkedId;
  var createCalls = 0;

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    final filtered = rows
        .where((p) => p.familyId == familyId && p.isFavorite)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return filtered;
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    final filtered = rows
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
    createCalls++;
    ensureValidPlaceCreate(label: label, address: address);
    final place = Place(
      id: 'pl-new',
      familyId: familyId,
      label: label.trim(),
      address: address.trim(),
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
      lastUsedAt: DateTime.utc(2026, 9, 27),
    );
    rows.add(place);
    return place;
  }

  @override
  Future<Place> markUsed(String placeId) async {
    markUsedCalls++;
    lastMarkedId = placeId;
    final i = rows.indexWhere((p) => p.id == placeId);
    if (i < 0) throw StateError('missing $placeId');
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
      lastUsedAt: DateTime.utc(2026, 9, 27, 12),
    );
    rows[i] = updated;
    return updated;
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    throw UnimplementedError();
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
}

class _FakeSearchGateway implements MapboxSearchGateway {
  _FakeSearchGateway({this.hits = const [], this.throwOnSearch = false});

  final List<MapboxSearchHit> hits;
  final bool throwOnSearch;
  var searchCalls = 0;
  String? lastQuery;

  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async {
    searchCalls++;
    lastQuery = query;
    if (throwOnSearch) {
      throw MapboxSearchException('geocode failed', statusCode: 500);
    }
    return hits;
  }
}

Widget _placeholderMap({double? lat, double? lng}) {
  return SizedBox(
    height: 120,
    child: Text('map-placeholder ${lat ?? 'none'},${lng ?? 'none'}'),
  );
}

Future<Place?> _openModal(
  WidgetTester tester, {
  required PlacesGateway places,
  required MapboxSearchGateway search,
  bool hasMapboxToken = true,
  Place? Function()? onResult,
}) async {
  Place? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await PlacePickerModal.show(
                context,
                familyId: _familyId,
                places: places,
                search: search,
                hasMapboxToken: hasMapboxToken,
                mapBuilder: _placeholderMap,
              );
              onResult?.call();
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('renders Favorites and Recents from gateway', (tester) async {
    final places = _FakePlacesGateway(
      seed: [
        _place(
          id: 'fav1',
          label: 'Favorite Park',
          address: '1 Park Ave',
          isFavorite: true,
        ),
        _place(
          id: 'rec1',
          label: 'Recent Cafe',
          address: '2 Main St',
          lastUsedAt: DateTime.utc(2026, 9, 20),
        ),
      ],
    );
    final search = _FakeSearchGateway();

    await _openModal(
      tester,
      places: places,
      search: search,
      hasMapboxToken: true,
    );

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recents'), findsOneWidget);
    expect(find.text('Favorite Park'), findsOneWidget);
    expect(find.text('Recent Cafe'), findsOneWidget);
  });

  testWidgets('shows locked failure copy when Mapbox token missing', (
    tester,
  ) async {
    final places = _FakePlacesGateway();
    final search = _FakeSearchGateway();

    await _openModal(
      tester,
      places: places,
      search: search,
      hasMapboxToken: false,
    );

    expect(find.text(_mapFailureCopy), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows locked failure copy when search throws', (tester) async {
    final places = _FakePlacesGateway();
    final search = _FakeSearchGateway(throwOnSearch: true);

    await _openModal(
      tester,
      places: places,
      search: search,
      hasMapboxToken: true,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search places'),
      'Central Park',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text(_mapFailureCopy), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(search.searchCalls, greaterThan(0));
  });

  testWidgets('selecting a recent calls markUsed and pops Place', (
    tester,
  ) async {
    final places = _FakePlacesGateway(
      seed: [
        _place(
          id: 'rec1',
          label: 'Recent Cafe',
          address: '2 Main St',
          lastUsedAt: DateTime.utc(2026, 9, 20),
        ),
      ],
    );
    final search = _FakeSearchGateway();

    Place? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await PlacePickerModal.show(
                  context,
                  familyId: _familyId,
                  places: places,
                  search: search,
                  hasMapboxToken: true,
                  mapBuilder: _placeholderMap,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recent Cafe'));
    await tester.pumpAndSettle();

    expect(places.markUsedCalls, 1);
    expect(places.lastMarkedId, 'rec1');
    expect(result, isNotNull);
    expect(result!.id, 'rec1');
    expect(result!.label, 'Recent Cafe');
    expect(find.text('Choose place'), findsNothing);
  });

  testWidgets('selecting a favorite calls markUsed and pops Place', (
    tester,
  ) async {
    final places = _FakePlacesGateway(
      seed: [
        _place(
          id: 'fav1',
          label: 'Favorite Park',
          address: '1 Park Ave',
          isFavorite: true,
        ),
      ],
    );
    final search = _FakeSearchGateway();

    Place? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await PlacePickerModal.show(
                  context,
                  familyId: _familyId,
                  places: places,
                  search: search,
                  hasMapboxToken: true,
                  mapBuilder: _placeholderMap,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favorite Park'));
    await tester.pumpAndSettle();

    expect(places.markUsedCalls, 1);
    expect(places.lastMarkedId, 'fav1');
    expect(result?.id, 'fav1');
  });

  testWidgets('search hit reuses existing mapbox place via markUsed', (
    tester,
  ) async {
    final places = _FakePlacesGateway(
      seed: [
        _place(
          id: 'existing',
          label: 'Central Park',
          address: 'New York, NY, USA',
          mapboxPlaceId: 'poi.123',
          lastUsedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    final search = _FakeSearchGateway(
      hits: const [
        MapboxSearchHit(
          id: 'poi.123',
          label: 'Central Park',
          address: 'New York, NY, USA',
          lat: 40.78,
          lng: -73.96,
        ),
      ],
    );

    Place? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await PlacePickerModal.show(
                  context,
                  familyId: _familyId,
                  places: places,
                  search: search,
                  hasMapboxToken: true,
                  mapBuilder: _placeholderMap,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search places'),
      'Central',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Central Park'), findsWidgets);
    await tester.tap(find.text('New York, NY, USA').first);
    await tester.pumpAndSettle();

    expect(places.createCalls, 0);
    expect(places.markUsedCalls, 1);
    expect(places.lastMarkedId, 'existing');

    await tester.tap(find.text('Use this place'));
    await tester.pumpAndSettle();

    expect(result?.id, 'existing');
  });

  testWidgets('search hit creates place with separate label and address', (
    tester,
  ) async {
    final places = _FakePlacesGateway();
    final search = _FakeSearchGateway(
      hits: const [
        MapboxSearchHit(
          id: 'poi.new',
          label: 'Short Name',
          address: 'Full Address, City',
          lat: 1.5,
          lng: 2.5,
        ),
      ],
    );

    Place? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await PlacePickerModal.show(
                  context,
                  familyId: _familyId,
                  places: places,
                  search: search,
                  hasMapboxToken: true,
                  mapBuilder: _placeholderMap,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search places'),
      'Short',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Full Address, City'));
    await tester.pumpAndSettle();

    expect(places.createCalls, 1);
    expect(places.rows.last.label, 'Short Name');
    expect(places.rows.last.address, 'Full Address, City');
    expect(places.rows.last.mapboxPlaceId, 'poi.new');

    await tester.tap(find.text('Use this place'));
    await tester.pumpAndSettle();

    expect(result?.label, 'Short Name');
    expect(result?.address, 'Full Address, City');
  });
}
