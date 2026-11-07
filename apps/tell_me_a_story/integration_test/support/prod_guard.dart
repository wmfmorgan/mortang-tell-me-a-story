import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

const _localOrigins = {'http://127.0.0.1:8080', 'http://localhost:8080'};

void assertLocalSupabase() {
  if (!_localOrigins.contains(Env.serverUrl)) {
    fail('SERVER_URL is not the local server');
  }
}
