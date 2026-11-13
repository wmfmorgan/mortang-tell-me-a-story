import 'dart:async';

import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

/// The whole tree as the tree views draw it.
class TreeTimelineData {
  const TreeTimelineData({required this.tree, required this.stories});

  /// Live families of the tree (`family.listTree`).
  final List<TreeFamily> tree;

  /// Published stories of every live family in the tree, in timeline order
  /// (`story.listPublishedInTree`).
  final List<Story> stories;
}

class TreeTimelineLoader {
  TreeTimelineLoader({required this.stories, required this.families});

  final StoriesGateway stories;
  final FamiliesGateway families;

  /// Both reads in parallel. Throws whatever a gateway throws.
  Future<TreeTimelineData> load(String familyId) async {
    try {
      final (tree, published) = await (
        families.listFamilyTree(familyId),
        stories.listPublishedInTree(familyId),
      ).wait;
      return TreeTimelineData(tree: tree, stories: published);
    } on ParallelWaitError<
      (List<TreeFamily>?, List<Story>?),
      (Object?, Object?)
    > catch (error) {
      // .wait stores AsyncError, not the gateway error (as AllStoriesLoader).
      switch (error.errors.$1 ?? error.errors.$2) {
        case AsyncError(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace);
        case final Object cause:
          throw cause;
        case null:
          rethrow;
      }
    }
  }
}
