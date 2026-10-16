import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/features/places/place_map.dart';
import 'package:tell_me_a_story/features/places/place_picker_modal.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakeInviteApi implements InviteGateway {
  _FakeInviteApi({this.familyId = _familyId});

  final String? familyId;
  var createFamilyCalls = 0;

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async {
    createFamilyCalls++;
    return _familyId;
  }

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _FakePeopleApi extends PeopleGateway {
  _FakePeopleApi({List<Person>? seed}) : rows = [...?seed];

  final List<Person> rows;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    return rows.where((p) => p.familyId == familyId).toList();
  }

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    DateTime? birthDate,
    String? birthPrecision,
    DateTime? passingDate,
    String? passingPrecision,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) async {
    final person = Person(
      id: 'p-created',
      familyId: familyId,
      name: name.trim(),
      email: email,
      about: about,
      birthDate: birthDate,
      birthPrecision: birthPrecision,
      passingDate: passingDate,
      passingPrecision: passingPrecision,
      createdBy: 'u1',
    );
    rows.add(person);
    return person;
  }
}

class _FakePlacesApi implements PlacesGateway {
  _FakePlacesApi({List<Place>? seed}) : rows = [...?seed];

  final List<Place> rows;

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    return rows.where((p) => p.familyId == familyId && p.isFavorite).toList();
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    return rows
        .where((p) => p.familyId == familyId && p.lastUsedAt != null)
        .take(limit)
        .toList();
  }

  @override
  Future<List<Place>> listPlaces(String familyId) async {
    return rows.where((p) => p.familyId == familyId).toList();
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
    throw UnimplementedError();
  }

  @override
  Future<Place> markUsed(String placeId) async {
    final existing = rows.firstWhere((p) => p.id == placeId);
    return existing;
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
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
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async {
    for (final p in rows) {
      if (p.id == id) return p;
    }
    return null;
  }
}

class _FakeMapboxSearch implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}

Widget _shell({
  InviteGateway? invite,
  PeopleGateway? people,
  PlacesGateway? places,
  MapboxSearchGateway? search,
  bool hasMapboxToken = true,
  PlaceMapBuilder? mapBuilder = _defaultStubMap,
}) {
  return MaterialApp(
    home: NewStoryPage(
      inviteApi: invite ?? _FakeInviteApi(),
      peopleApi: people ?? _FakePeopleApi(),
      placesApi: places ?? _FakePlacesApi(),
      mapboxSearch: search ?? _FakeMapboxSearch(),
      hasMapboxToken: hasMapboxToken,
      mapBuilder: mapBuilder,
    ),
  );
}

Widget _defaultStubMap({double? lat, double? lng}) {
  return const SizedBox(key: Key('stub-map'), height: 120);
}

Rect _cardRect(WidgetTester tester, Finder marker) {
  expect(marker, findsOneWidget);
  final card = find
      .ancestor(of: marker, matching: find.byType(DecoratedBox))
      .first;
  return tester.getRect(card);
}

bool _skipStoryPumpError(FlutterErrorDetails details) {
  final report = details.toString();
  return report.contains('RenderFlex overflowed') &&
      report.contains('album_header.dart');
}

Future<void> _pumpStory(WidgetTester tester) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // Known exception: album_header overflow at 390px; M14.1c dropped by Bill 2026-10-16.
    if (_skipStoryPumpError(details)) return;
    previous?.call(details);
  };
  try {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previous;
  }
}

FlutterErrorDetails _pumpError(String message, String library) {
  return FlutterErrorDetails(
    exception: FlutterError(message),
    library: library,
    stack: StackTrace.fromString(
      '#0 build (package:tell_me_a_story/$library:10:3)\n',
    ),
  );
}

void main() {
  testWidgets('shell shows New story chrome with people and place', (
    tester,
  ) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.text('Tell Me a Story'), findsOneWidget);
    expect(find.text('New story'), findsNothing);
    expect(find.text('Invite'), findsNothing);
    expect(find.text('Add person'), findsOneWidget);
    expect(find.text('Choose place'), findsOneWidget);
    expect(find.text('Capture fields arrive in M4.'), findsNothing);
  });

  testWidgets('Add person opens AddPersonModal', (tester) async {
    final people = _FakePeopleApi(
      seed: const [
        Person(
          id: 'p1',
          familyId: _familyId,
          name: 'Ada',
          relationship: 'Aunt',
          createdBy: 'u1',
        ),
      ],
    );

    await tester.pumpWidget(_shell(people: people));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Add person'));
    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-person-picker')), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('NAME'), findsNothing);
  });

  testWidgets('Choose place opens PlacePickerModal', (tester) async {
    final places = _FakePlacesApi(
      seed: [
        Place(
          id: 'pl1',
          familyId: _familyId,
          label: 'Central Park',
          address: 'New York, NY',
          lat: 40.78,
          lng: -73.96,
          isFavorite: true,
        ),
      ],
    );

    await tester.pumpWidget(_shell(places: places));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Choose place'));
    await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Central Park'), findsOneWidget);
    expect(find.text('Search address or place…'), findsOneWidget);
  });

  testWidgets('selecting person shows chip in memory only', (tester) async {
    final people = _FakePeopleApi(
      seed: const [
        Person(
          id: 'p1',
          familyId: _familyId,
          name: 'Ada',
          relationship: 'Aunt',
          createdBy: 'u1',
        ),
      ],
    );

    await tester.pumpWidget(_shell(people: people));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Add person'));
    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Ada'), findsOneWidget);
    expect(find.text('NAME'), findsNothing);
  });

  testWidgets('selecting place shows label and stub map', (tester) async {
    final places = _FakePlacesApi(
      seed: [
        Place(
          id: 'pl1',
          familyId: _familyId,
          label: 'Central Park',
          address: 'New York, NY',
          lat: 40.78,
          lng: -73.96,
          isFavorite: true,
        ),
      ],
    );

    await tester.pumpWidget(_shell(places: places));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Choose place'));
    await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central Park'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use this place'));
    await tester.tap(find.text('Use this place'));
    await tester.pumpAndSettle();

    expect(find.text('Central Park'), findsOneWidget);
    expect(find.text('New York, NY'), findsOneWidget);
    expect(find.byKey(const Key('stub-map')), findsOneWidget);
  });

  testWidgets(
    'selected place with no Mapbox token shows failure copy, not PlaceMap',
    (tester) async {
      final places = _FakePlacesApi(
        seed: [
          Place(
            id: 'pl1',
            familyId: _familyId,
            label: 'Central Park',
            address: 'New York, NY',
            lat: 40.78,
            lng: -73.96,
            isFavorite: true,
          ),
        ],
      );

      await tester.pumpWidget(
        _shell(places: places, hasMapboxToken: false, mapBuilder: null),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Choose place'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central Park'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use this place'));
      await tester.tap(find.text('Use this place'));
      await tester.pumpAndSettle();

      expect(find.text(placeMapFailureCopy), findsOneWidget);
      expect(find.text(placeMapRetryLabel), findsOneWidget);
      expect(find.byType(PlaceMap), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(TileLayer), findsNothing);
      expect(find.text('Central Park'), findsOneWidget);
    },
  );

  testWidgets('bootstraps family via createFamily when none exists', (
    tester,
  ) async {
    final invite = _FakeInviteApi(familyId: null);
    final people = _FakePeopleApi();

    await tester.pumpWidget(_shell(invite: invite, people: people));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Add person'));
    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();

    expect(invite.createFamilyCalls, 1);
    expect(find.byKey(const Key('add-person-picker')), findsOneWidget);
  });

  test('_pumpStory ignores only an album_header RenderFlex overflow', () {
    final headerOverflow = _pumpError(
      'A RenderFlex overflowed by 385 pixels on the right.',
      'core/theme/album_header.dart',
    );
    final headerOther = _pumpError(
      'setState() called after dispose().',
      'core/theme/album_header.dart',
    );
    final pageOverflow = _pumpError(
      'A RenderFlex overflowed by 12 pixels on the bottom.',
      'features/stories/new_story_page.dart',
    );

    expect(_skipStoryPumpError(headerOverflow), isTrue);
    expect(_skipStoryPumpError(headerOther), isFalse);
    expect(_skipStoryPumpError(pageOverflow), isFalse);
  });

  testWidgets('story cards stack with a 20px gap at every width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;

      await _pumpStory(tester);

      final cards = [
        _cardRect(tester, find.byKey(const Key('story-title'))),
        _cardRect(tester, find.text('Photos & Keepsakes')),
        _cardRect(tester, find.text('Timeframe')),
        _cardRect(tester, find.text('People')),
        _cardRect(tester, find.text('Place')),
      ];

      for (var i = 0; i < cards.length - 1; i++) {
        final above = cards[i];
        final below = cards[i + 1];
        expect(
          below.top,
          greaterThan(above.bottom),
          reason: 'card ${i + 1} is below card $i at ${width}px',
        );
        expect(
          below.top - above.bottom,
          closeTo(20, 0.5),
          reason: '20px gap after card $i at ${width}px',
        );
        expect(
          below.center.dx,
          closeTo(above.center.dx, 0.5),
          reason: 'cards share a center at ${width}px',
        );
      }
    }
  });
}
