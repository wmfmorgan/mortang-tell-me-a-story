import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
import 'package:tell_me_a_story/features/settings/settings_page.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    ProfileSession.loadOwn = null;
    ProfileSession.downloadAvatar = null;
    ProfileSession.instance.clear();
  });

  testWidgets('settings body is name, email, upload, and one Save', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Profile()));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Upload picture'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Your family'), findsNothing);
    expect(find.text('Family members'), findsNothing);
    expect(find.byKey(const Key('settings-save')), findsOneWidget);
  });

  testWidgets('fields start from the stored profile', (tester) async {
    await tester.pumpWidget(_app(_Profile()));
    await tester.pumpAndSettle();

    expect(_text(tester, 'settings-name'), 'Sarah Morgan');
    expect(_text(tester, 'settings-email'), 'sarah@example.com');
    expect(find.text('SM'), findsWidgets);
  });

  testWidgets('a blank stored name with no picture paints an empty circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Profile(
          profile: const OwnProfile(id: 'user-1', email: 'sarah@example.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SM'), findsNothing);
    expect(find.text('S'), findsNothing);
    expect(find.byKey(const Key('profile-avatar-image')), findsNothing);
  });

  testWidgets('a saved picture fills the circle when the name is blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _Profile(
          profile: OwnProfile(
            id: 'user-1',
            email: 'sarah@example.com',
            avatarPath: 'user-1/avatar.jpg',
          ),
          download: _jpeg(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-avatar-image')), findsWidgets);
    expect(find.text('SM'), findsNothing);
    expect(find.text('S'), findsNothing);
  });

  testWidgets('a blank name does not save', (tester) async {
    final profile = _Profile();
    await tester.pumpWidget(_app(profile));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-name')), '   ');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, isEmpty);
    expect(profile.emails, isEmpty);
    expect(profile.uploads, 0);
  });

  testWidgets('save writes the trimmed name and not the email column', (
    tester,
  ) async {
    final profile = _Profile();
    await tester.pumpWidget(_app(profile));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-name')), '  Ada  ');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Ada']);
    expect(profile.emails, isEmpty);
  });

  testWidgets('a changed address calls updateEmail and the field stays', (
    tester,
  ) async {
    final profile = _Profile();
    await tester.pumpWidget(_app(profile));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('settings-email')),
      'next@example.com',
    );
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.emails, ['next@example.com']);
    expect(profile.names, ['Sarah Morgan']);
    expect(_text(tester, 'settings-email'), 'sarah@example.com');
  });

  testWidgets('a blank email still saves the name', (tester) async {
    final profile = _Profile();
    await tester.pumpWidget(_app(profile));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-email')), '  ');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Sarah Morgan']);
    expect(profile.emails, isEmpty);
    expect(_text(tester, 'settings-email'), 'sarah@example.com');
  });

  testWidgets('a pending picture uploads on save', (tester) async {
    final profile = _Profile();
    await tester.pumpWidget(_app(profile, pick: () async => _jpeg()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-upload')));
    await tester.pumpAndSettle();
    expect(profile.uploads, 0);

    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.uploads, 1);
    expect(profile.avatarBytes, isNotEmpty);
  });

  testWidgets('a failed upload keeps the name and the preview', (tester) async {
    final profile = _Profile()..failUpload = true;
    await tester.pumpWidget(_app(profile, pick: () async => _jpeg()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-name')), 'Ada');
    await tester.tap(find.byKey(const Key('settings-upload')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Ada']);
    expect(profile.emails, isEmpty);
    expect(find.text('Couldn’t save your profile. Try again.'), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-image')), findsWidgets);
  });

  testWidgets('the avatar opens Settings, then Logout', (tester) async {
    for (final page in AlbumHeaderPage.values) {
      await tester.pumpWidget(_bar(page));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('header-avatar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('header-avatar')));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Manage families'), findsNothing);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
      final settingsY = tester.getTopLeft(find.text('Settings')).dy;
      final logoutY = tester.getTopLeft(find.text('Logout')).dy;
      expect(settingsY, lessThan(logoutY));
      expect(find.byKey(const Key('settings-name')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Settings in the menu pushes /settings once', (tester) async {
    final router = _router(_Profile());
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/timeline');

    await tester.tap(find.byKey(const Key('header-menu-settings')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.settings);
    expect(find.byKey(const Key('settings-name')), findsOneWidget);

    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-menu-settings')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.settings);
    expect(find.byKey(const Key('settings-name')), findsOneWidget);
  });

  testWidgets('Logout calls sign-out', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      _app(
        _Profile(),
        onLogout: () async {
          signedOut = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-menu-logout')));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
  });
}

String _text(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

Uint8List _jpeg() {
  final image = img.Image(width: 4, height: 4);
  img.fill(image, color: img.ColorRgb8(180, 90, 40));
  return Uint8List.fromList(img.encodeJpg(image));
}

Widget _app(
  _Profile profile, {
  Future<Uint8List?> Function()? pick,
  Future<void> Function()? onLogout,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => SettingsPage(
          profileApi: profile,
          inviteApi: _Invite(),
          pickImageBytes: pick,
          onLogout: onLogout ?? () async {},
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
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

GoRouter _router(_Profile profile) {
  return GoRouter(
    initialLocation: '/timeline',
    routes: [
      GoRoute(
        path: '/timeline',
        builder: (context, state) => Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Morgan',
            families: const [],
            currentFamilyId: null,
            onFamilySelected: (_) {},
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) =>
            SettingsPage(profileApi: profile, inviteApi: _Invite()),
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
    ],
  );
}

Widget _bar(AlbumHeaderPage page) {
  return MaterialApp(
    home: Scaffold(
      appBar: AlbumHeader(
        page: page,
        familyName: 'Morgan',
        families: const [],
        currentFamilyId: null,
        onFamilySelected: (_) {},
        onLogout: () async {},
      ),
    ),
  );
}

class _Profile implements ProfileGateway {
  _Profile({
    this.profile = const OwnProfile(
      id: 'user-1',
      displayName: 'Sarah Morgan',
      email: 'sarah@example.com',
    ),
    this.download,
  });

  OwnProfile profile;
  Uint8List? download;
  final names = <String>[];
  final emails = <String>[];
  var uploads = 0;
  Uint8List? avatarBytes;
  var failUpload = false;

  @override
  Future<Uint8List?> downloadAvatar(String path) async => download;

  @override
  Future<OwnProfile?> loadOwn() async => profile;

  @override
  Future<String> saveAvatar(Uint8List bytes) async {
    if (failUpload) throw StateError('upload');
    uploads += 1;
    avatarBytes = bytes;
    return 'user-1/avatar.jpg';
  }

  @override
  Future<void> saveName(String displayName) async {
    names.add(displayName);
  }

  @override
  Future<void> updateEmail(String email) async {
    emails.add(email);
  }
}

class _Invite implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'fam', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => 'fam';

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => 'fam';

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}
