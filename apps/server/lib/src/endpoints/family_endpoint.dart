import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';

/// A soft-deleted family can be recovered for this long (business-rules.md
/// §3.5); the 3f purge removes it afterwards.
const recoveryWindow = Duration(days: 60);

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
  Future<FamilyDetailDto?> detail(Session session, UuidValue familyId) async {
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
