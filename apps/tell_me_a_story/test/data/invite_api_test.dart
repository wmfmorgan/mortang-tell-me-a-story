import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/unexpected_payload_exception.dart';

import '../support/json_http_client.dart';

void main() {
  test('createFamily throws when the payload has no id', () async {
    final api = InviteApi(
      client: SupabaseClient(
        'http://localhost',
        'test-anon-key',
        httpClient: JsonHttpClient('nope'),
      ),
    );
    await expectLater(
      api.createFamily('Ada'),
      throwsA(
        isA<UnexpectedPayloadException>().having(
          (error) => error.rpc,
          'rpc',
          'create_family',
        ),
      ),
    );
  });
}
