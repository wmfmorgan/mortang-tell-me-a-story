import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/features/family/manage_family_page.dart';

const _ada = 'ada';
const _bea = 'bea';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('a changed rename + family switch prompts', (tester) async {
    await _surface(tester);
    FamilySelection.remember('keep');
    final router = await _mount(tester);
    await tester.ensureVisible(find.byKey(const Key('manage-family-name')));
    await tester.enterText(
      find.byKey(const Key('manage-family-name')),
      'Ada renamed',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-$_bea')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this story?'), findsOneWidget);
    expect(find.textContaining('switching to Bea'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Stay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(router.state.uri.path, '/manage-families/ada');
    expect(_name(tester), 'Ada renamed');
    expect(FamilySelection.id, 'keep');
  });

  testWidgets('Rename failure stays with the snack', (tester) async {
    await _surface(tester);
    final router = await _mount(tester, failRename: true);
    await tester.ensureVisible(find.byKey(const Key('manage-family-rename')));
    await tester.tap(find.byKey(const Key('manage-family-rename')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rename failed'), findsOneWidget);
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/manage-families/ada');
  });
}

String _name(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byKey(const Key('manage-family-name')))
      .controller!
      .text;
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

GoRouter? _router;

Future<GoRouter> _mount(WidgetTester tester, {bool failRename = false}) async {
  final previous = _router;
  _router = null;
  previous?.dispose();
  final router = GoRouter(
    initialLocation: '/manage-families/ada',
    routes: [
      GoRoute(
        path: AppRoutes.manageFamily,
        builder: (_, state) => ManageFamilyPage(
          familyId: state.pathParameters['familyId']!,
          directoryApi: _Directory(),
          familiesApi: _Families(),
          manageApi: _Manage(failRename: failRename),
          inviteApi: _Invite(),
        ),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (_, _) => const Text('timeline-marker'),
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

class _Directory implements FamilyDirectoryGateway {
  @override
  Future<FamilyDirectory> listDirectory() async =>
      const FamilyDirectory(active: [], recoverable: []);

  @override
  Future<FamilyDetail?> loadDetail(String familyId) async {
    return FamilyDetail(
      id: familyId,
      name: 'Ada',
      myRole: 'owner',
      people: const [],
    );
  }
}

class _Families extends FamiliesGateway {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(id: _ada, name: 'Ada', createdAt: DateTime.utc(2020)),
    MemberFamily(id: _bea, name: 'Bea', createdAt: DateTime.utc(2021)),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [
    StewardFamily(id: _ada, name: 'Ada', role: 'owner'),
  ];
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

class _Manage implements ManageFamiliesGateway {
  _Manage({required this.failRename});

  final bool failRename;

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async {
    if (failRename) {
      throw ManageFamiliesException(
        code: 'VALIDATION',
        message: 'Rename failed',
      );
    }
  }

  @override
  Future<String> createRootFamily(String name) async => 'new';

  @override
  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  }) async => 'branch';

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
  Future<DateTime> resendInvite(String inviteId) async => DateTime.utc(2026);

  @override
  Future<void> revokeInvite(String inviteId) async {}
}
