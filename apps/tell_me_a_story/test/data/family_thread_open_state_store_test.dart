import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/family_thread_open_state.dart';
import 'package:tell_me_a_story/data/family_thread_open_state_store.dart';

const _userA = '11111111-1111-4111-8111-111111111111';
const _userB = '22222222-2222-4222-8222-222222222222';
const _family = '33333333-3333-4333-8333-333333333333';
const _otherFamily = '44444444-4444-4444-8444-444444444444';
const _story = '55555555-5555-4555-8555-555555555555';
const _state = FamilyThreadOpenState(
  density: FamilyThreadDensity.read,
  storyId: _story,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int loads;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    loads = 0;
  });

  Future<SharedPreferences> counting() async {
    loads += 1;
    return SharedPreferences.getInstance();
  }

  Future<SharedPreferences> platformFailure() async {
    throw PlatformException(code: 'store');
  }

  FamilyThreadOpenStateStore store({
    String? Function()? currentUserId,
    Future<SharedPreferences> Function()? preferences,
  }) {
    return FamilyThreadOpenStateStore(
      preferences: preferences ?? counting,
      currentUserId: currentUserId ?? () => _userA,
    );
  }

  String keyFor(String userId, String familyId) =>
      '${FamilyThreadOpenStateStore.keyPrefix}$userId.$familyId';

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
  test('writes the exact key for the live user', () async {
    await store().write(familyId: _family, state: _state);
    expect((await prefs()).getString(keyFor(_userA, _family)), _state.encode());
    expect(loads, 1);
  });
  test('no session makes zero preference calls', () async {
    final open = store(currentUserId: () => null);
    expect(await open.read(familyId: _family), isNull);
    await open.write(familyId: _family, state: _state);
    await open.remove(familyId: _family);
    expect(loads, 0);
  });
  test('userId "null" or non-UUID makes zero preference calls', () async {
    for (final userId in ['null', 'not-a-uuid', '']) {
      final open = store(currentUserId: () => userId);
      expect(await open.read(familyId: _family), isNull);
      await open.write(familyId: _family, state: _state);
      await open.remove(familyId: _family);
    }
    expect(loads, 0);
    expect((await prefs()).getKeys(), isEmpty);
  });
  test('non-UUID familyId makes zero preference calls', () async {
    final open = store();
    expect(await open.read(familyId: 'family'), isNull);
    await open.write(familyId: 'abc', state: _state);
    await open.remove(familyId: '');
    expect(loads, 0);
  });
  test('user B read ignores user A key', () async {
    final key = keyFor(_userA, _family);
    SharedPreferences.setMockInitialValues({key: _state.encode()});
    expect(
      await store(currentUserId: () => _userB).read(familyId: _family),
      isNull,
    );
    expect((await prefs()).getString(key), _state.encode());
  });
  test('written value contains only density and storyId', () async {
    await store().write(familyId: _family, state: _state);
    final decoded = jsonDecode(
      (await prefs()).getString(keyFor(_userA, _family))!,
    ) as Map<String, Object?>;
    expect(decoded.keys.toSet(), {'density', 'storyId'});
    expect(decoded['density'], 'read');
    expect(decoded['storyId'], _story);
  });
  test('round trip returns the same state', () async {
    final open = store();
    await open.write(familyId: _family, state: _state);
    final read = await open.read(familyId: _family);
    expect(read?.density, FamilyThreadDensity.read);
    expect(read?.storyId, _story);
  });
  test('remove deletes only that family key', () async {
    final open = store();
    await open.write(familyId: _family, state: _state);
    await open.write(
      familyId: _otherFamily,
      state: const FamilyThreadOpenState(
        density: FamilyThreadDensity.overview,
        storyId: _story,
      ),
    );
    await open.remove(familyId: _family);
    final stored = await prefs();
    expect(stored.getString(keyFor(_userA, _family)), isNull);
    expect(stored.getString(keyFor(_userA, _otherFamily)), isNotNull);
  });
  test('read is null when the key is absent', () async {
    expect(await store().read(familyId: _family), isNull);
    expect(loads, 1);
  });
  test('read is null on malformed JSON', () async {
    SharedPreferences.setMockInitialValues({keyFor(_userA, _family): '{'});
    expect(await store().read(familyId: _family), isNull);
  });
  test('read is null on unknown density name', () async {
    SharedPreferences.setMockInitialValues({
      keyFor(_userA, _family): '{"density":"zoom","storyId":"$_story"}',
    });
    expect(await store().read(familyId: _family), isNull);
  });
  test(
    'preferences loader throwing PlatformException makes read null',
    () async {
      expect(
        await store(preferences: platformFailure).read(familyId: _family),
        isNull,
      );
    },
  );
  test(
    'preferences loader throwing PlatformException makes write a no-op',
    () async {
      await store(preferences: platformFailure)
          .write(familyId: _family, state: _state);
      expect((await prefs()).getKeys(), isEmpty);
    },
  );
  test(
    'preferences loader throwing PlatformException makes remove a no-op',
    () async {
      final key = keyFor(_userA, _family);
      SharedPreferences.setMockInitialValues({key: _state.encode()});
      await store(preferences: platformFailure).remove(familyId: _family);
      expect((await prefs()).getString(key), _state.encode());
    },
  );
  test('a StateError from the loader is not caught', () {
    final open = store(preferences: () async => throw StateError('boom'));
    expect(open.read(familyId: _family), throwsA(isA<StateError>()));
    expect(
      open.write(familyId: _family, state: _state),
      throwsA(isA<StateError>()),
    );
    expect(open.remove(familyId: _family), throwsA(isA<StateError>()));
  });
  test('FormatException from the loader makes read null', () async {
    final open = store(
      preferences: () async => throw const FormatException('bad'),
    );
    expect(await open.read(familyId: _family), isNull);
    await open.write(familyId: _family, state: _state);
    await open.remove(familyId: _family);
    expect((await prefs()).getKeys(), isEmpty);
  });
  test('clearAll removes only family_thread.v1. keys', () async {
    const token = 'sb-lchytafmnuefrgkguynt-auth-token';
    SharedPreferences.setMockInitialValues({
      keyFor(_userA, _family): _state.encode(),
      keyFor(_userB, _otherFamily): 'keep-b',
      token: 'session',
      'other.key': 1,
    });
    await store(currentUserId: () => null).clearAll();
    final stored = await prefs();
    expect(stored.getKeys(), {token, 'other.key'});
    expect(stored.getString(token), 'session');
    expect(stored.getInt('other.key'), 1);
  });

  test(
    'clearAll is a no-op when the preferences loader throws PlatformException',
    () async {
      const token = 'sb-lchytafmnuefrgkguynt-auth-token';
      final key = keyFor(_userA, _family);
      SharedPreferences.setMockInitialValues({
        key: _state.encode(),
        token: 'session',
      });
      await store(preferences: platformFailure).clearAll();
      final stored = await prefs();
      expect(stored.getString(key), _state.encode());
      expect(stored.getString(token), 'session');
    },
  );

  test('a StateError from the loader is not caught by clearAll', () {
    final open = store(preferences: () async => throw StateError('boom'));
    expect(open.clearAll(), throwsA(isA<StateError>()));
  });

  test('read write and remove leave other keys untouched', () async {
    final other = keyFor(_userB, _family);
    SharedPreferences.setMockInitialValues({
      'other.key': 'keep',
      other: _state.encode(),
    });
    final open = store();
    expect(await open.read(familyId: _family), isNull);
    await open.write(familyId: _family, state: _state);
    await open.remove(familyId: _family);
    final stored = await prefs();
    expect(stored.getString('other.key'), 'keep');
    expect(stored.getString(other), _state.encode());
  });
}
