import 'dart:async';

import '../../data/families_api.dart';
import '../../data/stories_api.dart';
import 'all_stories_logic.dart';

class AllStoriesLoader {
  AllStoriesLoader({required this.stories, required this.families});

  final StoriesGateway stories;
  final FamiliesGateway families;

  /// Runs A1 + A2 in parallel, then A3 if needed (§7.4). Throws whatever a gateway throws.
  Future<AllStoriesData> load(String familyId) async {
    final List<Story> published;
    final List<TreeFamily> tree;
    try {
      (published, tree) = await (
        stories.listPublished(familyId),
        families.listFamilyTree(familyId),
      ).wait;
    } on ParallelWaitError<
      (List<Story>?, List<TreeFamily>?),
      (Object?, Object?)
    > catch (error, stack) {
      // .wait stores AsyncError, not the gateway error (§7.4 / L-03).
      final raw = error.errors.$1 ?? error.errors.$2;
      final cause = raw is AsyncError ? raw.error : raw;
      final trace = raw is AsyncError ? raw.stackTrace : stack;
      if (cause != null) Error.throwWithStackTrace(cause, trace);
      rethrow;
    }
    final self = treeFamilyById(tree, familyId);
    final storiesOut = [...published];
    final originId = self?.originStoryId;
    if (originId != null && !storiesOut.any((story) => story.id == originId)) {
      final origin = await stories.getPublishedOrigin(originId);
      if (origin != null) storiesOut.add(origin);
    }
    return AllStoriesData(familyId: familyId, stories: storiesOut, tree: tree);
  }
}
