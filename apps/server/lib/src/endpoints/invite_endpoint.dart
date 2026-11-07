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
}
