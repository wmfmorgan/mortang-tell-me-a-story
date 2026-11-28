import '../../data/stories_api.dart';
import '../all_stories/all_stories_logic.dart';

/// Dim-only river filter. Values in one category combine with OR.
/// Categories combine with AND. An empty category matches everything.
class RiverFilter {
  const RiverFilter({
    this.personIds = const {},
    this.placeIds = const {},
    this.fromDecade,
    this.toDecade,
    this.query = '',
  });

  final Set<String> personIds;
  final Set<String> placeIds;

  /// First year of the earliest decade kept, or null when that end is open.
  final int? fromDecade;

  /// First year of the latest decade kept, or null when that end is open.
  final int? toDecade;
  final String query;

  bool get isActive =>
      personIds.isNotEmpty ||
      placeIds.isNotEmpty ||
      fromDecade != null ||
      toDecade != null ||
      query.trim().isNotEmpty;

  static String statusLine(int matched, int total) =>
      '$matched of $total stories match';

  RiverFilter copyWith({
    Set<String>? personIds,
    Set<String>? placeIds,
    int? Function()? fromDecade,
    int? Function()? toDecade,
    String? query,
  }) {
    return RiverFilter(
      personIds: personIds ?? this.personIds,
      placeIds: placeIds ?? this.placeIds,
      fromDecade: fromDecade == null ? this.fromDecade : fromDecade(),
      toDecade: toDecade == null ? this.toDecade : toDecade(),
      query: query ?? this.query,
    );
  }

  bool matches(Story story) {
    if (!_peoplePass(story) || !_placePasses(story)) return false;
    if (!_decadePasses(story)) return false;
    return matchesSearch(story, query);
  }

  bool _peoplePass(Story story) {
    if (personIds.isEmpty) return true;
    return story.personIds.any(personIds.contains);
  }

  bool _placePasses(Story story) {
    if (placeIds.isEmpty) return true;
    final placeId = story.placeId;
    return placeId != null && placeIds.contains(placeId);
  }

  bool _decadePasses(Story story) {
    final from = fromDecade;
    final to = toDecade;
    if (from == null && to == null) return true;
    final start = story.timeframeStart;
    if (start == null) return false;
    final decade = decadeStartYear(start);
    if (from != null && decade < from) return false;
    if (to != null && decade > to) return false;
    return true;
  }
}

int riverMatchCount(Iterable<Story> stories, RiverFilter filter) {
  var count = 0;
  for (final story in stories) {
    if (filter.matches(story)) count++;
  }
  return count;
}
