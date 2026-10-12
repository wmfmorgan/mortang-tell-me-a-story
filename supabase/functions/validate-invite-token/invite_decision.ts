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

  const base = {
    family_id: invite.family_id,
    family_name: invite.family_name,
    inviter_name: invite.inviter_name,
    status: invite.status,
    expires_at: invite.expires_at,
  };

  if (invite.family_deleted) {
    return {
      valid: false,
      code: "INVITE_INVALID",
      message: "Invite is not valid",
      ...base,
    };
  }

  if (invite.status === "accepted") {
    return {
      valid: false,
      code: "INVITE_ACCEPTED",
      message: "Invite already used",
      ...base,
    };
  }

  if (invite.status === "revoked" || invite.status === "expired") {
    return {
      valid: false,
      code: "INVITE_INVALID",
      message: "Invite is not valid",
      ...base,
    };
  }

  if (new Date(invite.expires_at).getTime() <= now) {
    return {
      valid: false,
      code: "INVITE_EXPIRED",
      message: "Invite link expired",
      ...base,
    };
  }

  return {
    valid: true,
    code: null,
    message: null,
    ...base,
  };
}
