import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/comment.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_covers_repository.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_link_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/perspective.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/core/session/auth_info.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';
import 'package:tell_me_a_story/features/search/domain/search_repository.dart';
import 'package:tell_me_a_story/features/auth/presentation/sign_in_page.dart';
import 'package:tell_me_a_story/features/drafts/presentation/drafts_page.dart';
import 'package:tell_me_a_story/features/stories/presentation/new_story_page.dart';
import 'package:tell_me_a_story/features/family/presentation/family_landing_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_page.dart';

import '../../support/fakes/fake_invite_repository.dart';
import '../../support/fakes/fake_manage_families_repository.dart';
import '../../support/fakes/fake_mapbox_search.dart';
import '../../support/fakes/fake_photos_repository.dart';
import '../../support/fakes/fake_places_repository.dart';
import '../../support/fakes/fake_stories_repository.dart';
import '../../support/pump_app.dart';

class _StubPeopleApi extends PeopleRepository {
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

class _StubCommentsApi implements CommentsRepository {
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

class _StubPerspectivesApi implements PerspectivesRepository {
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

_TestApp _fullApp({required bool signedIn}) {
  return _TestApp(
    signedIn: signedIn,
    inviteApi: FakeInviteRepository(
      createdFamilyId: 'family-1',
      acceptedFamilyId: 'f',
    ),
    peopleApi: _StubPeopleApi(),
    placesApi: FakePlacesRepository(),
    mapboxSearch: FakeMapboxSearch(),
    storiesApi: FakeStoriesRepository(),
    photosApi: FakePhotosRepository(),
    commentsApi: _StubCommentsApi(),
    perspectivesApi: _StubPerspectivesApi(),
  );
}

void main() {
  testWidgets('signed-out user is redirected from /timeline to sign-in', (
    tester,
  ) async {
    final app = _TestApp(
      signedIn: false,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(TimelinePage), findsNothing);

    app.dispose();
  });

  testWidgets('signed-in user is redirected from sign-in to /family', (
    tester,
  ) async {
    final app = _TestApp(
      signedIn: true,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.familyLanding,
    );
    expect(find.byType(FamilyLandingPage), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);

    app.dispose();
  });

  testWidgets(
    'auth refresh moves signed-out user to Family Landing after sign-in',
    (tester) async {
      final info = ValueNotifier<AuthSuccess?>(null);
      final app = _TestApp(
        authInfo: info,
        inviteApi: FakeInviteRepository(
          createdFamilyId: 'family-1',
          acceptedFamilyId: 'f',
        ),
      );
      final router = app.router;

      await tester.pumpWidget(app.widget);
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

      app.dispose();
    },
  );

  testWidgets('invite query rewrites to /invite/:token', (tester) async {
    // Signed out, so the rewritten invite page stays. A signed-in session
    // accepts and continues to the timeline.
    final app = _TestApp(
      signedIn: false,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go('/?invite=abc123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/invite/abc123');
    expect(uri.queryParameters['invite'], isNull);

    app.dispose();
  });

  testWidgets('signed-in user can open /stories/new', (tester) async {
    final app = _TestApp(
      signedIn: true,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      peopleApi: _StubPeopleApi(),
      placesApi: FakePlacesRepository(),
      mapboxSearch: FakeMapboxSearch(),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
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

    app.dispose();
  });

  testWidgets('a non-member /stories/new returns to Family Landing', (
    tester,
  ) async {
    final app = _TestApp(
      signedIn: true,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      familiesApi: _MemberOf(['ada']),
      peopleApi: _StubPeopleApi(),
      placesApi: FakePlacesRepository(),
      mapboxSearch: FakeMapboxSearch(),
    );
    final router = app.router;
    _remember(app, 'other-family');

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    _remember(app, 'other-family');
    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.familyLanding,
    );
    expect(find.byType(NewStoryPage), findsNothing);

    app.dispose();
  });

  testWidgets('signed-out user is redirected from /stories/new to sign-in', (
    tester,
  ) async {
    final app = _TestApp(
      signedIn: false,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      peopleApi: _StubPeopleApi(),
      placesApi: FakePlacesRepository(),
      mapboxSearch: FakeMapboxSearch(),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(NewStoryPage), findsNothing);

    app.dispose();
  });

  testWidgets('timeline New story pushes /stories/new', (tester) async {
    final app = _TestApp(
      signedIn: true,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      familiesApi: _MemberOf(['family-1']),
      peopleApi: _StubPeopleApi(),
      placesApi: FakePlacesRepository(),
      mapboxSearch: FakeMapboxSearch(),
    );
    final router = app.router;

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app.widget);
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

    app.dispose();
  });

  testWidgets('Timeline AppBar Drafts pushes /drafts', (tester) async {
    final app = _fullApp(signedIn: true);
    final router = app.router;

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app.widget);
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

    app.dispose();
  });

  testWidgets('signed-in user can open /drafts', (tester) async {
    final app = _fullApp(signedIn: true);
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.drafts);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.drafts,
    );
    expect(find.byType(DraftsPage), findsOneWidget);
    expect(find.text('Draft Stories'), findsWidgets);

    app.dispose();
  });

  testWidgets('signed-out user is redirected from /settings to sign-in', (
    tester,
  ) async {
    final app = _fullApp(signedIn: false);
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);

    app.dispose();
  });

  testWidgets('signed-out user is redirected from /drafts to sign-in', (
    tester,
  ) async {
    final app = _fullApp(signedIn: false);
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.drafts);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.byType(DraftsPage), findsNothing);

    app.dispose();
  });

  testWidgets('new story route forwards draft query', (tester) async {
    final app = _fullApp(signedIn: true);
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go('${AppRoutes.newStory}?draft=s1');
    await tester.pumpAndSettle();

    expect(find.byType(NewStoryPage), findsOneWidget);
    expect(
      tester.widget<NewStoryPage>(find.byType(NewStoryPage)).draftId,
      's1',
    );

    app.dispose();
  });

  testWidgets('signed-in /stories/new is still capture, not the reader', (
    tester,
  ) async {
    final app = _fullApp(signedIn: true);
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.newStory);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.newStory,
    );
    expect(find.byType(NewStoryPage), findsOneWidget);
    expect(find.byKey(const Key('story-reader')), findsNothing);

    app.dispose();
  });

  testWidgets('signed-in /stories/<uuid> shows story-reader, not capture', (
    tester,
  ) async {
    const storyId = '550e8400-e29b-41d4-a716-446655440000';
    final app = _fullApp(signedIn: true);
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.storyPath(storyId));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.storyPath(storyId),
    );
    expect(find.byKey(const Key('story-reader-modal')), findsOneWidget);
    expect(find.byType(NewStoryPage), findsNothing);

    app.dispose();
  });

  testWidgets('signed-in /stories/<uuid>/perspective shows add-perspective', (
    tester,
  ) async {
    const storyId = '550e8400-e29b-41d4-a716-446655440000';
    final app = _fullApp(signedIn: true);
    final router = app.router;

    await tester.pumpWidget(app.widget);
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

    app.dispose();
  });

  testWidgets('signed-in /family/<id>/tree shows the whole-tree page', (
    tester,
  ) async {
    const familyId = '550e8400-e29b-41d4-a716-4466554400aa';
    final app = _TestApp(
      signedIn: true,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
      storiesApi: FakeStoriesRepository(),
      familiesApi: _MemberOf([familyId]),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.familyTreePath(familyId));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/family/$familyId/tree',
    );
    expect(find.byType(FamilyTreePage), findsOneWidget);
    expect(
      tester.widget<FamilyTreePage>(find.byType(FamilyTreePage)).familyId,
      familyId,
    );

    app.dispose();
  });

  testWidgets('signed-out user is redirected from the tree page to sign-in', (
    tester,
  ) async {
    final app = _TestApp(
      signedIn: false,
      inviteApi: FakeInviteRepository(
        createdFamilyId: 'family-1',
        acceptedFamilyId: 'f',
      ),
    );
    final router = app.router;

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    router.go(AppRoutes.familyTreePath('f'));
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.signIn,
    );
    expect(find.byType(FamilyTreePage), findsNothing);

    app.dispose();
  });
}

class _MemberOf extends FamiliesRepository {
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

final _signedInUser = AuthSuccess(
  authStrategy: 'session',
  token: 'token',
  authUserId: UuidValue.fromString('00000000-0000-4000-8000-00000000000b'),
  scopeNames: const {},
);

const _offline = AppException(
  code: AppErrorCode.unauthenticated,
  message: 'No server in widget tests.',
);

/// Fails every call like an unreachable server, for repositories a test
/// does not exercise.
mixin _Offline {
  @override
  Object? noSuchMethod(Invocation invocation) => Future<Never>.error(_offline);
}

class _OfflineDirectory with _Offline implements FamilyDirectoryRepository {}

class _OfflineCovers with _Offline implements FamilyCoversRepository {}

class _OfflineInviteLink with _Offline implements InviteLinkRepository {}

class _OfflineSearch with _Offline implements SearchRepository {}

class _OfflineOtp with _Offline implements OtpSignIn {}

void _remember(_TestApp app, String familyId) =>
    app.container.read(familySelectionProvider.notifier).remember(familyId);

/// The app's router and widget over a [ProviderContainer]. Repositories a
/// test leaves out get benign fakes (one live family, no stories); the rest
/// fail like an unreachable server.
class _TestApp {
  _TestApp({
    bool signedIn = false,
    ValueListenable<AuthSuccess?>? authInfo,
    required InviteRepository inviteApi,
    PeopleRepository? peopleApi,
    PlacesRepository? placesApi,
    MapboxSearchRepository? mapboxSearch,
    StoriesRepository? storiesApi,
    PhotosRepository? photosApi,
    CommentsRepository? commentsApi,
    PerspectivesRepository? perspectivesApi,
    FamiliesRepository? familiesApi,
  }) : container = ProviderContainer(
         overrides: [
           ...defaultTestOverrides,
           authInfoProvider.overrideWithValue(
             authInfo ??
                 ValueNotifier<AuthSuccess?>(signedIn ? _signedInUser : null),
           ),
           inviteRepositoryProvider.overrideWithValue(inviteApi),
           peopleRepositoryProvider.overrideWithValue(
             peopleApi ?? _StubPeopleApi(),
           ),
           placesRepositoryProvider.overrideWithValue(
             placesApi ?? FakePlacesRepository(),
           ),
           mapboxSearchRepositoryProvider.overrideWithValue(
             mapboxSearch ?? FakeMapboxSearch(),
           ),
           storiesRepositoryProvider.overrideWithValue(
             storiesApi ?? FakeStoriesRepository(),
           ),
           photosRepositoryProvider.overrideWithValue(
             photosApi ?? FakePhotosRepository(),
           ),
           commentsRepositoryProvider.overrideWithValue(
             commentsApi ?? _StubCommentsApi(),
           ),
           perspectivesRepositoryProvider.overrideWithValue(
             perspectivesApi ?? _StubPerspectivesApi(),
           ),
           familiesRepositoryProvider.overrideWithValue(
             familiesApi ?? _MemberOf(['family-1']),
           ),
           familyDirectoryRepositoryProvider.overrideWithValue(
             _OfflineDirectory(),
           ),
           familyCoversRepositoryProvider.overrideWithValue(_OfflineCovers()),
           manageFamiliesRepositoryProvider.overrideWithValue(
             FakeManageFamiliesRepository(),
           ),
           inviteLinkRepositoryProvider.overrideWithValue(_OfflineInviteLink()),
           searchRepositoryProvider.overrideWithValue(_OfflineSearch()),
           otpSignInProvider.overrideWithValue(_OfflineOtp()),
           storyThumbsLoaderProvider.overrideWithValue(
             (stories) async => const {},
           ),
         ],
       );

  final ProviderContainer container;

  GoRouter get router => container.read(appRouterProvider);

  Widget get widget =>
      UncontrolledProviderScope(container: container, child: const App());

  void dispose() => container.dispose();
}
