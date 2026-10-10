import { sendInviteEmail } from "../_shared/invite_email.ts";
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
    const { data, error } = await userSb.rpc("resend_invite", {
      iid: inviteId,
    });
    if (error) return mapRpcError(error.message);
    const row = data as {
      token?: string;
      email?: string;
      family_name?: string;
      expires_at?: string;
    } | null;
    const token = row?.token?.trim() ?? "";
    const email = row?.email?.trim() ?? "";
    const expiresAt = row?.expires_at ?? "";
    if (!token || !email || !expiresAt) {
      return errorResponse("VALIDATION", "Could not resend invite", 400);
    }
    // The token is already rotated. A failed send stays rotated; retry is safe.
    const failed = await sendInviteEmail({
      to: email,
      familyName: row?.family_name?.trim() || "a family",
      token,
    });
    if (failed) return failed;
    return jsonResponse({ sent: true, expires_at: expiresAt });
  })
);
