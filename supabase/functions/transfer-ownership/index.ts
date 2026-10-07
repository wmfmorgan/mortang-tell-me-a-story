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
    const newOwner = textField(body, "new_owner_user_id");
    const former = textField(body, "former_owner_becomes");
    if (!familyId || !newOwner || (former !== "co_owner" && former !== "member")) {
      return errorResponse(
        "VALIDATION",
        "family_id, new_owner_user_id, and former_owner_becomes are required",
        400,
      );
    }
    const { error } = await userSb.rpc("transfer_ownership", {
      fid: familyId,
      new_owner: newOwner,
      former_becomes: former,
    });
    if (error) return mapRpcError(error.message);
    return jsonResponse({ ok: true });
  })
);
