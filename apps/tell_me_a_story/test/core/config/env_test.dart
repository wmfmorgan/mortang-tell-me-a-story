import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

void main() {
  test('Env.validate fails closed when dart-defines are missing', () {
    // Without --dart-define, fromEnvironment defaults to empty string.
    expect(Env.supabaseUrl, isEmpty);
    expect(Env.supabaseAnonKey, isEmpty);
    expect(Env.validate, throwsA(isA<StateError>()));
  });

  test('isAbsoluteHttpUrl rejects relative placeholders like ...', () {
    expect(Env.isAbsoluteHttpUrl('...'), isFalse);
    expect(Env.isAbsoluteHttpUrl('/auth/v1'), isFalse);
    expect(Env.isAbsoluteHttpUrl('http://127.0.0.1:57321'), isTrue);
    expect(Env.isAbsoluteHttpUrl('https://example.supabase.co'), isTrue);
  });

  test('isPlausibleMapboxToken rejects empty and README placeholders', () {
    expect(Env.isPlausibleMapboxToken('pk.live_test_token_value_here'), isTrue);
    expect(Env.isPlausibleMapboxToken('...'), isFalse);
    expect(Env.isPlausibleMapboxToken(''), isFalse);
    expect(Env.isPlausibleMapboxToken('<public-token>'), isFalse);
    expect(Env.isPlausibleMapboxToken('short'), isFalse);
  });

  test('hasMapboxToken is false when MAPBOX_ACCESS_TOKEN is unset', () {
    // Without --dart-define, fromEnvironment defaults to empty string.
    expect(Env.mapboxAccessToken, isEmpty);
    expect(Env.hasMapboxToken, isFalse);
  });

  test('Env.validate does not require MAPBOX_ACCESS_TOKEN', () {
    // Missing Mapbox must stay soft: validate() only enforces Supabase defines.
    // With empty Supabase defines this still throws; assert the error is Supabase-only.
    expect(
      () => Env.validate(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          isNot(contains('MAPBOX')),
        ),
      ),
    );
  });
}
