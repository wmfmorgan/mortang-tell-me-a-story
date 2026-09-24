import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

void main() {
  test('Env.validate fails closed when dart-defines are missing', () {
    // Without --dart-define, fromEnvironment defaults to empty string.
    expect(Env.supabaseUrl, isEmpty);
    expect(Env.supabaseAnonKey, isEmpty);
    expect(Env.validate, throwsA(isA<StateError>()));
  });
}
