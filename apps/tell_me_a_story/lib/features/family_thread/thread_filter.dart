import '../../data/stories_api.dart';
import '../all_stories/all_stories_logic.dart';

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

  bool _peopleMatch(Story story) {
    if (personIds.isEmpty) return true;
    for (final id in story.personIds) {
      if (personIds.contains(id)) return true;
    }
    return false;
  }

  bool _placeMatches(Story story) {
    if (placeIds.isEmpty) return true;
    final placeId = story.placeId;
    return placeId != null && placeIds.contains(placeId);
  }

  bool _decadeMatches(Story story) {
    if (decadeFrom == null && decadeTo == null) return true;
    final decade = (story.publishedStart.year ~/ 10) * 10;
    if (decadeFrom != null && decade < decadeFrom!) return false;
    if (decadeTo != null && decade > decadeTo!) return false;
    return true;
  }
}
