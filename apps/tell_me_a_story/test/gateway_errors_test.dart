import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
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

  group('StoriesApi.linkPerson duplicates', () {
    test('an existing story_people row counts as linked', () async {
      final api = StoriesApi(
        client: _client(
          _Http(
            (_) => _error(
              409,
              '23505',
              'duplicate key value violates unique constraint "story_people_pkey"',
            ),
          ),
        ),
      );
      await api.linkPerson(storyId: 's1', personId: 'p1');
    });

    test('a duplicate on another constraint still fails', () async {
      final api = StoriesApi(
        client: _client(
          _Http(
            (_) => _error(
              409,
              '23505',
              'duplicate key value violates unique constraint "photos_pkey"',
            ),
          ),
        ),
      );
      await expectLater(
        api.linkPerson(storyId: 's1', personId: 'p1'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
