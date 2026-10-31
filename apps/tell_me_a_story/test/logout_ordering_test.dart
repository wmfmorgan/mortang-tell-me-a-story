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

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('Save runs before onLogout', (tester) async {
    await _surface(tester);
    final order = <String>[];
    final router = await _mount(tester, stories: _Stories(order));
    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.pump();
    await tester.tap(find.byKey(const Key('story-capture-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(order, ['createDraft']);
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/timeline');
    expect(find.byKey(const Key('header-menu-logout')), findsNothing);
  });
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

GoRouter? _router;

Future<GoRouter> _mount(
  WidgetTester tester, {
  required _Stories stories,
}) async {
  final previous = _router;
  _router = null;
  previous?.dispose();
  final router = GoRouter(
    initialLocation: '/stories/new',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (_, _) => const Text('timeline-marker'),
      ),
      GoRoute(
        path: '/stories/new',
        onExit: (context, state) => UnsavedGuards.onExit(context, state),
        builder: (_, _) => NewStoryPage(
          inviteApi: _Invite(),
          peopleApi: _People(),
          placesApi: _Places(),
          mapboxSearch: _Mapbox(),
          storiesApi: stories,
          photosApi: _Photos(),
          hasMapboxToken: false,
          mapBuilder: ({double? lat, double? lng}) => const SizedBox.shrink(),
          pickImageBytes: () async => null,
        ),
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
  return router;
}

class _Stories implements StoriesGateway {
  @override
  Future<Story?> getPublishedOrigin(String storyId) async => null;
  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => const [];

  _Stories(this.order);

  final List<String> order;
  var createDraftCalls = 0;

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
    order.add('createDraft');
    createDraftCalls++;
    return Story(
      id: id ?? 's1',
      familyId: familyId,
      authorId: 'u1',
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      status: StoryStatus.draft,
      personIds: personIds,
    );
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
    throw UnimplementedError();
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
  Future<Story> publish(String storyId) async {
    throw UnimplementedError();
  }

  @override
  Future<Story> getStory(String storyId) async {
    throw UnimplementedError();
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

class _People extends PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

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
  Future<List<Place>> listFavorites(String familyId) async => const [];

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      const [];

  @override
  Future<List<Place>> listPlaces(String familyId) async => const [];

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
    throw UnimplementedError();
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
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async => null;
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
