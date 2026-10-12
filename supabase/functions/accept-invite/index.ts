import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { bearerToken, serviceClient, userClient } from "../_shared/supabase.ts";

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

  const userSb = userClient(auth);
  const {
    data: { user },
    error: userErr,
  } = await userSb.auth.getUser();
  if (userErr || !user) {
    return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  }

  const admin = serviceClient();
  const { data: invite, error: inviteErr } = await admin
    .from("invites")
    .select("id, family_id, status, expires_at")
    .eq("token", token)
    .maybeSingle();

  if (inviteErr) {
    return errorResponse("VALIDATION", inviteErr.message, 400);
  }
  if (!invite) {
    return errorResponse("INVITE_INVALID", "Invite is not valid", 400);
  }
  if (invite.status === "accepted") {
    return errorResponse("INVITE_ACCEPTED", "Invite already used", 400);
  }
  if (invite.status !== "pending") {
    return errorResponse("INVITE_INVALID", "Invite is not valid", 400);
  }
  if (new Date(invite.expires_at).getTime() <= Date.now()) {
    return errorResponse("INVITE_EXPIRED", "Invite link expired", 400);
  }

  // Keep an existing role. Upserting role=member demotes an owner who
  // opens their own invite.
  const { data: existing, error: existingErr } = await admin
    .from("memberships")
    .select("id")
    .eq("family_id", invite.family_id)
    .eq("user_id", user.id)
    .maybeSingle();

  if (existingErr) {
    return errorResponse("VALIDATION", existingErr.message, 400);
  }

  let membershipId = existing?.id as string | undefined;
  if (!membershipId) {
    const { data: membership, error: memErr } = await admin
      .from("memberships")
      .insert({
        family_id: invite.family_id,
        user_id: user.id,
        role: "member",
      })
      .select("id")
      .single();

    if (memErr || !membership) {
      return errorResponse(
        "VALIDATION",
        memErr?.message ?? "Could not create membership",
        400,
      );
    }
    membershipId = membership.id;
  }

  // 4. Mark invite accepted (single-use)
  const { error: updErr } = await admin
    .from("invites")
    .update({
      status: "accepted",
      accepted_by: user.id,
      accepted_at: new Date().toISOString(),
    })
    .eq("id", invite.id)
    .eq("status", "pending");

  if (updErr) {
    return errorResponse("VALIDATION", updErr.message, 400);
  }

  return jsonResponse({
    family_id: invite.family_id,
    membership_id: membershipId,
  });
});
