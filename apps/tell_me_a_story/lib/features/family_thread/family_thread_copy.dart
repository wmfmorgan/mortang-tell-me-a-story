abstract final class FamilyThreadCopy {
  static const screenTitle = 'Family Thread';
  static const loadError = "Couldn't load stories.";
  static const retry = 'Retry';
  static const loadingStories = 'Loading stories';
  static const emptyFamily =
      'No stories yet. Capture the first one for this family.';
  static const fallbackFamily = 'Family';

  static String threadList(int storyCount) =>
      'Family Thread, $storyCount stories';
}
