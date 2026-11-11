import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';

/// [ManageFamiliesRepository] that records every call in [calls] as
/// `method:arg,arg` and succeeds. Set [error] to make every call throw it.
/// Subclass and override a method for anything else.
class FakeManageFamiliesRepository implements ManageFamiliesRepository {
  FakeManageFamiliesRepository({DateTime? resentUntil})
    : resentUntil = resentUntil ?? DateTime.utc(2030);

  /// What [resendInvite] returns.
  final DateTime resentUntil;

  final calls = <String>[];
  Object? error;

  void _record(String call) {
    calls.add(call);
    final thrown = error;
    if (thrown != null) throw thrown;
  }

  @override
  Future<String> createRootFamily(String name) async {
    _record('createRootFamily:$name');
    return 'family-root-${calls.length}';
  }

  @override
  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  }) async {
    _record(
      'createBranchFamily:$parentFamilyId,$originStoryId,$name,$branchYear,'
      '$ownerUserId,${personIds.join('+')}',
    );
    return 'family-branch-${calls.length}';
  }

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async => _record('renameFamily:$familyId,$name');

  @override
  Future<void> addCoOwner({
    required String familyId,
    required String userId,
  }) async => _record('addCoOwner:$familyId,$userId');

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) async => _record('removeCoOwner:$familyId,$userId');

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async => _record('removeMember:$familyId,$userId');

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) async => _record(
    'transferOwnership:$familyId,$newOwnerUserId,$formerOwnerBecomes',
  );

  @override
  Future<void> softDeleteFamily(String familyId) async =>
      _record('softDeleteFamily:$familyId');

  @override
  Future<void> recoverFamily(String familyId) async =>
      _record('recoverFamily:$familyId');

  @override
  Future<DateTime> resendInvite(String inviteId) async {
    _record('resendInvite:$inviteId');
    return resentUntil;
  }

  @override
  Future<void> revokeInvite(String inviteId) async =>
      _record('revokeInvite:$inviteId');
}
