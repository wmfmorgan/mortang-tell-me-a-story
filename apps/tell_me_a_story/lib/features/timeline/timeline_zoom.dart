import '../../data/families_api.dart';
import '../../data/stories_api.dart';

enum TimelineZoom { far, mid, near }

class DecadeBand {
  const DecadeBand({required this.startYear, required this.stories});

  final int startYear;
  final List<Story> stories;

  String get label => '${startYear}s';
}

int decadeStartYear(DateTime date) => (date.year ~/ 10) * 10;

List<Story> publishedStories(Iterable<Story> stories) {
  return stories
      .where((story) => story.status == StoryStatus.published)
      .toList();
}

/// Newest decade first. Stories inside a decade are newest first.
List<DecadeBand> decadeBands(Iterable<Story> stories) {
  final grouped = <int, List<Story>>{};
  for (final story in publishedStories(stories)) {
    final start = decadeStartYear(story.timeframeStart);
    (grouped[start] ??= []).add(story);
  }
  final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final year in years)
      DecadeBand(
        startYear: year,
        stories: [...grouped[year]!]
          ..sort((a, b) => b.timeframeStart.compareTo(a.timeframeStart)),
      ),
  ];
}

/// Oldest story first, for the mid rail.
List<Story> decadeOldestFirst(Iterable<Story> stories, int startYear) {
  final rows = publishedStories(stories)
      .where((story) => decadeStartYear(story.timeframeStart) == startYear)
      .toList();
  rows.sort((a, b) => a.timeframeStart.compareTo(b.timeframeStart));
  return rows;
}

/// Newest story first, for the near rail.
List<Story> decadeNewestFirst(Iterable<Story> stories, int startYear) {
  return decadeOldestFirst(stories, startYear).reversed.toList();
}

String storyTitle(Story story) {
  final title = story.title?.trim() ?? '';
  return title.isEmpty ? 'Untitled' : title;
}

String dotTooltip(Story story) =>
    '${storyTitle(story)} (${story.timeframeStart.year})';

String excerpt(String? body, {int max = 180}) {
  final flat = (body ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= max) return flat;
  return '${flat.substring(0, max - 1)}…';
}

String countWord(int count, String singular, String plural) {
  return '$count ${count == 1 ? singular : plural}';
}

String farFooter({required String familyName}) =>
    '$familyName Archive · heirloom stories preserved across the decades';

/// Every published story, newest year first. Mid scrolls this whole list.
List<Story> dialStories(Iterable<Story> stories) {
  final rows = publishedStories(stories).toList();
  rows.sort((a, b) => b.timeframeStart.compareTo(a.timeframeStart));
  return rows;
}

/// Share of the viewport, at the top and at the bottom, where a decade
/// starts to dim while it is still on screen.
const farFadeBand = 0.45;

/// 1 while the row's center is in the middle of the rail. Dims as that
/// center enters the top or bottom band, and returns to 1 when it moves back.
double farEdgeOpacity({
  required double rowTop,
  required double rowHeight,
  required double viewportTop,
  required double viewportHeight,
}) {
  if (rowHeight <= 0 || viewportHeight <= 0) return 1;
  final band = viewportHeight * farFadeBand;
  if (band <= 0) return 1;
  final rowCenter = rowTop + rowHeight / 2;
  final fromTop = rowCenter - viewportTop;
  final fromBottom = viewportTop + viewportHeight - rowCenter;
  final nearest = fromTop < fromBottom ? fromTop : fromBottom;
  if (nearest >= band) return 1;
  if (nearest <= 0) return 0;
  return nearest / band;
}

/// Full-card fade. Same band as [farEdgeOpacity]: sharp in the middle 10%,
/// dimming through the top and bottom 45%.
double fullCardOpacity({
  required double rowTop,
  required double rowHeight,
  required double viewportTop,
  required double viewportHeight,
}) {
  return farEdgeOpacity(
    rowTop: rowTop,
    rowHeight: rowHeight,
    viewportTop: viewportTop,
    viewportHeight: viewportHeight,
  );
}

/// Fade from 1 at the dial center to 0.10 at the edge of the viewport.
double dialOpacity({required double distance, required double halfExtent}) {
  if (halfExtent <= 0) return 1;
  final t = (distance / halfExtent).clamp(0.0, 1.0);
  return (1 - (t * 0.9)).clamp(0.10, 1.0);
}

String dialFocusLabel(int year) => '$year · IN FOCUS';

TimelineZoom zoomIn(TimelineZoom zoom) {
  return switch (zoom) {
    TimelineZoom.far => TimelineZoom.mid,
    TimelineZoom.mid => TimelineZoom.near,
    TimelineZoom.near => TimelineZoom.near,
  };
}

TimelineZoom zoomOut(TimelineZoom zoom) {
  return switch (zoom) {
    TimelineZoom.near => TimelineZoom.mid,
    TimelineZoom.mid => TimelineZoom.far,
    TimelineZoom.far => TimelineZoom.far,
  };
}

/// Child family when the member can see one, otherwise the parent.
MemberFamily? branchFamily(List<MemberFamily> families, String currentId) {
  for (final family in families) {
    if (family.parentFamilyId == currentId) return family;
  }
  final current = families.cast<MemberFamily?>().firstWhere(
    (family) => family?.id == currentId,
    orElse: () => null,
  );
  final parentId = current?.parentFamilyId;
  if (parentId == null) return null;
  for (final family in families) {
    if (family.id == parentId) return family;
  }
  return null;
}

/// Every tree row except the open family. Null years come first, then year,
/// then id.
List<TreeFamily> relatedMarks(List<TreeFamily> tree, String currentId) {
  final rows = [
    for (final row in tree)
      if (row.id != currentId) row,
  ];
  rows.sort((a, b) {
    final years = _nullsFirst(a.branchYear, b.branchYear);
    if (years != 0) return years;
    return a.id.compareTo(b.id);
  });
  return rows;
}

int _nullsFirst(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

String branchMarkLabel(TreeFamily family) {
  final year = family.branchYear;
  if (year == null) return family.name;
  return '${family.name} · $year';
}

/// Decade start for a branch year. Null years are not placed on a decade.
int? branchDecadeStart(int? branchYear) {
  if (branchYear == null) return null;
  return branchYear - (branchYear % 10);
}

List<TreeFamily> marksOnDecade(List<TreeFamily> marks, int startYear) {
  return [
    for (final mark in marks)
      if (branchDecadeStart(mark.branchYear) == startYear) mark,
  ];
}

/// Index of the newest-first story closest to [year]. An equal distance
/// keeps the newer story, which is the earlier row in [newestFirst].
int closestNewerStoryIndex(List<Story> newestFirst, int year) {
  if (newestFirst.isEmpty) return 0;
  var best = 0;
  var bestDelta = (newestFirst.first.timeframeStart.year - year).abs();
  for (var i = 1; i < newestFirst.length; i++) {
    final delta = (newestFirst[i].timeframeStart.year - year).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = i;
    }
  }
  return best;
}

/// Where a dated mark sits in a newest-first card list. The mark is after
/// every card newer than [branchYear] and before the first card at or before
/// that year. A year past both ends sits at that end.
int fullCardMarkIndex(List<Story> newestFirst, int branchYear) {
  for (var i = 0; i < newestFirst.length; i++) {
    if (newestFirst[i].timeframeStart.year <= branchYear) return i;
  }
  return newestFirst.length;
}

MemberFamily? childFamily(List<MemberFamily> families, String currentId) {
  for (final family in families) {
    if (family.parentFamilyId == currentId) return family;
  }
  return null;
}

int closestStoryIndex(List<Story> oldestFirst, DateTime createdAt) {
  if (oldestFirst.isEmpty) return 0;
  var best = 0;
  var bestDelta = 1 << 30;
  for (var i = 0; i < oldestFirst.length; i++) {
    final delta = (oldestFirst[i].timeframeStart.year - createdAt.year).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = i;
    }
  }
  return best;
}
