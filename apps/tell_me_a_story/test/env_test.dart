import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

void main() {
  test('Env.validate fails closed when SERVER_URL is missing', () {
    // Without --dart-define, fromEnvironment defaults to empty string.
    expect(Env.serverUrl, isEmpty);
    expect(
      Env.validate,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('SERVER_URL'),
        ),
      ),
    );
  });

  test('validateServerUrl accepts only an absolute http(s) URL', () {
    expect(
      () => Env.validateServerUrl('http://127.0.0.1:8080'),
      returnsNormally,
    );
    expect(
      () => Env.validateServerUrl('https://api.example.com/'),
      returnsNormally,
    );
    expect(() => Env.validateServerUrl(''), throwsStateError);
    expect(() => Env.validateServerUrl('...'), throwsStateError);
    expect(() => Env.validateServerUrl('/api'), throwsStateError);
    expect(() => Env.validateServerUrl('ws://127.0.0.1:8080'), throwsStateError);
  });

  test('isAbsoluteHttpUrl rejects relative placeholders like ...', () {
    expect(Env.isAbsoluteHttpUrl('...'), isFalse);
    expect(Env.isAbsoluteHttpUrl('/auth/v1'), isFalse);
    expect(Env.isAbsoluteHttpUrl('http://127.0.0.1:8080'), isTrue);
    expect(Env.isAbsoluteHttpUrl('https://api.example.com'), isTrue);
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
    // Missing Mapbox must stay soft: validate() only enforces SERVER_URL.
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
