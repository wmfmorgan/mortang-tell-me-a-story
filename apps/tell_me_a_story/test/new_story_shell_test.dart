import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
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
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _FakePeopleApi implements PeopleGateway {
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
    required String relationship,
    String? email,
  }) async {
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async =>
      null;
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
}) {
  return MaterialApp(
    home: NewStoryPage(
      inviteApi: invite ?? _FakeInviteApi(),
      peopleApi: people ?? _FakePeopleApi(),
      placesApi: places ?? _FakePlacesApi(),
      mapboxSearch: search ?? _FakeMapboxSearch(),
      hasMapboxToken: false,
      mapBuilder: ({double? lat, double? lng}) =>
          const SizedBox(key: Key('stub-map'), height: 120),
    ),
  );
}

void main() {
  testWidgets('shell shows New story chrome without draft/publish',
      (tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Add person'), findsOneWidget);
    expect(find.text('Choose place'), findsOneWidget);
    expect(find.text('Capture fields arrive in M4.'), findsOneWidget);

    expect(find.text('Save draft'), findsNothing);
    expect(find.textContaining('Save draft'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.textContaining('Publish'), findsNothing);
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

    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();

    expect(find.text('Choose or create'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
    await tester.pumpAndSettle();

    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Central Park'), findsOneWidget);
    expect(find.text('Search places'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ada'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'Ada'), findsOneWidget);
    expect(find.text('Choose or create'), findsNothing);
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

    await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Central Park'));
    await tester.pumpAndSettle();

    expect(find.text('Central Park'), findsOneWidget);
    expect(find.text('New York, NY'), findsOneWidget);
    expect(find.byKey(const Key('stub-map')), findsOneWidget);
  });

  testWidgets('bootstraps family via createFamily when none exists',
      (tester) async {
    final invite = _FakeInviteApi(familyId: null);
    final people = _FakePeopleApi();

    await tester.pumpWidget(_shell(invite: invite, people: people));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();

    expect(invite.createFamilyCalls, 1);
    expect(find.text('Choose or create'), findsOneWidget);
  });
}
