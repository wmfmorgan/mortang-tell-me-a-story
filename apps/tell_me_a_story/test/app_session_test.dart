import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';

void main() {
  tearDown(() => AppSession.instance = const SupabaseAppSession());

  test('the default session is Supabase-backed', () {
    expect(AppSession.instance, isA<SupabaseAppSession>());
  });

  test('the Supabase session has no user before Supabase starts', () {
    expect(const SupabaseAppSession().currentUserId, isNull);
  });
}
