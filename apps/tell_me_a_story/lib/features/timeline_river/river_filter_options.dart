import '../../data/stories_api.dart';
import 'river_filter.dart';

/// People, places, and decades the filter can offer for one family.
class RiverFilterOptions {
  const RiverFilterOptions({
    required this.people,
    required this.places,
    required this.decades,
  });

  final List<({String id, String name})> people;
  final List<({String id, String label})> places;
  final List<int> decades;

  static const empty = RiverFilterOptions(people: [], places: [], decades: []);

  static RiverFilterOptions fromStories(Iterable<Story> stories) {
    final people = <String, String>{};
    final places = <String, String>{};
    final decades = <int>{};
    for (final story in stories) {
      _addPeople(people, story);
      _addPlace(places, story);
      final start = story.timeframeStart;
      if (start != null) decades.add(decadeStartYear(start));
    }
    return RiverFilterOptions(
      people: _people(people),
      places: _places(places),
      decades: (decades.toList()..sort()),
    );
  }

  /// Label for a narrowed year range, or null when the range is fully open.
  String? yearRangeLabel(RiverFilter filter) {
    if (decades.length < 2) return null;
    if (filter.fromDecade == null && filter.toDecade == null) return null;
    final from = filter.fromDecade ?? decades.first;
    final to = filter.toDecade ?? decades.last;
    return '${from}s – ${to}s';
  }
}

void _addPeople(Map<String, String> people, Story story) {
  for (final person in story.people) {
    people.putIfAbsent(person.id, () => person.name);
  }
}

void _addPlace(Map<String, String> places, Story story) {
  final placeId = story.placeId;
  final label = _placeLabel(story);
  if (placeId != null && label != null) {
    places.putIfAbsent(placeId, () => label);
  }
}

String? _placeLabel(Story story) {
  final label = story.placeLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  final address = story.placeAddress?.trim();
  if (address != null && address.isNotEmpty) return address;
  return null;
}

List<({String id, String name})> _people(Map<String, String> rows) {
  final list = [
    for (final entry in rows.entries) (id: entry.key, name: entry.value),
  ];
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

List<({String id, String label})> _places(Map<String, String> rows) {
  final list = [
    for (final entry in rows.entries) (id: entry.key, label: entry.value),
  ];
  list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return list;
}
