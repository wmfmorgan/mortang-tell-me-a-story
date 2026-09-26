import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/supabase/auth_callback.dart';

void main() {
  test('detects otp error redirect as auth callback', () {
    final uri = Uri.parse(
      'http://127.0.0.1:3000/'
      '?error=access_denied'
      '&error_code=otp_expired'
      '&error_description=Email+link+is+invalid+or+has+expired',
    );
    expect(isAuthCallbackUri(uri), isTrue);
  });

  test('detects successful code callback', () {
    final uri = Uri.parse('http://127.0.0.1:3000/?code=abc');
    expect(isAuthCallbackUri(uri), isTrue);
  });

  test('plain app urls are not auth callbacks', () {
    expect(isAuthCallbackUri(Uri.parse('http://127.0.0.1:3000/')), isFalse);
    expect(
      isAuthCallbackUri(Uri.parse('http://127.0.0.1:3000/timeline?invite=tok')),
      isFalse,
    );
  });

  test('strips auth params but keeps invite', () {
    final uri = Uri.parse(
      'http://127.0.0.1:3000/timeline'
      '?invite=tok'
      '&error=access_denied'
      '&error_code=otp_expired'
      '&code=stale',
    );
    final cleaned = uriWithoutAuthParams(uri);
    expect(cleaned.queryParameters['invite'], 'tok');
    expect(cleaned.queryParameters.containsKey('error'), isFalse);
    expect(cleaned.queryParameters.containsKey('code'), isFalse);
    expect(cleaned.fragment, isEmpty);
  });
}
