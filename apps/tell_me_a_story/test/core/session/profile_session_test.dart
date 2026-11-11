import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/session/auth_info.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';

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
  test('a different user clears the saved profile', () {
    final container = _container();
    final session = container.read(profileSessionProvider.notifier);
    session.bindUser('user-a');
    session.apply(
      displayName: 'Sarah Morgan',
      email: 'sarah@example.com',
      avatarBytes: Uint8List.fromList([1]),
    );

    session.bindUser('user-b');

    final profile = container.read(profileSessionProvider);
    expect(profile.displayName, isNull);
    expect(profile.email, isNull);
    expect(profile.avatarBytes, isNull);
  });

  test('the same user keeps the profile', () {
    final container = _container();
    final session = container.read(profileSessionProvider.notifier);
    session.bindUser('user-a');
    session.apply(displayName: 'Ada', email: 'ada@example.com');

    session.bindUser('user-a');

    expect(container.read(profileSessionProvider).displayName, 'Ada');
  });

  test('a dropped session clears the profile', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final container = _container(info);
    final auth = container.read(authRefreshProvider);
    container
        .read(profileSessionProvider.notifier)
        .apply(displayName: 'Ada', email: 'ada@example.com');

    info.value = null;

    expect(container.read(profileSessionProvider).displayName, isNull);
    expect(auth.isSignedIn, isFalse);
  });

  test('signing in as another user drops the previous profile', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final container = _container(info);
    final auth = container.read(authRefreshProvider);
    container
        .read(profileSessionProvider.notifier)
        .apply(displayName: 'Ada', email: 'ada@example.com');

    info.value = _auth(_userA);
    expect(container.read(profileSessionProvider).displayName, 'Ada');

    info.value = _auth(_userB);
    expect(container.read(profileSessionProvider).displayName, isNull);
    expect(auth.isSignedIn, isTrue);
  });
}
