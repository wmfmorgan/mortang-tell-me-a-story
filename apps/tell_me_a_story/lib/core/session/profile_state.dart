import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_state.freezed.dart';

/// The signed-in profile as shown in the header and composer.
@freezed
abstract class ProfileState with _$ProfileState {
  const factory ProfileState({
    String? displayName,
    String? email,
    Uint8List? avatarBytes,
  }) = _ProfileState;
}
