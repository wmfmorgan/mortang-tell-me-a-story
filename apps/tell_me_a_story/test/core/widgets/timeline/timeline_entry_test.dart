import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/widgets/timeline/time_scale.dart';
import 'package:tell_me_a_story/core/widgets/timeline/timeline_entry.dart';

Story _story(String id, DateTime start) => Story(
  id: id,
  familyId: 'root',
  authorId: 'u1',
  title: id,
  timeframeStart: start,
  status: StoryStatus.published,
);

void main() {
  test('an entry places its story at the fractional start year', () {
    final story = _story('s', DateTime(1987, 7, 2));
    final entry = TimelineEntry(story: story, matched: true);
    expect(entry.id, 's');
    expect(entry.year, fractionalYear(DateTime(1987, 7, 2)));
  });

  test('timelineEntries keeps order and flags matches (dim, never hide)', () {
    final stories = [
      _story('a', DateTime(1950)),
      _story('b', DateTime(1960)),
      _story('c', DateTime(1970)),
    ];
    final entries = timelineEntries(stories, matches: (s) => s.id != 'b');
    expect(entries.map((e) => e.id), ['a', 'b', 'c']);
    expect(entries.map((e) => e.matched), [true, false, true]);
    expect(timelineEntries(stories).every((e) => e.matched), isTrue);
  });
}
