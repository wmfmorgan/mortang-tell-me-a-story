import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import {
  bearerToken,
  buildInviteUrl,
  serviceClient,
  userClient,
} from "../_shared/supabase.ts";

Deno.serve(async (req) => {
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

  let body: { family_id?: string; email?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("VALIDATION", "Invalid JSON body", 400);
  }

  const familyId = body.family_id?.trim();
  if (!familyId) {
    return errorResponse("VALIDATION", "family_id is required", 400);
  }
  const email = body.email?.trim() || null;

  const userSb = userClient(auth);
  const {
    data: { user },
    error: userErr,
  } = await userSb.auth.getUser();
  if (userErr || !user) {
    return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  }

  const { data: member, error: memberErr } = await userSb.rpc(
    "is_family_member",
    { fid: familyId },
  );
  if (memberErr || member !== true) {
    return errorResponse("FORBIDDEN", "Not a family member", 403);
  }

  const token = crypto.randomUUID().replace(/-/g, "") +
    crypto.randomUUID().replace(/-/g, "");

  const admin = serviceClient();
  const { data: invite, error: insertErr } = await admin
    .from("invites")
    .insert({
      family_id: familyId,
      invited_by: user.id,
      email,
      token,
      status: "pending",
    })
    .select("id, token, expires_at")
    .single();

  if (insertErr || !invite) {
    return errorResponse(
      "VALIDATION",
      insertErr?.message ?? "Could not create invite",
      400,
    );
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
});
