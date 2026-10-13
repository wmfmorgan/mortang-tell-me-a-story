import {
  errorResponse,
  handleManage,
  jsonResponse,
  mapRpcError,
  textField,
} from "../_shared/manage.ts";

type RpcClient = {
  rpc: (
    fn: string,
    args: Record<string, string>,
  ) => Promise<{ error: { message: string } | null }>;
};

export async function removeMember(
  userSb: RpcClient,
  body: Record<string, unknown>,
): Promise<Response> {
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
}

if (import.meta.main) {
  Deno.serve((req) =>
    handleManage(req, (userSb, body) =>
      removeMember(userSb as unknown as RpcClient, body))
  );
}
