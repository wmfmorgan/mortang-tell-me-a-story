import 'dart:typed_data';

import 'package:tell_me_a_story/core/domain/birth_visibility.dart';
import 'package:tell_me_a_story/core/domain/own_profile.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';

typedef SavedAccount = ({
  String displayName,
  DateTime? birthDate,
  String? birthPrecision,
  BirthVisibility? birthVisibility,
  String? about,
});

/// In-memory [ProfileRepository]: [loadOwn] returns [own] (null by default),
/// [downloadAvatar] returns null, writes are recorded.
class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository({this.own});

  OwnProfile? own;
  final List<String> savedNames = [];
  final List<SavedAccount> savedAccounts = [];
  final List<Uint8List> savedAvatars = [];
  final List<String> downloadedPaths = [];
  int clearAvatarCalls = 0;

  @override
  Future<OwnProfile?> loadOwn() async => own;

  @override
  Future<void> saveName(String displayName) async {
    savedNames.add(displayName);
  }

  @override
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) async {
    savedAccounts.add((
      displayName: displayName,
      birthDate: birthDate,
      birthPrecision: birthPrecision,
      birthVisibility: birthVisibility,
      about: about,
    ));
  }

  @override
  Future<String> saveAvatar(Uint8List bytes) async {
    savedAvatars.add(bytes);
    return 'users/fake-avatar-${savedAvatars.length}.jpg';
  }

  @override
  Future<void> clearAvatar() async {
    clearAvatarCalls++;
  }

  @override
  Future<Uint8List?> downloadAvatar(String path) async {
    downloadedPaths.add(path);
    return null;
  }
}
