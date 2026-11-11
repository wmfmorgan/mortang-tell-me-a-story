import 'package:tell_me_a_story/core/domain/family_invite.dart';
import 'package:tell_me_a_story/core/domain/family_person.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_detail.freezed.dart';

@freezed
abstract class FamilyDetail with _$FamilyDetail {
  const factory FamilyDetail({
    required String id,
    required String name,
    required String myRole,
    required List<FamilyPerson> people,
    @Default(<FamilyInvite>[]) List<FamilyInvite> pendingInvites,
  }) = _FamilyDetail;
}
