/// Lab data model. Mirrors the story shape of `apps/tell_me_a_story`
/// (`stories_api.dart`) and the date rules of the future schema
/// (`docs/migration/schema-design.md`): dates are UTC midnight and
/// [DatePrecision] is coarse → fine.
library;

enum DatePrecision { year, month, day }

class LabPerson {
  const LabPerson({required this.id, required this.name});

  final String id;
  final String name;
}

class LabPlace {
  const LabPlace({required this.id, required this.label});

  final String id;
  final String label;
}

class LabFamily {
  const LabFamily({
    required this.id,
    required this.name,
    this.parentFamilyId,
    this.branchYear,
    this.originStoryId,
  });

  final String id;
  final String name;
  final String? parentFamilyId;
  final int? branchYear;
  final String? originStoryId;

  bool get isBranch => parentFamilyId != null;

  LabFamily withOrigin(String? originStoryId) => LabFamily(
    id: id,
    name: name,
    parentFamilyId: parentFamilyId,
    branchYear: branchYear,
    originStoryId: originStoryId,
  );
}

class LabStory {
  const LabStory({
    required this.id,
    required this.familyId,
    required this.title,
    required this.body,
    required this.start,
    required this.precision,
    required this.createdAt,
    required this.placeId,
    required this.personIds,
    required this.photoCount,
  });

  final String id;
  final String familyId;
  final String title;
  final String body;

  /// UTC midnight.
  final DateTime start;
  final DatePrecision precision;
  final DateTime createdAt;
  final String? placeId;
  final List<String> personIds;
  final int photoCount;

  /// Last day covered by the story, derived from [precision].
  DateTime get end => switch (precision) {
    DatePrecision.year => DateTime.utc(start.year, 12, 31),
    DatePrecision.month => DateTime.utc(start.year, start.month + 1, 0),
    DatePrecision.day => start,
  };

  int get decade => start.year - start.year % 10;

  /// Year plus the fraction of the year elapsed at [start]; always < year+1.
  double get fractionalYear =>
      start.year + (dayOfYear(start) - 1) / daysInYear(start.year);
}

int dayOfYear(DateTime d) =>
    d.difference(DateTime.utc(d.year, 1, 1)).inDays + 1;

int daysInYear(int year) =>
    DateTime.utc(year + 1).difference(DateTime.utc(year)).inDays;

/// Canonical ascending order: start, precision, createdAt, id.
int compareLabStories(LabStory a, LabStory b) {
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  final byPrecision = a.precision.index.compareTo(b.precision.index);
  if (byPrecision != 0) return byPrecision;
  final byCreated = a.createdAt.compareTo(b.createdAt);
  if (byCreated != 0) return byCreated;
  return a.id.compareTo(b.id);
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class LabDataset {
  LabDataset({
    required List<LabStory> stories,
    required this.people,
    required this.places,
    required this.families,
  }) : stories = List.unmodifiable(
         <LabStory>[...stories]..sort(compareLabStories),
       ),
       minYear = stories.isEmpty
           ? 0
           : stories.map((s) => s.start.year).reduce((a, b) => a < b ? a : b),
       maxYear = stories.isEmpty
           ? 0
           : stories.map((s) => s.start.year).reduce((a, b) => a > b ? a : b);

  /// Sorted ascending by [compareLabStories].
  final List<LabStory> stories;
  final Map<String, LabPerson> people;
  final Map<String, LabPlace> places;
  final Map<String, LabFamily> families;
  final int minYear;
  final int maxYear;

  /// Shown exactly as entered: `1987`, `March 1987`, `March 4, 1987`.
  String dateLabel(LabStory s) {
    final y = s.start.year;
    final m = _monthNames[s.start.month - 1];
    return switch (s.precision) {
      DatePrecision.year => '$y',
      DatePrecision.month => '$m $y',
      DatePrecision.day => '$m ${s.start.day}, $y',
    };
  }

  String? placeLabel(LabStory s) =>
      s.placeId == null ? null : places[s.placeId]?.label;

  List<String> personNames(LabStory s) => [
    for (final id in s.personIds)
      if (people[id] != null) people[id]!.name,
  ];
}
