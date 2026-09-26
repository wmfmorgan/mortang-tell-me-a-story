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

  let body: { invite_id?: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse("VALIDATION", "Invalid JSON body", 400);
  }
  const inviteId = body.invite_id?.trim();
  if (!inviteId) {
    return errorResponse("VALIDATION", "invite_id is required", 400);
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
    .select("id, family_id, email, token, status, expires_at, families(name)")
    .eq("id", inviteId)
    .maybeSingle();

  if (inviteErr || !invite) {
    return errorResponse("NOT_FOUND", "Invite not found", 404);
  }

  const { data: isMember } = await userSb.rpc("is_family_member", {
    fid: invite.family_id,
  });
  if (isMember !== true) {
    return errorResponse("FORBIDDEN", "Not a family member", 403);
  }

  if (invite.status !== "pending") {
    return errorResponse("INVITE_INVALID", "Invite is not pending", 400);
  }
  if (new Date(invite.expires_at).getTime() <= Date.now()) {
    return errorResponse("INVITE_EXPIRED", "Invite link expired", 400);
  }
  if (!invite.email) {
    return errorResponse(
      "VALIDATION",
      "Invite has no email address to send to",
      400,
    );
  }

  const resendKey = Deno.env.get("RESEND_API_KEY")?.trim();
  if (!resendKey) {
    return errorResponse(
      "VALIDATION",
      "RESEND_API_KEY is not configured (OPEN Bill)",
      503,
    );
  }

  const familyName = Array.isArray(invite.families)
    ? invite.families[0]?.name
    : (invite.families as { name?: string } | null)?.name;
  const inviteUrl = buildInviteUrl(invite.token);
  const from = Deno.env.get("RESEND_FROM")?.trim() ||
    "Tell Me a Story <onboarding@resend.dev>";

  const html = `
    <p>You're invited to join <strong>${escapeHtml(familyName ?? "a family")}</strong> on Tell Me a Story.</p>
    <p><a href="${inviteUrl}">Accept the invite</a></p>
    <p>This link expires in 7 days and can only be used once.</p>
  `;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [invite.email],
      subject: `Invite to ${familyName ?? "the family"}`,
      html,
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    return errorResponse(
      "VALIDATION",
      `Could not send invite email: ${detail}`,
      502,
    );
  }

  return jsonResponse({ sent: true });
});

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
