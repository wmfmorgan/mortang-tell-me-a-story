import 'package:freezed_annotation/freezed_annotation.dart';

part 'accept_invite_result.freezed.dart';

@freezed
abstract class AcceptInviteResult with _$AcceptInviteResult {
  const factory AcceptInviteResult({required String familyId}) =
      _AcceptInviteResult;
}
