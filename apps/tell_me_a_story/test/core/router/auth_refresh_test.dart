import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/family_thread_open_state_store.dart';
import 'package:tell_me_a_story/data/profile_session.dart';

void main() {
  tearDown(() {
    FamilySelection.clear();
    ProfileSession.instance.clear();
  });

  test('session null calls openStateStore.clearAll once', () async {
    final store = _CountingOpenStateStore();
    final states = StreamController<AuthState>();
    final auth = AuthRefresh(
      authStateChanges: states.stream,
      initiallySignedIn: true,
      openStateStore: store,
    );
    addTearDown(auth.dispose);
    addTearDown(states.close);

    states.add(AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);

    expect(store.clearAllCalls, 1);
  });

  test('signed-in event does not call clearAll', () async {
    final store = _CountingOpenStateStore();
    final states = StreamController<AuthState>();
    final auth = AuthRefresh(
      authStateChanges: states.stream,
      initiallySignedIn: false,
      openStateStore: store,
    );
    addTearDown(auth.dispose);
    addTearDown(states.close);

    states.add(AuthState(AuthChangeEvent.signedIn, _session()));
    await Future<void>.delayed(Duration.zero);

    expect(store.clearAllCalls, 0);
    expect(auth.isSignedIn, isTrue);
  });
}

Session _session() {
  return Session.fromJson({
    'access_token': 'token',
    'token_type': 'bearer',
    'user': {'id': '11111111-1111-4111-8111-111111111111'},
  })!;
}

class _CountingOpenStateStore extends FamilyThreadOpenStateStore {
  int clearAllCalls = 0;

  @override
  Future<void> clearAll() async {
    clearAllCalls += 1;
  }
}
