import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_facets.freezed.dart';

/// What a family's published stories can be filtered by. Each entry has at
/// least one story: decade starts ascending, people by name, places by label.
@freezed
abstract class SearchFacets with _$SearchFacets {
  const factory SearchFacets({
    @Default([]) List<int> decades,
    @Default([]) List<({String id, String name})> people,
    @Default([]) List<({String id, String label})> places,
  }) = _SearchFacets;
}

/// Chip label for one decade or a span, using an en dash between the ends.
String decadeChipLabel(List<int> startYears) {
  if (startYears.isEmpty) return '';
  final sorted = [...startYears]..sort();
  if (sorted.length == 1) return '${sorted.first}s';
  return '${sorted.first}s–${sorted.last}s';
}
