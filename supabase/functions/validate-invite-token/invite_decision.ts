export type InviteDecision = {
  valid: boolean;
  code: string | null;
  message: string | null;
  family_id: string | null;
  family_name: string | null;
  inviter_name: string | null;
  status: string | null;
  expires_at: string | null;
};

export type InviteRow = {
  family_id: string;
  status: string;
  expires_at: string;
  family_name: string | null;
  family_deleted: boolean;
  inviter_name: string | null;
};

export function decideInvite(
  invite: InviteRow | null,
  now = Date.now(),
): InviteDecision {
  if (!invite) {
    return {
      valid: false,
      code: "INVITE_INVALID",
      message: "Invite is not valid",
      family_id: null,
      family_name: null,
      inviter_name: null,
      status: null,
      expires_at: null,
    };
  }

  const status = invite.status;
  const expiresAt = invite.expires_at;

  if (invite.family_deleted) {
    return invalid("INVITE_INVALID", "Invite is not valid", status, expiresAt);
  }

  if (invite.status === "accepted") {
    return invalid("INVITE_ACCEPTED", "Invite already used", status, expiresAt);
  }

  if (invite.status === "revoked" || invite.status === "expired") {
    return invalid("INVITE_INVALID", "Invite is not valid", status, expiresAt);
  }

  if (new Date(invite.expires_at).getTime() <= now) {
    return invalid("INVITE_EXPIRED", "Invite link expired", status, expiresAt);
  }

  return {
    valid: true,
    code: null,
    message: null,
    family_id: invite.family_id,
    family_name: invite.family_name,
    inviter_name: invite.inviter_name,
    status,
    expires_at: expiresAt,
  };
}

function invalid(
  code: string,
  message: string,
  status: string | null,
  expiresAt: string | null,
): InviteDecision {
  return {
    valid: false,
    code,
    message,
    family_id: null,
    family_name: null,
    inviter_name: null,
    status,
    expires_at: expiresAt,
  };
}
