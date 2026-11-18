import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/rpc_error.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

void main() {
  test('detail mapping keeps the four prefixes and ignores other text', () {
    expect(
      mapRpcError(const PostgrestException(message: 'NOT_FOUND: person')),
      'person',
    );
    expect(
      mapRpcError(const PostgrestException(message: 'FORBIDDEN: member only')),
      'member only',
    );
    expect(
      mapRpcError(
        const PostgrestException(message: 'VALIDATION: date required'),
      ),
      'date required',
    );
    expect(
      mapRpcError(const PostgrestException(message: 'INVITE_INVALID: token')),
      'token',
    );
    expect(
      mapRpcError(const PostgrestException(message: 'NOT_FOUND:')),
      isNull,
    );
    expect(
      mapRpcError(const PostgrestException(message: 'VALIDATION:')),
      isNull,
    );
    expect(
      mapRpcError(const PostgrestException(message: '  FORBIDDEN: locked  ')),
      'locked',
    );
    expect(
      mapRpcError(
        const PostgrestException(message: 'db said NOT_FOUND: person'),
      ),
      isNull,
    );
    expect(
      mapRpcError(const PostgrestException(message: 'permission')),
      isNull,
    );
    expect(mapRpcError(StateError('NOT_FOUND: person')), isNull);
  });

  test('rpcErrorPrefix matches only a leading prefix', () {
    expect(
      rpcErrorPrefix(const PostgrestException(message: 'NOT_FOUND: person')),
      RpcErrorPrefix.notFound,
    );
    expect(
      rpcErrorPrefix(const PostgrestException(message: 'FORBIDDEN: member')),
      RpcErrorPrefix.forbidden,
    );
    expect(
      rpcErrorPrefix(const PostgrestException(message: 'VALIDATION: name')),
      RpcErrorPrefix.validation,
    );
    expect(
      rpcErrorPrefix(
        const PostgrestException(message: 'INVITE_INVALID: token'),
      ),
      RpcErrorPrefix.inviteInvalid,
    );
    expect(
      rpcErrorPrefix(
        const PostgrestException(message: 'FORBIDDEN: NOT_FOUND: person'),
      ),
      RpcErrorPrefix.forbidden,
    );
    expect(
      rpcErrorPrefix(
        const PostgrestException(message: 'db said NOT_FOUND: person'),
      ),
      isNull,
    );
    expect(
      rpcErrorPrefix(const PostgrestException(message: 'not found')),
      isNull,
    );
    expect(rpcErrorPrefix(StateError('NOT_FOUND: person')), isNull);
  });

  test('rpcConstraintViolation needs the sqlstate and the quoted constraint', () {
    const people = PostgrestException(
      message:
          'duplicate key value violates unique constraint "story_people_pkey"',
      code: '23505',
    );
    const stories = PostgrestException(
      message: 'duplicate key value violates unique constraint "stories_pkey"',
      code: '23505',
    );
    const wrongState = PostgrestException(
      message:
          'duplicate key value violates unique constraint "story_people_pkey"',
      code: '23503',
    );
    const unquoted = PostgrestException(
      message: 'story_people_pkey',
      code: '23505',
    );

    expect(
      rpcConstraintViolation(people, '23505', 'story_people_pkey'),
      isTrue,
    );
    expect(
      rpcConstraintViolation(stories, '23505', 'story_people_pkey'),
      isFalse,
    );
    expect(
      rpcConstraintViolation(wrongState, '23505', 'story_people_pkey'),
      isFalse,
    );
    expect(
      rpcConstraintViolation(unquoted, '23505', 'story_people_pkey'),
      isFalse,
    );
    expect(rpcConstraintViolation(people, '23505', 'stories_pkey'), isFalse);
    expect(
      rpcConstraintViolation(
        StateError('story_people_pkey'),
        '23505',
        'story_people_pkey',
      ),
      isFalse,
    );
    expect(isDuplicateStoryKey(stories), isTrue);
    expect(isDuplicateStoryKey(people), isFalse);
    expect(
      isDuplicateStoryKey(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      ),
      isFalse,
    );
  });

  test('origin mappings keep catalog text and validation detail', () {
    final forbidden = originRpcException(
      const PostgrestException(message: 'FORBIDDEN: member only'),
    );
    expect(forbidden?.code, 'FORBIDDEN');
    expect(forbidden?.message, 'You do not have permission to do that.');

    final missing = originRpcException(
      const PostgrestException(message: 'NOT_FOUND: story'),
    );
    expect(missing?.code, 'NOT_FOUND');
    expect(missing?.message, 'Not found.');

    final validation = originRpcException(
      const PostgrestException(message: 'VALIDATION: name is required'),
    );
    expect(validation?.code, 'VALIDATION');
    expect(validation?.message, 'name is required');

    expect(
      originRpcException(
        const PostgrestException(message: 'FORBIDDEN then NOT_FOUND'),
      ),
      isNull,
    );
    expect(originRpcException(StateError('FORBIDDEN')), isNull);
    expect(
      originRpcException(
        const PostgrestException(message: 'permission denied'),
      ),
      isNull,
    );
  });

  test(
    'an origin failure without a leading VALIDATION prefix keeps screen copy',
    () {
      const raw = PostgrestException(
        message: 'duplicate key value violates unique constraint "stories_pkey" VALIDATION: leaked',
        code: '23505',
      );
      expect(originRpcException(raw), isNull);
      expect(mapRpcError(raw), isNull);
    },
  );

  test('edgeError reads a FunctionException body', () {
    final error = edgeError(
      const FunctionException(
        status: 403,
        details: {'code': 'FORBIDDEN', 'message': 'Not a family member'},
        reasonPhrase: 'Forbidden',
      ),
    );
    expect(error.code, EdgeErrorCode.forbidden);
    expect(error.message, 'Not a family member');
  });

  test('edgeError reads a decoded response body map', () {
    final error = edgeError({
      'code': 'NOT_FOUND',
      'message': 'Invite not found',
    });
    expect(error.code, EdgeErrorCode.notFound);
    expect(error.message, 'Invite not found');
  });

  test('edgeError maps an unknown code to validation and Try again', () {
    final error = edgeError({
      'code': 'INVITE_EXPIRED',
      'message': 'Invite link expired',
    });
    expect(error.code, EdgeErrorCode.validation);
    expect(error.message, 'Try again');
  });

  test('edgeError uses Try again when the message is missing or empty', () {
    expect(edgeError({'code': 'AUTH_REQUIRED'}).message, 'Try again');
    expect(
      edgeError({'code': 'AUTH_REQUIRED', 'message': ''}).message,
      'Try again',
    );
    expect(
      edgeError({'code': 'AUTH_REQUIRED'}).code,
      EdgeErrorCode.authRequired,
    );
  });
}
