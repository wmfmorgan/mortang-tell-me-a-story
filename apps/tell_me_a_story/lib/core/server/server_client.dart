import 'package:flutter/foundation.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart';

import '../config/env.dart';

Client? _serverClient;

/// The app's Serverpod client. [initServer] must have run first.
Client get serverClient =>
    _serverClient ?? (throw StateError('initServer() has not run'));

/// Builds the client for [url] (default [Env.serverUrl]) with a persisted
/// auth session, restores a saved sign-in, and makes it [serverClient].
/// Tests pass an in-memory [storage].
Future<Client> initServer({
  String? url,
  ClientAuthSuccessStorage? storage,
}) async {
  final client = Client(serverHost(url ?? Env.serverUrl))
    ..authSessionManager = FlutterAuthSessionManager(storage: storage);
  await client.auth.initialize();
  return _serverClient = client;
}

/// Replaces [serverClient] in tests; null forgets it.
@visibleForTesting
set serverClientForTesting(Client? client) => _serverClient = client;

/// Serverpod clients expect the host URL to end with a slash.
String serverHost(String url) => url.endsWith('/') ? url : '$url/';
