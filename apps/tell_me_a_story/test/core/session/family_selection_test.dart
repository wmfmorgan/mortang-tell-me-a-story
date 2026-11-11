import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/session/auth_info.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';

const _userA = '00000000-0000-4000-8000-00000000000a';
const _userB = '00000000-0000-4000-8000-00000000000b';

AuthSuccess _auth(String userId) => AuthSuccess(
  authStrategy: 'session',
  token: 'token',
  authUserId: UuidValue.fromString(userId),
  scopeNames: const {},
);

ProviderContainer _container([ValueListenable<AuthSuccess?>? info]) {
  final container = ProviderContainer(
    overrides: [authInfoProvider.overrideWithValue(info)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a different user clears the remembered family', () {
    final container = _container();
    final selection = container.read(familySelectionProvider.notifier);
    selection.remember('fam-a');
    expect(selection.bindUser('user-a'), 'fam-a');

    expect(selection.bindUser('user-b'), isNull);
    expect(container.read(familySelectionProvider), isNull);
  });

  test('a dropped session clears the remembered family', () {
    final container = _container();
    final selection = container.read(familySelectionProvider.notifier);
    selection.remember('fam-a');
    selection.bindUser('user-a');

    selection.clear();

    expect(container.read(familySelectionProvider), isNull);
    expect(selection.bindUser('user-a'), isNull);
  });

  test('the auth listener clears the family when the session drops', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final container = _container(info);
    final auth = container.read(authRefreshProvider);
    final selection = container.read(familySelectionProvider.notifier);
    selection.remember('fam-a');

    info.value = null;

    expect(auth.isSignedIn, isFalse);
    expect(container.read(familySelectionProvider), isNull);
    expect(selection.bindUser(_userA), isNull);
  });

  test('the auth listener binds the signed-in user', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final container = _container(info);
    final auth = container.read(authRefreshProvider);
    container.read(familySelectionProvider.notifier).remember('fam-a');

    info.value = _auth(_userA);
    expect(container.read(familySelectionProvider), 'fam-a');

    info.value = _auth(_userB);
    expect(auth.isSignedIn, isTrue);
    expect(container.read(familySelectionProvider), isNull);
  });

  test('a same-user token rotation does not refresh the router', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final container = _container(info);
    final auth = container.read(authRefreshProvider);
    var notified = 0;
    auth.addListener(() => notified++);
    container.read(familySelectionProvider.notifier).remember('fam-a');

    info.value = AuthSuccess(
      authStrategy: 'jwt',
      token: 'rotated',
      refreshToken: 'rotated-refresh',
      authUserId: UuidValue.fromString(_userA),
      scopeNames: const {},
    );

    expect(notified, 0);
    expect(auth.isSignedIn, isTrue);
    expect(container.read(familySelectionProvider), 'fam-a');
  });
}
