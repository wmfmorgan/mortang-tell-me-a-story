import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';

/// Family-level authorization predicates (business-rules.md §1).
///
/// Every predicate is false for an unauthenticated session. "Live" means the
/// family has no `deletedAt`. Tree membership is equality on `treeId`.
class Authz {
  Authz(this.session);

  final Session session;

  UuidValue? get userId => session.authenticated?.authUserId;

  /// Returns the caller's id or throws `AppException(code: 'auth_required')`.
  UuidValue requireUser() {
    final id = userId;
    if (id == null) {
      throw AppException(code: 'auth_required', message: 'Sign in to continue.');
    }
    return id;
  }

  Future<MembershipRole?> roleIn(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return null;
    final row = await Membership.db.findFirstRow(
      session,
      where: (t) => t.familyId.equals(familyId) & t.userId.equals(uid),
    );
    return row?.role;
  }

  /// Membership in [familyId], ignoring soft delete.
  Future<bool> isMember(UuidValue familyId) async =>
      await roleIn(familyId) != null;

  Future<bool> isOwner(UuidValue familyId) async =>
      await roleIn(familyId) == MembershipRole.owner;

  /// Owner or co-owner, ignoring soft delete.
  Future<bool> isSteward(UuidValue familyId) async {
    final role = await roleIn(familyId);
    return role == MembershipRole.owner || role == MembershipRole.coOwner;
  }

  /// Membership in [familyId] and the family is not soft-deleted.
  Future<bool> isLiveMember(UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return false;
    return isMember(familyId);
  }

  /// Caller is a member of some live family in the same tree as [familyId].
  Future<bool> isTreeReadable(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return false;
    final family = await Family.db.findById(session, familyId);
    if (family == null) return false;
    final memberships = await Membership.db.find(
      session,
      where: (t) => t.userId.equals(uid),
    );
    if (memberships.isEmpty) return false;
    final count = await Family.db.count(
      session,
      where: (t) =>
          t.id.inSet(memberships.map((m) => m.familyId).toSet()) &
          t.treeId.equals(family.treeId) &
          t.deletedAt.equals(null),
    );
    return count > 0;
  }

  /// [isTreeReadable] and [familyId] itself is live.
  Future<bool> isTreeMember(UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return false;
    return isTreeReadable(familyId);
  }

  /// Throws `AppException(code: 'forbidden')` unless [allowed].
  void ensure(bool allowed) {
    if (!allowed) {
      throw AppException(
        code: 'forbidden',
        message: "You don't have access to that.",
      );
    }
  }
}
