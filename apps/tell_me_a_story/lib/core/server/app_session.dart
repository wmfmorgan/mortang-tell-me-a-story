import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'server_client.dart';

/// Who is signed in, for code outside `lib/data`.
///
/// Widgets that take a `currentUserId` / `signedInUserId` / `onLogout`
/// argument still prefer it; this is the fallback.
abstract class AppSession {
  const AppSession();

  /// App-wide session. Tests replace it and restore
  /// `const ServerAppSession()` in tearDown.
  static AppSession instance = const ServerAppSession();

  /// Signed-in user id, or null when signed out or auth has not started.
  String? get currentUserId;

  Future<void> signOut();
}

/// [AppSession] over the Serverpod client's auth session.
class ServerAppSession extends AppSession {
  /// Reads [serverClient] unless a [client] is given.
  const ServerAppSession({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client? get _client {
    final injected = _injected;
    if (injected != null) return injected;
    try {
      return serverClient;
    } on StateError {
      // initServer() has not run (widget tests).
      return null;
    }
  }

  @override
  String? get currentUserId => _client?.auth.authInfo?.authUserId.toString();

  @override
  Future<void> signOut() async {
    await (_injected ?? serverClient).auth.signOutDevice();
  }
}

/// Saved-session storage that treats an unreadable entry as signed out.
///
/// A corrupted entry (for example in web secure storage) would otherwise make
/// `initServer()` throw at startup. The entry is deleted so the next start is
/// clean, and the app starts signed out.
class SessionRecoveringStorage implements ClientAuthSuccessStorage {
  SessionRecoveringStorage(this._delegate);

  final ClientAuthSuccessStorage _delegate;

  @override
  Future<AuthSuccess?> get() async {
    try {
      return await _delegate.get();
    } catch (_) {
      try {
        await _delegate.set(null);
      } catch (_) {
        // Still start signed out; the next sign-in overwrites the entry.
      }
      return null;
    }
  }

  @override
  Future<void> set(AuthSuccess? data) => _delegate.set(data);
}
