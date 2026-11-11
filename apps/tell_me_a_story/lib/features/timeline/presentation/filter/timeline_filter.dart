import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';
import 'package:tell_me_a_story/core/widgets/story/story_search.dart';

/// The timeline filter (Q4: dim only). Categories combine with AND; values
/// within a category combine with OR; an empty category passes. There is no
/// family filter: a rail shows one family.
class TimelineFilter {
  const TimelineFilter({
    this.personIds = const {},
    this.placeIds = const {},
    this.fromDecade,
    this.toDecade,
    this.query = '',
  });

  final Set<String> personIds;
  final Set<String> placeIds;

  /// First year of the earliest decade kept (1950 for the 1950s); null is
  /// open. A story counts in its start decade, the same as its Decades row.
  final int? fromDecade;

  /// First year of the latest decade kept; null is open.
  final int? toDecade;

  /// Free text, matched with [matchesSearch] (title, body, person names).
  final String query;

  bool get isActive =>
      personIds.isNotEmpty ||
      placeIds.isNotEmpty ||
      fromDecade != null ||
      toDecade != null ||
      query.trim().isNotEmpty;

  TimelineFilter copyWith({
    Set<String>? personIds,
    Set<String>? placeIds,
    int? Function()? fromDecade,
    int? Function()? toDecade,
    String? query,
  }) => TimelineFilter(
    personIds: personIds ?? this.personIds,
    placeIds: placeIds ?? this.placeIds,
    fromDecade: fromDecade == null ? this.fromDecade : fromDecade(),
    toDecade: toDecade == null ? this.toDecade : toDecade(),
    query: query ?? this.query,
  );

  bool matches(Story story) {
    if (personIds.isNotEmpty && !story.personIds.any(personIds.contains)) {
      return false;
    }
    if (placeIds.isNotEmpty &&
        (story.placeId == null || !placeIds.contains(story.placeId))) {
      return false;
    }
    final from = fromDecade;
    final to = toDecade;
    if (from != null || to != null) {
      final decade = decadeStartYear(story.publishedStart);
      if (from != null && decade < from) return false;
      if (to != null && decade > to) return false;
    }
    return matchesSearch(story, query);
  }
}

/// What the filter can offer for the loaded stories: people and places by
/// name, decades in order.
class FilterOptions {
  const FilterOptions({
    required this.people,
    required this.places,
    required this.decades,
  });

  final List<({String id, String name})> people;
  final List<({String id, String label})> places;
  final List<int> decades;
}

FilterOptions filterOptions(Iterable<Story> stories) {
  final people = <String, String>{};
  final places = <String, String>{};
  final decades = <int>{};
  for (final story in stories) {
    for (final person in story.people) {
      people.putIfAbsent(person.id, () => person.name);
    }
    final placeId = story.placeId;
    final label = _placeLabel(story);
    if (placeId != null && label != null) {
      places.putIfAbsent(placeId, () => label);
    }
    decades.add(decadeStartYear(story.publishedStart));
  }
  int byText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  return FilterOptions(
    people: [for (final e in people.entries) (id: e.key, name: e.value)]
      ..sort((a, b) => byText(a.name, b.name)),
    places: [for (final e in places.entries) (id: e.key, label: e.value)]
      ..sort((a, b) => byText(a.label, b.label)),
    decades: decades.toList()..sort(),
  );
}

String? _placeLabel(Story story) {
  final label = story.placeLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  final address = story.placeAddress?.trim();
  if (address != null && address.isNotEmpty) return address;
  return null;
}

/// C16, shown while a filter is active.
String filterStatusLine(int matched, int total) =>
    '$matched of $total stories match';

/// C18, a decade header's count while filtering.
String decadeMatchCount(int matched, int total) => '$matched of $total';
