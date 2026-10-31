import '../../data/families_api.dart';
import '../../data/stories_api.dart';
import 'all_stories_logic.dart';

class AllStoriesLoader {
  AllStoriesLoader({required this.stories, required this.families});

  final StoriesGateway stories;
  final FamiliesGateway families;

  /// Runs A1 + A2 in parallel, then A3 if needed (§7.4). Throws whatever a gateway throws.
  Future<AllStoriesData> load(String familyId) async {
    final results = await Future.wait<Object>([
      stories.listPublished(familyId),
      families.listFamilyTree(familyId),
    ]);
    final published = results[0] as List<Story>;
    final tree = results[1] as List<TreeFamily>;
    TreeFamily? self;
    for (final row in tree) {
      if (row.id == familyId) {
        self = row;
        break;
      }
    }
    final merged = [...published];
    final originId = self?.originStoryId;
    if (originId != null && !merged.any((story) => story.id == originId)) {
      final origin = await stories.getPublishedOrigin(originId);
      if (origin != null) merged.add(origin);
    }
    final seen = <String>{};
    final unique = <Story>[];
    for (final story in merged) {
      if (seen.add(story.id)) unique.add(story);
    }
    return AllStoriesData(familyId: familyId, stories: unique, tree: tree);
  }
}
