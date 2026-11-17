import { assertEquals } from "jsr:@std/assert@1";

import { sendInviteEmail } from "./invite_email.ts";

const validationBody = JSON.stringify({
  name: "validation_error",
  message: "Invalid `to` field.",
});

function stubProvider(status: number): () => void {
  const original = globalThis.fetch;
  const priorKey = Deno.env.get("RESEND_API_KEY");
  const priorMail = Deno.env.get("MAILPIT_URL");
  Deno.env.set("RESEND_API_KEY", "test-key");
  Deno.env.delete("MAILPIT_URL");
  globalThis.fetch = (input, init) => {
    const url = String(input);
    if (url.includes("api.resend.com")) {
      return Promise.resolve(new Response(validationBody, { status }));
    }
    return original(input, init);
  };
  return () => {
    globalThis.fetch = original;
    if (priorKey == null) Deno.env.delete("RESEND_API_KEY");
    else Deno.env.set("RESEND_API_KEY", priorKey);
    if (priorMail == null) Deno.env.delete("MAILPIT_URL");
    else Deno.env.set("MAILPIT_URL", priorMail);
  };
}

Deno.test("a provider 422 is a 400 validation error", async () => {
  const restore = stubProvider(422);
  try {
    const failed = await sendInviteEmail({
      to: "joe blow",
      familyName: "Ada",
      token: "tok",
    });
    assertEquals(failed?.status, 400);
    assertEquals(await failed?.json(), {
      code: "VALIDATION",
      message: "Could not send invite email",
    });
  } finally {
    restore();
  }
});

Deno.test("a provider outage stays a 502", async () => {
  const restore = stubProvider(500);
  try {
    const failed = await sendInviteEmail({
      to: "a@b.co",
      familyName: "Ada",
      token: "tok",
    });
    assertEquals(failed?.status, 502);
    assertEquals(await failed?.json(), {
      code: "VALIDATION",
      message: "Could not send invite email",
    });
  } finally {
    restore();
  }
});
