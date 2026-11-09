import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../families/purge.dart';
import '../live/live_events.dart';
import '../media/blob_keys.dart';
import '../media/blob_outbox.dart';

/// A soft-deleted family can be recovered for this long (business-rules.md
/// §3.5). Same value as the purge cutoff, so recovery closes exactly when the
/// purge may run.
const recoveryWindow = purgeAfter;

/// Branch creation refuses a parent this many levels deep (business-rules.md
/// §3.2 step 7).
const maxBranchDepth = 63;

const _mimeByExt = {
  'jpg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

/// Families, memberships and covers (business-rules.md §2.1, §2.2, §3.1–§3.3,
/// §3.5, §3.6; schema-design.md §3.2). Every write and member read needs a
/// live family (D6b); only `recover` and the steward reads `listStewarded`,
/// `directory` and `detail` reach a soft-deleted family.
class FamilyEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  // ── create root ──────────────────────────────────────────────────────

  /// A new tree with one family; the caller is its owner and gets a linked
  /// person (business-rules.md §3.1).
  Future<UuidValue> createRoot(Session session, String name) async {
    final uid = Authz(session).requireUser();
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw validation('name is required');
    return session.db.transaction((t) async {
      final tree = await Tree.db.insertRow(session, Tree(), transaction: t);
      final family = await Family.db.insertRow(
        session,
        Family(treeId: tree.id!, name: trimmed, createdById: uid),
        transaction: t,
      );
      await Membership.db.insertRow(
        session,
        Membership(
          familyId: family.id!,
          userId: uid,
          role: MembershipRole.owner,
        ),
        transaction: t,
      );
      await ensureLinkedPerson(
        session,
        treeId: tree.id!,
        homeFamilyId: family.id!,
        userId: uid,
        transaction: t,
      );
      return family.id!;
    });
  }

  // ── reads ────────────────────────────────────────────────────────────

  /// The caller's live families, any role.
  Future<List<MemberFamilyDto>> listMine(Session session) async {
    final roles = await _myRoles(session);
    if (roles.isEmpty) return [];
    final families = await Family.db.find(
      session,
      where: (t) => t.id.inSet(roles.keys.toSet()) & t.deletedAt.equals(null),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        MemberFamilyDto(
          id: f.id!,
          name: f.name,
          parentId: f.parentId,
          branchYear: f.branchYear,
          createdAt: f.createdAt,
          role: roles[f.id]!,
          coverKey: f.coverKey,
        ),
    ];
  }

  /// Families the caller owns or co-owns: live ones and soft-deleted ones
  /// still inside the recovery window (recovery read, D6b).
  Future<List<StewardFamilyDto>> listStewarded(Session session) async {
    final roles = await _myRoles(session, stewardOnly: true);
    if (roles.isEmpty) return [];
    final cutoff = DateTime.now().toUtc().subtract(recoveryWindow);
    final families = await Family.db.find(
      session,
      where: (t) =>
          t.id.inSet(roles.keys.toSet()) &
          (t.deletedAt.equals(null) | (t.deletedAt >= cutoff)),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        StewardFamilyDto(
          id: f.id!,
          name: f.name,
          role: roles[f.id]!,
          deletedAt: f.deletedAt,
        ),
    ];
  }

  /// Live families sharing [familyId]'s tree (D8), with their effective
  /// origin. Empty unless the caller reads that tree.
  Future<List<TreeFamilyDto>> listTree(
    Session session,
    UuidValue familyId,
  ) async {
    final authz = Authz(session);
    if (!await authz.isTreeReadable(familyId)) return [];
    final family = await Family.db.findById(session, familyId);
    final families = await Family.db.find(
      session,
      where: (t) => t.treeId.equals(family!.treeId) & t.deletedAt.equals(null),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        TreeFamilyDto(
          id: f.id!,
          name: f.name,
          parentId: f.parentId,
          branchYear: f.branchYear,
          effectiveOriginStoryId: await authz.effectiveOrigin(f),
        ),
    ];
  }

  Future<List<FamilyMemberDto>> listMembers(
    Session session,
    UuidValue familyId,
  ) async {
    await Authz(session).requireLiveMember(familyId);
    return _members(session, familyId);
  }

  /// The caller's stewarded families with member and published-story counts,
  /// in one query: live ones are `active`; soft-deleted ones inside the
  /// recovery window are `recoverable` (recovery read, D6b).
  Future<FamilyDirectoryDto> directory(Session session) async {
    final uid = Authz(session).requireUser();
    final rows = await session.db.unsafeQuery(
      '''
SELECT f."id", f."name", m."role", f."deletedAt",
  (SELECT count(*) FROM "memberships" c WHERE c."familyId" = f."id"),
  (SELECT count(*) FROM "stories" s
     WHERE s."familyId" = f."id" AND s."status" = 'published')
FROM "memberships" m
JOIN "families" f ON f."id" = m."familyId"
WHERE m."userId" = @uid::uuid AND m."role" IN ('owner', 'coOwner')
ORDER BY f."createdAt", f."id"
''',
      parameters: QueryParameters.named({'uid': uid.uuid}),
    );
    final cutoff = DateTime.now().toUtc().subtract(recoveryWindow);
    final active = <FamilyRosterDto>[];
    final recoverable = <FamilyRosterDto>[];
    for (final row in rows) {
      final deletedAt = row[3] as DateTime?;
      final roster = FamilyRosterDto(
        id: UuidValue.fromString(row[0].toString()),
        name: row[1] as String,
        role: MembershipRole.fromJson(row[2] as String),
        memberCount: row[4] as int,
        publishedCount: row[5] as int,
        deletedAt: deletedAt,
      );
      if (deletedAt == null) {
        active.add(roster);
      } else if (!deletedAt.isBefore(cutoff)) {
        recoverable.add(roster);
      }
    }
    return FamilyDirectoryDto(active: active, recoverable: recoverable);
  }

  /// Family, members and pending invites. Live members read a live family;
  /// owners and co-owners also read a soft-deleted one (recovery read, D6b),
  /// whose invites are not readable, so `pendingInvites` is empty.
  Future<FamilyDetailDto> detail(Session session, UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    final role = await Authz(session).roleIn(familyId);
    if (family == null || role == null) throw forbidden('member only');
    final deleted = family.deletedAt != null;
    if (deleted && role == MembershipRole.member) {
      throw forbidden('owner or co-owner only');
    }
    final invites = deleted
        ? const <Invite>[]
        : await Invite.db.find(
            session,
            where: (t) =>
                t.familyId.equals(familyId) &
                t.acceptedAt.equals(null) &
                t.revokedAt.equals(null),
            orderByList: (t) => [t.email.asc(), t.createdAt.asc()],
          );
    return FamilyDetailDto(
      id: family.id!,
      name: family.name,
      myRole: role,
      members: await _members(session, familyId),
      pendingInvites: [
        for (final i in invites)
          PendingInviteDto(
            id: i.id!,
            email: i.email,
            personId: i.personId,
            sentAt: i.lastSentAt,
            expiresAt: i.expiresAt,
            createdAt: i.createdAt,
          ),
      ],
    );
  }

  // ── names and roles ──────────────────────────────────────────────────

  Future<void> rename(Session session, UuidValue familyId, String name) async {
    final trimmed = name.trim();
    await Authz(session).requireLiveSteward(familyId);
    if (trimmed.isEmpty) throw validation('name is required');
    await session.db.transaction((t) async {
      final family = (await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      ))!;
      await Family.db.updateRow(
        session,
        family.copyWith(name: trimmed),
        columns: (c) => [c.name],
        transaction: t,
      );
    });
  }

  /// Owner or co-owner promotes a plain member; at most two co-owners, counted
  /// under the family row lock.
  Future<void> addCoOwner(
    Session session,
    UuidValue familyId,
    UuidValue userId,
  ) async {
    await Authz(session).requireLiveSteward(familyId);
    await session.db.transaction((t) async {
      await _lockFamily(session, familyId, t);
      final target = await _membership(session, familyId, userId, t);
      if (target == null || target.role != MembershipRole.member) {
        throw validation('target must be a member');
      }
      final coOwners = await Membership.db.count(
        session,
        where: (m) =>
            m.familyId.equals(familyId) & m.role.equals(MembershipRole.coOwner),
        transaction: t,
      );
      if (coOwners >= 2) throw validation('co-owner cap is 2');
      await _setRole(session, target, MembershipRole.coOwner, t);
    });
  }

  Future<void> removeCoOwner(
    Session session,
    UuidValue familyId,
    UuidValue userId,
  ) async {
    await Authz(session).requireLiveOwner(familyId);
    await session.db.transaction((t) async {
      await _lockFamily(session, familyId, t);
      final target = await _membership(session, familyId, userId, t);
      if (target == null || target.role != MembershipRole.coOwner) {
        throw validation('target must be a co-owner');
      }
      await _setRole(session, target, MembershipRole.member, t);
    });
  }

  /// Business-rules.md §3.6. Writes demote the caller, promote the target,
  /// then make the caller co-owner if asked, so the one-owner index and the
  /// co-owner cap hold at every step.
  Future<void> transferOwnership(
    Session session,
    UuidValue familyId,
    UuidValue newOwnerUserId,
    MembershipRole formerOwnerBecomes,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveOwner(familyId);
    if (formerOwnerBecomes == MembershipRole.owner) {
      throw validation('former role must be co_owner or member');
    }
    await session.db.transaction((t) async {
      await _lockFamily(session, familyId, t);
      final target = await _membership(session, familyId, newOwnerUserId, t);
      if (target == null || target.role != MembershipRole.coOwner) {
        throw forbidden('target must be a co-owner');
      }
      final me = (await _membership(session, familyId, uid, t))!;
      await _setRole(session, me, MembershipRole.member, t);
      await _setRole(session, target, MembershipRole.owner, t);
      if (formerOwnerBecomes == MembershipRole.coOwner) {
        await _setRole(session, me, MembershipRole.coOwner, t);
      }
    });
  }

  /// Removes [userId] from every family in the tree, soft-deleted ones
  /// included (so recovery can't restore them), and unlinks their person in
  /// the tree; story tags stay (business-rules.md §2.2).
  Future<void> removeMember(
    Session session,
    UuidValue familyId,
    UuidValue userId,
  ) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    final role = await authz.requireLiveSteward(familyId);
    if (userId == uid) throw forbidden('cannot remove yourself');
    await session.db.transaction((t) async {
      final family = await _lockFamily(session, familyId, t);
      final treeFamilies = await Family.db.find(
        session,
        where: (f) => f.treeId.equals(family.treeId),
        transaction: t,
      );
      final treeFamilyIds = {for (final f in treeFamilies) f.id!};
      final targetRoles = await Membership.db.find(
        session,
        where: (m) => m.userId.equals(userId) & m.familyId.inSet(treeFamilyIds),
        transaction: t,
      );
      if (targetRoles.any((m) => m.role == MembershipRole.owner)) {
        throw forbidden('cannot remove an owner');
      }
      if (targetRoles.any((m) => m.role == MembershipRole.coOwner) &&
          role != MembershipRole.owner) {
        throw forbidden('cannot remove a co-owner');
      }
      await Membership.db.deleteWhere(
        session,
        where: (m) => m.userId.equals(userId) & m.familyId.inSet(treeFamilyIds),
        transaction: t,
      );
      await Person.db.updateWhere(
        session,
        columnValues: (p) => [
          p.userId(null),
          p.updatedAt(DateTime.now().toUtc()),
        ],
        where: (p) => p.userId.equals(userId) & p.treeId.equals(family.treeId),
        transaction: t,
      );
    });
  }

  // ── soft delete ──────────────────────────────────────────────────────

  /// Owner only. Only sets `deletedAt`; the purge (3f) removes the family
  /// after the recovery window. Repeating it as the owner of an already
  /// deleted family is a no-op (business-rules.md §3.5). Posts a `family`
  /// event (deleted) to the tree channel after commit.
  Future<void> softDelete(Session session, UuidValue familyId) async {
    final authz = Authz(session);
    if (await authz.isOwner(familyId)) {
      final family = await Family.db.findById(session, familyId);
      if (family?.deletedAt != null) return;
    }
    await authz.requireLiveOwner(familyId);
    final deleted = await session.db.transaction((t) async {
      final family = await _lockFamily(session, familyId, t);
      return Family.db.updateRow(
        session,
        family.copyWith(deletedAt: DateTime.now().toUtc()),
        columns: (c) => [c.deletedAt],
        transaction: t,
      );
    });
    await postFamilyEvent(session, deleted, deleted: true);
  }

  /// Owner or co-owner of the soft-deleted family, inside the recovery
  /// window (recovery exception, D6b). Posts a `family` event to the tree
  /// channel after commit.
  Future<void> recover(Session session, UuidValue familyId) async {
    if (!await Authz(session).isSteward(familyId)) {
      throw forbidden('owner or co-owner only');
    }
    final recovered = await session.db.transaction((t) async {
      final family = await _lockFamily(session, familyId, t);
      final deletedAt = family.deletedAt;
      if (deletedAt == null) throw validation('family is not deleted');
      final cutoff = DateTime.now().toUtc().subtract(recoveryWindow);
      if (deletedAt.isBefore(cutoff)) {
        throw forbidden('recovery window closed');
      }
      return Family.db.updateRow(
        session,
        family.copyWith(deletedAt: null),
        columns: (c) => [c.deletedAt],
        transaction: t,
      );
    });
    await postFamilyEvent(session, recovered);
  }

  // ── origin ───────────────────────────────────────────────────────────

  /// Business-rules.md §3.3: bare FORBIDDEN first, then a deleted parent,
  /// then a story that is missing, unpublished or not in
  /// `coalesce(parent, family)`.
  Future<void> setOrigin(
    Session session,
    UuidValue familyId,
    UuidValue storyId,
  ) async {
    final authz = Authz(session);
    authz.ensure(await authz.isLiveSteward(familyId));
    await session.db.transaction((t) async {
      final family = (await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      ))!;
      final parentId = family.parentId;
      if (parentId != null) {
        final parent = await Family.db.findById(
          session,
          parentId,
          transaction: t,
        );
        if (parent == null || parent.deletedAt != null) {
          throw validation('parent family is deleted');
        }
      }
      final story = await Story.db.findById(session, storyId, transaction: t);
      if (story == null ||
          story.status != StoryStatus.published ||
          story.familyId != (parentId ?? familyId)) {
        throw notFound('story');
      }
      await Family.db.updateRow(
        session,
        family.copyWith(originStoryId: storyId),
        columns: (c) => [c.originStoryId],
        transaction: t,
      );
    });
  }

  /// Families whose effective origin is [storyId]. Empty unless the caller is
  /// a live member of the story's family.
  Future<List<OriginDependentDto>> listOriginDependents(
    Session session,
    UuidValue storyId,
  ) async {
    final authz = Authz(session);
    final story = await Story.db.findById(session, storyId);
    if (story == null || !await authz.isLiveMember(story.familyId)) return [];
    final families = await Family.db.find(
      session,
      where: (t) => t.originStoryId.equals(storyId) & t.deletedAt.equals(null),
      orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
    );
    return [
      for (final f in families)
        if (await authz.effectiveOrigin(f) == storyId)
          OriginDependentDto(familyId: f.id!, name: f.name),
    ];
  }

  // ── branch ───────────────────────────────────────────────────────────

  /// "Start a new timeline" (business-rules.md §3.2, in that check order).
  /// The owner and each picked linked member get a linked person in the tree
  /// (D6d). A lost race on `people_tree_user_uidx` reruns the write once.
  /// Posts a `family` event to the tree channel after commit.
  Future<UuidValue> createBranch(
    Session session, {
    required UuidValue parentFamilyId,
    required UuidValue originStoryId,
    required String name,
    required int branchYear,
    required UuidValue ownerUserId,
    List<UuidValue> personIds = const [],
  }) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(parentFamilyId);
    final parent = (await Family.db.findById(session, parentFamilyId))!;
    final story = await Story.db.findById(session, originStoryId);
    if (story == null ||
        story.status != StoryStatus.published ||
        story.familyId != parentFamilyId) {
      throw notFound('story');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw validation('name is required');
    if (branchYear < 1000 || branchYear > 9999) {
      throw validation('attach year must be four digits');
    }
    final ownerMembership = await Membership.db.findFirstRow(
      session,
      where: (t) =>
          t.familyId.equals(parentFamilyId) & t.userId.equals(ownerUserId),
    );
    if (ownerMembership == null) {
      throw validation('owner must be a member of the parent family');
    }
    final pickedIds = personIds.toSet();
    final picked = pickedIds.isEmpty
        ? const <Person>[]
        : await Person.db.find(
            session,
            where: (t) => t.id.inSet(pickedIds),
          );
    if (picked.length != pickedIds.length ||
        picked.any((p) => p.homeFamilyId != parentFamilyId)) {
      throw validation('members must come from the parent family');
    }
    if (await _depth(session, parent) >= maxBranchDepth) {
      throw validation('too many levels');
    }
    final memberIds = {
      for (final p in picked)
        if (p.userId != null) p.userId!,
    };

    Future<Family> write() => session.db.transaction((t) async {
      final branch = await Family.db.insertRow(
        session,
        Family(
          treeId: parent.treeId,
          parentId: parentFamilyId,
          name: trimmed,
          branchYear: branchYear,
          originStoryId: originStoryId,
          createdById: uid,
        ),
        transaction: t,
      );
      await Membership.db.insertRow(
        session,
        Membership(
          familyId: branch.id!,
          userId: ownerUserId,
          role: MembershipRole.owner,
        ),
        transaction: t,
      );
      for (final memberId in memberIds.difference({ownerUserId})) {
        await Membership.db.insertRow(
          session,
          Membership(familyId: branch.id!, userId: memberId),
          transaction: t,
        );
      }
      for (final userId in {ownerUserId, ...memberIds}) {
        await ensureLinkedPerson(
          session,
          treeId: parent.treeId,
          homeFamilyId: branch.id!,
          userId: userId,
          transaction: t,
        );
      }
      return branch;
    });

    Family branch;
    try {
      branch = await write();
    } on DatabaseQueryException catch (e) {
      if (e.code != '23505' || e.constraintName != 'people_tree_user_uidx') {
        rethrow;
      }
      branch = await write();
    }
    await postFamilyEvent(session, branch);
    return branch.id!;
  }

  // ── cover ────────────────────────────────────────────────────────────

  /// Steward of the live family. [mimeType] (jpeg, png or webp) picks the key
  /// extension; [byteLength] is pinned in the upload, at most 5 MiB.
  Future<CoverUploadTicketDto> startCoverUpload(
    Session session,
    UuidValue familyId,
    String mimeType,
    int byteLength,
  ) async {
    await Authz(session).requireLiveSteward(familyId);
    final key = familyCoverKey(familyId: familyId, mimeType: mimeType);
    if (byteLength < 1) throw validation('file is empty');
    if (byteLength > coverMaxBytes) throw validation('file is too large');
    final description = await session.storage.createUploadDescription(
      storageId: blobStorageId,
      path: key,
      options: UploadOptions(
        maxFileSize: coverMaxBytes,
        contentLength: byteLength,
        preventOverwrite: true,
        metadata: FileMetadata(contentType: mimeType),
      ),
    );
    return CoverUploadTicketDto(key: key, uploadDescription: description);
  }

  /// Verifies the upload at [key], checks its size and that its bytes are the
  /// image type its extension names, then makes it the cover. A rejected blob
  /// is queued for deletion; the previous cover key is queued in the same
  /// transaction that replaces it. Finishing the current cover again is a
  /// no-op; a key already queued for deletion (e.g. a replaced cover) is
  /// STORAGE_FAILED.
  Future<String> finishCoverUpload(
    Session session,
    UuidValue familyId,
    String key,
  ) async {
    await Authz(session).requireLiveSteward(familyId);
    final mimeType = _coverKeyMime(familyId, key);
    final current = await Family.db.findById(session, familyId);
    if (current!.coverKey == key) return key;
    if (await _isQueuedForDeletion(session, key)) throw _uploadGone();
    final uploaded = await session.storage.verifyUpload(
      storageId: blobStorageId,
      path: key,
    );
    if (!uploaded) throw validation('upload not found');
    final bytes = await session.storage.retrieveFile(
      storageId: blobStorageId,
      path: key,
    );
    if (bytes.lengthInBytes > coverMaxBytes) {
      await queueBlobDeletions(session, [key]);
      throw validation('file is too large');
    }
    if (sniffImageMime(bytes) != mimeType) {
      await queueBlobDeletions(session, [key]);
      throw validation('unsupported image type');
    }
    try {
      await session.db.transaction((t) async {
        final family = (await Family.db.findById(
          session,
          familyId,
          transaction: t,
          lockMode: LockMode.forUpdate,
        ))!;
        if (family.coverKey == key) return;
        if (await _isQueuedForDeletion(session, key, transaction: t)) {
          throw _uploadGone();
        }
        await queueBlobDeletions(session, [family.coverKey], transaction: t);
        await Family.db.updateRow(
          session,
          family.copyWith(coverKey: key),
          columns: (c) => [c.coverKey],
          transaction: t,
        );
      });
    } on AppException {
      rethrow;
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return key;
  }

  Future<void> clearCover(Session session, UuidValue familyId) async {
    await Authz(session).requireLiveSteward(familyId);
    await session.db.transaction((t) async {
      final family = (await Family.db.findById(
        session,
        familyId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      ))!;
      if (family.coverKey == null) return;
      await queueBlobDeletions(session, [family.coverKey], transaction: t);
      await Family.db.updateRow(
        session,
        family.copyWith(coverKey: null),
        columns: (c) => [c.coverKey],
        transaction: t,
      );
    });
  }
}

/// The caller's role per family id, optionally owners and co-owners only.
Future<Map<UuidValue, MembershipRole>> _myRoles(
  Session session, {
  bool stewardOnly = false,
}) async {
  final uid = Authz(session).requireUser();
  final memberships = await Membership.db.find(
    session,
    where: (t) => stewardOnly
        ? t.userId.equals(uid) &
              t.role.inSet({MembershipRole.owner, MembershipRole.coOwner})
        : t.userId.equals(uid),
  );
  return {for (final m in memberships) m.familyId: m.role};
}

Future<List<FamilyMemberDto>> _members(
  Session session,
  UuidValue familyId,
) async {
  final memberships = await Membership.db.find(
    session,
    where: (t) => t.familyId.equals(familyId),
    orderByList: (t) => [t.createdAt.asc(), t.id.asc()],
  );
  if (memberships.isEmpty) return [];
  final users = await AppUser.db.find(
    session,
    where: (t) => t.authUserId.inSet({for (final m in memberships) m.userId}),
  );
  final byId = {for (final u in users) u.authUserId: u};
  return [
    for (final m in memberships)
      FamilyMemberDto(
        userId: m.userId,
        role: m.role,
        displayName: byId[m.userId]?.displayName,
        avatarKey: byId[m.userId]?.avatarKey,
      ),
  ];
}

Future<Family> _lockFamily(
  Session session,
  UuidValue familyId,
  Transaction t,
) async => (await Family.db.findById(
  session,
  familyId,
  transaction: t,
  lockMode: LockMode.forUpdate,
))!;

Future<Membership?> _membership(
  Session session,
  UuidValue familyId,
  UuidValue userId,
  Transaction t,
) => Membership.db.findFirstRow(
  session,
  where: (m) => m.familyId.equals(familyId) & m.userId.equals(userId),
  transaction: t,
);

Future<void> _setRole(
  Session session,
  Membership membership,
  MembershipRole role,
  Transaction t,
) => Membership.db.updateRow(
  session,
  membership.copyWith(role: role),
  columns: (m) => [m.role],
  transaction: t,
);

/// Ancestors above [family], walking `parentId` (deleted families included,
/// D8); cycle-safe and capped one past [maxBranchDepth].
Future<int> _depth(Session session, Family family) async {
  final seen = {family.id!};
  var depth = 0;
  var cursor = family;
  while (cursor.parentId != null && depth <= maxBranchDepth) {
    final up = await Family.db.findById(session, cursor.parentId!);
    if (up == null || !seen.add(up.id!)) break;
    depth++;
    cursor = up;
  }
  return depth;
}

/// [key] is already in `blob_deletions` (replaced or rejected), so it must
/// never become a live reference again.
Future<bool> _isQueuedForDeletion(
  Session session,
  String key, {
  Transaction? transaction,
}) async =>
    await BlobDeletion.db.count(
      session,
      where: (b) => b.key.equals(key),
      transaction: transaction,
    ) >
    0;

AppException _uploadGone() => AppException(
  code: AppErrorCode.storageFailed,
  message: 'upload not found',
);

/// The MIME type a cover [key] of [familyId] names by its extension;
/// VALIDATION for any key the server could not have issued for this family.
String _coverKeyMime(UuidValue familyId, String key) {
  final prefix = 'families/$familyId/cover/';
  final match = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$',
  ).firstMatch(key.startsWith(prefix) ? key.substring(prefix.length) : '');
  if (match == null) throw validation('invalid cover key');
  return _mimeByExt[match.group(1)]!;
}
