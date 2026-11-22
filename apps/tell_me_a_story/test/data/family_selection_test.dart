import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';

import '../support/quiet_gateways.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(FamilySelection.clear);

  test('remembered id in the membership set is returned', () {
    expect(
      resolveCurrentFamilyId(
        userId: 'user-a',
        remembered: 'fam-b',
        membershipIds: const ['fam-a', 'fam-b'],
        fallback: 'fam-a',
      ),
      'fam-b',
    );
  });

  test('a remembered id that is not a membership falls through', () {
    expect(
      resolveCurrentFamilyId(
        userId: 'user-a',
        remembered: 'gone',
        membershipIds: const ['fam-a'],
        fallback: 'fam-a',
      ),
      'fam-a',
    );
  });

  test('nothing remembered uses the fallback and no membership list', () {
    expect(
      resolveCurrentFamilyId(
        userId: 'user-a',
        remembered: null,
        fallback: 'fam-a',
      ),
      'fam-a',
    );
  });

  test('signed out returns null and ignores memberships and fallback', () {
    expect(
      resolveCurrentFamilyId(
        userId: null,
        remembered: 'fam-a',
        membershipIds: const ['fam-a'],
        fallback: 'fam-a',
      ),
      isNull,
    );
  });

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

  test('remembered family is used when its tree contains that id', () async {
    final families = _Families(
      tree: [const TreeFamily(id: 'saved', name: 'Saved')],
    );

    final id = await resolveShownFamilyId(
      families: families,
      userId: 'user-a',
      remembered: 'saved',
      memberships: [_member('home')],
    );

    expect(id, 'saved');
    expect(families.treeCalls, 1);
  });

  test(
    'an unreadable remembered family falls back to the membership',
    () async {
      final families = _Families();

      final id = await resolveShownFamilyId(
        families: families,
        userId: 'user-a',
        remembered: 'saved',
        memberships: [_member('home')],
      );

      expect(id, 'home');
    },
  );

  test('signed in with nothing remembered uses the first membership', () async {
    final families = _Families();

    final id = await resolveShownFamilyId(
      families: families,
      userId: 'user-a',
      remembered: null,
      memberships: [_member('home'), _member('other')],
    );

    expect(id, 'home');
    expect(families.treeCalls, 0);
  });

  test('signed out returns null', () async {
    final families = _Families(
      tree: [const TreeFamily(id: 'saved', name: 'Saved')],
    );

    final id = await resolveShownFamilyId(
      families: families,
      userId: null,
      remembered: 'saved',
      memberships: [_member('saved')],
    );

    expect(id, isNull);
    expect(families.treeCalls, 0);
  });

  test(
    'a families read that throws is caught as GatewayReadException',
    () async {
      final families = _Families(error: const FormatException('tree'));

      final id = await resolveShownFamilyId(
        families: families,
        userId: 'user-a',
        remembered: 'saved',
        memberships: [_member('home')],
      );

      expect(id, 'home');
    },
  );
}

MemberFamily _member(String id) {
  return MemberFamily(id: id, name: id, createdAt: DateTime.utc(2020));
}

class _Families extends FamiliesGateway with QuietFamiliesDefaults {
  _Families({this.tree = const [], this.error});

  final List<TreeFamily> tree;
  final Object? error;
  var treeCalls = 0;

  @override
  Future<List<MemberFamily>> listMine() async => const [];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    treeCalls += 1;
    final error = this.error;
    if (error != null) throw error;
    return tree;
  }
}
