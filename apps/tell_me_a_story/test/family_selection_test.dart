import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/family_selection.dart';

const _userA = '00000000-0000-4000-8000-00000000000a';
const _userB = '00000000-0000-4000-8000-00000000000b';

AuthSuccess _auth(String userId) => AuthSuccess(
  authStrategy: 'session',
  token: 'token',
  authUserId: UuidValue.fromString(userId),
  scopeNames: const {},
);

void main() {
  tearDown(FamilySelection.clear);

  test('a different user clears the remembered family', () {
    FamilySelection.remember('fam-a');
    expect(FamilySelection.bindUser('user-a'), 'fam-a');

    expect(FamilySelection.bindUser('user-b'), isNull);
    expect(FamilySelection.id, isNull);
  });

  test('a dropped session clears the remembered family', () {
    FamilySelection.remember('fam-a');
    FamilySelection.bindUser('user-a');

    FamilySelection.clear();

    expect(FamilySelection.id, isNull);
    expect(FamilySelection.bindUser('user-a'), isNull);
  });

  test('the auth listener clears the family when the session drops', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final auth = AuthRefresh(authInfo: info);
    addTearDown(auth.dispose);
    FamilySelection.remember('fam-a');

    info.value = null;

    expect(auth.isSignedIn, isFalse);
    expect(FamilySelection.id, isNull);
    expect(FamilySelection.bindUser(_userA), isNull);
  });

  test('the auth listener binds the signed-in user', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final auth = AuthRefresh(authInfo: info);
    addTearDown(auth.dispose);
    FamilySelection.remember('fam-a');

    info.value = _auth(_userA);
    expect(FamilySelection.id, 'fam-a');

    info.value = _auth(_userB);
    expect(auth.isSignedIn, isTrue);
    expect(FamilySelection.id, isNull);
  });

  test('a same-user token rotation does not refresh the router', () {
    final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
    final auth = AuthRefresh(authInfo: info);
    addTearDown(auth.dispose);
    var notified = 0;
    auth.addListener(() => notified++);
    FamilySelection.remember('fam-a');

    info.value = AuthSuccess(
      authStrategy: 'jwt',
      token: 'rotated',
      refreshToken: 'rotated-refresh',
      authUserId: UuidValue.fromString(_userA),
      scopeNames: const {},
    );

    expect(notified, 0);
    expect(auth.isSignedIn, isTrue);
    expect(FamilySelection.id, 'fam-a');
  });
}
