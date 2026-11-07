import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/photos_api.dart'
    show StorageFailedException;
import 'package:tell_me_a_story/data/server/server_errors.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

Future<void> fails(server.AppErrorCode code) =>
    withServerErrors<void>(() async {
      throw server.AppException(code: code, message: 'server text');
    });

Matcher clientError(AppErrorCode code, [String message = 'server text']) =>
    throwsA(
      isA<AppException>()
          .having((e) => e.code, 'code', code)
          .having((e) => e.message, 'message', message),
    );

void main() {
  test('codes the client knows keep their code and message', () async {
    await expectLater(
      fails(server.AppErrorCode.forbidden),
      clientError(AppErrorCode.forbidden),
    );
    await expectLater(
      fails(server.AppErrorCode.notFound),
      clientError(AppErrorCode.notFound),
    );
    await expectLater(
      fails(server.AppErrorCode.validation),
      clientError(AppErrorCode.validation),
    );
    await expectLater(
      fails(server.AppErrorCode.inviteInvalid),
      clientError(AppErrorCode.inviteInvalid),
    );
  });

  test('authRequired becomes unauthenticated', () async {
    await expectLater(
      fails(server.AppErrorCode.authRequired),
      clientError(AppErrorCode.unauthenticated),
    );
  });

  test('used and expired invites read as invalid invites', () async {
    await expectLater(
      fails(server.AppErrorCode.inviteAccepted),
      clientError(AppErrorCode.inviteInvalid),
    );
    await expectLater(
      fails(server.AppErrorCode.inviteExpired),
      clientError(AppErrorCode.inviteInvalid),
    );
  });

  test(
    'conflict, which the server never sends today, is a validation error',
    () async {
      await expectLater(
        fails(server.AppErrorCode.conflict),
        clientError(AppErrorCode.validation),
      );
    },
  );

  test('photo cap and storage failure keep the photo exceptions', () async {
    await expectLater(
      fails(server.AppErrorCode.photoCap),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'PHOTO_CAP'),
      ),
    );
    await expectLater(
      fails(server.AppErrorCode.storageFailed),
      throwsA(isA<StorageFailedException>()),
    );
  });

  test('a rejected session reads as unauthenticated', () async {
    await expectLater(
      withServerErrors<void>(() async {
        throw server.ServerpodClientUnauthorized();
      }),
      clientError(AppErrorCode.unauthenticated, 'Sign-in required'),
    );
  });

  test('anything else passes through unchanged', () async {
    final error = StateError('network down');
    await expectLater(
      withServerErrors<void>(() async => throw error),
      throwsA(same(error)),
    );
  });

  test('a successful call returns its value', () async {
    expect(await withServerErrors(() async => 42), 42);
  });
}
