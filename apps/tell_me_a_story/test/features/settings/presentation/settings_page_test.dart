import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tell_me_a_story/core/domain/birth_visibility.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/own_profile.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/features/settings/presentation/settings_page.dart';

import '../../../support/fakes/fake_invite_repository.dart';
import '../../../support/pump_app.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> tall(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> pumpTall(
    WidgetTester tester,
    _Profile profile, {
    Future<Uint8List?> Function()? pick,
    Future<void> Function()? onLogout,
  }) async {
    await tall(tester);
    await pumpRouterApp(
      tester,
      _app(pick: pick, onLogout: onLogout),
      overrides: _overrides(profile),
    );
  }

  testWidgets('settings body is name, email, upload, and one Save', (
    tester,
  ) async {
    await pumpTall(tester, _Profile());
    await tester.pumpAndSettle();

    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('DATE OF BIRTH'), findsOneWidget);
    expect(
      find.text(
        'Year is required. Add the month or day only if you remember. Day unlocks after Month.',
      ),
      findsNothing,
    );
    expect(find.text('PROFILE PHOTO'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('ACCOUNT EMAIL'), findsOneWidget);
    expect(find.text('Date of passing'), findsNothing);
    expect(find.text('Replace photo'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Your family'), findsNothing);
    expect(find.text('Family members'), findsNothing);
    expect(find.byKey(const Key('settings-save')), findsOneWidget);
  });

  testWidgets('fields start from the stored profile', (tester) async {
    await pumpTall(tester, _Profile());
    await tester.pumpAndSettle();

    expect(_text(tester, 'settings-name'), 'Sarah Morgan');
    expect(_text(tester, 'settings-email'), 'sarah@example.com');
    expect(find.text('SM'), findsWidgets);
  });

  testWidgets('a blank stored name with no picture paints an empty circle', (
    tester,
  ) async {
    await pumpTall(
      tester,
      _Profile(
        profile: const OwnProfile(id: 'user-1', email: 'sarah@example.com'),
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
    await pumpTall(
      tester,
      _Profile(
        profile: const OwnProfile(
          id: 'user-1',
          email: 'sarah@example.com',
          avatarPath: 'user-1/avatar.jpg',
        ),
        download: _jpeg(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-avatar-image')), findsWidgets);
    expect(find.text('SM'), findsNothing);
    expect(find.text('S'), findsNothing);
  });

  testWidgets('a blank name does not save', (tester) async {
    final profile = _Profile();
    await pumpTall(tester, profile);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-name')), '   ');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, isEmpty);
    expect(profile.uploads, 0);
  });

  testWidgets('save writes the trimmed name and not the email column', (
    tester,
  ) async {
    final profile = _Profile();
    await pumpTall(tester, profile);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-name')), '  Ada  ');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Ada']);
    expect(profile.births, [(null, null)]);
    expect(profile.abouts, [null]);
  });

  testWidgets('one Save writes birth and about on the account', (tester) async {
    final profile = _Profile();
    await pumpTall(tester, profile);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('story-date-year')), '1987');
    await tester.enterText(find.byKey(const Key('settings-about')), 'A note');
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Sarah Morgan']);
    expect(profile.births, [(DateTime(1987, 1, 1), 'year')]);
    expect(profile.abouts, ['A note']);
  });

  testWidgets('the account email is read-only (D1)', (tester) async {
    final profile = _Profile();
    await pumpTall(tester, profile);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('settings-email')),
    );
    expect(field.readOnly, isTrue);

    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Sarah Morgan']);
    expect(_text(tester, 'settings-email'), 'sarah@example.com');
  });

  testWidgets('a pending picture uploads on save', (tester) async {
    final profile = _Profile();
    await pumpTall(tester, profile, pick: () async => _jpeg());
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
    await pumpTall(tester, profile, pick: () async => _jpeg());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('settings-name')), 'Ada');
    await tester.tap(find.byKey(const Key('settings-upload')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-save')));
    await tester.pumpAndSettle();

    expect(profile.names, ['Ada']);
    expect(find.text('Couldn’t save your profile. Try again.'), findsOneWidget);
    expect(find.byKey(const Key('profile-avatar-image')), findsWidgets);
  });

  testWidgets('the avatar opens Settings, then Logout', (tester) async {
    for (final page in AlbumHeaderPage.values) {
      await tall(tester);
      await pumpApp(tester, _bar(page));
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
    final router = _router();
    await tall(tester);
    await pumpRouterApp(tester, router, overrides: _overrides(_Profile()));
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
    await pumpTall(
      tester,
      _Profile(),
      onLogout: () async {
        signedOut = true;
      },
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

List<Override> _overrides(_Profile profile) => [
  profileRepositoryProvider.overrideWithValue(profile),
  inviteRepositoryProvider.overrideWithValue(
    FakeInviteRepository(
      familyId: 'fam',
      createdFamilyId: 'fam',
      acceptedFamilyId: 'fam',
    ),
  ),
  familiesRepositoryProvider.overrideWithValue(_Families()),
];

GoRouter _app({
  Future<Uint8List?> Function()? pick,
  Future<void> Function()? onLogout,
}) {
  return GoRouter(
    initialLocation: AppRoutes.settings,
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => SettingsPage(
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
}

GoRouter _router() {
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
        builder: (context, state) => const SettingsPage(),
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
  return Scaffold(
    appBar: AlbumHeader(
      page: page,
      familyName: 'Morgan',
      families: const [],
      currentFamilyId: null,
      onFamilySelected: (_) {},
      onLogout: () async {},
    ),
  );
}

/// The one family the settings page lists for the signed-in user.
class _Families extends FamiliesRepository {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(id: 'fam', name: 'Family', createdAt: DateTime.utc(2020)),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}

class _Profile implements ProfileRepository {
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
  final births = <(DateTime?, String?)>[];
  final abouts = <String?>[];
  var uploads = 0;
  var clears = 0;
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
  Future<void> clearAvatar() async {
    clears += 1;
  }

  @override
  Future<void> saveName(String displayName) async {
    names.add(displayName);
  }

  @override
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) async {
    names.add(displayName);
    births.add((birthDate, birthPrecision));
    abouts.add(about);
  }
}
