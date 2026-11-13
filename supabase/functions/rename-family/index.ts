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
    const name = textField(body, "name");
    if (!familyId || !name) {
      return errorResponse("VALIDATION", "family_id and name are required", 400);
    }
    const { error } = await userSb.rpc("rename_family", {
      fid: familyId,
      name,
    });
    if (error) return mapRpcError(error.message);
    return jsonResponse({ ok: true });
  })
);
