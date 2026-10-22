import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
import 'package:tell_me_a_story/features/settings/settings_page.dart';

const _ada = 'ada';
const _bea = 'bea';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(() {
    FamilySelection.clear();
    ProfileSession.instance.clear();
  });

  testWidgets('dirty + family switch prompts', (tester) async {
    await _surface(tester);
    final router = await _mount(tester);
    await tester.enterText(find.byKey(const Key('settings-name')), 'New Ada');
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
    expect(router.state.uri.path, AppRoutes.settings);
    expect(_field(tester, 'settings-name'), 'New Ada');
  });

  testWidgets('dirty + Back to Timeline, Drafts or Logout do not prompt', (
    tester,
  ) async {
    await _surface(tester);

    final back = await _mount(tester);
    await tester.enterText(find.byKey(const Key('settings-name')), 'New Ada');
    await tester.pump();
    await tester.ensureVisible(find.text('Back to Timeline'));
    await tester.tap(find.text('Back to Timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this story?'), findsNothing);
    expect(back.state.uri.path, AppRoutes.timeline);

    final drafts = await _mount(tester);
    await tester.enterText(find.byKey(const Key('settings-name')), 'New Ada');
    await tester.pump();
    await tester.tap(find.byKey(const Key('drafts-nav')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this story?'), findsNothing);
    expect(drafts.state.uri.path, AppRoutes.drafts);

    var signedOut = false;
    final logout = await _mount(
      tester,
      onLogout: () async {
        signedOut = true;
      },
    );
    await tester.enterText(find.byKey(const Key('settings-name')), 'New Ada');
    await tester.pump();
    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-menu-logout')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this story?'), findsNothing);
    expect(signedOut, isTrue);
    expect(logout.state.uri.path, AppRoutes.settings);
  });

  testWidgets('clean after a saved email change', (tester) async {
    await _surface(tester);
    final profile = _Profile();
    final router = await _mount(tester, profile: profile);
    await tester.enterText(
      find.byKey(const Key('settings-email')),
      'new@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('settings-save')));
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();
    expect(profile.emails, ['new@example.com']);
    expect(_field(tester, 'settings-email'), 'ada@example.com');
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-$_bea')));
    await tester.pumpAndSettle();
    expect(find.text('Leave this story?'), findsNothing);
    expect(router.state.uri.path, AppRoutes.timeline);
  });
}

String _field(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

GoRouter? _router;

Future<GoRouter> _mount(
  WidgetTester tester, {
  _Profile? profile,
  Future<void> Function()? onLogout,
}) async {
  final previous = _router;
  _router = null;
  previous?.dispose();
  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => SettingsPage(
          profileApi: profile ?? _Profile(),
          familiesApi: _Families(),
          inviteApi: _Invite(),
          onLogout: onLogout,
        ),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (_, _) => const Text('timeline-marker'),
      ),
      GoRoute(
        path: AppRoutes.drafts,
        builder: (_, _) => const Text('drafts-marker'),
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

class _Profile implements ProfileGateway {
  final emails = <String>[];

  @override
  Future<OwnProfile?> loadOwn() async =>
      const OwnProfile(id: 'u1', displayName: 'Ada', email: 'ada@example.com');

  @override
  Future<Uint8List?> downloadAvatar(String path) async => null;

  @override
  Future<String> saveAvatar(Uint8List bytes) async => 'u1/avatar.jpg';

  @override
  Future<void> clearAvatar() async {}

  @override
  Future<void> saveName(String displayName) async {}

  @override
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) async {}

  @override
  Future<void> updateEmail(String email) async {
    emails.add(email);
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
