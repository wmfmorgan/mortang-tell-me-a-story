import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/features/family/manage_families_page.dart';
import 'package:tell_me_a_story/features/family/manage_family_page.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('dropdown lists live families, a divider, Start, then Manage', (
    tester,
  ) async {
    await tester.pumpWidget(
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
    final startY = tester.getTopLeft(find.text('+ Start a family')).dy;
    final manageY = tester.getTopLeft(find.text('Manage families')).dy;
    expect(adaY, lessThan(beaY));
    expect(beaY, lessThan(dividerY));
    expect(dividerY, lessThan(startY));
    expect(startY, lessThan(manageY));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('Start is visible for a members-only user and opens the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      _menu(
        families: [_live('mem', 'Cousin Archive')],
        currentId: 'mem',
        stewarded: const [],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();

    expect(find.text('+ Start a family'), findsOneWidget);
    expect(find.text('Manage families'), findsNothing);
    await tester.tap(find.byKey(const Key('family-menu-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('start-family-dialog')), findsOneWidget);
  });

  testWidgets('Manage is shown for an owner', (tester) async {
    await _openMenu(
      tester,
      stewarded: const [
        StewardFamily(id: 'ada', name: 'Ada Archive', role: 'owner'),
      ],
    );
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
  });

  testWidgets('Manage is shown for a co-owner', (tester) async {
    await _openMenu(
      tester,
      stewarded: const [
        StewardFamily(id: 'ada', name: 'Ada Archive', role: 'co_owner'),
      ],
    );
    expect(find.byKey(const Key('family-menu-manage')), findsOneWidget);
  });

  testWidgets('Manage is shown when the only owned family is soft-deleted', (
    tester,
  ) async {
    await _openMenu(
      tester,
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
    expect(find.text('+ Start a family'), findsOneWidget);
  });

  testWidgets('Manage is hidden for a members-only user', (tester) async {
    await _openMenu(tester, stewarded: const []);
    expect(find.byKey(const Key('family-menu-manage')), findsNothing);
    expect(find.text('+ Start a family'), findsOneWidget);
  });

  testWidgets('Manage stays visible after switching to a member family', (
    tester,
  ) async {
    await tester.pumpWidget(
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
    await _openMenu(
      tester,
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
    await tester.pumpWidget(
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
      final directory = _Directory();
      final router = GoRouter(
        initialLocation: AppRoutes.manageFamilies,
        routes: [
          GoRoute(
            path: AppRoutes.manageFamilies,
            builder: (context, state) => ManageFamiliesPage(
              directoryApi: directory,
              manageApi: _Manage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.manageFamily,
            builder: (context, state) => ManageFamilyPage(
              familyId: state.pathParameters['familyId']!,
              directoryApi: directory,
              manageApi: _Manage(),
            ),
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
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('header-underline-family')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('header-underline-timeline')),
          findsNothing,
        );
        expect(find.byKey(const Key('header-underline-drafts')), findsNothing);
      }

      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await expectActive(AppRoutes.manageFamilies);
      await expectActive('/manage-families/fam-1');
    },
  );

  testWidgets('monogram skips a leading The', (tester) async {
    await _openMenu(
      tester,
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

    final directory = _Directory()
      ..directory = FamilyDirectory(
        active: [
          FamilyRoster(
            id: 'morgan',
            name: "The Morgan Family",
            role: 'owner',
            memberCount: 1,
            publishedCount: 0,
          ),
          const FamilyRoster(
            id: 'south',
            name: 'South Archive',
            role: 'member',
            memberCount: 2,
            publishedCount: 0,
          ),
        ],
        recoverable: const [],
      );
    await tester.pumpWidget(
      MaterialApp(
        home: ManageFamiliesPage(directoryApi: directory, manageApi: _Manage()),
      ),
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

  testWidgets('picking a family on Manage opens that timeline', (tester) async {
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
              onFamilySelected: FamilySelection.remember,
              stewarded: const [],
              manageApi: _Manage(),
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
              currentFamilyId: 'ada',
              onFamilySelected: FamilySelection.remember,
              stewarded: const [],
              manageApi: _Manage(),
            ),
            body: const Text('detail-screen'),
          ),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) =>
              const Scaffold(body: Text('timeline-screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-bea')));
    await tester.pumpAndSettle();

    expect(find.text('timeline-screen'), findsOneWidget);
    expect(find.text('hub-screen'), findsNothing);
    expect(FamilySelection.id, 'bea');

    router.go('/manage-families/ada');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-ada')));
    await tester.pumpAndSettle();

    expect(find.text('timeline-screen'), findsOneWidget);
    expect(FamilySelection.id, 'ada');
  });

  testWidgets('a live family lands on the timeline', (tester) async {
    final path = await _land(
      tester,
      families: _Families(live: [_live('ada', 'Ada Archive')]),
      familyId: 'ada',
    );
    expect(path, AppRoutes.timeline);
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
  WidgetTester tester, {
  List<MemberFamily>? families,
  String? currentId = 'ada',
  String familyName = 'Ada Archive',
  List<StewardFamily> stewarded = const [],
}) async {
  await tester.pumpWidget(
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
        manageApi: _Manage(),
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
          manageApi: _Manage(),
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
  final auth = AuthRefresh(initiallySignedIn: true);
  final router = createAppRouter(
    authRefresh: auth,
    inviteApi: _Invite(familyId),
    familiesApi: families,
  );
  addTearDown(auth.dispose);
  addTearDown(router.dispose);
  await tester.pumpWidget(TellMeAStoryApp(router: router));
  await tester.pumpAndSettle();
  return router.routerDelegate.currentConfiguration.uri.path;
}

class _Families implements FamiliesGateway {
  _Families({this.live = const [], this.stewarded = const []});

  final List<MemberFamily> live;
  final List<StewardFamily> stewarded;

  @override
  Future<List<MemberFamily>> listMine() async => live;

  @override
  Future<List<StewardFamily>> listStewarded() async => stewarded;
}

class _Invite implements InviteGateway {
  _Invite(this.familyId);

  final String? familyId;

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => 'created';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) async {
    return const CreateInviteResult(
      inviteId: 'i',
      token: 't',
      expiresAt: '2099-01-01T00:00:00Z',
      inviteUrl: 'http://127.0.0.1/timeline?invite=t',
    );
  }

  @override
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _Directory implements FamilyDirectoryGateway {
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

class _Manage implements ManageFamiliesGateway {
  @override
  Future<String> createRootFamily(String name) async => 'created-1';

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async {}

  @override
  Future<void> addCoOwner({
    required String familyId,
    required String userId,
  }) async {}

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) async {}

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async {}

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) async {}

  @override
  Future<void> softDeleteFamily(String familyId) async {}

  @override
  Future<void> recoverFamily(String familyId) async {}

  @override
  Future<DateTime> resendInvite(String inviteId) async =>
      DateTime.utc(2026, 10, 17);

  @override
  Future<void> revokeInvite(String inviteId) async {}
}
