import '../model/lab_models.dart';

enum FilterMode { hide, dim }

/// Immutable filter. Categories combine with AND; values within a category
/// combine with OR; an empty category passes.
class TimelineFilter {
  const TimelineFilter({
    this.personIds = const {},
    this.placeIds = const {},
    this.familyIds = const {},
    this.fromYear,
    this.toYear,
    this.query = '',
    this.mode = FilterMode.dim,
  });

  final Set<String> personIds;
  final Set<String> placeIds;
  final Set<String> familyIds;

  /// Inclusive; null is open.
  final int? fromYear;

  /// Inclusive; null is open.
  final int? toYear;
  final String query;
  final FilterMode mode;

  bool get isActive =>
      personIds.isNotEmpty ||
      placeIds.isNotEmpty ||
      familyIds.isNotEmpty ||
      fromYear != null ||
      toYear != null ||
      query.trim().isNotEmpty;

  TimelineFilter copyWith({
    Set<String>? personIds,
    Set<String>? placeIds,
    Set<String>? familyIds,
    int? Function()? fromYear,
    int? Function()? toYear,
    String? query,
    FilterMode? mode,
  }) => TimelineFilter(
    personIds: personIds ?? this.personIds,
    placeIds: placeIds ?? this.placeIds,
    familyIds: familyIds ?? this.familyIds,
    fromYear: fromYear == null ? this.fromYear : fromYear(),
    toYear: toYear == null ? this.toYear : toYear(),
    query: query ?? this.query,
    mode: mode ?? this.mode,
  );

  bool matches(LabStory s, LabDataset d) {
    if (personIds.isNotEmpty && !s.personIds.any(personIds.contains)) {
      return false;
    }
    if (placeIds.isNotEmpty &&
        (s.placeId == null || !placeIds.contains(s.placeId))) {
      return false;
    }
    if (familyIds.isNotEmpty && !familyIds.contains(s.familyId)) {
      return false;
    }
    if (fromYear != null && s.end.isBefore(DateTime.utc(fromYear!, 1, 1))) {
      return false;
    }
    if (toYear != null && s.start.isAfter(DateTime.utc(toYear!, 12, 31))) {
      return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      // Mirrors All Stories `matchesSearch`: title, body, person names.
      // Place is deliberately not searched.
      final hit =
          s.title.toLowerCase().contains(q) ||
          s.body.toLowerCase().contains(q) ||
          d.personNames(s).any((n) => n.toLowerCase().contains(q));
      if (!hit) return false;
    }
    return true;
  }
}

class TimelineEntry {
  const TimelineEntry({required this.story, required this.matched});

  final LabStory story;
  final bool matched;
}

/// Entries in dataset (ascending) order. Hide drops non-matches; dim keeps
/// them with `matched: false`.
List<TimelineEntry> applyFilter(LabDataset d, TimelineFilter f) {
  if (!f.isActive) {
    return [for (final s in d.stories) TimelineEntry(story: s, matched: true)];
  }
  final out = <TimelineEntry>[];
  for (final s in d.stories) {
    final matched = f.matches(s, d);
    if (matched || f.mode == FilterMode.dim) {
      out.add(TimelineEntry(story: s, matched: matched));
    }
  }
  return out;
}

/// Scratch-app copy, not app copy.
String statusLine(int n, int total, TimelineFilter f) =>
    f.isActive ? '$n of $total stories match' : '$total stories';
