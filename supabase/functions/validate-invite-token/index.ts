import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return errorResponse("VALIDATION", "Method not allowed", 405);
  }

  const url = new URL(req.url);
  const token = url.searchParams.get("token")?.trim();
  if (!token) {
    return jsonResponse({
      valid: false,
      code: "VALIDATION",
      message: "token is required",
    });
  }

  const admin = serviceClient();
  const { data: invite, error } = await admin
    .from("invites")
    .select("id, family_id, status, expires_at, families(name)")
    .eq("token", token)
    .maybeSingle();

  if (error) {
    return errorResponse("VALIDATION", error.message, 400);
  }
  if (!invite) {
    return jsonResponse({
      valid: false,
      code: "INVITE_INVALID",
      message: "Invite is not valid",
    });
  }

  if (invite.status === "accepted") {
    return jsonResponse({
      valid: false,
      code: "INVITE_ACCEPTED",
      message: "Invite already used",
      status: invite.status,
      expires_at: invite.expires_at,
    });
  }

  if (invite.status === "revoked" || invite.status === "expired") {
    return jsonResponse({
      valid: false,
      code: "INVITE_INVALID",
      message: "Invite is not valid",
      status: invite.status,
      expires_at: invite.expires_at,
    });
  }

  if (new Date(invite.expires_at).getTime() <= Date.now()) {
    return jsonResponse({
      valid: false,
      code: "INVITE_EXPIRED",
      message: "Invite link expired",
      status: invite.status,
      expires_at: invite.expires_at,
    });
  }

  const familyName = Array.isArray(invite.families)
    ? invite.families[0]?.name
    : (invite.families as { name?: string } | null)?.name;

  return jsonResponse({
    valid: true,
    family_id: invite.family_id,
    family_name: familyName ?? null,
    status: invite.status,
    expires_at: invite.expires_at,
  });
});
