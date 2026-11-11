import 'package:freezed_annotation/freezed_annotation.dart';

part 'person_profile.freezed.dart';

/// What the profile dialog shows. Never includes userId or email.
@freezed
abstract class PersonProfile with _$PersonProfile {
  const factory PersonProfile({
    required String id,
    required String familyId,
    required String name,
    required bool isLinked,
    DateTime? birthDate,
    String? birthPrecision,
    String? about,
    String? avatarPath,
    DateTime? passingDate,
    String? passingPrecision,
    @Default(false) bool passedAway,
  }) = _PersonProfile;
}
