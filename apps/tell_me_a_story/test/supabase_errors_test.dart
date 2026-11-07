import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/supabase_errors.dart';

void main() {
  group('appExceptionFromPostgrest', () {
    test('maps each catalog prefix to its code and detail', () {
      final cases = <String, (AppErrorCode, String)>{
        'NOT_FOUND: story': (AppErrorCode.notFound, 'story'),
        'FORBIDDEN: not a steward': (AppErrorCode.forbidden, 'not a steward'),
        'VALIDATION: Already on this story': (
          AppErrorCode.validation,
          'Already on this story',
        ),
        'INVITE_INVALID: Invite link expired': (
          AppErrorCode.inviteInvalid,
          'Invite link expired',
        ),
      };
      for (final entry in cases.entries) {
        final mapped = appExceptionFromPostgrest(
          PostgrestException(message: entry.key),
        );
        expect(mapped?.code, entry.value.$1, reason: entry.key);
        expect(mapped?.message, entry.value.$2, reason: entry.key);
      }
    });

    test('keeps the trimmed message when the detail is empty', () {
      final mapped = appExceptionFromPostgrest(
        const PostgrestException(message: ' VALIDATION: '),
      );
      expect(mapped?.message, 'VALIDATION:');
    });

    test('returns null for an uncatalogued message', () {
      expect(
        appExceptionFromPostgrest(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint',
            code: '23505',
          ),
        ),
        isNull,
      );
    });
  });

  group('withAppErrors', () {
    test('returns the call result', () async {
      expect(await withAppErrors(() async => 3), 3);
    });

    test('rethrows a catalog error as AppException', () async {
      await expectLater(
        withAppErrors<void>(
          () async => throw const PostgrestException(message: 'FORBIDDEN: no'),
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having((e) => e.message, 'message', 'no'),
        ),
      );
    });

    test('leaves other errors untouched', () async {
      const raw = PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
      await expectLater(
        withAppErrors<void>(() async => throw raw),
        throwsA(same(raw)),
      );
      final state = StateError('network');
      await expectLater(
        withAppErrors<void>(() async => throw state),
        throwsA(same(state)),
      );
    });

    test('keeps the original stack trace of a translated error', () async {
      StackTrace? stack;
      try {
        await withAppErrors<void>(() async => _throwCatalogError());
      } on AppException catch (_, s) {
        stack = s;
      }
      expect(stack.toString(), contains('_throwCatalogError'));
    });
  });

  test('appErrorMessage reads only AppException', () {
    expect(
      appErrorMessage(
        const AppException(
          code: AppErrorCode.validation,
          message: 'Already linked',
        ),
      ),
      'Already linked',
    );
    expect(appErrorMessage(StateError('x')), isNull);
    expect(
      appErrorMessage(const PostgrestException(message: 'VALIDATION: raw')),
      isNull,
    );
  });

  group('edge-function envelopes', () {
    test('map codes; unknown or missing codes are validation', () {
      expect(envelopeErrorCode('NOT_FOUND'), AppErrorCode.notFound);
      expect(envelopeErrorCode('FORBIDDEN'), AppErrorCode.forbidden);
      expect(envelopeErrorCode('VALIDATION'), AppErrorCode.validation);
      expect(envelopeErrorCode('INVITE_INVALID'), AppErrorCode.inviteInvalid);
      expect(envelopeErrorCode('INVITE_EXPIRED'), AppErrorCode.inviteInvalid);
      expect(envelopeErrorCode('INVITE_ACCEPTED'), AppErrorCode.inviteInvalid);
      expect(envelopeErrorCode('AUTH_REQUIRED'), AppErrorCode.unauthenticated);
      expect(envelopeErrorCode('SOMETHING_NEW'), AppErrorCode.validation);
      expect(envelopeErrorCode(null), AppErrorCode.validation);
    });

    test('use the body message, else the fallback', () {
      final withMessage = appExceptionFromEnvelope(
        envelopeBody({'code': 'FORBIDDEN', 'message': 'member only'}),
        fallbackMessage: 'Try again',
      );
      expect(withMessage.code, AppErrorCode.forbidden);
      expect(withMessage.message, 'member only');

      final bare = appExceptionFromEnvelope(
        envelopeBody('not a map'),
        fallbackMessage: 'Request failed',
      );
      expect(bare.code, AppErrorCode.validation);
      expect(bare.message, 'Request failed');
    });
  });
}

Never _throwCatalogError() =>
    throw const PostgrestException(message: 'NOT_FOUND: story');
