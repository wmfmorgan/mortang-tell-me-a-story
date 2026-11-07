import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/family_selection.dart';

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

  test('the auth listener clears the family when the session drops', () async {
    FamilySelection.remember('fam-a');
    FamilySelection.bindUser('user-a');
    final states = StreamController<AuthState>();
    final auth = AuthRefresh(
      authStateChanges: states.stream,
      initiallySignedIn: true,
    );
    addTearDown(auth.dispose);
    addTearDown(states.close);

    states.add(AuthState(AuthChangeEvent.signedOut, null));
    await Future<void>.delayed(Duration.zero);

    expect(FamilySelection.id, isNull);
    expect(FamilySelection.bindUser('user-a'), isNull);
  });
}
