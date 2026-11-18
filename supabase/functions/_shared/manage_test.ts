import { assertEquals } from "jsr:@std/assert@1";

import { jsonPost } from "./json_post.ts";
import { handleManage, mapRpcError } from "./manage.ts";

const invalidJson = { code: "VALIDATION", message: "Invalid JSON body" };

function post(body: string): Request {
  return jsonPost("http://local/manage", body);
}

async function expectInvalid(result: unknown): Promise<void> {
  if (!(result instanceof Response)) {
    throw new Error("expected a 400 response");
  }
  assertEquals(result.status, 400);
  assertEquals(await result.json(), invalidJson);
}

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

Deno.test("a bare prefix message is Try again", async () => {
  const validation = mapRpcError("VALIDATION:");
  assertEquals(validation.status, 400);
  assertEquals(await validation.json(), {
    code: "VALIDATION",
    message: "Try again",
  });
  const forbidden = mapRpcError("FORBIDDEN:");
  assertEquals(forbidden.status, 403);
  assertEquals(await forbidden.json(), {
    code: "FORBIDDEN",
    message: "Try again",
  });
});

Deno.test("handleManage rejects a non-object body", async () => {
  const res = await handleManage(post("[1]"), () => {
    throw new Error("run should not be called");
  });
  await expectInvalid(res);
});
