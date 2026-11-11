import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/session/family_membership.dart';

part 'family_selection.g.dart';

/// Process-memory family choice. Not a table and not kept across a restart.
///
/// State is the remembered family id.
@Riverpod(keepAlive: true)
class FamilySelection extends _$FamilySelection {
  String? _userId;

  @override
  String? build() => null;

  void remember(String familyId) {
    state = familyId;
  }

  /// Also clears [FamilyMembership].
  void clear() {
    state = null;
    _userId = null;
    ref.read(familyMembershipProvider.notifier).clear();
  }

  /// Drops the remembered id when it is the family that was just soft-deleted.
  void forget(String familyId) {
    if (state == familyId) state = null;
  }

  /// Binds [userId] as the signed-in user.
  ///
  /// A different user clears the remembered family. The same user keeps it.
  /// Returns the remembered id after that check.
  String? bindUser(String userId) {
    if (_userId != userId) {
      if (_userId != null) {
        state = null;
        ref.read(familyMembershipProvider.notifier).clear();
      }
      _userId = userId;
    }
    return state;
  }
}
