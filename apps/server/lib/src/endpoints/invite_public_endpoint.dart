import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../invites/invites.dart';

/// The anonymous invite landing (business-rules.md §3.4, validate).
class InvitePublicEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Anyone, signed in or not. An unknown token, a soft-deleted family (D6a),
  /// an accepted, revoked or expired invite all give `valid: false` with no
  /// family or inviter.
  Future<InvitePreviewDto> preview(Session session, String token) async {
    final invalid = InvitePreviewDto(valid: false);
    final trimmed = token.trim();
    if (trimmed.isEmpty) return invalid;
    final invite = await Invite.db.findFirstRow(
      session,
      where: (t) => t.tokenHash.equals(hashInviteToken(trimmed)),
    );
    if (invite == null) return invalid;
    final family = await Family.db.findById(session, invite.familyId);
    if (family == null || family.deletedAt != null) return invalid;
    if (invite.acceptedAt != null ||
        invite.revokedAt != null ||
        isInviteExpired(invite, DateTime.now().toUtc())) {
      return invalid;
    }
    final inviterId = invite.invitedById;
    final inviter = inviterId == null
        ? null
        : await AppUser.db.findFirstRow(
            session,
            where: (t) => t.authUserId.equals(inviterId),
          );
    final inviterName = inviter?.displayName?.trim() ?? '';
    return InvitePreviewDto(
      valid: true,
      familyId: family.id,
      familyName: family.name,
      inviterName: inviterName.isEmpty ? null : inviterName,
    );
  }
}
