import { errorResponse } from "./cors.ts";
import { buildInviteUrl } from "./supabase.ts";

export type InviteMail = {
  to: string;
  familyName: string;
  token: string;
};

const emailNotConfiguredMessage = "Email is not configured";
const emailSendFailedMessage = "Could not send invite email";

/// True when Resend or a local Mailpit URL is configured.
export function emailConfigured(): boolean {
  return resendKey().length > 0 || mailpitUrl().length > 0;
}

/// Resend when RESEND_API_KEY is set. Mailpit only when MAILPIT_URL is set.
/// Neither fails closed. No hostname guess and no default Mailpit URL.
export async function sendInviteEmail(
  mail: InviteMail,
): Promise<Response | null> {
  if (!emailConfigured()) return emailNotConfiguredResponse();

  const inviteUrl = buildInviteUrl(mail.token);
  const subject = `Invite to ${mail.familyName}`;
  const html = `
    <p>You're invited to join <strong>${escapeHtml(mail.familyName)}</strong> on Tell Me a Story.</p>
    <p><a href="${inviteUrl}">Accept the invite</a></p>
    <p>This link expires in 7 days and can only be used once.</p>
  `;

  const key = resendKey();
  if (key) {
    const from = Deno.env.get("RESEND_FROM")?.trim() ||
      "Tell Me a Story <onboarding@resend.dev>";
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${key}`,
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
      console.error("invite email provider failed", detail);
      return errorResponse("VALIDATION", emailSendFailedMessage, 502);
    }
    return null;
  }

  const mailpit = mailpitUrl();
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
      const detail = await res.text();
      console.error("invite email provider failed", detail);
      return errorResponse("VALIDATION", emailSendFailedMessage, 502);
    }
  } catch (error) {
    console.error("invite email provider failed", error);
    return errorResponse("VALIDATION", emailSendFailedMessage, 502);
  }
  return null;
}

export function emailNotConfiguredResponse(): Response {
  return errorResponse("VALIDATION", emailNotConfiguredMessage, 503);
}

function resendKey(): string {
  return Deno.env.get("RESEND_API_KEY")?.trim() ?? "";
}

function mailpitUrl(): string {
  return Deno.env.get("MAILPIT_URL")?.trim().replace(/\/$/, "") ?? "";
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
