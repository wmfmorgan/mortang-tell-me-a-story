import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_detail.dart';
import 'package:tell_me_a_story/core/domain/family_directory.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';

part 'manage_families_providers.freezed.dart';
part 'manage_families_providers.g.dart';

/// Everything the Manage families hub renders.
@freezed
abstract class ManageFamiliesHub with _$ManageFamiliesHub {
  const factory ManageFamiliesHub({
    required FamilyDirectory directory,
    required List<MemberFamily> families,
    required List<StewardFamily> stewarded,
    String? sessionFamilyId,
  }) = _ManageFamiliesHub;
}

/// Everything one Manage family detail page renders. [detail] is null when
/// the family is not readable.
@freezed
abstract class ManageFamilyView with _$ManageFamilyView {
  const factory ManageFamilyView({
    required FamilyDetail? detail,
    required List<MemberFamily> families,
    required List<StewardFamily> stewarded,
    String? sessionFamilyId,
  }) = _ManageFamilyView;
}

@riverpod
Future<ManageFamiliesHub> manageFamiliesHub(Ref ref) async {
  final directory = await ref
      .watch(familyDirectoryRepositoryProvider)
      .listDirectory();
  final families = ref.watch(familiesRepositoryProvider);
  final mine = await families.listMine();
  final stewarded = await families.listStewarded();
  final session = await ref.watch(inviteRepositoryProvider).currentFamilyId();
  return ManageFamiliesHub(
    directory: directory,
    families: mine,
    stewarded: stewarded,
    sessionFamilyId: session,
  );
}

@riverpod
Future<ManageFamilyView> manageFamilyView(Ref ref, String familyId) async {
  final detail = await ref
      .watch(familyDirectoryRepositoryProvider)
      .loadDetail(familyId);
  final families = ref.watch(familiesRepositoryProvider);
  final mine = await families.listMine();
  final stewarded = await families.listStewarded();
  final session = await ref.watch(inviteRepositoryProvider).currentFamilyId();
  return ManageFamilyView(
    detail: detail,
    families: mine,
    stewarded: stewarded,
    sessionFamilyId: session,
  );
}
