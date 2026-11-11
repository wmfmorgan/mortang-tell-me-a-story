import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/data/server/wire.dart';

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

class ServerManageFamiliesRepository implements ManageFamiliesRepository {
  ServerManageFamiliesRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  static server.UuidValue _id(String id) => server.UuidValue.fromString(id);

  @override
  Future<String> createRootFamily(String name) async {
    final id = await withServerErrors(() => _client.family.createRoot(name));
    return id.toString();
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
    final id = await withServerErrors(
      () => _client.family.createBranch(
        parentFamilyId: _id(parentFamilyId),
        originStoryId: _id(originStoryId),
        name: name,
        branchYear: branchYear,
        ownerUserId: _id(ownerUserId),
        personIds: [for (final personId in personIds) _id(personId)],
      ),
    );
    return id.toString();
  }

  @override
  Future<void> renameFamily({required String familyId, required String name}) {
    return withServerErrors(() => _client.family.rename(_id(familyId), name));
  }

  @override
  Future<void> addCoOwner({required String familyId, required String userId}) {
    return withServerErrors(
      () => _client.family.addCoOwner(_id(familyId), _id(userId)),
    );
  }

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) {
    return withServerErrors(
      () => _client.family.removeCoOwner(_id(familyId), _id(userId)),
    );
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) {
    return withServerErrors(
      () => _client.family.removeMember(_id(familyId), _id(userId)),
    );
  }

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) {
    return withServerErrors(
      () => _client.family.transferOwnership(
        _id(familyId),
        _id(newOwnerUserId),
        roleFromName(formerOwnerBecomes),
      ),
    );
  }

  @override
  Future<void> softDeleteFamily(String familyId) {
    return withServerErrors(() => _client.family.softDelete(_id(familyId)));
  }

  @override
  Future<void> recoverFamily(String familyId) {
    return withServerErrors(() => _client.family.recover(_id(familyId)));
  }

  /// Rotates the token and returns the new expiry.
  @override
  Future<DateTime> resendInvite(String inviteId) {
    return withServerErrors(() => _client.invite.resend(_id(inviteId)));
  }

  @override
  Future<void> revokeInvite(String inviteId) {
    return withServerErrors(() => _client.invite.revoke(_id(inviteId)));
  }
}
