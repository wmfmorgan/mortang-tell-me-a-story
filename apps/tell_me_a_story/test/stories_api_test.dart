import 'package:flutter_test/flutter_test.dart';
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
}
