import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';

const _userId = '6f1c2b4e-0000-4000-8000-000000000001';

// No server listens here; a signed-out client never calls it.
const _noServer = 'http://127.0.0.1:1';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() {
    AppSession.instance = const ServerAppSession();
    serverClientForTesting = null;
  });

  test('the server session has no user before initServer', () {
    serverClientForTesting = null;
    expect(const ServerAppSession().currentUserId, isNull);
  });

  test('the server session reads the signed-in auth user', () async {
    final storage = _Storage();
    final client = await initServer(url: _noServer, storage: storage);
    await client.auth.updateSignedInUser(_auth(_userId));

    expect(const ServerAppSession().currentUserId, _userId);
    expect(ServerAppSession(client: client).currentUserId, _userId);
  });

  test('the app storage keeps the auth cache outermost', () async {
    final client = await initServer(
      url: _noServer,
      storage: appAuthStorage(keyValueStorage: _KeyValues()),
    );

    // The session manager invalidates only a cached storage before a JWT
    // refresh, which keeps other web tabs' rotations from revoking us.
    expect(client.auth.storage, isA<CachedClientAuthSuccessStorage>());
  });

  test('a readable saved session survives an unreachable server', () async {
    final values = _KeyValues();
    await appAuthStorage(keyValueStorage: values).set(_auth(_userId));

    final client = await initServer(
      url: _noServer,
      storage: appAuthStorage(keyValueStorage: values),
    );

    expect(client.auth.authInfo?.authUserId.toString(), _userId);
    expect(values.entries, isNotEmpty);
  });

  test(
    'an unreadable saved session starts signed out, is cleared and reported',
    () async {
      final reported = <FlutterErrorDetails>[];
      final onError = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = onError);
      final values = _KeyValues()
        ..entries['serverpod_auth_success_key'] = 'not an auth entry';

      final client = await initServer(
        url: _noServer,
        storage: appAuthStorage(keyValueStorage: values),
      );

      expect(client.auth.authInfo, isNull);
      expect(ServerAppSession(client: client).currentUserId, isNull);
      expect(values.entries, isEmpty);
      expect(reported, hasLength(1));
    },
  );

  testWidgets('header Logout without onLogout signs out through AppSession', (
    tester,
  ) async {
    final session = _FakeSession('u1');
    AppSession.instance = session;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Morgan',
            families: const [],
            currentFamilyId: null,
            onFamilySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-menu-logout')));
    await tester.pumpAndSettle();

    expect(session.signOutCalls, 1);
  });
}

AuthSuccess _auth(String userId) => AuthSuccess(
  authStrategy: 'session',
  token: 'token',
  authUserId: UuidValue.fromString(userId),
  scopeNames: const {},
);

class _Storage implements ClientAuthSuccessStorage {
  AuthSuccess? _value;

  @override
  Future<AuthSuccess?> get() async => _value;

  @override
  Future<void> set(AuthSuccess? data) async => _value = data;
}

/// In-memory stand-in for the secure key-value store.
class _KeyValues implements KeyValueStorage {
  final entries = <String, String>{};

  @override
  Future<String?> get(String key) async => entries[key];

  @override
  Future<void> set(String key, String? value) async {
    if (value == null) {
      entries.remove(key);
    } else {
      entries[key] = value;
    }
  }
}

class _FakeSession extends AppSession {
  _FakeSession(this.currentUserId);

  @override
  final String? currentUserId;

  var signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
