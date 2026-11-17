import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { readJsonObject } from "../_shared/json_object.ts";
import { mapRpcError, textField } from "../_shared/manage.ts";
import {
  bearerToken,
  buildInviteUrl,
  serviceClient,
  userClient,
} from "../_shared/supabase.ts";

type InviteInsert = {
  id: string;
  token: string;
  expires_at: string;
};

export type CreateInviteDb = {
  userId: () => Promise<string | null>;
  isFamilyMember: (
    familyId: string,
  ) => Promise<{ member: boolean; error: string | null }>;
  assertPerson: (
    familyId: string,
    personId: string,
  ) => Promise<string | null>;
  insertInvite: (row: {
    familyId: string;
    invitedBy: string;
    email: string | null;
    personId: string | null;
    token: string;
  }) => Promise<{ invite: InviteInsert | null; error: string | null }>;
};

function liveDb(auth: string): CreateInviteDb {
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
    async isFamilyMember(familyId) {
      const { data, error } = await userSb.rpc("is_family_member", {
        fid: familyId,
      });
      return { member: data === true, error: error?.message ?? null };
    },
    async assertPerson(familyId, personId) {
      const { error } = await userSb.rpc("assert_invite_person", {
        p_family_id: familyId,
        p_person_id: personId,
      });
      return error?.message ?? null;
    },
    async insertInvite(row) {
      const { data, error } = await admin
        .from("invites")
        .insert({
          family_id: row.familyId,
          invited_by: row.invitedBy,
          email: row.email,
          person_id: row.personId,
          token: row.token,
          status: "pending",
        })
        .select("id, token, expires_at")
        .single();
      return {
        invite: (data as InviteInsert | null) ?? null,
        error: error?.message ?? null,
      };
    },
  };
}

const inviteEmailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function inviteFields(body: Record<string, unknown>): {
  familyId: string;
  email: string | null;
  personId: string | null;
} | Response {
  const familyId = textField(body, "family_id");
  if (!familyId) {
    return errorResponse("VALIDATION", "family_id is required", 400);
  }
  const email = textField(body, "email");
  if (email.length > 0 && !inviteEmailPattern.test(email)) {
    return errorResponse(
      "VALIDATION",
      "Please enter a full email address.",
      400,
    );
  }
  const personId = textField(body, "person_id");
  return {
    familyId,
    email: email.length > 0 ? email : null,
    personId: personId.length > 0 ? personId : null,
  };
}

export function createInvite(
  req: Request,
  options?: { db?: CreateInviteDb },
): Promise<Response> {
  return handleCreateInvite(req, options?.db);
}

async function handleCreateInvite(
  req: Request,
  db?: CreateInviteDb,
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

  const parsed = await readJsonObject(req);
  if (parsed instanceof Response) return parsed;
  const fields = inviteFields(parsed);
  if (fields instanceof Response) return fields;
  const { familyId, email, personId } = fields;

  const store = db ?? liveDb(auth);
  const userId = await store.userId();
  if (!userId) {
    return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  }

  const member = await store.isFamilyMember(familyId);
  if (member.error || !member.member) {
    return errorResponse("FORBIDDEN", "Not a family member", 403);
  }

  if (personId) {
    const personErr = await store.assertPerson(familyId, personId);
    if (personErr) return mapRpcError(personErr);
  }

  const token = crypto.randomUUID().replace(/-/g, "") +
    crypto.randomUUID().replace(/-/g, "");
  const { invite, error: insertErr } = await store.insertInvite({
    familyId,
    invitedBy: userId,
    email,
    personId,
    token,
  });
  if (insertErr || !invite) {
    console.error("create-invite insert failed", insertErr);
    return errorResponse("VALIDATION", "Could not create invite", 400);
  }

  return jsonResponse(
    {
      invite_id: invite.id,
      token: invite.token,
      expires_at: invite.expires_at,
      invite_url: buildInviteUrl(invite.token),
    },
    201,
  );
}

if (import.meta.main) {
  Deno.serve((req) => createInvite(req));
}
