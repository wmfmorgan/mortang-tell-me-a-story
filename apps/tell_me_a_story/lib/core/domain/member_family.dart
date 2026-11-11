import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_family.freezed.dart';

/// A family the signed-in member can already read.
@freezed
abstract class MemberFamily with _$MemberFamily {
  const factory MemberFamily({
    required String id,
    required String name,
    required DateTime createdAt,
    String? parentFamilyId,

    /// `families.branch_year`; null when the family has no attach year.
    int? branchYear,

    /// The caller's `memberships.role` ('owner', 'co_owner', 'member');
    /// null when the row did not come from `listMine()`.
    String? role,

    /// Object key in `family-covers`, or null when the hero is a placeholder.
    String? coverPhotoPath,
  }) = _MemberFamily;
}
