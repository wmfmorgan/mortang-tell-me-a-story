import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/birth_visibility.dart';
import 'package:tell_me_a_story/core/domain/own_profile.dart';

part 'profile_repository.g.dart';

abstract class ProfileRepository {
  Future<OwnProfile?> loadOwn();

  /// Writes the display name only.
  Future<void> saveName(String displayName);

  /// One Save: display name, birth, and about. Does not write email or people.
  Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    String? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  });

  /// Stores [bytes] as the account avatar; returns its blob key.
  Future<String> saveAvatar(Uint8List bytes);

  /// Clears the account avatar.
  Future<void> clearAvatar();

  Future<Uint8List?> downloadAvatar(String path);
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
