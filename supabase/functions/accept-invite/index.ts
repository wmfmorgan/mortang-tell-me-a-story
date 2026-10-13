import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { mapRpcError } from "../_shared/manage.ts";
import { bearerToken, serviceClient, userClient } from "../_shared/supabase.ts";

const MEMBERSHIP_CHECK_FAILED = "Could not check membership";
const MEMBERSHIP_CREATE_FAILED = "Could not create membership";

type InviteRow = {
  id: string;
  family_id: string;
  status: string;
  expires_at: string;
  person_id: string | null;
  accepted_by: string | null;
};

export type AcceptInviteDb = {
  userId: () => Promise<string | null>;
  inviteByToken: (
    token: string,
  ) => Promise<{ row: InviteRow | null; error: string | null }>;
  membershipId: (
    familyId: string,
    userId: string,
  ) => Promise<{ id: string | null; error: string | null }>;
  insertMember: (
    familyId: string,
    userId: string,
  ) => Promise<{ id: string | null; error: string | null }>;
  linkPerson: (personId: string) => Promise<string | null>;
  markAccepted: (inviteId: string, userId: string) => Promise<string | null>;
};

function liveDb(auth: string): AcceptInviteDb {
  const userSb = userClient(auth);
  const admin = serviceClient();
  return {
    async userId() {
      const {
        data: { user },
        error,
      } = await userSb.auth.getUser();
      if (error || !user) return null;
      return user.id;
    },
    async inviteByToken(token) {
      const { data, error } = await admin
        .from("invites")
        .select("id, family_id, status, expires_at, person_id, accepted_by")
        .eq("token", token)
        .maybeSingle();
      return {
        row: (data as InviteRow | null) ?? null,
        error: error?.message ?? null,
      };
    },
    async membershipId(familyId, userId) {
      const { data, error } = await admin
        .from("memberships")
        .select("id")
        .eq("family_id", familyId)
        .eq("user_id", userId)
        .maybeSingle();
      return {
        id: (data?.id as string | undefined) ?? null,
        error: error?.message ?? null,
      };
    },
    async insertMember(familyId, userId) {
      const { data, error } = await admin
        .from("memberships")
        .insert({
          family_id: familyId,
          user_id: userId,
          role: "member",
        })
        .select("id")
        .single();
      return {
        id: (data?.id as string | undefined) ?? null,
        error: error?.message ?? null,
      };
    },
    async linkPerson(personId) {
      const { error } = await userSb.rpc("link_accepted_person", {
        p_person_id: personId,
      });
      return error?.message ?? null;
    },
    async markAccepted(inviteId, userId) {
      const { error } = await admin
        .from("invites")
        .update({
          status: "accepted",
          accepted_by: userId,
          accepted_at: new Date().toISOString(),
        })
        .eq("id", inviteId)
        .eq("status", "pending");
      return error?.message ?? null;
    },
  };
}

export function acceptInvite(
  req: Request,
  options?: { db?: AcceptInviteDb },
): Promise<Response> {
  return handleAcceptInvite(req, options?.db);
}

async function handleAcceptInvite(
  req: Request,
  db?: AcceptInviteDb,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("VALIDATION", "Method not allowed", 405);
  }

  const auth = bearerToken(req);
  if (!auth) {
    return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  }

  let body: { token?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("VALIDATION", "Invalid JSON body", 400);
  }
  const token = body.token?.trim();
  if (!token) {
    return errorResponse("VALIDATION", "token is required", 400);
  }

  const store = db ?? liveDb(auth);
  const userId = await store.userId();
  if (!userId) {
    return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  }

  const { row: invite, error: inviteErr } = await store.inviteByToken(token);
  if (inviteErr) {
    return errorResponse("VALIDATION", inviteErr, 400);
  }
  if (!invite) {
    return errorResponse("INVITE_INVALID", "Invite is not valid", 400);
  }
  if (invite.status === "accepted") {
    // The magic-link return opens this invite again after the first accept.
    // The same person continues into the family. Anyone else still sees it used.
    if (invite.accepted_by === userId) {
      const again = await store.membershipId(invite.family_id, userId);
      if (again.error || !again.id) {
        return errorResponse("VALIDATION", MEMBERSHIP_CHECK_FAILED, 400);
      }
      return jsonResponse({
        family_id: invite.family_id,
        membership_id: again.id,
      });
    }
    return errorResponse("INVITE_ACCEPTED", "Invite already used", 400);
  }
  if (invite.status !== "pending") {
    return errorResponse("INVITE_INVALID", "Invite is not valid", 400);
  }
  if (new Date(invite.expires_at).getTime() <= Date.now()) {
    return errorResponse("INVITE_EXPIRED", "Invite link expired", 400);
  }

  // Keep an existing role. Inserting role=member demotes an owner who
  // opens their own invite.
  const existing = await store.membershipId(invite.family_id, userId);
  if (existing.error) {
    return errorResponse("VALIDATION", MEMBERSHIP_CHECK_FAILED, 400);
  }

  let membershipId = existing.id ?? undefined;
  if (!membershipId) {
    const created = await store.insertMember(invite.family_id, userId);
    if (created.error || !created.id) {
      return errorResponse("VALIDATION", MEMBERSHIP_CREATE_FAILED, 400);
    }
    membershipId = created.id;
  }

  if (invite.person_id) {
    const linkErr = await store.linkPerson(invite.person_id);
    if (linkErr) {
      if (linkErr.trim().startsWith("NOT_FOUND:")) {
        return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
      }
      return mapRpcError(linkErr);
    }
  }

  const updErr = await store.markAccepted(invite.id, userId);
  if (updErr) {
    return errorResponse("VALIDATION", updErr, 400);
  }

  return jsonResponse({
    family_id: invite.family_id,
    membership_id: membershipId,
  });
}

if (import.meta.main) {
  Deno.serve((req) => acceptInvite(req));
}
