import '../../data/family_thread_density.dart';
import '../../data/stories_api.dart';
import 'thread_beat.dart';

class ThreadBeatModel {
  ThreadBeatModel._(this._stories);

  factory ThreadBeatModel.build(List<Story> stories) {
    return ThreadBeatModel._(List<Story>.unmodifiable(stories));
  }

  final List<Story> _stories;

  int get storyCount => _stories.length;

  List<ThreadBeat> beatsFor(FamilyThreadDensity density) {
    return switch (density) {
      FamilyThreadDensity.overview => _grouped(
        threadDecadeOf,
        (decade, stories) => DecadeBeat(decadeStart: decade, stories: stories),
      ),
      FamilyThreadDensity.browse => _grouped(
        _yearOf,
        (year, stories) => YearBeat(year: year, stories: stories),
      ),
      FamilyThreadDensity.read => [
        for (final story in _stories) StoryBeat(story: story),
      ],
    };
  }

  int indexOfStory(String storyId, FamilyThreadDensity density) {
    final beats = beatsFor(density);
    for (var index = 0; index < beats.length; index++) {
      if (_contains(beats[index], storyId)) return index;
    }
    return -1;
  }

  List<ThreadBeat> _grouped(
    int Function(Story story) keyOf,
    ThreadBeat Function(int key, List<Story> stories) make,
  ) {
    final groups = <int, List<Story>>{};
    for (final story in _stories) {
      final key = keyOf(story);
      (groups[key] ??= <Story>[]).add(story);
    }
    return [for (final entry in groups.entries) make(entry.key, entry.value)];
  }
}

int threadDecadeOfYear(int year) => (year ~/ 10) * 10;

int threadDecadeOf(Story story) =>
    threadDecadeOfYear(story.publishedStart.year);

int _yearOf(Story story) => story.publishedStart.year;

bool _contains(ThreadBeat beat, String storyId) {
  return switch (beat) {
    DecadeBeat(:final stories) => stories.any((story) => story.id == storyId),
    YearBeat(:final stories) => stories.any((story) => story.id == storyId),
    StoryBeat(:final story) => story.id == storyId,
  };
}
