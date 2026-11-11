import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/person.dart';

part 'invite_modal_providers.g.dart';

List<Person> _notPassed(List<Person> rows) => [
  for (final row in rows)
    if (!row.passedAway) row,
];

/// Living people in [familyId] without an account: the Link tab's picks.
@riverpod
Future<List<Person>> inviteLinkPeople(Ref ref, String familyId) async {
  final rows = await ref
      .watch(peopleRepositoryProvider)
      .listUnlinkedPeople(familyId);
  return _notPassed(rows);
}

/// The modal's "Not invited yet" list. Rows leave once invited.
@riverpod
class NotInvitedPeople extends _$NotInvitedPeople {
  @override
  Future<List<Person>> build(String familyId) async {
    final rows = await ref
        .watch(peopleRepositoryProvider)
        .listUnlinkedPeople(familyId);
    return _notPassed(rows);
  }

  /// Removes [personId] after their invite went out.
  void drop(String personId) {
    final rows = state.value;
    if (rows == null) return;
    state = AsyncData([
      for (final row in rows)
        if (row.id != personId) row,
    ]);
  }

  /// Swaps in [saved] after its email was written.
  void replace(Person saved) {
    final rows = state.value;
    if (rows == null) return;
    state = AsyncData([
      for (final row in rows)
        if (row.id == saved.id) saved else row,
    ]);
  }
}
