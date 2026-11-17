import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/invite_api.dart';

void main() {
  test('createFamily throws when the payload has no id', () async {
    final api = InviteApi(
      client: SupabaseClient(
        'http://localhost',
        'test-anon-key',
        httpClient: _JsonClient('nope'),
      ),
    );
    await expectLater(
      api.createFamily('Ada'),
      throwsA(isA<UnexpectedInvitePayloadException>()),
    );
  });
}

class _JsonClient extends http.BaseClient {
  _JsonClient(this.body);

  final Object body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
