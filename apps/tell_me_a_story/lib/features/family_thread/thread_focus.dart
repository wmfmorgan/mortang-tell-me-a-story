import '../../data/stories_api.dart';
import 'thread_beat.dart';

abstract final class ThreadFocus {
  static Story representative(ThreadBeat beat, {String? previousFocusId}) {
    return switch (beat) {
      StoryBeat(:final story) => story,
      DecadeBeat(:final stories) => _kept(stories, previousFocusId),
      YearBeat(:final stories) => _kept(stories, previousFocusId),
    };
  }

  static Story? nearestInTime(List<Story> candidates, DateTime target) {
    Story? best;
    Duration? bestGap;
    for (final story in candidates) {
      final gap = story.publishedStart.difference(target).abs();
      if (best == null || gap < bestGap!) {
        best = story;
        bestGap = gap;
      } else if (gap == bestGap && _newerOrTied(story, best)) {
        best = story;
      }
    }
    return best;
  }

  static Story browseCardStory(YearBeat beat, {String? focusId}) {
    return _kept(beat.stories, focusId);
  }

  static Story? moreTarget(YearBeat beat, Story cardStory) {
    final stories = beat.stories;
    for (var index = 0; index < stories.length; index++) {
      if (stories[index].id != cardStory.id) continue;
      final next = index + 1;
      return next < stories.length ? stories[next] : null;
    }
    return null;
  }
}

Story _kept(List<Story> stories, String? focusId) {
  if (focusId != null) {
    for (final story in stories) {
      if (story.id == focusId) return story;
    }
  }
  return stories.first;
}

bool _newerOrTied(Story story, Story best) {
  return story.publishedStart.compareTo(best.publishedStart) >= 0;
}
