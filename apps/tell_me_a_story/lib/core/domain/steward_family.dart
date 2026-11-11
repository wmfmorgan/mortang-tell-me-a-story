import 'package:tell_me_a_story/core/domain/recovery_window.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'steward_family.freezed.dart';

/// A family the caller owns or co-owns. [deletedAt] is set while it is
/// soft-deleted. The manage gate keeps rows still inside the 60-day window.
@freezed
abstract class StewardFamily with _$StewardFamily {
  const StewardFamily._();

  const factory StewardFamily({
    required String id,
    required String name,
    required String role,
    DateTime? deletedAt,
  }) = _StewardFamily;

  bool countsForManage([DateTime? now]) {
    if (!originSteward(role)) return false;
    final deleted = deletedAt;
    if (deleted == null) return true;
    return isInsideRecoveryWindow(deleted, now);
  }
}

/// Owner or co-owner of a family. Other roles are false.
bool originSteward(String? role) => role == 'owner' || role == 'co_owner';
