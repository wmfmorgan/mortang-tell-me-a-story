import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../errors.dart';
import '../generated/protocol.dart';

/// Family- and story-level authorization predicates (business-rules.md §1,
/// with the 2026-11-07 decisions: every write and member read needs a live
/// family, D6b).
///
/// Every predicate is false for an unauthenticated session. "Live" means the
/// family has no `deletedAt`. Tree membership is equality on `treeId`; tree
/// reads require both the target family and the caller's family to be live.
class Authz {
  Authz(this.session);

  final Session session;

  UuidValue? get userId => session.authenticated?.authUserId;

  /// Returns the caller's id or throws `AppException(AppErrorCode.authRequired)`.
  UuidValue requireUser() {
    final id = userId;
    if (id == null) {
      throw AppException(
        code: AppErrorCode.authRequired,
        message: 'Sign in to continue.',
      );
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
  Future<bool> isLiveMember(UuidValue familyId) async =>
      await _liveRole(familyId) != null;

  /// Owner or co-owner of [familyId], and the family is live.
  Future<bool> isLiveSteward(UuidValue familyId) async {
    final role = await _liveRole(familyId);
    return role == MembershipRole.owner || role == MembershipRole.coOwner;
  }

  /// The caller's role in live [familyId]; otherwise
  /// `AppException(forbidden, 'member only')`. A missing or soft-deleted
  /// family is refused the same way, so ids don't leak.
  Future<MembershipRole> requireLiveMember(UuidValue familyId) async {
    final role = await _liveRole(familyId);
    if (role == null) throw forbidden('member only');
    return role;
  }

  /// Owner or co-owner of live [familyId]; otherwise
  /// `AppException(forbidden, 'owner or co-owner only')`.
  Future<MembershipRole> requireLiveSteward(UuidValue familyId) async {
    final role = await _liveRole(familyId);
    if (role != MembershipRole.owner && role != MembershipRole.coOwner) {
      throw forbidden('owner or co-owner only');
    }
    return role!;
  }

  /// Owner of live [familyId]; otherwise `AppException(forbidden, 'owner only')`.
  Future<void> requireLiveOwner(UuidValue familyId) async {
    if (await _liveRole(familyId) != MembershipRole.owner) {
      throw forbidden('owner only');
    }
  }

  Future<MembershipRole?> _liveRole(UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return null;
    return roleIn(familyId);
  }

  /// [familyId] is live and the caller is a member of some live family in the
  /// same tree.
  Future<bool> isTreeReadable(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return false;
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return false;
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

  /// Same as [isTreeReadable]; kept as the business-rules name.
  Future<bool> isTreeMember(UuidValue familyId) => isTreeReadable(familyId);

  /// `familyOrigin(f)` (schema-design.md §3.5): [family]'s origin story when
  /// [family] is live, the story is published, the story's family is live,
  /// and the story belongs to the parent (branch) or to [family] (root).
  Future<UuidValue?> effectiveOrigin(Family family) async {
    final storyId = family.originStoryId;
    if (storyId == null || family.deletedAt != null) return null;
    final story = await Story.db.findById(session, storyId);
    if (story == null || story.status != StoryStatus.published) return null;
    if (story.familyId != (family.parentId ?? family.id)) return null;
    final owner = await Family.db.findById(session, story.familyId);
    if (owner == null || owner.deletedAt != null) return null;
    return storyId;
  }

  /// Drafts: the author while a live member. Published: live members of the
  /// story's family and tree readers.
  Future<bool> canReadStory(Story story) async {
    if (story.status == StoryStatus.draft) {
      return _isAuthor(story) && await isLiveMember(story.familyId);
    }
    return await isLiveMember(story.familyId) ||
        await isTreeReadable(story.familyId);
  }

  /// `canEditStory`: the family is live and the caller is the author (live
  /// member), or the story is published and the caller is a steward of the
  /// story's family.
  Future<bool> canEditStory(Story story) async {
    final role = await _liveRole(story.familyId);
    if (role == null) return false;
    if (_isAuthor(story)) return true;
    return story.status == StoryStatus.published &&
        (role == MembershipRole.owner || role == MembershipRole.coOwner);
  }

  /// `canContribute`: the story is published or the caller wrote it, and the
  /// caller is a live member of its family, or a live member of a live child
  /// family whose effective origin is this story (origin contributor).
  Future<bool> canContribute(Story story) async {
    if (story.status != StoryStatus.published && !_isAuthor(story)) {
      return false;
    }
    if (await isLiveMember(story.familyId)) return true;
    final children = await Family.db.find(
      session,
      where: (t) =>
          t.parentId.equals(story.familyId) &
          t.originStoryId.equals(story.id) &
          t.deletedAt.equals(null),
    );
    for (final child in children) {
      if (await effectiveOrigin(child) == story.id &&
          await isLiveMember(child.id!)) {
        return true;
      }
    }
    return false;
  }

  bool _isAuthor(Story story) {
    final uid = userId;
    return uid != null && story.authorId == uid;
  }

  /// Throws `AppException(AppErrorCode.forbidden)` unless [allowed].
  void ensure(bool allowed) {
    if (!allowed) throw forbidden();
  }
}
