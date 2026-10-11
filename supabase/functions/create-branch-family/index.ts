import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  errorResponse,
  handleManage,
  jsonResponse,
  type ManageBody,
  mapRpcError,
  textField,
} from "../_shared/manage.ts";

export type BranchRpc = (
  fn: string,
  args: Record<string, unknown>,
) => Promise<{ data: { id?: string } | null; error: { message: string } | null }>;

export type BranchGate = (
  req: Request,
  run: (
    userSb: { rpc: BranchRpc },
    body: ManageBody,
  ) => Promise<Response>,
) => Promise<Response>;

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Mugatu has not named the malformed-id sentence. Do not treat this as locked.
const UNNAMED_INVALID_ID = "That id is not valid.";

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_RE.test(value.trim());
}

export function createBranchFamily(
  req: Request,
  options?: { gate?: BranchGate; rpc?: BranchRpc },
): Promise<Response> {
  const gate = options?.gate ??
    ((request, run) =>
      handleManage(request, (userSb, body) =>
        run(userSb as unknown as { rpc: BranchRpc }, body)
      ));

  return gate(req, async (userSb, body) => {
    const parentRaw = body.parent_family_id;
    if (typeof parentRaw !== "string" || parentRaw.trim() === "") {
      return errorResponse("VALIDATION", "parent_family_id is required", 400);
    }
    if (!isUuid(parentRaw)) {
      return errorResponse("VALIDATION", UNNAMED_INVALID_ID, 400);
    }

    const originRaw = body.origin_story_id;
    if (typeof originRaw !== "string" || originRaw.trim() === "") {
      return errorResponse("VALIDATION", "origin_story_id is required", 400);
    }
    if (!isUuid(originRaw)) {
      return errorResponse("VALIDATION", UNNAMED_INVALID_ID, 400);
    }

    const name = textField(body, "name");
    if (!name) {
      return errorResponse("VALIDATION", "name is required", 400);
    }

    const year = body.branch_year;
    if (typeof year !== "number" || !Number.isInteger(year)) {
      return errorResponse("VALIDATION", "attach year must be four digits", 400);
    }

    const ownerRaw = body.owner_user_id;
    if (!isUuid(ownerRaw)) {
      return errorResponse("VALIDATION", UNNAMED_INVALID_ID, 400);
    }

    const peopleRaw = body.person_ids;
    let personIds: string[] = [];
    if (peopleRaw !== undefined && peopleRaw !== null) {
      if (!Array.isArray(peopleRaw) || !peopleRaw.every(isUuid)) {
        return errorResponse("VALIDATION", UNNAMED_INVALID_ID, 400);
      }
      personIds = peopleRaw.map((id) => id.trim());
    }

    const call = options?.rpc ??
      ((fn: string, args: Record<string, unknown>) =>
        (userSb as unknown as SupabaseClient).rpc(fn, args));

    const { data, error } = await call("create_branch_family", {
      p_parent_family_id: parentRaw.trim(),
      p_origin_story_id: originRaw.trim(),
      p_name: name,
      p_branch_year: year,
      p_owner_user_id: ownerRaw.trim(),
      p_person_ids: personIds,
    });
    if (error) return mapRpcError(error.message);
    const familyId = data?.id;
    if (!familyId) {
      return errorResponse("VALIDATION", "create_branch_family returned no id", 400);
    }
    return jsonResponse({ family_id: familyId }, 201);
  });
}

if (import.meta.main) {
  Deno.serve((req) => createBranchFamily(req));
}
