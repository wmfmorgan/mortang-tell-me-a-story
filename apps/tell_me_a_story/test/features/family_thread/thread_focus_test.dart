import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_model.dart';
import 'package:tell_me_a_story/features/family_thread/thread_focus.dart';

void main() {
  test('representative is the oldest story', () {
    final oldest = _story('old', DateTime.utc(1982, 1, 1));
    final later = _story('later', DateTime.utc(1982, 8, 1));
    final year = YearBeat(year: 1982, stories: [oldest, later]);
    final decade = DecadeBeat(decadeStart: 1980, stories: [oldest, later]);

    expect(ThreadFocus.representative(year).id, 'old');
    expect(ThreadFocus.representative(decade).id, 'old');
    expect(ThreadFocus.representative(StoryBeat(story: later)).id, 'later');
  });

  test('previous focus inside the beat stays focus', () {
    final stories = [
      _story('old', DateTime.utc(1980, 1, 1)),
      _story('keep', DateTime.utc(1986, 1, 1)),
    ];
    final decade = DecadeBeat(decadeStart: 1980, stories: stories);
    final year = YearBeat(year: 1986, stories: stories);

    expect(
      ThreadFocus.representative(decade, previousFocusId: 'keep').id,
      'keep',
    );
    expect(
      ThreadFocus.representative(decade, previousFocusId: 'gone').id,
      'old',
    );
    expect(
      ThreadFocus.representative(year, previousFocusId: 'keep').id,
      'keep',
    );
  });

  test('nearest in time picks the newer on a tie', () {
    final target = DateTime.utc(1990, 6, 1);
    final older = _story('older', target.subtract(const Duration(days: 365)));
    final newer = _story('newer', target.add(const Duration(days: 365)));
    final first = _story('first', target);
    final second = _story('second', target);

    expect(ThreadFocus.nearestInTime(const [], target), isNull);
    expect(ThreadFocus.nearestInTime([older, newer], target)?.id, 'newer');
    expect(ThreadFocus.nearestInTime([newer, older], target)?.id, 'newer');
    expect(ThreadFocus.nearestInTime([first, second], target)?.id, 'second');
  });

  test('browse card shows focus story when in year else oldest', () {
    final beat = YearBeat(
      year: 1982,
      stories: [
        _story('old', DateTime.utc(1982, 1, 1)),
        _story('mid', DateTime.utc(1982, 6, 1)),
      ],
    );

    expect(ThreadFocus.browseCardStory(beat, focusId: 'mid').id, 'mid');
    expect(ThreadFocus.browseCardStory(beat, focusId: 'other').id, 'old');
    expect(ThreadFocus.browseCardStory(beat).id, 'old');
  });

  test('more target is the next story after the card story', () {
    final stories = [
      _story('a', DateTime.utc(1982, 1, 1)),
      _story('b', DateTime.utc(1982, 6, 1)),
      _story('c', DateTime.utc(1982, 12, 1)),
    ];
    final beat = YearBeat(year: 1982, stories: stories);

    expect(ThreadFocus.moreTarget(beat, stories[0])?.id, 'b');
    expect(ThreadFocus.moreTarget(beat, stories[1])?.id, 'c');
    expect(ThreadFocus.moreTarget(beat, stories[2]), isNull);
    expect(
      ThreadFocus.moreTarget(beat, _story('missing', DateTime.utc(1982))),
      isNull,
    );
  });

  test(
    'anchoring read to browse to overview and back returns the same story',
    () {
      final model = ThreadBeatModel.build([
        _story('oldest', DateTime.utc(1980, 1, 1)),
        _story('focus', DateTime.utc(1982, 6, 1)),
        _story('next', DateTime.utc(1994, 1, 1)),
      ]);

      var focusId = 'focus';
      for (final density in [
        FamilyThreadDensity.browse,
        FamilyThreadDensity.overview,
        FamilyThreadDensity.browse,
        FamilyThreadDensity.read,
      ]) {
        focusId = ThreadFocus.representative(
          model.beatsFor(density)[model.indexOfStory(focusId, density)],
          previousFocusId: focusId,
        ).id;
        expect(focusId, 'focus');
      }
    },
  );
}

Story _story(String id, DateTime start) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: start,
  );
}
