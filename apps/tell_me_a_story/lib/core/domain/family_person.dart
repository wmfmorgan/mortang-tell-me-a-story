import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_person.freezed.dart';

@freezed
abstract class FamilyPerson with _$FamilyPerson {
  const factory FamilyPerson({
    required String userId,
    required String role,
    required String? displayName,
    Uint8List? avatarBytes,
  }) = _FamilyPerson;
}
