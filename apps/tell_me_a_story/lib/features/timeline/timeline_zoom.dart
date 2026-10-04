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

String farSubtitle(int decades) =>
    'Macro overview spanning ${countWord(decades, 'decade', 'decades')} of heirloom memories';

String farFooter({
  required String familyName,
  required int stories,
  required int decades,
}) {
  return '$familyName Archive · ${countWord(stories, 'heirloom story', 'heirloom stories')} preserved across ${countWord(decades, 'decade', 'decades')}';
}

String midHeading(int decadeStart) => 'Mid-${decadeStart}s';

String nearHeading(Iterable<Story> stories) {
  final years = stories.map((story) => story.timeframeStart.year).toList();
  if (years.isEmpty) return 'Generational Chapters';
  final first = years.reduce((a, b) => a < b ? a : b);
  final last = years.reduce((a, b) => a > b ? a : b);
  if (first == last) return 'Generational Chapters ($first)';
  return 'Generational Chapters ($first–$last)';
}

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
