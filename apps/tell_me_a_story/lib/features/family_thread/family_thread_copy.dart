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

  static String overviewCaption(String familyName) =>
      '$familyName · stories carried down the years';

  static String _stories(int count) =>
      count == 1 ? '1 story' : '$count stories';
}
