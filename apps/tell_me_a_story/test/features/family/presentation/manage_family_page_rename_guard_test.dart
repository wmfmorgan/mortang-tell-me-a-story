import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/features/family/presentation/manage_family_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/fakes/fake_manage_families_repository.dart';

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
    FamilySelection.remember('keep');
    final router = await _mount(tester, failRename: true);
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
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rename failed'), findsOneWidget);
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, '/manage-families/ada');
    expect(FamilySelection.id, 'keep');
    expect(_name(tester), 'Ada renamed');
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
          inviteApi: FakeInviteRepository(
            familyId: _ada,
            createdFamilyId: _ada,
            acceptedFamilyId: _ada,
          ),
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

class _Directory implements FamilyDirectoryRepository {
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

class _Families extends FamiliesRepository {
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

class _Manage extends FakeManageFamiliesRepository {
  _Manage({required this.failRename});

  final bool failRename;

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async {
    if (failRename) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Rename failed',
      );
    }
  }
}
