import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_covers_repository.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/family_roster.dart';
import 'package:tell_me_a_story/core/domain/invite_link_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/session/auth_info.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';
import 'package:tell_me_a_story/features/search/domain/search_repository.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_family_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/fakes/fake_manage_families_repository.dart';
import '../../../support/fakes/fake_stories_repository.dart';
import '../../../support/album_test_scope.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('dropdown lists live families, a divider, then Manage', (
    tester,
  ) async {
    final container = albumTestContainer();
    await pumpScoped(
      tester,
      container,
      _menu(
        families: [_live('ada', 'Ada Archive'), _live('bea', 'Bea Archive')],
        currentId: 'ada',
        stewarded: const [
          StewardFamily(id: 'ada', name: 'Ada Archive', role: 'owner'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();

    final adaY = tester
        .getTopLeft(find.byKey(const Key('family-menu-item-ada')))
        .dy;
    final beaY = tester
        .getTopLeft(find.byKey(const Key('family-menu-item-bea')))
        .dy;
    final dividerY = tester
        .getTopLeft(find.byKey(const Key('family-menu-divider')))
        .dy;
    final manageY = tester.getTopLeft(find.text('Manage families')).dy;
    expect(adaY, lessThan(beaY));
    expect(beaY, lessThan(dividerY));
    expect(dividerY, lessThan(manageY));
    expect(find.text('Start a family'), findsNothing);
    expect(find.text('Start a new timeline'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('Start is gone and Manage shows for a members-only user', (
    tester,
  ) async {
    final container = albumTestContainer();
    await pumpScoped(
      tester,
      container,
      _menu(
        families: [_live('mem', 'Cousin Archive')],
        currentId: 'mem',
        stewarded: const [],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Start a family'), findsNothing);
    expect(find.text('Manage families'), findsOneWidget);
  });

  testWidgets('Manage is shown for an owner', (tester) async {
    final container = albumTestContainer();
    await _openMenu(
      tester,
      container,
      stewarded: const [
        StewardFamily(id: 'ada', name: 'Ada Archive', role: 'owner'),
      ],
    );
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
  });

  testWidgets('Manage is shown for a co-owner', (tester) async {
    final container = albumTestContainer();
    await _openMenu(
      tester,
      container,
      stewarded: const [
        StewardFamily(id: 'ada', name: 'Ada Archive', role: 'co_owner'),
      ],
    );
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
  });

  testWidgets('Manage is shown when the only owned family is soft-deleted', (
    tester,
  ) async {
    final container = albumTestContainer();
    await _openMenu(
      tester,
      container,
      families: const [],
      currentId: null,
      familyName: 'Family',
      stewarded: [
        StewardFamily(
          id: 'gone',
          name: 'Gone Archive',
          role: 'owner',
          deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 4)),
        ),
      ],
    );
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
    expect(find.text('Gone Archive'), findsNothing);
    expect(find.text('Start a family'), findsNothing);
  });

  testWidgets('Manage is shown for a members-only user', (tester) async {
    final container = albumTestContainer();
    await _openMenu(tester, container, stewarded: const []);
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
    expect(find.text('Start a family'), findsNothing);
  });

  testWidgets('Manage stays visible after switching to a member family', (
    tester,
  ) async {
    final container = albumTestContainer();
    await pumpScoped(
      tester,
      container,
      _SwitchHost(
        families: [
          _live('owned', 'Owned Archive'),
          _live('mem', 'Cousin Archive'),
        ],
        stewarded: const [
          StewardFamily(id: 'owned', name: 'Owned Archive', role: 'owner'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cousin Archive'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
    expect(find.text('Cousin Archive'), findsWidgets);
  });

  testWidgets('a soft-deleted family is absent from the switch list', (
    tester,
  ) async {
    final container = albumTestContainer();
    await _openMenu(
      tester,
      container,
      families: [_live('ada', 'Ada Archive')],
      stewarded: [
        const StewardFamily(id: 'ada', name: 'Ada Archive', role: 'owner'),
        StewardFamily(
          id: 'gone',
          name: 'Gone Archive',
          role: 'co_owner',
          deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        ),
      ],
    );
    expect(find.text('Ada Archive'), findsWidgets);
    expect(find.text('Gone Archive'), findsNothing);
  });

  testWidgets('the avatar menu is exactly Settings and Logout', (tester) async {
    final container = albumTestContainer();
    await pumpScoped(
      tester,
      container,
      _menu(families: [_live('ada', 'Ada Archive')], stewarded: const []),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Manage families'), findsNothing);
    expect(find.byType(PopupMenuDivider), findsNothing);
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Settings')).dy,
      lessThan(tester.getTopLeft(find.text('Logout')).dy),
    );
  });

  testWidgets(
    'family trigger is active and Timeline is plain on both Manage routes',
    (tester) async {
      final container = albumTestContainer(_hub(directory: _Directory()));
      final router = GoRouter(
        initialLocation: AppRoutes.manageFamilies,
        routes: [
          GoRoute(
            path: AppRoutes.manageFamilies,
            builder: (context, state) => const ManageFamiliesPage(),
          ),
          GoRoute(
            path: AppRoutes.manageFamily,
            builder: (context, state) =>
                ManageFamilyPage(familyId: state.pathParameters['familyId']!),
          ),
          GoRoute(
            path: AppRoutes.timeline,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.drafts,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.newStory,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.search,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);

      Future<void> expectActive(String location) async {
        router.go(location);
        await pumpScoped(
          tester,
          container,
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('header-underline-family')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('header-underline-stories')), findsNothing);
        expect(find.byKey(const Key('header-underline-drafts')), findsNothing);
      }

      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await expectActive(AppRoutes.manageFamilies);
      await expectActive('/manage-families/fam-1');
    },
  );

  testWidgets('monogram skips a leading The', (tester) async {
    final directory = _Directory()
      ..directory = const FamilyDirectory(
        active: [
          FamilyRoster(
            id: 'morgan',
            name: "The Morgan Family",
            role: 'owner',
            memberCount: 1,
            publishedCount: 0,
          ),
          FamilyRoster(
            id: 'south',
            name: 'South Archive',
            role: 'member',
            memberCount: 2,
            publishedCount: 0,
          ),
        ],
        recoverable: [],
      );
    final container = albumTestContainer(
      _hub(
        directory: directory,
        families: _Families(
          stewarded: const [
            StewardFamily(
              id: 'morgan',
              name: 'The Morgan Family',
              role: 'owner',
            ),
          ],
        ),
      ),
    );
    await _openMenu(
      tester,
      container,
      families: [
        _live('morgan', "The Morgan Family"),
        _live('ruth', "Grandma Ruth's Side"),
      ],
      currentId: 'morgan',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('family-monogram-morgan')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'M',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('family-monogram-ruth')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'G',
    );

    await pumpScoped(
      tester,
      container,
      const MaterialApp(home: ManageFamiliesPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('South Archive'), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('hub-monogram-morgan')),
              matching: find.byType(Text),
            ),
          )
          .data,
      'M',
    );
  });

  testWidgets('picking a family on Manage opens Family Landing', (
    tester,
  ) async {
    final container = albumTestContainer();
    final router = GoRouter(
      initialLocation: AppRoutes.manageFamilies,
      routes: [
        GoRoute(
          path: AppRoutes.manageFamilies,
          builder: (context, state) => Scaffold(
            appBar: AlbumHeader(
              page: AlbumHeaderPage.manageFamilies,
              familyName: 'Ada Archive',
              families: [
                _live('ada', 'Ada Archive'),
                _live('bea', 'Bea Archive'),
              ],
              currentFamilyId: 'ada',
              onFamilySelected: (id) =>
                  container.read(familySelectionProvider.notifier).remember(id),
              stewarded: const [],
            ),
            body: const Text('hub-screen'),
          ),
        ),
        GoRoute(
          path: '/manage-families/:familyId',
          builder: (context, state) => Scaffold(
            appBar: AlbumHeader(
              page: AlbumHeaderPage.manageFamilies,
              familyName: 'Ada Archive',
              families: [
                _live('ada', 'Ada Archive'),
                _live('bea', 'Bea Archive'),
              ],
              currentFamilyId: 'bea',
              onFamilySelected: (id) =>
                  container.read(familySelectionProvider.notifier).remember(id),
              stewarded: const [],
            ),
            body: const Text('detail-screen'),
          ),
        ),
        GoRoute(
          path: AppRoutes.familyLanding,
          builder: (context, state) =>
              const Scaffold(body: Text('landing-screen')),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) =>
              const Scaffold(body: Text('timeline-screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-bea')));
    await tester.pumpAndSettle();

    expect(find.text('landing-screen'), findsOneWidget);
    expect(find.text('hub-screen'), findsNothing);
    expect(container.read(familySelectionProvider), 'bea');

    router.go('/manage-families/ada');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-ada')));
    await tester.pumpAndSettle();

    expect(find.text('landing-screen'), findsOneWidget);
    expect(container.read(familySelectionProvider), 'ada');
  });

  testWidgets('a live family lands on Family Landing', (tester) async {
    final path = await _land(
      tester,
      families: _Families(live: [_live('ada', 'Ada Archive')]),
      familyId: 'ada',
    );
    expect(path, AppRoutes.familyLanding);
  });

  testWidgets(
    'no live family and a recoverable owned family lands on the hub',
    (tester) async {
      final path = await _land(
        tester,
        families: _Families(
          stewarded: [
            StewardFamily(
              id: 'gone',
              name: 'Gone Archive',
              role: 'owner',
              deletedAt: DateTime.now().toUtc().subtract(
                const Duration(days: 3),
              ),
            ),
          ],
        ),
      );
      expect(path, AppRoutes.manageFamilies);
      expect(find.text('Manage families'), findsOneWidget);
    },
  );

  testWidgets(
    'no live family and nothing to recover lands on the empty Start state',
    (tester) async {
      final path = await _land(tester, families: _Families());
      expect(path, AppRoutes.timeline);
      expect(
        find.text('No stories yet. Capture the first one for this family.'),
        findsOneWidget,
      );
      expect(find.byType(ManageFamiliesPage), findsNothing);
    },
  );
}

MemberFamily _live(String id, String name) {
  return MemberFamily(id: id, name: name, createdAt: DateTime.utc(2020));
}

Future<void> _openMenu(
  WidgetTester tester,
  ProviderContainer container, {
  List<MemberFamily>? families,
  String? currentId = 'ada',
  String familyName = 'Ada Archive',
  List<StewardFamily> stewarded = const [],
}) async {
  await pumpScoped(
    tester,
    container,
    _menu(
      families: families ?? [_live('ada', 'Ada Archive')],
      currentId: currentId,
      familyName: familyName,
      stewarded: stewarded,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('family-menu')));
  await tester.pumpAndSettle();
}

Widget _menu({
  required List<MemberFamily> families,
  String? currentId = 'ada',
  String familyName = 'Ada Archive',
  required List<StewardFamily> stewarded,
}) {
  return MaterialApp(
    home: Scaffold(
      appBar: AlbumHeader(
        page: AlbumHeaderPage.timeline,
        familyName: familyName,
        families: families,
        currentFamilyId: currentId,
        onFamilySelected: (_) {},
        stewarded: stewarded,
        onLogout: () async {},
      ),
    ),
  );
}

class _SwitchHost extends StatefulWidget {
  const _SwitchHost({required this.families, required this.stewarded});

  final List<MemberFamily> families;
  final List<StewardFamily> stewarded;

  @override
  State<_SwitchHost> createState() => _SwitchHostState();
}

class _SwitchHostState extends State<_SwitchHost> {
  String _current = 'owned';

  @override
  Widget build(BuildContext context) {
    final name = widget.families
        .firstWhere((family) => family.id == _current)
        .name;
    return MaterialApp(
      home: Scaffold(
        appBar: AlbumHeader(
          page: AlbumHeaderPage.timeline,
          familyName: name,
          families: widget.families,
          currentFamilyId: _current,
          onFamilySelected: (id) => setState(() => _current = id),
          stewarded: widget.stewarded,
          onLogout: () async {},
        ),
      ),
    );
  }
}

Future<String> _land(
  WidgetTester tester, {
  required _Families families,
  String? familyId,
}) async {
  final container = albumTestContainer([
    authInfoProvider.overrideWithValue(
      ValueNotifier<AuthSuccess?>(_signedInUser),
    ),
    inviteRepositoryProvider.overrideWithValue(
      FakeInviteRepository(
        familyId: familyId,
        createdFamilyId: 'created',
        acceptedFamilyId: 'f',
      ),
    ),
    familiesRepositoryProvider.overrideWithValue(families),
    storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
    familyDirectoryRepositoryProvider.overrideWithValue(_Directory()),
    manageFamiliesRepositoryProvider.overrideWithValue(
      FakeManageFamiliesRepository()..error = StateError('unexpected call'),
    ),
    familyCoversRepositoryProvider.overrideWithValue(_OfflineCovers()),
    inviteLinkRepositoryProvider.overrideWithValue(_OfflineInviteLink()),
    peopleRepositoryProvider.overrideWithValue(_OfflinePeople()),
    placesRepositoryProvider.overrideWithValue(_OfflinePlaces()),
    mapboxSearchRepositoryProvider.overrideWithValue(_OfflineMapbox()),
    photosRepositoryProvider.overrideWithValue(_OfflinePhotos()),
    commentsRepositoryProvider.overrideWithValue(_OfflineComments()),
    perspectivesRepositoryProvider.overrideWithValue(_OfflinePerspectives()),
    searchRepositoryProvider.overrideWithValue(_OfflineSearch()),
    otpSignInProvider.overrideWithValue(_OfflineOtp()),
    storyThumbsLoaderProvider.overrideWithValue((stories) async => const {}),
  ]);
  await pumpScoped(tester, container, const App());
  await tester.pumpAndSettle();
  return container
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
}

/// Hub repositories: [directory], [families] (both empty by default), and a
/// manage repository these flows must not use.
List<Override> _hub({
  FamilyDirectoryRepository? directory,
  _Families? families,
}) {
  return [
    familyDirectoryRepositoryProvider.overrideWithValue(
      directory ?? _Directory(),
    ),
    familiesRepositoryProvider.overrideWithValue(families ?? _Families()),
    manageFamiliesRepositoryProvider.overrideWithValue(
      FakeManageFamiliesRepository()..error = StateError('unexpected call'),
    ),
    inviteRepositoryProvider.overrideWithValue(
      FakeInviteRepository(familyId: null),
    ),
  ];
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

class _OfflineCovers with _Offline implements FamilyCoversRepository {}

class _OfflineInviteLink with _Offline implements InviteLinkRepository {}

class _OfflinePeople with _Offline implements PeopleRepository {}

class _OfflinePlaces with _Offline implements PlacesRepository {}

class _OfflineMapbox with _Offline implements MapboxSearchRepository {}

class _OfflinePhotos with _Offline implements PhotosRepository {}

class _OfflineComments with _Offline implements CommentsRepository {}

class _OfflinePerspectives with _Offline implements PerspectivesRepository {}

class _OfflineSearch with _Offline implements SearchRepository {}

class _OfflineOtp with _Offline implements OtpSignIn {}

class _Families extends FamiliesRepository {
  _Families({this.live = const [], this.stewarded = const []});

  final List<MemberFamily> live;
  final List<StewardFamily> stewarded;

  @override
  Future<List<MemberFamily>> listMine() async => live;

  @override
  Future<List<StewardFamily>> listStewarded() async => stewarded;
}

class _Directory implements FamilyDirectoryRepository {
  FamilyDirectory directory = const FamilyDirectory(
    active: [
      FamilyRoster(
        id: 'fam-1',
        name: 'North Archive',
        role: 'owner',
        memberCount: 1,
        publishedCount: 0,
      ),
    ],
    recoverable: [],
  );

  FamilyDetail? detail = const FamilyDetail(
    id: 'fam-1',
    name: 'North Archive',
    myRole: 'owner',
    people: [],
  );

  @override
  Future<FamilyDirectory> listDirectory() async => directory;

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async => detail;
}
