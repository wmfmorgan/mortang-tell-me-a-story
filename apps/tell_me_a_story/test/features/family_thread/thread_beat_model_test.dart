import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_model.dart';

void main() {
  test('overview has one beat per decade with stories', () {
    final model = ThreadBeatModel.build([
      _story('b', DateTime.utc(1982, 3, 1), createdAt: DateTime.utc(2020)),
      _story('a', DateTime.utc(1982, 3, 1), createdAt: DateTime.utc(2010)),
      _story('c', DateTime.utc(1989, 1, 1)),
      _story('d', DateTime.utc(2001, 5, 1)),
    ]);

    final beats = model.beatsFor(FamilyThreadDensity.overview);

    expect(model.storyCount, 4);
    expect(beats, hasLength(2));
    final eighties = beats[0] as DecadeBeat;
    expect(eighties.decadeStart, 1980);
    expect(_ids(eighties.stories), ['b', 'a', 'c']);
    expect(
      () => eighties.stories.add(_story('x', DateTime.utc(1980))),
      throwsUnsupportedError,
    );
    final twoThousands = beats[1] as DecadeBeat;
    expect(twoThousands.decadeStart, 2000);
    expect(_ids(twoThousands.stories), ['d']);
  });

  test('browse has one beat per year with stories', () {
    final model = ThreadBeatModel.build([
      _story('b', DateTime.utc(1982, 3, 1), createdAt: DateTime.utc(2020)),
      _story('a', DateTime.utc(1982, 3, 1), createdAt: DateTime.utc(2010)),
      _story('c', DateTime.utc(1985, 1, 1)),
      _story('d', DateTime.utc(2001, 5, 1)),
    ]);

    final beats = model.beatsFor(FamilyThreadDensity.browse);

    expect(beats, hasLength(3));
    final year1982 = beats[0] as YearBeat;
    expect(year1982.year, 1982);
    expect(_ids(year1982.stories), ['b', 'a']);
    expect(() => year1982.stories.clear(), throwsUnsupportedError);
    expect((beats[1] as YearBeat).year, 1985);
    expect(_ids((beats[1] as YearBeat).stories), ['c']);
    expect((beats[2] as YearBeat).year, 2001);
    expect(_ids((beats[2] as YearBeat).stories), ['d']);
  });

  test('read has one beat per story in listPublished order', () {
    final beats = ThreadBeatModel.build([
      _story('a', DateTime.utc(1982, 3, 1)),
      _story('b', DateTime.utc(1982, 11, 1)),
      _story('c', DateTime.utc(2001, 5, 1)),
    ]).beatsFor(FamilyThreadDensity.read);

    expect(beats, hasLength(3));
    expect(
      [for (final beat in beats) (beat as StoryBeat).story.id],
      ['a', 'b', 'c'],
    );
  });

  test('legacy decade-precision row lands at its decade-start year', () {
    final model = ThreadBeatModel.build([
      _story(
        'legacy',
        DateTime.utc(1990, 1, 1),
        precision: StoryDatePrecision.decade,
      ),
      _story('later', DateTime.utc(1994, 6, 1)),
    ]);

    final years = model.beatsFor(FamilyThreadDensity.browse);
    expect(years, hasLength(2));
    expect((years[0] as YearBeat).year, 1990);
    expect(_ids((years[0] as YearBeat).stories), ['legacy']);
    expect((years[1] as YearBeat).year, 1994);

    final decades = model.beatsFor(FamilyThreadDensity.overview);
    expect(decades, hasLength(1));
    final decade = decades.single as DecadeBeat;
    expect(decade.decadeStart, 1990);
    expect(_ids(decade.stories), ['legacy', 'later']);
  });

  test('indexOfStory returns the containing beat per density', () {
    final model = ThreadBeatModel.build([
      _story('a', DateTime.utc(1982, 3, 1)),
      _story('b', DateTime.utc(1989, 1, 1)),
      _story('c', DateTime.utc(2001, 5, 1)),
    ]);

    expect(model.indexOfStory('a', FamilyThreadDensity.overview), 0);
    expect(model.indexOfStory('b', FamilyThreadDensity.overview), 0);
    expect(model.indexOfStory('c', FamilyThreadDensity.overview), 1);
    expect(model.indexOfStory('a', FamilyThreadDensity.browse), 0);
    expect(model.indexOfStory('b', FamilyThreadDensity.browse), 1);
    expect(model.indexOfStory('c', FamilyThreadDensity.browse), 2);
    expect(model.indexOfStory('a', FamilyThreadDensity.read), 0);
    expect(model.indexOfStory('b', FamilyThreadDensity.read), 1);
    expect(model.indexOfStory('c', FamilyThreadDensity.read), 2);
    expect(model.indexOfStory('missing', FamilyThreadDensity.overview), -1);
    expect(model.indexOfStory('missing', FamilyThreadDensity.browse), -1);
    expect(model.indexOfStory('missing', FamilyThreadDensity.read), -1);

    final empty = ThreadBeatModel.build(const []);
    expect(empty.storyCount, 0);
    expect(empty.beatsFor(FamilyThreadDensity.overview), isEmpty);
    expect(empty.beatsFor(FamilyThreadDensity.browse), isEmpty);
    expect(empty.beatsFor(FamilyThreadDensity.read), isEmpty);
    expect(empty.indexOfStory('a', FamilyThreadDensity.overview), -1);
    expect(empty.indexOfStory('a', FamilyThreadDensity.browse), -1);
    expect(empty.indexOfStory('a', FamilyThreadDensity.read), -1);
  });
}

List<String> _ids(List<Story> stories) {
  return [for (final story in stories) story.id];
}

Story _story(
  String id,
  DateTime start, {
  StoryDatePrecision precision = StoryDatePrecision.day,
  DateTime? createdAt,
}) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: start,
    datePrecision: precision,
    createdAt: createdAt,
  );
}
