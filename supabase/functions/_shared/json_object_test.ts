import { assertEquals } from "jsr:@std/assert@1";

import { jsonPost } from "./json_post.ts";
import { readJsonObject } from "./json_object.ts";

const invalidJson = { code: "VALIDATION", message: "Invalid JSON body" };

function post(body?: string): Request {
  return jsonPost("http://local/json", body);
}

async function expectInvalid(result: unknown): Promise<void> {
  if (!(result instanceof Response)) {
    throw new Error("expected a 400 response");
  }
  assertEquals(result.status, 400);
  assertEquals(await result.json(), invalidJson);
}

Deno.test("readJsonObject rejects an empty body", async () => {
  await expectInvalid(await readJsonObject(post("")));
  await expectInvalid(await readJsonObject(post()));
});

Deno.test("readJsonObject rejects invalid JSON", async () => {
  await expectInvalid(await readJsonObject(post("{")));
});

Deno.test("readJsonObject rejects a non-object body", async () => {
  await expectInvalid(await readJsonObject(post("[1]")));
  await expectInvalid(await readJsonObject(post("\"hi\"")));
});

Deno.test("readJsonObject returns a JSON object", async () => {
  const body = await readJsonObject(post('{"token":"abc"}'));
  assertEquals(body, { token: "abc" });
});
