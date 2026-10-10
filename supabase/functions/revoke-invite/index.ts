import {
  errorResponse,
  handleManage,
  jsonResponse,
  mapRpcError,
  textField,
} from "../_shared/manage.ts";

Deno.serve((req) =>
  handleManage(req, async (userSb, body) => {
    const inviteId = textField(body, "invite_id");
    if (!inviteId) {
      return errorResponse("VALIDATION", "invite_id is required", 400);
    }
    const { error } = await userSb.rpc("revoke_invite", { iid: inviteId });
    if (error) return mapRpcError(error.message);
    return jsonResponse({ ok: true });
  })
);
