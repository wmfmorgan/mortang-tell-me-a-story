import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/navigation/unsaved_guard.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';

const _ada = 'ada';

const _person = Person(id: 'p1', familyId: _ada, name: 'Ada', createdBy: 'u1');

final _park = Place(
  id: 'pl1',
  familyId: _ada,
  label: 'Central Park',
  address: 'New York, NY',
  lat: 40.78,
  lng: -73.96,
  isFavorite: true,
);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('any field change prompts', (tester) async {
    await _surface(tester);

    Future<void> dirty(Future<void> Function() change, {Story? story}) async {
      await _mount(tester, story: story ?? _dated());
      await change();
      await tester.pump();
      await tester.tap(find.byKey(const Key('story-capture-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Stay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await dirty(() async {
      await tester.enterText(find.byKey(const Key('story-title')), 'Renamed');
    });
    await dirty(() async {
      await tester.enterText(find.byKey(const Key('story-body')), 'Edited');
    });
    await dirty(() async {
      await tester.enterText(find.byKey(const Key('story-date-year')), '1999');
    });
    await dirty(() async {
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('story-date-month')),
          )
          .onChanged!(3);
    });
    await dirty(() async {
      tester.widget<Chip>(find.widgetWithText(Chip, 'Ada')).onDeleted!();
    }, story: _dated(personIds: const ['p1']));
    await dirty(() async {
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Choose place'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central Park'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this place'));
      await tester.pumpAndSettle();
    }, story: _dated(placeId: null));
  });

  testWidgets('close and back prompt', (tester) async {
    await _surface(tester);
    final router = await _mount(tester, story: _dated(), pushed: true);
    await tester.enterText(find.byKey(const Key('story-title')), 'Renamed');
    await tester.pump();

    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Stay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.state.uri.path, '/stories/s1/edit');

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Stay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.state.uri.path, '/stories/s1/edit');
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets(
    'the Save changes button never prompts and returns to the reader',
    (tester) async {
      await _surface(tester);
      final stories = _Stories(_dated());
      final router = await _mount(tester, stories: stories);
      await tester.enterText(find.byKey(const Key('story-title')), 'Renamed');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this story?'), findsNothing);
      expect(find.text('reader-s1'), findsOneWidget);
      expect(router.state.uri.path, '/stories/s1');
      expect(stories.updateDraftCalls, 1);
    },
  );

  testWidgets('Save from the prompt finishes the exit, not the reader', (
    tester,
  ) async {
    await _surface(tester);
    final stories = _Stories(_dated());
    final router = await _mount(tester, stories: stories);
    await tester.enterText(find.byKey(const Key('story-title')), 'Renamed');
    await tester.pump();
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this story?'), findsNothing);
    expect(find.text('reader-s1'), findsNothing);
    expect(router.state.uri.path, '/timeline');
    expect(stories.updateDraftCalls, 1);
  });

  testWidgets(
    'Save on an undated edit is blocked by the Save changes date check and stays',
    (tester) async {
      await _surface(tester);
      final stories = _Stories(
        Story(
          id: 's1',
          familyId: _ada,
          authorId: 'u1',
          title: 'Jam',
          body: 'We made jam.',
          status: StoryStatus.draft,
        ),
      );
      final router = await _mount(tester, stories: stories);
      await tester.enterText(find.byKey(const Key('story-title')), 'Renamed');
      await tester.pump();
      await tester.tap(find.byKey(const Key('story-capture-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsNothing);
      expect(router.state.uri.path, '/stories/s1/edit');
      expect(find.text('Renamed'), findsOneWidget);
      expect(stories.updateDraftCalls, 0);
      expect(stories.createDraftCalls, 0);
    },
  );
}

Story _dated({List<String> personIds = const [], String? placeId}) {
  return Story(
    id: 's1',
    familyId: _ada,
    authorId: 'u1',
    title: 'Jam',
    body: 'We made jam.',
    timeframeStart: DateTime(1987),
    timeframeEnd: DateTime(1987, 12, 31),
    datePrecision: StoryDatePrecision.year,
    placeId: placeId,
    status: StoryStatus.draft,
    personIds: personIds,
  );
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

GoRouter? _router;

Future<GoRouter> _mount(
  WidgetTester tester, {
  Story? story,
  _Stories? stories,
  bool pushed = false,
}) async {
  final previous = _router;
  _router = null;
  previous?.dispose();
  final api = stories ?? _Stories(story ?? _dated());
  final page = NewStoryPage(
    inviteApi: _Invite(),
    peopleApi: _People(),
    placesApi: _Places(),
    mapboxSearch: _Mapbox(),
    storiesApi: api,
    photosApi: _Photos(),
    hasMapboxToken: true,
    mapBuilder: ({double? lat, double? lng}) => const SizedBox.shrink(),
    pickImageBytes: () async => null,
    editStoryId: 's1',
  );
  final router = GoRouter(
    initialLocation: pushed ? '/timeline' : '/stories/s1/edit',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (_, _) => const Text('timeline-marker'),
      ),
      GoRoute(
        path: '/stories/:storyId/edit',
        onExit: (context, state) => UnsavedGuards.onExit(context, state),
        builder: (_, _) => page,
      ),
      GoRoute(
        path: '/stories/:storyId',
        builder: (_, state) =>
            Text('reader-${state.pathParameters['storyId']}'),
      ),
    ],
  );
  _router = router;
  addTearDown(() {
    if (_router == router) {
      _router = null;
      router.dispose();
    }
  });
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  if (pushed) {
    router.push('/stories/s1/edit');
    await tester.pumpAndSettle();
  }
  return router;
}

class _Stories implements StoriesGateway {
  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => const [];

  _Stories(this.story);

  Story story;
  var createDraftCalls = 0;
  var updateDraftCalls = 0;

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
    bool allowUndated = false,
    List<String> personIds = const [],
  }) async {
    createDraftCalls++;
    return story;
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
    updateDraftCalls++;
    story = Story(
      id: storyId,
      familyId: story.familyId,
      authorId: story.authorId,
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      placeId: placeId,
      status: StoryStatus.draft,
      personIds: personIds ?? story.personIds,
    );
    return story;
  }

  @override
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async => true;

  @override
  Future<Story> publish(String storyId) async => story;

  @override
  Future<Story> getStory(String storyId) async => story;

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

class _People extends PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [_person];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) async {
    throw UnimplementedError();
  }
}

class _Places implements PlacesGateway {
  @override
  Future<List<Place>> listFavorites(String familyId) async => [_park];

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      const [];

  @override
  Future<List<Place>> listPlaces(String familyId) async => [_park];

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
  Future<Place> markUsed(String placeId) async => _park;

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
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async => id == _park.id ? _park : null;
}

class _Mapbox implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}

class _Photos implements PhotosGateway {
  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePhoto(Photo photo) async {}

  @override
  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {}

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);
}

class _Invite implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: _ada, membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => _ada;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => _ada;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}
