import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/features/auth/magic_link_page.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

class _StubInviteApi implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => 'family-1';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) async {
    return const CreateInviteResult(
      inviteId: 'i',
      token: 't',
      expiresAt: '2099-01-01T00:00:00Z',
      inviteUrl: 'http://127.0.0.1:3000/timeline?invite=t',
    );
  }

  @override
  Future<String?> currentFamilyId() async => 'family-1';

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _StubPeopleApi implements PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

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

class _StubPlacesApi implements PlacesGateway {
  @override
  Future<List<Place>> listFavorites(String familyId) async => const [];

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      const [];

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
  ) async =>
      null;
}

class _StubMapboxSearch implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}

void main() {
  testWidgets('signed-out user is redirected from /timeline to magic-link',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.magicLink);
    expect(find.byType(MagicLinkPage), findsOneWidget);
    expect(find.byType(TimelinePage), findsNothing);

    auth.dispose();
  });

  testWidgets('signed-in user is redirected from magic-link to /timeline',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.timeline);
    expect(find.byType(TimelinePage), findsOneWidget);
    expect(find.byType(MagicLinkPage), findsNothing);

    auth.dispose();
  });

  testWidgets('auth refresh moves signed-out user to timeline after sign-in',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();
    expect(find.byType(MagicLinkPage), findsOneWidget);

    auth.setSignedIn(true);
    await tester.pumpAndSettle();

    expect(find.byType(TimelinePage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.timeline,
    );

    auth.dispose();
  });

  testWidgets('invite query is preserved when redirecting to timeline',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
    );

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go('/?invite=abc123');
    await tester.pumpAndSettle();

    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, AppRoutes.timeline);
    expect(uri.queryParameters['invite'], 'abc123');

    auth.dispose();
  });

  testWidgets('signed-in user can open /stories/new', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
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
    expect(find.text('New story'), findsWidgets);

    auth.dispose();
  });

  testWidgets('signed-out user is redirected from /stories/new to magic-link',
      (tester) async {
    final auth = AuthRefresh(initiallySignedIn: false);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
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
      AppRoutes.magicLink,
    );
    expect(find.byType(MagicLinkPage), findsOneWidget);
    expect(find.byType(NewStoryPage), findsNothing);

    auth.dispose();
  });

  testWidgets('timeline New story pushes /stories/new', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: _StubInviteApi(),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byType(TimelinePage), findsOneWidget);
    final newStoryButton = find.widgetWithText(TextButton, 'New story');
    expect(newStoryButton, findsOneWidget);
    // Invoke directly: AppBar action hit-tests can miss in small surfaces;
    // push Future completes only when the route is popped.
    tester.widget<TextButton>(newStoryButton).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewStoryPage), findsOneWidget);
    final locations = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(locations, contains(AppRoutes.newStory));

    auth.dispose();
  });
}
