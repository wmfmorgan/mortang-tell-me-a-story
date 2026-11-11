import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_families_repository.g.dart';

abstract class ManageFamiliesRepository {
  Future<String> createRootFamily(String name);

  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  });
  Future<void> renameFamily({required String familyId, required String name});
  Future<void> addCoOwner({required String familyId, required String userId});
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  });
  Future<void> removeMember({required String familyId, required String userId});
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  });
  Future<void> softDeleteFamily(String familyId);
  Future<void> recoverFamily(String familyId);
  Future<DateTime> resendInvite(String inviteId);
  Future<void> revokeInvite(String inviteId);
}

@Riverpod(keepAlive: true)
ManageFamiliesRepository manageFamiliesRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
