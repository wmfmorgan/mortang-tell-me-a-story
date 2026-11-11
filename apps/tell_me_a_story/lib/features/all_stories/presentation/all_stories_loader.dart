import 'dart:async';
// riverpod_annotation exports its own AsyncError; .wait stores dart's.
import 'dart:async' as dart_async show AsyncError;
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_logic.dart';

part 'all_stories_loader.g.dart';

/// Failed loads stay failed until the user taps Retry (no automatic retry).
Duration? _noRetry(int retryCount, Object error) => null;

/// Runs A1 + A2 in parallel, then A3 if needed (§7.4). Throws whatever a
/// repository throws.
@Riverpod(retry: _noRetry)
Future<AllStoriesData> allStoriesData(Ref ref, String familyId) {
  return _loadData(
    ref.read(storiesRepositoryProvider),
    ref.read(familiesRepositoryProvider),
    familyId,
  );
}

Future<AllStoriesData> _loadData(
  StoriesRepository stories,
  FamiliesRepository families,
  String familyId,
) async {
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
  > catch (error) {
    // .wait stores AsyncError, not the repository error (§7.4 / L-03).
    switch (error.errors.$1 ?? error.errors.$2) {
      case dart_async.AsyncError(:final error, :final stackTrace):
        Error.throwWithStackTrace(error, stackTrace);
      case final Object cause:
        throw cause;
      case null:
        rethrow;
    }
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

/// Header membership for the All Stories page.
typedef AllStoriesChrome = ({
  List<MemberFamily> families,
  List<StewardFamily> stewarded,
  bool canWrite,
});

/// Everything one All Stories load shows.
typedef AllStoriesPageData = ({
  AllStoriesData data,
  Map<String, Uint8List> thumbs,
  AllStoriesChrome chrome,
});

/// Stories, thumbs and header membership. Only a story failure fails the
/// load; the header read is best-effort (same as Landing).
@Riverpod(retry: _noRetry)
Future<AllStoriesPageData> allStoriesPage(Ref ref, String familyId) async {
  final loadThumbs = ref.read(storyThumbsLoaderProvider);
  final dataFuture = _loadData(
    ref.read(storiesRepositoryProvider),
    ref.read(familiesRepositoryProvider),
    familyId,
  );
  final chromeFuture = _loadChrome(ref, familyId);
  final data = await dataFuture;
  final chrome = await chromeFuture;
  final thumbs = await loadThumbs(data.stories);
  return (data: data, thumbs: thumbs, chrome: chrome);
}

Future<AllStoriesChrome> _loadChrome(Ref ref, String familyId) async {
  final families = ref.read(familiesRepositoryProvider);
  final membership = ref.read(familyMembershipProvider.notifier);
  try {
    final mine = await families.listMine();
    final stewarded = await families.listStewarded();
    if (ref.mounted) membership.remember(mine.map((row) => row.id));
    return (
      families: mine,
      stewarded: stewarded,
      canWrite: mine.any((row) => row.id == familyId),
    );
  } catch (_) {
    // Boundary: a menu failure must not replace a loaded story list with
    // the story error line; the header shows no families instead.
    return (
      families: const <MemberFamily>[],
      stewarded: const <StewardFamily>[],
      canWrite: false,
    );
  }
}

/// In-memory, per-family, app-lifetime view state. Never persisted.
@Riverpod(keepAlive: true)
class AllStoriesView extends _$AllStoriesView {
  @override
  AllStoriesViewState build(String familyId) => const AllStoriesViewState();

  void save(AllStoriesViewState next) => state = next;
}
