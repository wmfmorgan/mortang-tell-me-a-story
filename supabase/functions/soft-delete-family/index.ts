import {
  errorResponse,
  handleManage,
  jsonResponse,
  mapRpcError,
  textField,
} from "../_shared/manage.ts";

Deno.serve((req) =>
  handleManage(req, async (userSb, body) => {
    const familyId = textField(body, "family_id");
    if (!familyId) {
      return errorResponse("VALIDATION", "family_id is required", 400);
    }
    const { error } = await userSb.rpc("soft_delete_family", { fid: familyId });
    if (error) return mapRpcError(error.message);
    return jsonResponse({ ok: true });
  })
);
