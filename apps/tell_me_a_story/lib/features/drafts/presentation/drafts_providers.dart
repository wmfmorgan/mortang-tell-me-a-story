import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/session/family_membership.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';

part 'drafts_providers.g.dart';

/// The signed-in author's drafts in [familyId] (null: no family yet).
@immutable
class MyDrafts {
  const MyDrafts({required this.familyId, required this.drafts});

  final String? familyId;
  final List<Story> drafts;

  @override
  bool operator ==(Object other) =>
      other is MyDrafts &&
      other.familyId == familyId &&
      listEquals(other.drafts, drafts);

  @override
  int get hashCode => Object.hash(familyId, Object.hashAll(drafts));
}

/// Drafts for the remembered family, or the invite-resolved current family.
///
/// Remembers the resolved family. Reads (not watches) the selection: the page
/// invalidates this after switching family.
@riverpod
Future<MyDrafts> myDrafts(Ref ref) async {
  final familyId =
      ref.read(familySelectionProvider) ??
      await ref.read(inviteRepositoryProvider).currentFamilyId();
  if (familyId == null) return const MyDrafts(familyId: null, drafts: []);
  final drafts = await ref
      .read(storiesRepositoryProvider)
      .listMyDrafts(familyId);
  ref.read(familySelectionProvider.notifier).remember(familyId);
  return MyDrafts(familyId: familyId, drafts: drafts);
}

/// Families for the drafts header (member + stewarded).
@immutable
class DraftsFamilies {
  const DraftsFamilies({required this.member, required this.stewarded});

  final List<MemberFamily> member;
  final List<StewardFamily> stewarded;

  @override
  bool operator ==(Object other) =>
      other is DraftsFamilies &&
      listEquals(other.member, member) &&
      listEquals(other.stewarded, stewarded);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(member), Object.hashAll(stewarded));
}

/// Loads the header families and remembers the member ids.
@riverpod
Future<DraftsFamilies> draftsFamilies(Ref ref) async {
  final families = ref.read(familiesRepositoryProvider);
  final member = await families.listMine();
  final stewarded = await families.listStewarded();
  ref
      .read(familyMembershipProvider.notifier)
      .remember(member.map((row) => row.id));
  return DraftsFamilies(member: member, stewarded: stewarded);
}
