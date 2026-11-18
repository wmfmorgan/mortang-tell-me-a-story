import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import { corsHeaders, errorResponse, jsonResponse } from "./cors.ts";
import type { ErrorCode } from "./error_codes.ts";
import { readJsonObject } from "./json_object.ts";
import { bearerToken, userClient } from "./supabase.ts";

export type ManageBody = Record<string, unknown>;

export const GENERIC_ERROR = "Try again";

export function mapRpcError(message: string): Response {
  const trimmed = message.trim();
  const rules: Array<[string, ErrorCode, number]> = [
    ["NOT_FOUND:", "NOT_FOUND", 404],
    ["FORBIDDEN:", "FORBIDDEN", 403],
    ["VALIDATION:", "VALIDATION", 400],
    ["INVITE_INVALID:", "INVITE_INVALID", 400],
  ];
  for (const [prefix, code, status] of rules) {
    if (!trimmed.startsWith(prefix)) continue;
    const detail = trimmed.slice(prefix.length).trim();
    return errorResponse(
      code,
      detail.length > 0 ? detail : GENERIC_ERROR,
      status,
    );
  }
  return errorResponse("VALIDATION", GENERIC_ERROR, 400);
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
  const body = await readJsonObject(req);
  if (body instanceof Response) return body;

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
