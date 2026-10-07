import {
  errorResponse,
  handleManage,
  jsonResponse,
  mapRpcError,
  textField,
} from "../_shared/manage.ts";

Deno.serve((req) =>
  handleManage(req, async (userSb, body) => {
    const name = textField(body, "name");
    if (!name) {
      return errorResponse("VALIDATION", "name is required", 400);
    }
    const { data, error } = await userSb.rpc("create_family", {
      p_name: name,
    });
    if (error) return mapRpcError(error.message);
    const row = data as { id?: string } | null;
    const familyId = row?.id;
    if (!familyId) {
      return errorResponse("VALIDATION", "create_family returned no id", 400);
    }
    return jsonResponse({ family_id: familyId }, 201);
  })
);
