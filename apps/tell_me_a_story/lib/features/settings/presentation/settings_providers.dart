import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/own_profile.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';

part 'settings_providers.g.dart';

/// The signed-in account and its stored avatar bytes.
typedef SettingsProfile = ({OwnProfile? profile, Uint8List? avatar});

@riverpod
Future<SettingsProfile> settingsProfile(Ref ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final profile = await repository.loadOwn();
  final path = profile?.avatarPath;
  final avatar = path == null ? null : await repository.downloadAvatar(path);
  return (profile: profile, avatar: avatar);
}

/// The family the header shows and the families the user can switch to.
typedef SettingsFamilies = ({
  String? currentFamilyId,
  List<MemberFamily> families,
  List<StewardFamily> stewarded,
});

@riverpod
Future<SettingsFamilies> settingsFamilies(Ref ref) async {
  final familyId = await ref.watch(inviteRepositoryProvider).currentFamilyId();
  final families = ref.watch(familiesRepositoryProvider);
  final rows = await families.listMine();
  final stewarded = await families.listStewarded();
  return (currentFamilyId: familyId, families: rows, stewarded: stewarded);
}
