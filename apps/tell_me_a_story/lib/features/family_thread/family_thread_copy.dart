import '../../data/family_thread_density.dart';

abstract final class FamilyThreadCopy {
  static const screenTitle = 'Family Thread';
  static const loadError = "Couldn't load stories.";
  static const retry = 'Retry';
  static const loadingStories = 'Loading stories';
  static const emptyFamily =
      'No stories yet. Capture the first one for this family.';
  static const fallbackFamily = 'Family';
  static const densityGroup = 'Density';
  static const overview = 'Overview';
  static const browse = 'Browse';
  static const read = 'Read';

  static String threadList(int storyCount) =>
      'Family Thread, ${_stories(storyCount)}';

  static String stopName(FamilyThreadDensity density) {
    return switch (density) {
      FamilyThreadDensity.overview => overview,
      FamilyThreadDensity.browse => browse,
      FamilyThreadDensity.read => read,
    };
  }

  static String showingDensity(FamilyThreadDensity density) =>
      'Showing ${stopName(density)}';

  static String decadeLabel(int decade, int count) =>
      '${decade}s · ${_stories(count)}';

  static String decadeBeat(int decade, int count) =>
      '${decade}s, ${_stories(count)}';

  static String focusedStory(int year, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Focused $year';
    return 'Focused $year, $trimmed';
  }

  static String focusedDecade(int decadeStart, int count) =>
      'Focused ${decadeStart}s, ${_stories(count)}';

  static const openStory = 'Open story';

  static String moreInYear(int count, int year) => '$count more in $year';

  static String overviewCaption(String familyName) =>
      '$familyName · stories carried down the years';

  static const filters = 'Filters';
  static const clearFilters = 'Clear filters';

  static String filtersButton(int activeCount) {
    if (activeCount == 0) return filters;
    return '$filters · $activeCount';
  }

  static String filterCount(int matched, int total) {
    final noun = total == 1 ? 'story' : 'stories';
    return '$matched of $total $noun';
  }

  static String decadeRange(int from, int to) => '${from}s – ${to}s';

  static String removeFilter(String value) => 'Remove filter: $value';

  static String _stories(int count) =>
      count == 1 ? '1 story' : '$count stories';
}
