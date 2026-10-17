import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
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
  Key? key,
  InviteGateway? invite,
  PeopleGateway? people,
  PlacesGateway? places,
  MapboxSearchGateway? search,
  StoriesGateway? stories,
  bool hasMapboxToken = true,
  PlaceMapBuilder? mapBuilder = _defaultStubMap,
}) {
  return MaterialApp(
    home: NewStoryPage(
      key: key,
      inviteApi: invite ?? _FakeInviteApi(),
      peopleApi: people ?? _FakePeopleApi(),
      placesApi: places ?? _FakePlacesApi(),
      mapboxSearch: search ?? _FakeMapboxSearch(),
      storiesApi: stories,
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

  testWidgets('first keystroke inserts one draft with a client id', (
    tester,
  ) async {
    final stories = _AutosaveStories();
    await tester.pumpWidget(_shell(stories: stories));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('story-title')), 'J');
    await tester.pump(kAutosavePause);
    await tester.pump();

    expect(stories.createIds, hasLength(1));
    expect(stories.createStatuses, ['draft']);
    expect(stories.createStarts.single, isNull);
    final id = stories.createIds.single;
    expect(id, isNotNull);
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(id!),
      isTrue,
    );

    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.pump(kAutosavePause);
    await tester.pump();

    expect(stories.createIds, hasLength(1));
    expect(stories.updateIds, [id]);
  });

  testWidgets('a duplicate-key insert becomes an update by the same id', (
    tester,
  ) async {
    final stories = _AutosaveStories()..duplicateOnCreate = true;
    await tester.pumpWidget(_shell(stories: stories));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.pump(kAutosavePause);
    await tester.pump();

    expect(stories.createIds, hasLength(1));
    expect(stories.updateIds, [stories.createIds.single]);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a typing pause saves and leaving saves with no prompt', (
    tester,
  ) async {
    final paused = _AutosaveStories();
    await tester.pumpWidget(_shell(stories: paused));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('story-body')), 'Porch');
    await tester.pump(const Duration(seconds: 1));
    expect(paused.createIds, isEmpty);
    await tester.pump(kAutosavePause - const Duration(seconds: 1));
    await tester.pump();
    expect(paused.createIds, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);

    final leaving = _AutosaveStories();
    await tester.pumpWidget(
      _shell(key: const ValueKey('leaving'), stories: leaving),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.pump();
    expect(leaving.createIds, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(leaving.createIds, hasLength(1));
  });

  testWidgets('a successful autosave shows Saved in muted ink', (tester) async {
    final stories = _AutosaveStories();
    await tester.pumpWidget(_shell(stories: stories));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.pump(kAutosavePause);
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    final saved = tester.widget<Text>(find.text('Saved'));
    expect(saved.style?.color, albumInk.withValues(alpha: 0.55));
    expect(
      tester.getTopLeft(find.text('Saved')).dx,
      lessThan(tester.getTopLeft(find.text('Save draft')).dx),
    );
  });

  testWidgets('a failed autosave shows Not saved and retries next pause', (
    tester,
  ) async {
    final stories = _AutosaveStories()..createError = StateError('down');
    await tester.pumpWidget(_shell(stories: stories));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.pump(kAutosavePause);
    await tester.pump();

    expect(find.text('Not saved'), findsOneWidget);
    expect(find.text('Jam'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(stories.createIds, hasLength(1));

    stories.createError = null;
    await tester.enterText(find.byKey(const Key('story-title')), 'Jam today');
    await tester.pump(kAutosavePause);
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Jam today'), findsOneWidget);
    expect(stories.createIds, hasLength(2));
    expect(stories.createIds[1], stories.createIds[0]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Save draft and Publish still work, and a missing date blocks publish', (
    tester,
  ) async {
    final stories = _AutosaveStories();
    await tester.pumpWidget(
      _shell(
        stories: stories,
        people: _FakePeopleApi(
          seed: const [
            Person(
              id: 'p1',
              familyId: _familyId,
              name: 'Ada',
              relationship: 'Aunt',
              createdBy: 'u1',
            ),
          ],
        ),
        places: _FakePlacesApi(
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('story-date-year')), '1980');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsOneWidget);
    expect(stories.createIds, hasLength(1));
    expect(stories.createStarts.single, DateTime(1980, 1, 1));

    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.enterText(find.byKey(const Key('story-body')), 'We made jam.');
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Add person'));
    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Choose place'));
    await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Central Park'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use this place'));
    await tester.tap(find.text('Use this place'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pumpAndSettle();
    expect(stories.publishCalls, 1);
    expect(
      find.text('Finish the highlighted fields to publish.'),
      findsNothing,
    );

    final blocked = _AutosaveStories();
    await tester.pumpWidget(
      _shell(key: const ValueKey('blocked'), stories: blocked),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('story-title')), 'No date');
    await tester.pump(kAutosavePause);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pump();
    expect(
      find.text('Finish the highlighted fields to publish.'),
      findsOneWidget,
    );
    expect(blocked.publishCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

class _AutosaveStories implements StoriesGateway {
  var duplicateOnCreate = false;
  Object? createError;
  final List<String?> createIds = [];
  final List<String> createStatuses = [];
  final List<DateTime?> createStarts = [];
  final List<String> updateIds = [];
  var publishCalls = 0;
  Story? story;

  @override
  Future<Story> createDraft({
    String? id,
    required String familyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  }) async {
    createIds.add(id);
    createStatuses.add('draft');
    createStarts.add(timeframeStart);
    if (duplicateOnCreate) {
      duplicateOnCreate = false;
      throw const PostgrestException(
        message:
            'duplicate key value violates unique constraint "stories_pkey"',
        code: '23505',
      );
    }
    if (createError != null) throw createError!;
    story = Story(
      id: id ?? 'server-id',
      familyId: familyId,
      authorId: 'u1',
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      placeId: placeId,
      status: StoryStatus.draft,
      personIds: personIds,
    );
    return story!;
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    updateIds.add(storyId);
    story = Story(
      id: storyId,
      familyId: story?.familyId ?? _familyId,
      authorId: 'u1',
      title: title ?? story?.title,
      body: body ?? story?.body,
      timeframeStart: timeframeStart ?? story?.timeframeStart,
      status: StoryStatus.draft,
      personIds: personIds ?? story?.personIds ?? const [],
    );
    return story!;
  }

  @override
  Future<Story> publish(String storyId) async {
    publishCalls++;
    return story ??
        Story(
          id: storyId,
          familyId: _familyId,
          authorId: 'u1',
          timeframeStart: DateTime(1980, 1, 1),
          status: StoryStatus.published,
        );
  }

  @override
  Future<Story> getStory(String storyId) async {
    final existing = story;
    if (existing == null || existing.id != storyId) {
      throw StateError('missing $storyId');
    }
    return existing;
  }

  @override
  Future<Story?> getPublished(String storyId) async => null;

  @override
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async => const [];

  @override
  Future<void> discard(String storyId) async {}

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {}
}
