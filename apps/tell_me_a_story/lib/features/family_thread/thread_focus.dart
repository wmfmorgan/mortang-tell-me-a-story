import '../../data/stories_api.dart';
import 'thread_beat.dart';
import 'thread_filter.dart';

abstract final class ThreadFocus {
  static Story representative(
    ThreadBeat beat, {
    String? previousFocusId,
    ThreadFilter filter = ThreadFilter.cleared,
  }) {
    return switch (beat) {
      StoryBeat(:final story) => story,
      DecadeBeat(:final stories) => _kept(stories, previousFocusId, filter),
      YearBeat(:final stories) => _kept(stories, previousFocusId, filter),
    };
  }

  /// publishedStart tie: later list entry wins (newer, listPublished order).
  static Story? nearestInTime(List<Story> candidates, DateTime target) {
    if (candidates.isEmpty) return null;
    var best = candidates.first;
    var bestGap = best.publishedStart.difference(target).abs();
    for (final story in candidates.skip(1)) {
      final gap = story.publishedStart.difference(target).abs();
      if (gap < bestGap) {
        best = story;
        bestGap = gap;
      } else if (gap == bestGap && _newerOrTied(story, best)) {
        best = story;
      }
    }
    return best;
  }

  static Story browseCardStory(YearBeat beat, {String? focusId}) {
    return _kept(beat.stories, focusId, ThreadFilter.cleared);
  }

  static Story? moreTarget(YearBeat beat, Story cardStory) {
    final stories = beat.stories;
    final i = stories.indexWhere((story) => story.id == cardStory.id);
    return i >= 0 && i + 1 < stories.length ? stories[i + 1] : null;
  }
}

Story _kept(List<Story> stories, String? focusId, ThreadFilter filter) {
  if (focusId != null) {
    for (final story in stories) {
      if (story.id == focusId && filter.matches(story)) return story;
    }
  }
  for (final story in stories) {
    if (filter.matches(story)) return story;
  }
  return stories.first;
}

bool _newerOrTied(Story story, Story best) {
  return story.publishedStart.compareTo(best.publishedStart) >= 0;
}
