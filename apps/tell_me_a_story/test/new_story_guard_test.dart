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

  testWidgets(
    'prompts for year, month, day, place, person removal, a date-only new form and typing inside 2 s',
    (tester) async {
      await _surface(tester);

      await _mount(tester);
      await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
      await tester.pump();
      await _expectLeave(tester);

      await _mount(tester);
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('story-date-month')),
          )
          .onChanged!(1);
      await tester.pump();
      await _expectLeave(tester);

      await _mount(tester);
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('story-date-month')),
          )
          .onChanged!(1);
      await tester.pump();
      tester
          .widget<DropdownButton<int>>(find.byKey(const Key('story-date-day')))
          .onChanged!(15);
      await tester.pump();
      await _expectLeave(tester);

      await _mount(tester);
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
      await _expectLeave(tester);

      final stories = _Stories(
        story: Story(
          id: 's1',
          familyId: _ada,
          authorId: 'u1',
          title: 'Jam',
          body: 'We made jam.',
          timeframeStart: DateTime(1987),
          timeframeEnd: DateTime(1987, 12, 31),
          datePrecision: StoryDatePrecision.year,
          status: StoryStatus.draft,
          personIds: const ['p1'],
        ),
      );
      await _mount(tester, stories: stories, draftId: 's1');
      tester.widget<Chip>(find.widgetWithText(Chip, 'Ada')).onDeleted!();
      await tester.pump();
      await _expectLeave(tester);

      await _mount(tester);
      await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
      await tester.pump();
      tester
          .widget<DropdownButton<int>>(
            find.byKey(const Key('story-date-month')),
          )
          .onChanged!(1);
      await tester.pump();
      tester
          .widget<DropdownButton<int>>(find.byKey(const Key('story-date-day')))
          .onChanged!(15);
      await tester.pump();
      expect(find.text('Give your memory a title...'), findsOneWidget);
      await _expectLeave(tester);

      await _mount(tester);
      await tester.enterText(
        find.byKey(const Key('story-title')),
        'Just typed',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved'), findsNothing);
      await _expectLeave(tester);
    },
  );

  testWidgets('no prompt after Saved', (tester) async {
    await _surface(tester);
    final stories = _Stories();
    final router = await _mount(tester, stories: stories);
    await tester.enterText(find.byKey(const Key('story-title')), 'Jam');
    await tester.pump(kAutosavePause);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Saved'), findsOneWidget);
    expect(stories.autosaveCalls + stories.createDraftCalls, greaterThan(0));
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/timeline');
  });

  testWidgets('close, system back, and router pop prompt before leaving', (
    tester,
  ) async {
    await _surface(tester);
    FamilySelection.remember('keep');
    final router = await _mount(tester, pushed: true);
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();

    Future<void> onePrompt(Future<void> Function() exit) async {
      await exit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Stay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsNothing);
      expect(router.state.uri.path, '/stories/new');
    }

    await onePrompt(
      () => tester.tap(find.byKey(const Key('story-capture-close'))),
    );
    expect(FamilySelection.id, 'keep');
    await onePrompt(() => tester.binding.handlePopRoute());
    await onePrompt(() async => router.pop());
  });

  testWidgets('Discard writes nothing after dispose', (tester) async {
    await _surface(tester);
    final stories = _Stories();
    final router = await _mount(tester, stories: stories);
    await tester.enterText(find.byKey(const Key('story-title')), 'Temporary');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Discard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.state.uri.path, '/timeline');
    expect(stories.createDraftCalls, 0);
    expect(stories.autosaveCalls, 0);
    expect(stories.updateDraftCalls, 0);
  });

  testWidgets('Save writes with the original familyId', (tester) async {
    await _surface(tester);
    final stories = _Stories();
    final router = await _mount(tester, stories: stories);
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(stories.createDraftCalls, 1);
    expect(stories.createdFamilyId, _ada);
    expect(router.state.uri.path, '/timeline');
  });

  testWidgets('Save failure stays and shows Couldn’t save draft. Try again.', (
    tester,
  ) async {
    await _surface(tester);
    final stories = _Stories()..throwOnCreate = true;
    final router = await _mount(tester, stories: stories);
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Couldn’t save draft. Try again.'), findsOneWidget);
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/stories/new');
    expect(stories.createDraftCalls, 0);
    expect(find.byKey(const Key('story-date-year')), findsOneWidget);
  });

  testWidgets('Publish and Save draft never prompt', (tester) async {
    await _surface(tester);
    final draft = _Stories();
    final draftRouter = await _mount(tester, stories: draft);
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();
    expect(find.text('Draft saved'), findsOneWidget);
    expect(find.text('Leave this story?'), findsNothing);
    expect(draftRouter.state.uri.path, '/stories/new');
    expect(draft.createDraftCalls, 1);

    final blocked = _Stories();
    final blockedRouter = await _mount(tester, stories: blocked);
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pumpAndSettle();
    expect(
      find.text('Finish the highlighted fields to publish.'),
      findsOneWidget,
    );
    expect(find.text('Leave this story?'), findsNothing);
    expect(blocked.publishCalls, 0);
    expect(blockedRouter.state.uri.path, '/stories/new');

    final ready = _Stories(
      story: Story(
        id: 's1',
        familyId: _ada,
        authorId: 'u1',
        title: 'Jam',
        body: 'We made jam.',
        timeframeStart: DateTime(1987),
        timeframeEnd: DateTime(1987, 12, 31),
        datePrecision: StoryDatePrecision.year,
        placeId: _park.id,
        status: StoryStatus.draft,
        personIds: const ['p1'],
      ),
    );
    final readyRouter = await _mount(tester, stories: ready, draftId: 's1');
    await tester.enterText(find.byKey(const Key('story-title')), 'Jam today');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsNothing);
    await tester.pumpAndSettle();
    expect(readyRouter.state.uri.path, '/stories/s1');
    expect(ready.publishCalls, 1);
    expect(find.text('Leave this story?'), findsNothing);
  });

  testWidgets(
    'Save on an undated new story writes nothing, closes the dialog and stays',
    (tester) async {
      await _surface(tester);
      final stories = _Stories();
      final router = await _mount(tester, stories: stories);
      await tester.enterText(find.byKey(const Key('story-title')), 'No date');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('story-capture-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Leave this story?'), findsNothing);
      expect(router.state.uri.path, '/stories/new');
      expect(find.text('No date'), findsOneWidget);
      expect(stories.createDraftCalls, 0);
      expect(stories.autosaveCalls, 0);
      expect(stories.updateDraftCalls, 0);
      await tester.pump(kAutosavePause);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Start a family is not in the dropdown over a dirty story', (
    tester,
  ) async {
    await _surface(tester);
    final router = await _mount(tester);
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    expect(find.byKey(const Key('family-menu')), findsNothing);
    expect(find.byKey(const Key('family-menu-start')), findsNothing);
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/stories/new');
  });
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

GoRouter? _router;

Future<GoRouter> _mount(
  WidgetTester tester, {
  _Stories? stories,
  String? draftId,
  bool pushed = false,
}) async {
  final previous = _router;
  _router = null;
  previous?.dispose();
  final page = NewStoryPage(
    inviteApi: _Invite(),
    peopleApi: _People(),
    placesApi: _Places(),
    mapboxSearch: _Mapbox(),
    storiesApi: stories ?? _Stories(),
    photosApi: _Photos(),
    hasMapboxToken: true,
    mapBuilder: ({double? lat, double? lng}) => const SizedBox.shrink(),
    pickImageBytes: () async => null,
    draftId: draftId,
  );
  final router = GoRouter(
    initialLocation: pushed ? '/timeline' : '/stories/new',
    routes: [
      GoRoute(path: '/family', builder: (_, _) => const Text('landing-marker')),
      GoRoute(
        path: '/timeline',
        builder: (_, _) => const Text('timeline-marker'),
      ),
      GoRoute(path: '/drafts', builder: (_, _) => const Text('drafts-marker')),
      GoRoute(path: '/search', builder: (_, _) => const Text('search-marker')),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Text('settings-marker'),
      ),
      GoRoute(
        path: '/manage-families',
        builder: (_, _) => const Text('manage-marker'),
      ),
      GoRoute(
        path: '/stories/new',
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
    router.push('/stories/new');
    await tester.pumpAndSettle();
  }
  return router;
}

Future<void> _expectLeave(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('story-capture-close')));
  await tester.tap(find.byKey(const Key('story-capture-close')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('Leave this story?'), findsOneWidget);
  await tester.tap(find.widgetWithText(TextButton, 'Stay'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _Stories implements StoriesGateway {
  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => const [];

  _Stories({this.story});

  Story? story;
  var throwOnCreate = false;
  var createDraftCalls = 0;
  var updateDraftCalls = 0;
  var autosaveCalls = 0;
  var publishCalls = 0;
  String? createdFamilyId;

  Story _stored({
    required String id,
    required String familyId,
    String? title,
    String? body,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? placeId,
    List<String> personIds = const [],
  }) {
    return Story(
      id: id,
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
  }

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
    if (throwOnCreate) throw StateError('save failed');
    createDraftCalls++;
    createdFamilyId = familyId;
    story = _stored(
      id: id ?? 's1',
      familyId: familyId,
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      placeId: placeId,
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
    updateDraftCalls++;
    story = _stored(
      id: storyId,
      familyId: story?.familyId ?? _ada,
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      placeId: placeId,
      personIds: personIds ?? const [],
    );
    return story!;
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
  }) async {
    autosaveCalls++;
    return true;
  }

  @override
  Future<Story> publish(String storyId) async {
    publishCalls++;
    return story ??
        Story(
          id: storyId,
          familyId: _ada,
          authorId: 'u1',
          status: StoryStatus.published,
        );
  }

  @override
  Future<Story> getStory(String storyId) async => story!;

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
