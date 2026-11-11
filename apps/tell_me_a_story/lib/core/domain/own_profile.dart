import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:tell_me_a_story/core/domain/birth_visibility.dart';

part 'own_profile.freezed.dart';

/// The signed-in user's account. The email is the login identity and is
/// read-only (D1). [avatarPath] is the avatar's blob key.
@freezed
abstract class OwnProfile with _$OwnProfile {
  const factory OwnProfile({
    required String id,
    String? displayName,
    String? email,
    String? avatarPath,
    DateTime? birthDate,
    String? birthPrecision,
    @Default(BirthVisibility.hidden) BirthVisibility birthVisibility,
    String? about,
  }) = _OwnProfile;
}
