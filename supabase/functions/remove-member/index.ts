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
    const userId = textField(body, "user_id");
    if (!familyId || !userId) {
      return errorResponse("VALIDATION", "family_id and user_id are required", 400);
    }
    const { error } = await userSb.rpc("remove_member", {
      fid: familyId,
      target: userId,
    });
    if (error) return mapRpcError(error.message);
    return jsonResponse({ ok: true });
  })
);
