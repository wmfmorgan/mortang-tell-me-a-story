import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

typedef _Reply = ({int status, Object body});

/// Answers each request from [reply] and records `METHOD /path`.
class _Http extends http.BaseClient {
  _Http(this.reply);

  final _Reply Function(http.BaseRequest request) reply;
  final calls = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add('${request.method} ${request.url.path}');
    final answer = reply(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(answer.body))),
      answer.status,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

SupabaseClient _client(_Http transport) =>
    SupabaseClient('http://localhost', 'test-anon-key', httpClient: transport);

_Reply _error(int status, String code, String message) =>
    (status: status, body: {'code': code, 'message': message});

void main() {
  group('catalog RPC errors', () {
    test('PeopleApi.markPassedAway reports FORBIDDEN as AppException', () async {
      final api = PeopleApi(
        client: _client(
          _Http((_) => _error(400, 'P0001', 'FORBIDDEN: not a steward')),
        ),
      );
      await expectLater(
        api.markPassedAway(personId: 'p1', value: true),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having((e) => e.message, 'message', 'not a steward'),
        ),
      );
    });

    test('PeopleApi.markPassedAway leaves an uncatalogued error alone', () async {
      final api = PeopleApi(
        client: _client(_Http((_) => _error(500, 'XX000', 'boom'))),
      );
      await expectLater(
        api.markPassedAway(personId: 'p1', value: true),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('StoriesApi.linkPerson reports VALIDATION as AppException', () async {
      final api = StoriesApi(
        client: _client(
          _Http(
            (_) => _error(400, 'P0001', 'VALIDATION: Already on this story'),
          ),
        ),
      );
      await expectLater(
        api.linkPerson(storyId: 's1', personId: 'p1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.validation)
              .having((e) => e.message, 'message', 'Already on this story'),
        ),
      );
    });
  });
}
