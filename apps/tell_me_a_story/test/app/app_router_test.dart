import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/app/app.dart';
import 'package:tell_me_a_story/app/app_router.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/data/auth_refresh.dart';
import 'package:tell_me_a_story/data/comments_api.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart'
    hide displayNameOrMember;
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
import 'package:tell_me_a_story/features/auth/sign_in_page.dart';
import 'package:tell_me_a_story/features/drafts/drafts_page.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';
import 'package:tell_me_a_story/features/family/family_landing_page.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

import '../support/fakes/fake_invite_gateway.dart';
import '../support/fakes/fake_stories_gateway.dart';

class _StubPeopleApi extends PeopleGateway {
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

class _StubPlacesApi implements PlacesGateway {
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

class _StubMapboxSearch implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}

class _StubPhotosApi implements PhotosGateway {
  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) {
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
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);
}

class _StubCommentsApi implements CommentsGateway {
  @override
  Future<List<Comment>> listForStory(String storyId) async => const [];

  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> update({required String id, required String body}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}
}

class _StubPerspectivesApi implements PerspectivesGateway {
  @override
  Future<List<Perspective>> listForStory(String storyId) async => const [];

  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> update({required String id, required String body}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}
}

GoRouter _router({required AuthRefresh auth}) {
  return createAppRouter(
    authRefresh: auth,
    inviteApi: FakeInviteGateway(
      createdFamilyId: 'family-1',
      acceptedFamilyId: 'f',
    ),
    peopleApi: _StubPeopleApi(),
    placesApi: _StubPlacesApi(),
    mapboxSearch: _StubMapboxSearch(),
    storiesApi: FakeStoriesGateway(),
    photosApi: _StubPhotosApi(),
    commentsApi: _StubCommentsApi(),
    perspectivesApi: _StubPerspectivesApi(),
  );
}

void main() {
  testWidgets('signed-out user is redirected from /timeline to sign-in', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(TimelinePage), findsNothing);

    auth.dispose();
  });

  testWidgets('signed-in user is redirected from sign-in to /family', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.familyLanding,
    );
    expect(find.byType(FamilyLandingPage), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);

    auth.dispose();
  });

  testWidgets(
    'auth refresh moves signed-out user to Family Landing after sign-in',
    (tester) async {
      final info = ValueNotifier<AuthSuccess?>(null);
      final auth = AuthRefresh(authInfo: info);
      final router = createAppRouter(
        authRefresh: auth,
        inviteApi: FakeInviteGateway(
          createdFamilyId: 'family-1',
          acceptedFamilyId: 'f',
        ),
      );

      await tester.pumpWidget(TellMeAStoryApp(router: router));
      await tester.pumpAndSettle();
      expect(find.byType(SignInPage), findsOneWidget);

      info.value = AuthSuccess(
        authStrategy: 'session',
        token: 'token',
        authUserId: UuidValue.fromString(
          '00000000-0000-4000-8000-00000000000a',
        ),
        scopeNames: const {},
      );
      await tester.pumpAndSettle();

      expect(find.byType(FamilyLandingPage), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        AppRoutes.familyLanding,
      );

      auth.dispose();
      FamilySelection.clear();
      ProfileSession.instance.clear();
    },
  );

  testWidgets('invite query rewrites to /invite/:token', (tester) async {
    // Signed out, so the rewritten invite page stays. A signed-in session
    // accepts and continues to the timeline.
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go('/?invite=abc123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/invite/abc123');
    expect(uri.queryParameters['invite'], isNull);

    auth.dispose();
  });

  testWidgets('signed-in user can open /stories/new', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.newStory,
    );
    expect(find.byType(NewStoryPage), findsOneWidget);
    expect(find.byKey(const Key('story-capture-modal')), findsOneWidget);
    expect(find.text('STORY'), findsOneWidget);
    expect(find.text('Publish story'), findsOneWidget);
    expect(find.text('New story'), findsNothing);

    auth.dispose();
  });

  testWidgets('a non-member /stories/new returns to Family Landing', (
    tester,
  ) async {
    addTearDown(FamilySelection.clear);
    FamilySelection.remember('other-family');
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      familiesApi: _MemberOf(['ada']),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    FamilySelection.remember('other-family');
    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.familyLanding,
    );
    expect(find.byType(NewStoryPage), findsNothing);

    auth.dispose();
  });

  testWidgets('signed-out user is redirected from /stories/new to sign-in', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(NewStoryPage), findsNothing);

    auth.dispose();
  });

  testWidgets('timeline New story pushes /stories/new', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      familiesApi: _MemberOf(['family-1']),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byType(FamilyLandingPage), findsOneWidget);
    final newStoryButton = find.widgetWithText(FilledButton, 'New story');
    expect(newStoryButton, findsOneWidget);
    // Invoke directly: AppBar action hit-tests can miss in small surfaces;
    // push Future completes only when the route is popped.
    tester.widget<FilledButton>(newStoryButton).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewStoryPage), findsOneWidget);
    final locations = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(locations, contains(AppRoutes.newStory));

    auth.dispose();
  });

  testWidgets('Timeline AppBar Drafts pushes /drafts', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = _router(auth: auth);

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byType(FamilyLandingPage), findsOneWidget);
    await tester.tap(find.text('Draft Stories'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DraftsPage), findsOneWidget);
    final locations = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(locations, contains(AppRoutes.drafts));

    auth.dispose();
  });

  testWidgets('signed-in user can open /drafts', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.drafts);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.drafts,
    );
    expect(find.byType(DraftsPage), findsOneWidget);
    expect(find.text('Draft Stories'), findsWidgets);

    auth.dispose();
  });

  testWidgets('signed-out user is redirected from /settings to sign-in', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);

    auth.dispose();
  });

  testWidgets('signed-out user is redirected from /drafts to sign-in', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.drafts);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(DraftsPage), findsNothing);

    auth.dispose();
  });

  testWidgets('new story route forwards draft query', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go('${AppRoutes.newStory}?draft=s1');
    await tester.pumpAndSettle();

    expect(find.byType(NewStoryPage), findsOneWidget);
    expect(
      tester.widget<NewStoryPage>(find.byType(NewStoryPage)).draftId,
      's1',
    );

    auth.dispose();
  });

  testWidgets('signed-in /stories/new is still capture, not the reader', (
    tester,
  ) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.newStory,
    );
    expect(find.byType(NewStoryPage), findsOneWidget);
    expect(find.byKey(const Key('story-reader')), findsNothing);

    auth.dispose();
  });

  testWidgets('signed-in /stories/<uuid> shows story-reader, not capture', (
    tester,
  ) async {
    const storyId = '550e8400-e29b-41d4-a716-446655440000';
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.storyPath(storyId));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.storyPath(storyId),
    );
    expect(find.byKey(const Key('story-reader-modal')), findsOneWidget);
    expect(find.byType(NewStoryPage), findsNothing);

    auth.dispose();
  });

  testWidgets('signed-in /stories/<uuid>/perspective shows add-perspective', (
    tester,
  ) async {
    const storyId = '550e8400-e29b-41d4-a716-446655440000';
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = _router(auth: auth);

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.storyPerspectivePath(storyId));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.storyPerspectivePath(storyId),
    );
    expect(find.byKey(const Key('add-perspective')), findsOneWidget);
    expect(find.byType(NewStoryPage), findsNothing);
    expect(find.byKey(const Key('story-reader')), findsNothing);

    auth.dispose();
  });
}

class _MemberOf extends FamiliesGateway {
  _MemberOf(this.ids);

  final List<String> ids;

  @override
  Future<List<MemberFamily>> listMine() async {
    return [
      for (final id in ids)
        MemberFamily(id: id, name: id, createdAt: DateTime.utc(2020)),
    ];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}
