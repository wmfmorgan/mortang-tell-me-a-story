import { errorResponse } from "./cors.ts";
import { buildInviteUrl } from "./supabase.ts";

export type InviteMail = {
  to: string;
  familyName: string;
  token: string;
};

/// Resend when RESEND_API_KEY is set. Local stacks without a key deliver
/// to Mailpit. A hosted project without a key fails closed.
export async function sendInviteEmail(mail: InviteMail): Promise<Response | null> {
  const inviteUrl = buildInviteUrl(mail.token);
  const subject = `Invite to ${mail.familyName}`;
  const html = `
    <p>You're invited to join <strong>${escapeHtml(mail.familyName)}</strong> on Tell Me a Story.</p>
    <p><a href="${inviteUrl}">Accept the invite</a></p>
    <p>This link expires in 7 days and can only be used once.</p>
  `;

  const resendKey = Deno.env.get("RESEND_API_KEY")?.trim();
  if (resendKey) {
    const from = Deno.env.get("RESEND_FROM")?.trim() ||
      "Tell Me a Story <onboarding@resend.dev>";
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [mail.to],
        subject,
        html,
      }),
    });
    if (!res.ok) {
      const detail = await res.text();
      return errorResponse(
        "VALIDATION",
        `Could not send invite email: ${detail}`,
        502,
      );
    }
    return null;
  }

  const mailpit = localMailpitUrl();
  if (!mailpit) {
    return errorResponse(
      "VALIDATION",
      "RESEND_API_KEY is not configured (OPEN Bill)",
      503,
    );
  }
  try {
    const res = await fetch(`${mailpit}/api/v1/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        From: { Email: "invite@localhost", Name: "Tell Me a Story" },
        To: [{ Email: mail.to }],
        Subject: subject,
        HTML: html,
      }),
    });
    if (!res.ok) {
      return errorResponse(
        "VALIDATION",
        "Could not deliver invite email to local Mailpit",
        502,
      );
    }
  } catch {
    return errorResponse(
      "VALIDATION",
      "Could not deliver invite email to local Mailpit",
      502,
    );
  }
  return null;
}

function localMailpitUrl(): string | null {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  let host = "";
  try {
    host = new URL(supabaseUrl).hostname;
  } catch {
    return null;
  }
  if (host !== "kong" && host !== "127.0.0.1" && host !== "localhost") {
    return null;
  }
  const override = Deno.env.get("MAILPIT_URL")?.trim();
  if (override) return override.replace(/\/$/, "");
  return "http://host.docker.internal:57324";
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
