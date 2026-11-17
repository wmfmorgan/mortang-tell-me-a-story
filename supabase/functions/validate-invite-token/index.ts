import { corsHeaders, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { decideInvite, type InviteRow } from "./invite_decision.ts";

const LOOKUP_FAILED = "Could not look up invite";

type StoredInvite = {
  family_id: string;
  status: string;
  expires_at: string;
  families: unknown;
  profiles: unknown;
};

export type InviteLookup = (
  token: string,
) => Promise<{ row: InviteRow | null; failed: boolean }>;

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

function tokenRequired() {
  return {
    valid: false,
    code: "VALIDATION",
    message: "token is required",
    family_id: null,
    family_name: null,
    inviter_name: null,
    status: null,
    expires_at: null,
  };
}

function toInviteRow(stored: StoredInvite): InviteRow {
  return {
    family_id: stored.family_id,
    status: stored.status,
    expires_at: stored.expires_at,
    family_name: embedName(stored.families),
    family_deleted: embedDeleted(stored.families),
    inviter_name: embedName(stored.profiles),
  };
}

async function liveLookup(token: string): Promise<{
  row: InviteRow | null;
  failed: boolean;
}> {
  const { data, error } = await serviceClient()
    .from("invites")
    .select(
      "id, family_id, status, expires_at, families(name, deleted_at), profiles!invited_by(display_name)",
    )
    .eq("token", token)
    .maybeSingle();
  if (error) return { row: null, failed: true };
  if (!data) return { row: null, failed: false };
  return { row: toInviteRow(data as StoredInvite), failed: false };
}

export function validateInviteToken(
  req: Request,
  options?: { lookup?: InviteLookup },
): Promise<Response> {
  return handleValidateInviteToken(req, options?.lookup ?? liveLookup);
}

async function handleValidateInviteToken(
  req: Request,
  lookup: InviteLookup,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "GET") {
    return errorResponse("VALIDATION", "Method not allowed", 405);
  }

  const token = new URL(req.url).searchParams.get("token")?.trim() ?? "";
  if (!token) return jsonResponse(tokenRequired());

  const { row, failed } = await lookup(token);
  if (failed) return errorResponse("VALIDATION", LOOKUP_FAILED, 400);
  return jsonResponse(decideInvite(row));
}

if (import.meta.main) {
  Deno.serve((req) => validateInviteToken(req));
}
