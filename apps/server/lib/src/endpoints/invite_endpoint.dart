import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../invites/invites.dart';

/// Postgres errors an invite insert can hit when a row it refers to changes
/// underneath it (person or family deleted: FK; token hash collision:
/// unique). They map to `VALIDATION: Could not create invite`.
const _inviteInsertRefusals = {'23503', '23505'};

/// Invites (business-rules.md §2.9, §3.4; decisions D2, D3, D6a, D6b).
class InviteEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Any live member invites (D3). [email] is trimmed and lower-cased; blank
  /// means a link-only invite. The raw token is returned once; only its hash
  /// is stored.
  Future<CreatedInviteDto> create(
    Session session,
    UuidValue familyId, {
    String? email,
    UuidValue? personId,
  }) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(familyId, message: 'Not a family member');
    final family = (await Family.db.findById(session, familyId))!;
    if (personId != null) {
      await _requireInvitablePerson(session, family, personId);
    }
    final normalized = email == null ? '' : normalizeEmail(email);
    final origin = inviteAppOrigin(session);
    final token = newInviteToken();
    final now = DateTime.now().toUtc();
    final Invite invite;
    try {
      invite = await Invite.db.insertRow(
        session,
        Invite(
          familyId: familyId,
          treeId: family.treeId,
          personId: personId,
          email: normalized.isEmpty ? null : normalized,
          tokenHash: hashInviteToken(token),
          invitedById: uid,
          lastSentAt: now,
          expiresAt: now.add(inviteLifetime),
          createdAt: now,
        ),
      );
    } on DatabaseQueryException catch (e) {
      if (!_inviteInsertRefusals.contains(e.code)) rethrow;
      throw validation('Could not create invite');
    }
    return CreatedInviteDto(
      inviteId: invite.id!,
      token: token,
      expiresAt: invite.expiresAt,
      inviteUrl: buildInviteUrl(origin, token),
    );
  }

  /// `assert_invite_person`: the person is in the family's tree (unknown and
  /// out-of-tree give the same NOT_FOUND), unlinked and not passed away.
  Future<void> _requireInvitablePerson(
    Session session,
    Family family,
    UuidValue personId,
  ) async {
    final person = await Person.db.findById(session, personId);
    if (person == null || person.treeId != family.treeId) {
      throw notFound('person not found');
    }
    if (person.userId != null) throw validation('person is already linked');
    if (person.passedAway) throw validation('person has passed');
  }

  /// Any live member emails a pending invite. [token] is the raw token from
  /// [create]: only its hash is stored, so the link can't be rebuilt without
  /// it.
  Future<void> sendEmail(
    Session session,
    UuidValue inviteId,
    String token,
  ) async {
    final invite = await Invite.db.findById(session, inviteId);
    if (invite == null) throw notFound('Invite not found');
    await Authz(
      session,
    ).requireLiveMember(invite.familyId, message: 'Not a family member');
    final trimmed = token.trim();
    if (!inviteTokenMatches(trimmed, invite.tokenHash)) throw inviteInvalid();
    if (invite.acceptedAt != null || invite.revokedAt != null) {
      throw inviteInvalid('Invite is not pending');
    }
    if (isInviteExpired(invite, DateTime.now().toUtc())) throw inviteExpired();
    final to = invite.email;
    if (to == null) throw validation('Invite has no email address to send to');
    final family = (await Family.db.findById(session, invite.familyId))!;
    await deliverInviteMail(
      session,
      inviteMail(
        to: to,
        familyName: family.name,
        inviteUrl: buildInviteUrl(inviteAppOrigin(session), trimmed),
      ),
    );
  }

  /// Joins the invite's family and returns its id. Single transaction:
  /// membership, person link, invite marked accepted. A double-tapped accept
  /// that loses the linked-person race reruns once and finds the committed
  /// person.
  Future<UuidValue> accept(Session session, String token) async {
    final uid = Authz(session).requireUser();
    final trimmed = token.trim();
    if (trimmed.isEmpty) throw validation('token is required');
    final tokenHash = hashInviteToken(trimmed);
    try {
      return await _accept(session, uid, tokenHash);
    } on DatabaseQueryException catch (e) {
      if (e.code != '23505' || e.constraintName != 'people_tree_user_uidx') {
        rethrow;
      }
      return _accept(session, uid, tokenHash);
    }
  }

  Future<UuidValue> _accept(
    Session session,
    UuidValue uid,
    String tokenHash,
  ) => session.db.transaction((t) async {
    final invite = await Invite.db.findFirstRow(
      session,
      where: (i) => i.tokenHash.equals(tokenHash),
      transaction: t,
      lockMode: LockMode.forUpdate,
    );
    if (invite == null) throw inviteInvalid();
    final family = await Family.db.findById(
      session,
      invite.familyId,
      transaction: t,
    );
    // D6a, then D2; both before the accepted/re-entry check.
    if (family == null || family.deletedAt != null) throw inviteInvalid();
    final invitedEmail = invite.email;
    if (invitedEmail != null &&
        invitedEmail != await accountEmail(session, uid, transaction: t)) {
      throw inviteInvalid('Invite was sent to a different email');
    }

    final existing = await Membership.db.findFirstRow(
      session,
      where: (m) => m.familyId.equals(family.id!) & m.userId.equals(uid),
      transaction: t,
    );
    if (invite.acceptedAt != null) {
      if (invite.acceptedById != uid) throw inviteAccepted();
      if (existing == null) throw validation('Could not check membership');
      return family.id!;
    }
    if (invite.revokedAt != null) throw inviteInvalid();
    final now = DateTime.now().toUtc();
    if (isInviteExpired(invite, now)) throw inviteExpired();

    // No demotion: an existing member keeps their role.
    if (existing == null) {
      try {
        await Membership.db.insertRow(
          session,
          Membership(familyId: family.id!, userId: uid),
          transaction: t,
        );
      } on DatabaseQueryException catch (e) {
        if (e.code != '23505' ||
            e.constraintName != 'memberships_family_user_uidx') {
          rethrow;
        }
        throw validation('Could not create membership');
      }
    }

    await _linkPerson(session, invite, family, uid, now, t);

    await Invite.db.updateRow(
      session,
      invite.copyWith(acceptedAt: now, acceptedById: uid),
      transaction: t,
    );
    return family.id!;
  });

  /// Links the invited person when it is still unlinked and the caller has
  /// no linked person in the tree; otherwise makes sure the caller has one.
  Future<void> _linkPerson(
    Session session,
    Invite invite,
    Family family,
    UuidValue uid,
    DateTime now,
    Transaction t,
  ) async {
    final personId = invite.personId;
    final target = personId == null
        ? null
        : await Person.db.findById(
            session,
            personId,
            transaction: t,
            lockMode: LockMode.forUpdate,
          );
    final alreadyLinked = await Person.db.findFirstRow(
      session,
      where: (p) => p.treeId.equals(family.treeId) & p.userId.equals(uid),
      transaction: t,
    );
    if (target != null && target.userId == null && alreadyLinked == null) {
      final appUser = await AppUser.db.findFirstRow(
        session,
        where: (u) => u.authUserId.equals(uid),
        transaction: t,
      );
      final displayName = appUser?.displayName?.trim() ?? '';
      await Person.db.updateRow(
        session,
        target.copyWith(
          userId: uid,
          name: displayName.isEmpty ? target.name : displayName,
          updatedAt: now,
        ),
        transaction: t,
      );
      return;
    }
    await ensureLinkedPerson(
      session,
      treeId: family.treeId,
      homeFamilyId: family.id!,
      userId: uid,
      transaction: t,
    );
  }

  /// Owner or co-owner: rotates the token, moves `expiresAt` to now + 7 days
  /// (reviving an expired pending invite) and emails the new link. When the
  /// email fails the token stays rotated, so a retry is safe.
  Future<DateTime> resend(Session session, UuidValue inviteId) async {
    requireInviteMailConfigured(session);
    final authz = Authz(session);
    final origin = inviteAppOrigin(session);
    final (invite, token) = await session.db.transaction((t) async {
      final row = await Invite.db.findById(
        session,
        inviteId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (row == null) throw notFound('invite not found');
      await authz.requireLiveSteward(row.familyId);
      if (row.acceptedAt != null || row.revokedAt != null) {
        throw inviteInvalid('invite is not pending');
      }
      if (row.email == null) throw validation('invite has no email address');
      final token = newInviteToken();
      final now = DateTime.now().toUtc();
      final updated = await Invite.db.updateRow(
        session,
        row.copyWith(
          tokenHash: hashInviteToken(token),
          lastSentAt: now,
          expiresAt: now.add(inviteLifetime),
        ),
        transaction: t,
      );
      return (updated, token);
    });
    final family = (await Family.db.findById(session, invite.familyId))!;
    await deliverInviteMail(
      session,
      inviteMail(
        to: invite.email!,
        familyName: family.name,
        inviteUrl: buildInviteUrl(origin, token),
      ),
    );
    return invite.expiresAt;
  }

  /// Owner or co-owner. The row and its token hash stay, so accepting that
  /// token later fails INVITE_INVALID. Revoking twice is a no-op.
  Future<void> revoke(Session session, UuidValue inviteId) async {
    final authz = Authz(session);
    await session.db.transaction((t) async {
      final row = await Invite.db.findById(
        session,
        inviteId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (row == null) throw notFound('invite not found');
      await authz.requireLiveSteward(row.familyId);
      if (row.acceptedAt != null) throw inviteInvalid('invite is not pending');
      if (row.revokedAt != null) return;
      await Invite.db.updateRow(
        session,
        row.copyWith(revokedAt: DateTime.now().toUtc()),
        transaction: t,
      );
    });
  }
}
