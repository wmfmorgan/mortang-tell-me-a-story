import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
import 'package:tell_me_a_story/features/auth/welcome_page.dart';

Future<void> _pump(
  WidgetTester tester,
  _Profile profile, {
  Future<void> Function()? onSignOut,
}) async {
  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomePage(
          startPath: () async => '/family',
          profileApi: profile,
          onSignOut: onSignOut ?? () async {},
        ),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const Text('family-home'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('welcome-continue')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(ProfileSession.instance.clear);

  testWidgets('a blank name is required and not saved', (tester) async {
    final profile = _Profile();
    await _pump(tester, profile);

    await _continue(tester);
    expect(find.text(welcomeNameRequired), findsOneWidget);

    await tester.enterText(find.byKey(const Key('welcome-name')), '   ');
    await _continue(tester);

    expect(find.text(welcomeNameRequired), findsOneWidget);
    expect(profile.names, isEmpty);
    expect(find.byKey(const Key('welcome-page')), findsOneWidget);
  });

  testWidgets('a saved name updates the session and continues', (tester) async {
    final profile = _Profile();
    await _pump(tester, profile);

    await tester.enterText(
      find.byKey(const Key('welcome-name')),
      '  Ada Lovelace  ',
    );
    await _continue(tester);

    expect(profile.names, ['Ada Lovelace']);
    expect(ProfileSession.instance.displayName, 'Ada Lovelace');
    expect(find.text('family-home'), findsOneWidget);
  });

  testWidgets('a failed save shows the error and allows a retry', (
    tester,
  ) async {
    final profile = _Profile()..fail = true;
    await _pump(tester, profile);

    await tester.enterText(find.byKey(const Key('welcome-name')), 'Ada');
    await _continue(tester);

    expect(find.text('Couldn’t save your profile. Try again.'), findsOneWidget);
    expect(find.byKey(const Key('welcome-page')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('welcome-continue')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Use a different email signs out', (tester) async {
    var signOuts = 0;
    await _pump(tester, _Profile(), onSignOut: () async => signOuts++);

    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();

    expect(signOuts, 1);
  });
}

class _Profile implements ProfileGateway {
  final names = <String>[];
  var fail = false;

  @override
  Future<void> saveName(String displayName) async {
    if (fail) throw StateError('save');
    names.add(displayName);
  }

  @override
  Future<OwnProfile?> loadOwn() => throw UnimplementedError();

  @override
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) => throw UnimplementedError();

  @override
  Future<String> saveAvatar(Uint8List bytes) => throw UnimplementedError();

  @override
  Future<void> clearAvatar() => throw UnimplementedError();

  @override
  Future<Uint8List?> downloadAvatar(String path) => throw UnimplementedError();
}
