import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/features/timeline/presentation/timeline_zoom.dart';

part 'timeline_providers.g.dart';

/// The signed-in user's families: member rows and stewarded rows.
typedef TimelineMembership = ({
  List<MemberFamily> rows,
  List<StewardFamily> stewarded,
});

/// A failed read shows its empty state at once, like before providers; the
/// next reload or live change reads again.
Duration? _noRetry(int retryCount, Object error) => null;

@Riverpod(retry: _noRetry)
Future<TimelineMembership> timelineMembership(Ref ref) async {
  final families = ref.watch(familiesRepositoryProvider);
  final rows = await families.listMine();
  final stewarded = await families.listStewarded();
  return (rows: rows, stewarded: stewarded);
}

/// Live families in [familyId]'s tree.
@Riverpod(retry: _noRetry)
Future<List<TreeFamily>> timelineTree(Ref ref, String familyId) =>
    ref.watch(familiesRepositoryProvider).listFamilyTree(familyId);

/// Published stories of [familyId], plus its origin story from the parent
/// family when the tree names one.
@Riverpod(retry: _noRetry)
Future<List<Story>> timelinePublished(Ref ref, String familyId) async {
  final stories = ref.watch(storiesRepositoryProvider);
  // Read, not watched: the tree arriving must not list the stories again.
  // The page keeps the tree provider alive and refreshes both together.
  final treeRead = await AsyncValue.guard(
    () => ref.read(timelineTreeProvider(familyId).future),
  );
  final rows = await stories.listPublished(familyId);
  final merged = <Story>[...publishedStories(rows)];
  String? originId;
  for (final row in treeRead.value ?? const <TreeFamily>[]) {
    if (row.id == familyId) originId = row.originStoryId;
  }
  if (originId != null && !merged.any((story) => story.id == originId)) {
    final origin = await stories.getPublished(originId);
    if (origin != null && origin.status == StoryStatus.published) {
      merged.add(origin);
    }
  }
  return publishedStories(merged);
}

/// Membership id from [InviteRepository.currentFamilyId], unless the saved
/// family [remembered] is tree-readable (`list_family_tree` filters with
/// `is_family_tree_readable`).
Future<String?> readableSavedFamily({
  required InviteRepository invites,
  required FamiliesRepository families,
  required String? remembered,
}) async {
  final fallback = await invites.currentFamilyId();
  if (remembered == null || remembered == fallback) return fallback;
  try {
    final tree = await families.listFamilyTree(remembered);
    for (final row in tree) {
      if (row.id == remembered) return remembered;
    }
  } on Exception {
    // A tree read that throws cannot confirm the saved family. D9 falls back.
    return fallback;
  }
  return fallback;
}
