import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { readJsonObject } from "../_shared/json_object.ts";
import { mapRpcError } from "../_shared/manage.ts";
import { bearerToken, serviceClient, userClient } from "../_shared/supabase.ts";

const MEMBERSHIP_CHECK_FAILED = "Could not check membership";
const MEMBERSHIP_CREATE_FAILED = "Could not create membership";
const INVITE_LOOKUP_FAILED = "Could not look up invite";
const INVITE_NOT_VALID = "INVITE_INVALID: Invite is not valid";

type InviteRow = {
  id: string;
  family_id: string;
  status: string;
  expires_at: string;
  person_id: string | null;
  accepted_by: string | null;
  email: string | null;
  family_deleted: boolean;
};

type Session = { id: string | null; email: string | null };

export type AcceptInviteDb = {
  userId: () => Promise<string | null>;
  userEmail: () => Promise<string | null>;
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
  claimInvite: (inviteId: string, userId: string) => Promise<string | null>;
};

function liveDb(auth: string): AcceptInviteDb {
  const userSb = userClient(auth);
  const admin = serviceClient();
  let session: Promise<Session> | undefined;
  const loadSession = () => {
    session ??= userSb.auth.getUser().then(({ data, error }) => {
      const user = error ? null : data.user;
      if (!user) return { id: null, email: null };
      return { id: user.id, email: user.email ?? null };
    });
    return session;
  };
  return {
    userId: async () => (await loadSession()).id,
    userEmail: async () => (await loadSession()).email,
    inviteByToken: (token) => inviteByToken(admin, token),
    membershipId: (familyId, userId) => membershipId(admin, familyId, userId),
    insertMember: (familyId, userId) => insertMember(admin, familyId, userId),
    claimInvite: (inviteId, userId) => claimInvite(admin, inviteId, userId),
  };
}

async function inviteByToken(
  admin: ReturnType<typeof serviceClient>,
  token: string,
): Promise<{ row: InviteRow | null; error: string | null }> {
  const { data, error } = await admin
    .from("invites")
    .select("id, family_id, status, expires_at, person_id, accepted_by, email")
    .eq("token", token)
    .maybeSingle();
  if (error) return { row: null, error: INVITE_LOOKUP_FAILED };
  if (!data) return { row: null, error: null };
  const family = await admin
    .from("families")
    .select("deleted_at")
    .eq("id", data.family_id)
    .maybeSingle();
  if (family.error) return { row: null, error: INVITE_LOOKUP_FAILED };
  return {
    row: {
      id: data.id,
      family_id: data.family_id,
      status: data.status,
      expires_at: data.expires_at,
      person_id: data.person_id,
      accepted_by: data.accepted_by,
      email: data.email,
      family_deleted: family.data?.deleted_at != null,
    },
    error: null,
  };
}

async function membershipId(
  admin: ReturnType<typeof serviceClient>,
  familyId: string,
  userId: string,
): Promise<{ id: string | null; error: string | null }> {
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
}

async function insertMember(
  admin: ReturnType<typeof serviceClient>,
  familyId: string,
  userId: string,
): Promise<{ id: string | null; error: string | null }> {
  const { data, error } = await admin
    .from("memberships")
    .insert({ family_id: familyId, user_id: userId, role: "member" })
    .select("id")
    .single();
  return {
    id: (data?.id as string | undefined) ?? null,
    error: error?.message ?? null,
  };
}

async function claimInvite(
  admin: ReturnType<typeof serviceClient>,
  inviteId: string,
  userId: string,
): Promise<string | null> {
  const { error } = await admin.rpc("link_accepted_person", {
    p_invite_id: inviteId,
    p_user_id: userId,
  });
  if (error) return error.message;
  return null;
}

export function acceptInvite(
  req: Request,
  options?: { db?: AcceptInviteDb },
): Promise<Response> {
  return handleAcceptInvite(req, options?.db);
}

function emailRefusal(
  sessionEmail: string | null,
  inviteEmail: string | null,
): Response | null {
  if (inviteEmail == null || inviteEmail.trim() === "") return null;
  const session = sessionEmail?.trim().toLowerCase() ?? "";
  if (session.length > 0 && session === inviteEmail.trim().toLowerCase()) {
    return null;
  }
  return mapRpcError(INVITE_NOT_VALID);
}

async function readToken(req: Request): Promise<string | Response> {
  const parsed = await readJsonObject(req);
  if (parsed instanceof Response) return parsed;
  const body = parsed as { token?: string };
  const token = body.token?.trim();
  if (!token) return errorResponse("VALIDATION", "token is required", 400);
  return token;
}

async function reopenAccepted(
  store: AcceptInviteDb,
  invite: InviteRow,
  userId: string,
): Promise<Response | null> {
  if (invite.status !== "accepted") return null;
  // The magic-link return opens this invite again after the first accept.
  // The same person continues into the family. Anyone else still sees it used.
  if (invite.accepted_by !== userId) {
    return errorResponse("INVITE_ACCEPTED", "Invite already used", 400);
  }
  const again = await store.membershipId(invite.family_id, userId);
  if (again.error || !again.id) {
    return errorResponse("VALIDATION", MEMBERSHIP_CHECK_FAILED, 400);
  }
  return jsonResponse({
    family_id: invite.family_id,
    membership_id: again.id,
  });
}

function rejectPending(invite: InviteRow): Response | null {
  if (invite.status !== "pending") {
    return errorResponse("INVITE_INVALID", "Invite is not valid", 400);
  }
  if (new Date(invite.expires_at).getTime() <= Date.now()) {
    return errorResponse("INVITE_EXPIRED", "Invite link expired", 400);
  }
  if (invite.family_deleted) return mapRpcError(INVITE_NOT_VALID);
  return null;
}

async function ensureMembership(
  store: AcceptInviteDb,
  invite: InviteRow,
  userId: string,
): Promise<string | Response> {
  // Keep an existing role. Inserting role=member demotes an owner who
  // opens their own invite.
  const existing = await store.membershipId(invite.family_id, userId);
  if (existing.error) {
    return errorResponse("VALIDATION", MEMBERSHIP_CHECK_FAILED, 400);
  }
  if (existing.id) return existing.id;
  const created = await store.insertMember(invite.family_id, userId);
  if (created.error || !created.id) {
    return errorResponse("VALIDATION", MEMBERSHIP_CREATE_FAILED, 400);
  }
  return created.id;
}

async function acceptToken(
  store: AcceptInviteDb,
  token: string,
): Promise<Response> {
  const userId = await store.userId();
  if (!userId) return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  const { row: invite, error: inviteErr } = await store.inviteByToken(token);
  if (inviteErr) return errorResponse("VALIDATION", INVITE_LOOKUP_FAILED, 400);
  if (!invite) return errorResponse("INVITE_INVALID", "Invite is not valid", 400);
  const reopened = await reopenAccepted(store, invite, userId);
  if (reopened) return reopened;
  const pending = rejectPending(invite);
  if (pending) return pending;
  const emailStop = emailRefusal(await store.userEmail(), invite.email);
  if (emailStop) return emailStop;
  const claimErr = await store.claimInvite(invite.id, userId);
  if (claimErr) return mapRpcError(claimErr);
  const membershipId = await ensureMembership(store, invite, userId);
  if (membershipId instanceof Response) return membershipId;
  return jsonResponse({
    family_id: invite.family_id,
    membership_id: membershipId,
  });
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
  if (!auth) return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  const token = await readToken(req);
  if (token instanceof Response) return token;
  return acceptToken(db ?? liveDb(auth), token);
}

if (import.meta.main) {
  Deno.serve((req) => acceptInvite(req));
}
