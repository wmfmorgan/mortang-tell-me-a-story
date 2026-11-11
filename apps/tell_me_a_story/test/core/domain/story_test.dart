import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/publish_readiness.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';

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

  test('publishReadiness requires title, body, timeframe and person', () {
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

    final placeless = publishReadiness(
      title: 'Making Blackberry Jam on the Back Porch',
      body: 'We made jam.',
      timeframeStart: DateTime(1980, 1, 1),
      personIds: const ['p1'],
      placeId: null,
    );
    expect(placeless.hasPlace, isFalse);
    expect(placeless.canPublish, isTrue);
  });

  test('compareStories sorts a null date last', () {
    final undated = Story(
      id: 'undated',
      familyId: 'f1',
      authorId: 'u1',
      status: StoryStatus.draft,
      createdAt: DateTime.utc(2020),
    );
    final dated = Story(
      id: 'dated',
      familyId: 'f1',
      authorId: 'u1',
      timeframeStart: DateTime(1980),
      timeframeEnd: DateTime(1980, 12, 31),
      datePrecision: StoryDatePrecision.year,
      status: StoryStatus.draft,
      createdAt: DateTime.utc(2020, 1, 2),
    );
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

    final undated = const Story(
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
}
