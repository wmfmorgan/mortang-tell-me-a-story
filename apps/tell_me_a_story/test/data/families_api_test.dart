import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/families_api.dart';

void main() {
  test('listStewarded with no signed-in user throws NotSignedInException', () {
    final api = FamiliesApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
    );
    expect(api.listStewarded(), throwsA(isA<NotSignedInException>()));
  });
}
