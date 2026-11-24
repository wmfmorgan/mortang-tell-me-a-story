import '../../data/stories_api.dart';
import '../all_stories/all_stories_logic.dart';
import 'thread_beat.dart';
import 'thread_beat_model.dart';

class ThreadFilter {
  const ThreadFilter({
    this.search = '',
    this.personIds = const {},
    this.placeIds = const {},
    this.decadeFrom,
    this.decadeTo,
  });

  final String search;
  final Set<String> personIds;
  final Set<String> placeIds;
  final int? decadeFrom;
  final int? decadeTo;

  static const cleared = ThreadFilter();

  ThreadFilter copyWith({
    String? search,
    Set<String>? personIds,
    Set<String>? placeIds,
    int? decadeFrom,
    int? decadeTo,
    bool clearSearch = false,
    bool clearDecade = false,
  }) {
    return ThreadFilter(
      search: clearSearch ? '' : search ?? this.search,
      personIds: personIds ?? this.personIds,
      placeIds: placeIds ?? this.placeIds,
      decadeFrom: clearDecade ? null : decadeFrom ?? this.decadeFrom,
      decadeTo: clearDecade ? null : decadeTo ?? this.decadeTo,
    );
  }

  ThreadFilter withPerson(String id) => copyWith(personIds: {...personIds, id});

  ThreadFilter withoutPerson(String id) =>
      copyWith(personIds: {...personIds}..remove(id));

  ThreadFilter withPlace(String id) => copyWith(placeIds: {...placeIds, id});

  ThreadFilter withoutPlace(String id) =>
      copyWith(placeIds: {...placeIds}..remove(id));

  bool get isActive => activeCount > 0;

  int get activeCount {
    final range = decadeFrom != null || decadeTo != null ? 1 : 0;
    final query = search.trim().isEmpty ? 0 : 1;
    return personIds.length + placeIds.length + range + query;
  }

  bool matchesBeat(ThreadBeat beat) {
    if (!isActive) return true;
    return switch (beat) {
      StoryBeat(:final story) => matches(story),
      DecadeBeat(:final stories) ||
      YearBeat(:final stories) => stories.any(matches),
    };
  }

  bool matches(Story story) {
    return _peopleMatch(story) &&
        _placeMatches(story) &&
        _decadeMatches(story) &&
        matchesSearch(story, search);
  }

  ({int n, int total}) countStories(List<Story> stories) {
    var n = 0;
    for (final story in stories) {
      if (matches(story)) n += 1;
    }
    return (n: n, total: stories.length);
  }

  bool _peopleMatch(Story story) =>
      personIds.isEmpty || story.personIds.any(personIds.contains);

  bool _placeMatches(Story story) {
    if (placeIds.isEmpty) return true;
    final placeId = story.placeId;
    return placeId != null && placeIds.contains(placeId);
  }

  bool _decadeMatches(Story story) {
    final from = decadeFrom;
    final to = decadeTo;
    final decade = threadDecadeOf(story);
    if (from != null && decade < from) return false;
    if (to != null && decade > to) return false;
    return true;
  }
}
