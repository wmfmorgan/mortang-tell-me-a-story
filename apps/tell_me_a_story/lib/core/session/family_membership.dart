import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/session/family_membership_state.dart';

part 'family_membership.g.dart';

/// Families the signed-in user can write in, kept for this app session.
///
/// Header pages read this on the first frame so New story does not wait
/// for the next membership fetch.
@Riverpod(keepAlive: true)
class FamilyMembership extends _$FamilyMembership {
  @override
  FamilyMembershipState build() => const FamilyMembershipState();

  void remember(Iterable<String> ids) {
    state = FamilyMembershipState(ids: Set.unmodifiable(ids), known: true);
  }

  void clear() {
    state = const FamilyMembershipState();
  }
}
