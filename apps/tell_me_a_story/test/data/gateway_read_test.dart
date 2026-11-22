import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/gateway_read.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/unexpected_payload_exception.dart';

void main() {
  test('a value passes through', () async {
    expect(await guardRead(() async => 7), 7);
  });

  test('listed read failures become GatewayReadException', () async {
    final failures = <Object>[
      const PostgrestException(message: 'db'),
      const FunctionException(status: 500),
      const StorageException('missing', statusCode: '404'),
      const AuthException('signed out'),
      ClientException('offline'),
      const NotSignedInException(),
      const UnexpectedPayloadException('list'),
      const MissingPublishedStartException('story-1'),
      const FormatException('bad'),
    ];

    for (final failure in failures) {
      await expectLater(
        guardRead(() async => throw failure),
        throwsA(const GatewayReadException()),
      );
    }
    expect(
      const GatewayReadException().toString(),
      "Instance of 'GatewayReadException'",
    );
  });

  test('StateError and an unlisted exception propagate', () async {
    await expectLater(
      guardRead(() async => throw StateError('bug')),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      guardRead(() async => throw const _Unlisted()),
      throwsA(isA<_Unlisted>()),
    );
  });
}

class _Unlisted implements Exception {
  const _Unlisted();
}
