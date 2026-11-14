import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';

void main() {
  tearDown(() {
    ProfileSession.loadOwn = null;
    ProfileSession.downloadAvatar = null;
    ProfileSession.instance.clear();
  });

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

  test('ensureLoaded keeps a load failure for retry', () async {
    var calls = 0;
    ProfileSession.loadOwn = () async {
      calls += 1;
      if (calls == 1) {
        throw const PostgrestException(message: 'VALIDATION: bad row');
      }
      return const OwnProfile(id: 'user-1', displayName: 'Ada');
    };
    ProfileSession.instance.bindUser('user-1');

    await ProfileSession.instance.ensureLoaded();
    expect(ProfileSession.instance.loadError, isNotNull);
    expect(ProfileSession.instance.displayName, isNull);

    await ProfileSession.instance.retryLoad();
    expect(calls, 2);
    expect(ProfileSession.instance.loadError, isNull);
    expect(ProfileSession.instance.displayName, 'Ada');
  });

  test('a dropped session clears the profile', () async {
    final states = StreamController<AuthState>();
    addTearDown(states.close);
    ProfileSession.instance.apply(displayName: 'Ada', email: 'ada@example.com');
    final auth = AuthRefresh(
      authStateChanges: states.stream,
      initiallySignedIn: true,
    );
    addTearDown(auth.dispose);

    states.add(AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);

    expect(ProfileSession.instance.displayName, isNull);
    expect(auth.isSignedIn, isFalse);
  });
}
