import { assertEquals } from "jsr:@std/assert@1";

import { handleSendInviteEmail } from "./index.ts";

const invalidJson = { code: "VALIDATION", message: "Invalid JSON body" };

function rawPost(body: string): Request {
  return new Request("http://local/send-invite-email", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body,
  });
}

async function expectInvalidJson(body: string): Promise<void> {
  const res = await handleSendInviteEmail(rawPost(body));
  assertEquals(res.status, 400);
  assertEquals(await res.json(), invalidJson);
}

Deno.test("send-invite-email rejects an empty body", () => expectInvalidJson(""));

Deno.test("send-invite-email rejects invalid JSON", () => expectInvalidJson("{"));

Deno.test("send-invite-email rejects a non-object body", async () => {
  await expectInvalidJson("[1]");
  await expectInvalidJson("\"hi\"");
});
