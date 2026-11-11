import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/tree_timeline_loader.dart';

part 'family_tree_providers.g.dart';

/// Everything the family tree page draws: the tree and its stories, plus the
/// header's membership read.
class FamilyTreeContent {
  const FamilyTreeContent({
    required this.data,
    required this.families,
    required this.stewarded,
    required this.canWrite,
  });

  final TreeTimelineData data;
  final List<MemberFamily> families;
  final List<StewardFamily> stewarded;
  final bool canWrite;
}

typedef _Chrome = ({
  List<MemberFamily> families,
  List<StewardFamily> stewarded,
  bool canWrite,
});

/// The tree of [familyId] and the header's families, read in parallel.
/// Throws whatever the tree reads throw; the header read is best effort.
@riverpod
Future<FamilyTreeContent> familyTree(Ref ref, String familyId) async {
  final families = ref.watch(familiesRepositoryProvider);
  final loader = TreeTimelineLoader(
    stories: ref.watch(storiesRepositoryProvider),
    families: families,
  );
  final dataFuture = loader.load(familyId);
  final chromeFuture = _loadChrome(ref, families, familyId);
  final data = await dataFuture;
  final chrome = await chromeFuture;
  return FamilyTreeContent(
    data: data,
    families: chrome.families,
    stewarded: chrome.stewarded,
    canWrite: chrome.canWrite,
  );
}

/// The header's membership read, best effort as on All Stories: a menu
/// failure must not replace a loaded treemap with the error line.
Future<_Chrome> _loadChrome(
  Ref ref,
  FamiliesRepository families,
  String familyId,
) async {
  try {
    final mine = await families.listMine();
    final stewarded = await families.listStewarded();
    if (ref.mounted) {
      ref
          .read(familyMembershipProvider.notifier)
          .remember(mine.map((row) => row.id));
    }
    return (
      families: mine,
      stewarded: stewarded,
      canWrite: mine.any((row) => row.id == familyId),
    );
  } on AppException {
    return (
      families: const <MemberFamily>[],
      stewarded: const <StewardFamily>[],
      canWrite: false,
    );
  }
}
