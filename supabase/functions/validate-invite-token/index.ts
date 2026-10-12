import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { decideInvite } from "./invite_decision.ts";

function embedName(value: unknown): string | null {
  const row = Array.isArray(value) ? value[0] : value;
  if (!row || typeof row !== "object") return null;
  const name = (row as { name?: string; display_name?: string }).name
    ?? (row as { display_name?: string }).display_name;
  if (typeof name !== "string") return null;
  const trimmed = name.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function embedDeleted(value: unknown): boolean {
  const row = Array.isArray(value) ? value[0] : value;
  if (!row || typeof row !== "object") return false;
  return (row as { deleted_at?: string | null }).deleted_at != null;
}

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
      family_id: null,
      family_name: null,
      inviter_name: null,
      status: null,
      expires_at: null,
    });
  }

  const admin = serviceClient();
  const { data: invite, error } = await admin
    .from("invites")
    .select(
      "id, family_id, status, expires_at, families(name, deleted_at), profiles!invited_by(display_name)",
    )
    .eq("token", token)
    .maybeSingle();

  if (error) {
    return errorResponse("VALIDATION", error.message, 400);
  }

  const row = invite as {
    family_id: string;
    status: string;
    expires_at: string;
    families: unknown;
    profiles: unknown;
  } | null;

  return jsonResponse(
    decideInvite(
      row
        ? {
          family_id: row.family_id,
          status: row.status,
          expires_at: row.expires_at,
          family_name: embedName(row.families),
          family_deleted: embedDeleted(row.families),
          inviter_name: embedName(row.profiles),
        }
        : null,
    ),
  );
});
