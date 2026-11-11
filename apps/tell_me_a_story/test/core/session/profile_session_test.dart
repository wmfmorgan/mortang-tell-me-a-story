import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
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

void main() {
  tearDown(ProfileSession.instance.clear);

  test('a different user clears the saved profile', () {
    ProfileSession.instance.bindUser('user-a');
    ProfileSession.instance.apply(
      displayName: 'Sarah Morgan',
      email: 'sarah@example.com',
      avatarBytes: Uint8List.fromList([1]),
    );

    ProfileSession.instance.bindUser('user-b');

    expect(ProfileSession.instance.displayName, isNull);
    expect(ProfileSession.instance.email, isNull);
    expect(ProfileSession.instance.avatarBytes, isNull);
  });

  test('the same user keeps the profile', () {
    ProfileSession.instance.bindUser('user-a');
    ProfileSession.instance.apply(displayName: 'Ada', email: 'ada@example.com');

    ProfileSession.instance.bindUser('user-a');

    expect(ProfileSession.instance.displayName, 'Ada');
  });

  test('a dropped session clears the profile', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final auth = AuthRefresh(authInfo: info);
    addTearDown(auth.dispose);
    ProfileSession.instance.apply(displayName: 'Ada', email: 'ada@example.com');

    info.value = null;

    expect(ProfileSession.instance.displayName, isNull);
    expect(auth.isSignedIn, isFalse);
  });

  test('signing in as another user drops the previous profile', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final auth = AuthRefresh(authInfo: info);
    addTearDown(auth.dispose);
    ProfileSession.instance.apply(displayName: 'Ada', email: 'ada@example.com');

    info.value = _auth(_userA);
    expect(ProfileSession.instance.displayName, 'Ada');

    info.value = _auth(_userB);
    expect(ProfileSession.instance.displayName, isNull);
    expect(auth.isSignedIn, isTrue);
  });
}
