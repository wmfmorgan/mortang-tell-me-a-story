import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

const _localServers = {'http://127.0.0.1:8080', 'http://localhost:8080'};

/// The e2e flows create users and families, so they run only against a local
/// `just server`.
void assertLocalServer() {
  const url = Env.serverUrl;
  final origin = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  if (!_localServers.contains(origin)) {
    fail(
      'SERVER_URL "$url" is not the local just server (http://127.0.0.1:8080)',
    );
  }
}
