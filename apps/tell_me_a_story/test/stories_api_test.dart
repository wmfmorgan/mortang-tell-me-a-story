import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

void main() {
  test('storedStoryTitle trims and clears blank titles', () {
    expect(storedStoryTitle(null), isNull);
    expect(storedStoryTitle(''), isNull);
    expect(storedStoryTitle('   '), isNull);
    expect(
      storedStoryTitle('  Making Blackberry Jam on the Back Porch  '),
      'Making Blackberry Jam on the Back Porch',
    );
  });

  test('ensureValidDraftSave rejects missing timeframe', () {
    expect(
      () => ensureValidDraftSave(timeframeStart: null),
      throwsArgumentError,
    );
  });

  test('publishReadiness requires title, body, timeframe, person, place', () {
    final r = publishReadiness(
      title: '  ',
      body: '  ',
      timeframeStart: DateTime(1980, 1, 1),
      personIds: const [],
      placeId: null,
    );
    expect(r.canPublish, isFalse);
    expect(r.hasTitle, isFalse);
    expect(r.hasBody, isFalse);
    expect(r.hasTimeframe, isTrue);
    expect(r.hasPerson, isFalse);
    expect(r.hasPlace, isFalse);

    final ready = publishReadiness(
      title: 'Making Blackberry Jam on the Back Porch',
      body: 'We made jam.',
      timeframeStart: DateTime(1980, 1, 1),
      personIds: const ['p1'],
      placeId: 'pl1',
    );
    expect(ready.canPublish, isTrue);
    expect(ready.hasTitle, isTrue);
  });

  test('Story.fromJson maps draft status and nested person ids', () {
    final s = Story.fromJson({
      'id': 's1',
      'family_id': 'f1',
      'author_id': 'u1',
      'title': null,
      'body': 'Jam',
      'timeframe_start': '1980-01-01',
      'timeframe_end': '1989-12-31',
      'place_id': 'p1',
      'status': 'draft',
      'published_at': null,
      'story_people': [
        {'person_id': 'a'},
        {'person_id': 'b'},
      ],
      'photos': [
        {'id': 'ph1'},
      ],
    });
    expect(s.status, StoryStatus.draft);
    expect(s.personIds, ['a', 'b']);
    expect(s.photoCount, 1);
    expect(s.timeframeStart, DateTime(1980, 1, 1));
  });

  test('Story.fromJson tolerates a null timeframe', () {
    final story = Story.fromJson({
      'id': 's-null',
      'family_id': 'f1',
      'author_id': 'u1',
      'title': 'Undated',
      'body': 'Still writing',
      'timeframe_start': null,
      'timeframe_end': null,
      'date_precision': null,
      'status': 'draft',
    });
    expect(story.timeframeStart, isNull);
    expect(story.timeframeEnd, isNull);
    expect(story.status, StoryStatus.draft);
  });

  test('compareStories sorts a null date last', () {
    final undated = Story.fromJson({
      'id': 'undated',
      'family_id': 'f1',
      'author_id': 'u1',
      'timeframe_start': null,
      'timeframe_end': null,
      'date_precision': null,
      'status': 'draft',
      'created_at': '2020-01-01T00:00:00Z',
    });
    final dated = Story.fromJson({
      'id': 'dated',
      'family_id': 'f1',
      'author_id': 'u1',
      'timeframe_start': '1980-01-01',
      'timeframe_end': '1980-12-31',
      'date_precision': 'year',
      'status': 'draft',
      'created_at': '2020-01-02T00:00:00Z',
    });
    final rows = [undated, dated]..sort(compareStories);
    expect(rows.map((story) => story.id).toList(), ['dated', 'undated']);
  });

  test('publishedStart returns the start date and rejects a null one', () {
    final dated = Story(
      id: 'dated',
      familyId: 'f1',
      authorId: 'u1',
      timeframeStart: DateTime(1980, 6, 1),
      status: StoryStatus.published,
    );
    expect(dated.publishedStart, DateTime(1980, 6, 1));

    final undated = Story(
      id: 'undated',
      familyId: 'f1',
      authorId: 'u1',
      status: StoryStatus.draft,
    );
    expect(() => undated.publishedStart, throwsA(isA<StateError>()));
  });

  test('lib does not force a story start date with timeframeStart!', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('timeframeStart!')) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty);
  });

  test('isDuplicateStoryKey matches a stories primary key collision', () {
    expect(
      isDuplicateStoryKey(
        const PostgrestException(
          message:
              'duplicate key value violates unique constraint "stories_pkey"',
          code: '23505',
        ),
      ),
      isTrue,
    );
    expect(isDuplicateStoryKey(StateError('network')), isFalse);
  });
}
