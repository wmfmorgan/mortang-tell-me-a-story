import 'package:freezed_annotation/freezed_annotation.dart';

part 'tree_family.freezed.dart';

/// One live family from `family.listTree`.
/// [branchYear] and [originStoryId] are whatever the server returns.
@freezed
abstract class TreeFamily with _$TreeFamily {
  const factory TreeFamily({
    required String id,
    required String name,
    String? parentFamilyId,
    int? branchYear,

    /// Effective origin from `family_origin`. Null when the timeline has none.
    String? originStoryId,
  }) = _TreeFamily;
}
