import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_invite_result.freezed.dart';

@freezed
abstract class CreateInviteResult with _$CreateInviteResult {
  const factory CreateInviteResult({
    required String inviteId,
    required String token,
    required DateTime expiresAt,
    required String inviteUrl,
  }) = _CreateInviteResult;
}
