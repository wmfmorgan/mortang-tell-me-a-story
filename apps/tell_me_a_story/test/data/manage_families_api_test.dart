import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story/data/rpc_error.dart';

void main() {
  test('a malformed success payload throws validation Try again', () async {
    final cases = <_PayloadCase>[
      _PayloadCase(
        'createRootFamily with no id',
        <String, Object?>{},
        (api) => api.createRootFamily('Ada'),
      ),
      _PayloadCase(
        'createBranchFamily with no id',
        <String, Object?>{'family_id': ''},
        (api) => api.createBranchFamily(
          parentFamilyId: 'parent',
          originStoryId: 'origin',
          name: 'Side',
          branchYear: 1970,
          ownerUserId: 'owner',
        ),
      ),
      _PayloadCase(
        'resendInvite with no expires_at',
        <String, Object?>{},
        (api) => api.resendInvite('invite'),
      ),
    ];
    for (final item in cases) {
      final api = await _signedIn(item.body);
      await expectLater(
        item.call(api),
        throwsA(
          isA<ManageFamiliesException>()
              .having((error) => error.code, 'code', EdgeErrorCode.validation)
              .having((error) => error.message, 'message', 'Try again'),
        ),
        reason: item.name,
      );
    }
  });
}

class _PayloadCase {
  _PayloadCase(this.name, this.body, this.call);

  final String name;
  final Map<String, Object?> body;
  final Future<Object?> Function(ManageFamiliesApi api) call;
}

Future<ManageFamiliesApi> _signedIn(Map<String, Object?> body) async {
  final client = SupabaseClient(
    'http://localhost',
    'test-anon-key',
    httpClient: _FunctionClient(body),
  );
  await client.auth.recoverSession(
    jsonEncode({
      'access_token': 'token',
      'token_type': 'bearer',
      'user': {'id': '11111111-1111-4111-8111-111111111111'},
    }),
  );
  return ManageFamiliesApi(client: client);
}

class _FunctionClient extends http.BaseClient {
  _FunctionClient(this.body);

  final Map<String, Object?> body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode(body));
    final status = request.url.path.contains('resend-invite') ? 200 : 201;
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
