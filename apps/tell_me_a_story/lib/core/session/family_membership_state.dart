import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_membership_state.freezed.dart';

/// Families the signed-in user can write in; [known] once fetched.
@freezed
abstract class FamilyMembershipState with _$FamilyMembershipState {
  const factory FamilyMembershipState({
    @Default(<String>{}) Set<String> ids,
    @Default(false) bool known,
  }) = _FamilyMembershipState;

  const FamilyMembershipState._();

  bool canWrite(String? familyId) => familyId != null && ids.contains(familyId);
}
