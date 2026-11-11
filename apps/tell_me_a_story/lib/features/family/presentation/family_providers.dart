import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_covers_repository.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';

part 'family_providers.g.dart';

/// Wall clock used by the landing page when no test clock is given.
DateTime utcNow() => DateTime.now().toUtc();

/// Everything the family landing page renders.
@immutable
class FamilyLandingData {
  const FamilyLandingData({
    required this.families,
    required this.stewarded,
    required this.tree,
    required this.memberIds,
    required this.familyId,
    required this.latest,
    required this.thumbs,
    required this.coverBytes,
  });

  final List<MemberFamily> families;
  final List<StewardFamily> stewarded;
  final List<TreeFamily> tree;
  final Set<String> memberIds;
  final String? familyId;
  final List<Story> latest;
  final Map<String, Uint8List> thumbs;
  final Uint8List? coverBytes;

  MemberFamily? get family {
    for (final row in families) {
      if (row.id == familyId) return row;
    }
    return null;
  }
}

/// Landing data for the selected family. Picks the first family and
/// remembers it when the selection is missing or no longer a membership.
/// [clock] must be stable (a tear-off or a field), since it keys the family.
@riverpod
Future<FamilyLandingData> familyLanding(
  Ref ref, {
  DateTime Function() clock = utcNow,
}) async {
  final (rows, stewarded) = await _loadFamilies(ref);
  final memberIds = rows.map((row) => row.id).toSet();
  var familyId = ref.read(familySelectionProvider);
  if (rows.isNotEmpty &&
      (familyId == null || !rows.any((family) => family.id == familyId))) {
    familyId = rows.first.id;
    ref.read(familySelectionProvider.notifier).remember(familyId);
  }
  final tree = familyId == null
      ? const <TreeFamily>[]
      : await _loadTree(ref, familyId);
  final latest = familyId == null
      ? const <Story>[]
      : await _loadLatest(ref, familyId, clock());
  String? coverPath;
  for (final row in rows) {
    if (row.id == familyId) coverPath = row.coverPhotoPath;
  }
  final cover = await _downloadCover(ref, coverPath);
  final thumbs = await ref.read(storyThumbsLoaderProvider)(latest);
  return FamilyLandingData(
    families: rows,
    stewarded: stewarded,
    tree: tree,
    memberIds: memberIds,
    familyId: familyId,
    latest: latest,
    thumbs: thumbs,
    coverBytes: cover,
  );
}

/// Remembers the membership on success. A failed family list renders as no
/// families (the empty landing).
Future<(List<MemberFamily>, List<StewardFamily>)> _loadFamilies(Ref ref) async {
  final repository = ref.read(familiesRepositoryProvider);
  try {
    final rows = await repository.listMine();
    final stewarded = await repository.listStewarded();
    ref
        .read(familyMembershipProvider.notifier)
        .remember(rows.map((row) => row.id));
    return (rows, stewarded);
  } on AppException catch (error, stack) {
    _report(error, stack, 'loading families');
    return (const <MemberFamily>[], const <StewardFamily>[]);
  }
}

/// A failed tree read leaves the related-families menu empty.
Future<List<TreeFamily>> _loadTree(Ref ref, String familyId) async {
  try {
    return await ref.read(familiesRepositoryProvider).listFamilyTree(familyId);
  } on AppException catch (error, stack) {
    _report(error, stack, 'loading the family tree');
    return const [];
  }
}

/// A failed latest read shows the empty Latest shelf.
Future<List<Story>> _loadLatest(Ref ref, String familyId, DateTime now) async {
  try {
    final rows = await ref
        .read(storiesRepositoryProvider)
        .listLatestPublished(familyId, now: now);
    return latestShelf(rows, now: now);
  } on AppException catch (error, stack) {
    _report(error, stack, 'loading the latest stories');
    return const [];
  }
}

/// A cover that fails to load shows the monogram placeholder.
Future<Uint8List?> _downloadCover(Ref ref, String? path) async {
  if (path == null) return null;
  try {
    return await ref.read(familyCoversRepositoryProvider).download(path);
  } on AppException catch (error, stack) {
    _report(error, stack, 'loading the family cover');
    return null;
  }
}

void _report(AppException error, StackTrace stack, String context) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'family landing',
      context: ErrorDescription(context),
    ),
  );
}

/// Members and people of the parent family for the branch form.
@immutable
class StartTimelineRoster {
  const StartTimelineRoster({required this.members, required this.people});

  final List<FamilyPerson> members;
  final List<Person> people;
}

@riverpod
Future<StartTimelineRoster> startTimelineRoster(
  Ref ref,
  String parentId,
) async {
  final members = await ref
      .read(familiesRepositoryProvider)
      .listMembers(parentId);
  final people = await ref.read(peopleRepositoryProvider).listPeople(parentId);
  return StartTimelineRoster(members: members, people: people);
}
