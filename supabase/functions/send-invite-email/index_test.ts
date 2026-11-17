import { assertEquals } from "jsr:@std/assert@1";

import { jsonPost } from "../_shared/json_post.ts";
import { handleSendInviteEmail } from "./index.ts";

const invalidJson = { code: "VALIDATION", message: "Invalid JSON body" };

function rawPost(body: string): Request {
  return jsonPost("http://local/send-invite-email", body);
}

async function expectInvalidJson(body: string): Promise<void> {
  const res = await handleSendInviteEmail(rawPost(body));
  assertEquals(res.status, 400);
  assertEquals(await res.json(), invalidJson);
}

Deno.test("send-invite-email rejects a non-string invite_id", async () => {
  const res = await handleSendInviteEmail(
    jsonPost(
      "http://local/send-invite-email",
      JSON.stringify({ invite_id: 12 }),
    ),
  );
  assertEquals(res.status, 400);
  assertEquals(await res.json(), {
    code: "VALIDATION",
    message: "invite_id is required",
  });
});

Deno.test("send-invite-email rejects an empty body", () => expectInvalidJson(""));

Deno.test("send-invite-email rejects invalid JSON", () => expectInvalidJson("{"));

Deno.test("send-invite-email rejects a non-object body", async () => {
  await expectInvalidJson("[1]");
  await expectInvalidJson("\"hi\"");
});
