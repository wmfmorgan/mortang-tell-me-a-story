import '../../data/stories_api.dart';
import '../all_stories/all_stories_logic.dart';
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
    Set<String>? personIds,
    Set<String>? placeIds,
    bool clearSearch = false,
    bool clearDecade = false,
  }) {
    return ThreadFilter(
      search: clearSearch ? '' : search,
      personIds: personIds ?? this.personIds,
      placeIds: placeIds ?? this.placeIds,
      decadeFrom: clearDecade ? null : decadeFrom,
      decadeTo: clearDecade ? null : decadeTo,
    );
  }

  ThreadFilter withoutPeople(Set<String> personIds) =>
      copyWith(personIds: personIds);

  ThreadFilter withoutPlaces(Set<String> placeIds) =>
      copyWith(placeIds: placeIds);

  bool get isActive => activeCount > 0;

  int get activeCount {
    final range = decadeFrom != null || decadeTo != null ? 1 : 0;
    final query = search.trim().isEmpty ? 0 : 1;
    return personIds.length + placeIds.length + range + query;
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
