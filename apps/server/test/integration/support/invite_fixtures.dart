import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/invites/invites.dart';

import 'fixtures.dart';

/// Slice 3e row builders and lookups.
extension InviteFx on Fx {
  /// An invite stored the way `InviteEndpoint.create` stores it, plus its raw
  /// token. [expired] backdates it so `expiresAt` is a day in the past.
  Future<({Invite invite, String token})> tokenInvite(
    Family family, {
    String? email,
    UuidValue? personId,
    UuidValue? invitedById,
    UuidValue? acceptedById,
    bool revoked = false,
    bool expired = false,
  }) async {
    final token = newInviteToken();
    final now = DateTime.now().toUtc();
    final created = expired ? now.subtract(const Duration(days: 8)) : now;
    final invite = await Invite.db.insertRow(
      s,
      Invite(
        familyId: family.id!,
        treeId: family.treeId,
        personId: personId,
        email: email,
        tokenHash: hashInviteToken(token),
        invitedById: invitedById,
        acceptedById: acceptedById,
        acceptedAt: acceptedById == null ? null : now,
        revokedAt: revoked ? now : null,
        lastSentAt: created,
        createdAt: created,
        expiresAt: created.add(inviteLifetime),
      ),
    );
    return (invite: invite, token: token);
  }

  Future<Invite> reload(Invite invite) async =>
      (await Invite.db.findById(s, invite.id!))!;

  Future<Membership?> membershipOf(Family family, UuidValue user) =>
      Membership.db.findFirstRow(
        s,
        where: (t) => t.familyId.equals(family.id!) & t.userId.equals(user),
      );

  /// People linked to [user] in [treeId] (at most one: people_tree_user_uidx).
  Future<List<Person>> linkedPeople(UuidValue treeId, UuidValue user) =>
      Person.db.find(
        s,
        where: (t) => t.treeId.equals(treeId) & t.userId.equals(user),
      );

  Future<int> inviteCount(Family family) =>
      Invite.db.count(s, where: (t) => t.familyId.equals(family.id!));
}
