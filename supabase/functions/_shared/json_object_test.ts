import { assertEquals } from "jsr:@std/assert@1";

import { readJsonObject } from "./json_object.ts";
import { handleManage } from "./manage.ts";

const invalidJson = { code: "VALIDATION", message: "Invalid JSON body" };

function post(body: string): Request {
  return new Request("http://local/json", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body,
  });
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
  const missing = new Request("http://local/json", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
  });
  await expectInvalid(await readJsonObject(missing));
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

Deno.test("handleManage rejects an empty body", async () => {
  const res = await handleManage(post(""), () => {
    throw new Error("run should not be called");
  });
  await expectInvalid(res);
});

Deno.test("handleManage rejects invalid JSON", async () => {
  const res = await handleManage(post("{"), () => {
    throw new Error("run should not be called");
  });
  await expectInvalid(res);
});

Deno.test("handleManage rejects a non-object body", async () => {
  const res = await handleManage(post("[1]"), () => {
    throw new Error("run should not be called");
  });
  await expectInvalid(res);
});
