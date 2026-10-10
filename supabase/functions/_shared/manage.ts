import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import { corsHeaders, errorResponse, jsonResponse } from "./cors.ts";
import { bearerToken, userClient } from "./supabase.ts";

export type ManageBody = Record<string, unknown>;

export function mapRpcError(message: string): Response {
  const rules: Array<[string, string, number]> = [
    ["NOT_FOUND:", "NOT_FOUND", 404],
    ["FORBIDDEN:", "FORBIDDEN", 403],
    ["INVITE_INVALID:", "INVITE_INVALID", 400],
    ["VALIDATION:", "VALIDATION", 400],
  ];
  for (const [prefix, code, status] of rules) {
    const at = message.indexOf(prefix);
    if (at >= 0) {
      const detail = message.slice(at + prefix.length).trim();
      return errorResponse(code, detail.length > 0 ? detail : message, status);
    }
  }
  return errorResponse("VALIDATION", message, 400);
}

export async function handleManage(
  req: Request,
  run: (userSb: SupabaseClient, body: ManageBody) => Promise<Response>,
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
  let body: ManageBody;
  try {
    const parsed = await req.json();
    if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return errorResponse("VALIDATION", "Invalid JSON body", 400);
    }
    body = parsed as ManageBody;
  } catch {
    return errorResponse("VALIDATION", "Invalid JSON body", 400);
  }

  const userSb = userClient(auth);
  const {
    data: { user },
    error: userErr,
  } = await userSb.auth.getUser();
  if (userErr || !user) {
    return errorResponse("AUTH_REQUIRED", "Sign-in required", 401);
  }
  return run(userSb, body);
}

export function textField(body: ManageBody, key: string): string {
  const value = body[key];
  return typeof value === "string" ? value.trim() : "";
}

export { errorResponse, jsonResponse };
