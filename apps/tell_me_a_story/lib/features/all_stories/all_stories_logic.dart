import '../../data/families_api.dart';
import '../../data/stories_api.dart';

enum AllStoriesGroupBy { date, member, place }

/// Composed result of A1–A3 for family [familyId].
class AllStoriesData {
  const AllStoriesData({
    required this.familyId,
    required this.stories,
    required this.tree,
  });

  final String familyId;
  final List<Story> stories;
  final List<TreeFamily> tree;
}

/// D1 marks for one story.
class SpawnMark {
  const SpawnMark({
    this.isOrigin = false,
    this.inheritedFromName,
    this.branches = const [],
  });

  final bool isOrigin;
  final String? inheritedFromName;
  final List<TreeFamily> branches;

  bool get startedTimeline => isOrigin || branches.isNotEmpty;
}

/// One rendered section.
class StoryGroup {
  const StoryGroup({
    required this.key,
    required this.heading,
    this.address,
    this.personUserId,
    required this.stories,
  });

  final String key;
  final String heading;
  final String? address;
  final String? personUserId;
  final List<Story> stories;
}

/// Session-only view state (UX Rule 4; SAD §1).
class AllStoriesViewState {
  const AllStoriesViewState({
    this.groupBy = AllStoriesGroupBy.date,
    this.query = '',
    this.startedTimelineOnly = false,
  });

  final AllStoriesGroupBy groupBy;
  final String query;
  final bool startedTimelineOnly;

  AllStoriesViewState copyWith({
    AllStoriesGroupBy? groupBy,
    String? query,
    bool? startedTimelineOnly,
  }) {
    return AllStoriesViewState(
      groupBy: groupBy ?? this.groupBy,
      query: query ?? this.query,
      startedTimelineOnly: startedTimelineOnly ?? this.startedTimelineOnly,
    );
  }
}

/// In-memory, per-family, app-lifetime holder. Never persisted.
abstract final class AllStoriesSession {
  static final Map<String, AllStoriesViewState> _byFamily = {};

  static AllStoriesViewState of(String familyId) =>
      _byFamily[familyId] ?? const AllStoriesViewState();

  static void save(String familyId, AllStoriesViewState state) =>
      _byFamily[familyId] = state;

  static void resetForTest() => _byFamily.clear();
}

int decadeOf(DateTime timeframeStart) => (timeframeStart.year ~/ 10) * 10;

/// timeframeStart desc (null last), then publishedAt desc (null last), then id asc.
int compareAllStories(Story a, Story b) {
  final start = _descNullLast(a.timeframeStart, b.timeframeStart);
  if (start != 0) return start;
  final published = _descNullLast(a.publishedAt, b.publishedAt);
  if (published != 0) return published;
  return a.id.compareTo(b.id);
}

int _descNullLast(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

/// Key: story id. Every story in [stories] gets an entry (default SpawnMark()).
Map<String, SpawnMark> spawnMarks({
  required String familyId,
  required List<TreeFamily> tree,
  required List<Story> stories,
}) {
  TreeFamily? self;
  for (final row in tree) {
    if (row.id == familyId) {
      self = row;
      break;
    }
  }
  final origin = self?.originStoryId;
  TreeFamily? parent;
  final parentId = self?.parentFamilyId;
  if (parentId != null) {
    for (final row in tree) {
      if (row.id == parentId) {
        parent = row;
        break;
      }
    }
  }
  final marks = <String, SpawnMark>{};
  for (final story in stories) {
    final isOrigin = origin != null && story.id == origin;
    final inherited = isOrigin && story.familyId != familyId
        ? parent?.name
        : null;
    final branches =
        [
          for (final row in tree)
            if (row.parentFamilyId == familyId && row.originStoryId == story.id)
              row,
        ]..sort((a, b) {
          final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (name != 0) return name;
          return a.id.compareTo(b.id);
        });
    marks[story.id] = SpawnMark(
      isOrigin: isOrigin,
      inheritedFromName: inherited,
      branches: branches,
    );
  }
  return marks;
}

/// Groups and sorts.
List<StoryGroup> groupStories(List<Story> stories, AllStoriesGroupBy by) {
  switch (by) {
    case AllStoriesGroupBy.date:
      return _groupByDate(stories);
    case AllStoriesGroupBy.member:
      return _groupByMember(stories);
    case AllStoriesGroupBy.place:
      return _groupByPlace(stories);
  }
}

List<StoryGroup> _groupByDate(List<Story> stories) {
  final buckets = <int, List<Story>>{};
  final undated = <Story>[];
  for (final story in stories) {
    final start = story.timeframeStart;
    if (start == null) {
      undated.add(story);
      continue;
    }
    buckets.putIfAbsent(decadeOf(start), () => []).add(story);
  }
  final decades = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  final groups = <StoryGroup>[
    for (final decade in decades)
      StoryGroup(
        key: '$decade',
        heading: '${decade}s',
        stories: [...buckets[decade]!]..sort(compareAllStories),
      ),
  ];
  if (undated.isNotEmpty) {
    undated.sort(compareAllStories);
    groups.add(
      StoryGroup(key: '__none__', heading: 'No date yet', stories: undated),
    );
  }
  return groups;
}

List<StoryGroup> _groupByMember(List<Story> stories) {
  final buckets = <String, _MemberBucket>{};
  final untagged = <Story>[];
  for (final story in stories) {
    if (story.people.isEmpty) {
      untagged.add(story);
      continue;
    }
    for (final person in story.people) {
      final bucket = buckets.putIfAbsent(
        person.id,
        () => _MemberBucket(person.name, story.personUserIds[person.id]),
      );
      bucket.userId ??= story.personUserIds[person.id];
      bucket.stories.add(story);
    }
  }
  final ids = buckets.keys.toList()
    ..sort((a, b) {
      final name = buckets[a]!.name.toLowerCase().compareTo(
        buckets[b]!.name.toLowerCase(),
      );
      if (name != 0) return name;
      return a.compareTo(b);
    });
  final groups = <StoryGroup>[
    for (final id in ids)
      StoryGroup(
        key: id,
        heading: buckets[id]!.name,
        personUserId: buckets[id]!.userId,
        stories: [...buckets[id]!.stories]..sort(compareAllStories),
      ),
  ];
  if (untagged.isNotEmpty) {
    untagged.sort(compareAllStories);
    groups.add(
      StoryGroup(key: '__none__', heading: 'No one tagged', stories: untagged),
    );
  }
  return groups;
}

List<StoryGroup> _groupByPlace(List<Story> stories) {
  final buckets = <String, _PlaceBucket>{};
  final unplaced = <Story>[];
  for (final story in stories) {
    final placeId = story.placeId;
    if (placeId == null || placeId.isEmpty) {
      unplaced.add(story);
      continue;
    }
    final heading = _placeHeading(story);
    final bucket = buckets.putIfAbsent(
      placeId,
      () => _PlaceBucket(heading, story.placeAddress),
    );
    if (bucket.heading.isEmpty && heading.isNotEmpty) {
      bucket.heading = heading;
    }
    bucket.address ??= story.placeAddress;
    bucket.stories.add(story);
  }
  final ids = buckets.keys.toList()
    ..sort((a, b) {
      final label = buckets[a]!.heading.toLowerCase().compareTo(
        buckets[b]!.heading.toLowerCase(),
      );
      if (label != 0) return label;
      return a.compareTo(b);
    });
  final groups = <StoryGroup>[
    for (final id in ids)
      StoryGroup(
        key: id,
        heading: buckets[id]!.heading,
        address: buckets[id]!.address,
        stories: [...buckets[id]!.stories]..sort(compareAllStories),
      ),
  ];
  if (unplaced.isNotEmpty) {
    unplaced.sort(compareAllStories);
    groups.add(
      StoryGroup(key: '__none__', heading: 'No place yet', stories: unplaced),
    );
  }
  return groups;
}

String _placeHeading(Story story) {
  final label = story.placeLabel?.trim();
  if (label != null && label.isNotEmpty) return label;
  final address = story.placeAddress?.trim();
  if (address != null && address.isNotEmpty) return address;
  return '';
}

class _MemberBucket {
  _MemberBucket(this.name, this.userId);

  final String name;
  String? userId;
  final List<Story> stories = [];
}

class _PlaceBucket {
  _PlaceBucket(this.heading, this.address);

  String heading;
  String? address;
  final List<Story> stories = [];
}

/// Case-insensitive substring match of trimmed [query] on title, body, personNames.
/// Empty trimmed query => true. Never matches place label/address or decade.
bool matchesSearch(Story story, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  if (_contains(story.title, needle) || _contains(story.body, needle)) {
    return true;
  }
  for (final name in story.personNames) {
    if (_contains(name, needle)) return true;
  }
  return false;
}

bool _contains(String? value, String needle) {
  if (value == null) return false;
  return value.toLowerCase().contains(needle);
}

/// Undimmed iff (query empty OR matchesSearch) AND (!startedTimelineOnly OR mark.startedTimeline).
bool isUndimmed(Story story, AllStoriesViewState view, SpawnMark mark) {
  final query = view.query.trim();
  final searchOk = query.isEmpty || matchesSearch(story, query);
  final spawnOk = !view.startedTimelineOnly || mark.startedTimeline;
  return searchOk && spawnOk;
}

/// Null when query is empty and toggle is off. Otherwise one of the three stamped strings.
String? statusLine({
  required int n,
  required int total,
  required String query,
  required bool startedTimelineOnly,
}) {
  final needle = query.trim();
  final searching = needle.isNotEmpty;
  if (!searching && !startedTimelineOnly) return null;
  if (searching && startedTimelineOnly) {
    return '$n of $total stories match "$needle" and started a timeline';
  }
  if (searching) return '$n of $total stories match "$needle"';
  return '$n of $total stories started a timeline';
}

/// O-04 interim. Singular is not a stamped string.
String groupCountLabel(int n) => n == 1 ? '1 story' : '$n stories';
