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
      'NOT_FOUND:',
    );
    expect(
      mapRpcError(const PostgrestException(message: '  FORBIDDEN: locked  ')),
      'locked',
    );
    expect(
      mapRpcError(const PostgrestException(message: 'permission')),
      isNull,
    );
    expect(mapRpcError(StateError('NOT_FOUND: person')), isNull);
  });

  test('notFoundPrefix matches only a leading NOT_FOUND prefix', () {
    expect(
      mapRpcError(
        const PostgrestException(message: 'NOT_FOUND: person'),
        match: RpcErrorMatch.notFoundPrefix,
      ),
      'person',
    );
    expect(
      mapRpcError(
        const PostgrestException(message: 'FORBIDDEN: NOT_FOUND: person'),
        match: RpcErrorMatch.notFoundPrefix,
      ),
      isNull,
    );
    expect(
      mapRpcError(
        const PostgrestException(message: 'not found'),
        match: RpcErrorMatch.notFoundPrefix,
      ),
      isNull,
    );
  });

  test(
    'duplicateStoryKey matches sqlstate 23505 or the duplicate key text',
    () {
      expect(
        mapRpcError(
          const PostgrestException(message: 'unique violation', code: '23505'),
          match: RpcErrorMatch.duplicateStoryKey,
        ),
        'duplicate key',
      );
      expect(
        mapRpcError(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint',
            code: '23503',
          ),
          match: RpcErrorMatch.duplicateStoryKey,
        ),
        'duplicate key',
      );
      expect(
        mapRpcError(
          const PostgrestException(message: 'permission denied', code: '42501'),
          match: RpcErrorMatch.duplicateStoryKey,
        ),
        isNull,
      );
      expect(
        mapRpcError(
          StateError('duplicate key'),
          match: RpcErrorMatch.duplicateStoryKey,
        ),
        isNull,
      );
      expect(
        isDuplicateStoryKey(
          const PostgrestException(message: 'unique violation', code: '23505'),
        ),
        isTrue,
      );
    },
  );

  test('missingCoverColumn matches only a missing cover_photo_path column', () {
    const missing = PostgrestException(
      message: 'column families.cover_photo_path does not exist',
      code: '42703',
    );
    const cache = PostgrestException(
      message: "Could not find the 'cover_photo_path' column of 'families' in the schema cache",
      code: 'PGRST204',
    );
    const denied = PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    const otherColumn = PostgrestException(
      message: 'column families.name does not exist',
      code: '42703',
    );

    expect(
      mapRpcError(missing, match: RpcErrorMatch.missingCoverColumn),
      'cover_photo_path',
    );
    expect(
      mapRpcError(cache, match: RpcErrorMatch.missingCoverColumn),
      'cover_photo_path',
    );
    expect(
      mapRpcError(denied, match: RpcErrorMatch.missingCoverColumn),
      isNull,
    );
    expect(
      mapRpcError(otherColumn, match: RpcErrorMatch.missingCoverColumn),
      isNull,
    );
    expect(familiesCoverColumnMissing(missing), isTrue);
    expect(familiesCoverColumnMissing(denied), isFalse);
  });

  test('storyPeopleDuplicate requires the story_people primary key', () {
    const people = PostgrestException(
      message:
          'duplicate key value violates unique constraint "story_people_pkey"',
      code: '23505',
    );
    const stories = PostgrestException(
      message: 'duplicate key value violates unique constraint "stories_pkey"',
      code: '23505',
    );

    expect(
      mapRpcError(people, match: RpcErrorMatch.storyPeopleDuplicate),
      'story_people_pkey',
    );
    expect(
      mapRpcError(stories, match: RpcErrorMatch.storyPeopleDuplicate),
      isNull,
    );
    expect(
      mapRpcError(
        const PostgrestException(message: 'story_people_pkey', code: '23503'),
        match: RpcErrorMatch.storyPeopleDuplicate,
      ),
      isNull,
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

    final bare = originRpcException(
      const PostgrestException(message: 'VALIDATION:name'),
    );
    expect(bare?.message, 'VALIDATION:name');

    expect(
      originRpcException(
        const PostgrestException(message: 'FORBIDDEN then NOT_FOUND'),
      )?.code,
      'FORBIDDEN',
    );
    expect(originRpcException(StateError('FORBIDDEN')), isNull);
    expect(
      originRpcException(
        const PostgrestException(message: 'permission denied'),
      ),
      isNull,
    );
  });
}
