import { assertEquals } from "jsr:@std/assert@1";

import { mapRpcError } from "../_shared/manage.ts";
import {
  createBranchFamily,
  type BranchRpc,
} from "./index.ts";

const parent = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const origin = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const owner = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const person = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";

function post(body: unknown, auth = true): Request {
  const headers = new Headers({ "Content-Type": "application/json" });
  if (auth) headers.set("Authorization", "Bearer test-token");
  return new Request("http://local/create-branch-family", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
}

function gateWith(rpc: BranchRpc) {
  return async (
    req: Request,
    run: (
      userSb: { rpc: BranchRpc },
      body: Record<string, unknown>,
    ) => Promise<Response>,
  ) => {
    const body = await req.json();
    return run({ rpc }, body);
  };
}

const validBody = {
  parent_family_id: parent,
  origin_story_id: origin,
  name: " The Morgan-Reyes ",
  branch_year: 1970,
  owner_user_id: owner,
  person_ids: [person],
};

Deno.test("missing JWT is 401 AUTH_REQUIRED", async () => {
  const res = await createBranchFamily(post({}, false));
  const json = await res.json();
  assertEquals(res.status, 401);
  assertEquals(json.code, "AUTH_REQUIRED");
});

Deno.test("missing parent_family_id is 400 and does not call the RPC", async () => {
  let calls = 0;
  const rpc: BranchRpc = () => {
    calls += 1;
    return Promise.resolve({ data: null, error: null });
  };
  const res = await createBranchFamily(
    post({ ...validBody, parent_family_id: "  " }),
    { gate: gateWith(rpc) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message, "parent_family_id is required");
  assertEquals(calls, 0);
});

Deno.test("missing origin_story_id is 400", async () => {
  const res = await createBranchFamily(
    post({ ...validBody, origin_story_id: "" }),
    { gate: gateWith(() => Promise.resolve({ data: null, error: null })) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.message, "origin_story_id is required");
});

Deno.test("blank name is 400", async () => {
  const res = await createBranchFamily(
    post({ ...validBody, name: "   " }),
    { gate: gateWith(() => Promise.resolve({ data: null, error: null })) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.message, "name is required");
});

for (const year of [1.5, "1970", null, undefined]) {
  Deno.test(`non-integer year ${JSON.stringify(year)} does not call the RPC`, async () => {
    let calls = 0;
    const rpc: BranchRpc = () => {
      calls += 1;
      return Promise.resolve({ data: null, error: null });
    };
    const body: Record<string, unknown> = { ...validBody };
    if (year === undefined) delete body.branch_year;
    else body.branch_year = year;
    const res = await createBranchFamily(post(body), { gate: gateWith(rpc) });
    const json = await res.json();
    assertEquals(res.status, 400);
    assertEquals(json.code, "VALIDATION");
    assertEquals(json.message, "attach year must be four digits");
    assertEquals(json.message.includes("VALIDATION:"), false);
    assertEquals(calls, 0);
  });
}

Deno.test("a bad UUID is rejected before the RPC", async () => {
  let calls = 0;
  const rpc: BranchRpc = () => {
    calls += 1;
    return Promise.resolve({ data: null, error: null });
  };
  const res = await createBranchFamily(
    post({ ...validBody, parent_family_id: "not-a-uuid" }),
    { gate: gateWith(rpc) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message === "parent_family_id is required", false);
  assertEquals(json.message.includes("invalid input syntax"), false);
  assertEquals(calls, 0);
});

Deno.test("a bad person id is rejected before the RPC", async () => {
  let calls = 0;
  const rpc: BranchRpc = () => {
    calls += 1;
    return Promise.resolve({ data: null, error: null });
  };
  const res = await createBranchFamily(
    post({ ...validBody, person_ids: [person, "nope"] }),
    { gate: gateWith(rpc) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(calls, 0);
});

Deno.test("RPC NOT_FOUND: story is 404 with the bare message", async () => {
  const rpc: BranchRpc = () =>
    Promise.resolve({ data: null, error: { message: "NOT_FOUND: story" } });
  const res = await createBranchFamily(post(validBody), { gate: gateWith(rpc) });
  const json = await res.json();
  assertEquals(res.status, 404);
  assertEquals(json.code, "NOT_FOUND");
  assertEquals(json.message, "story");
});

Deno.test("RPC FORBIDDEN: member only is 403 with the bare message", async () => {
  const rpc: BranchRpc = () =>
    Promise.resolve({
      data: null,
      error: { message: "FORBIDDEN: member only" },
    });
  const res = await createBranchFamily(post(validBody), { gate: gateWith(rpc) });
  const json = await res.json();
  assertEquals(res.status, 403);
  assertEquals(json.code, "FORBIDDEN");
  assertEquals(json.message, "member only");
});

Deno.test("JSON integer 999 is sent to the RPC and the message has no prefix", async () => {
  let args: Record<string, unknown> | null = null;
  const rpc: BranchRpc = (_fn, got) => {
    args = got;
    return Promise.resolve({
      data: null,
      error: { message: "VALIDATION: attach year must be four digits" },
    });
  };
  const res = await createBranchFamily(
    post({ ...validBody, branch_year: 999 }),
    { gate: gateWith(rpc) },
  );
  const json = await res.json();
  assertEquals(args?.["p_branch_year"], 999);
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message, "attach year must be four digits");
  assertEquals(json.message.includes("VALIDATION:"), false);
});

Deno.test("an unprefixed database error hides the raw text", async () => {
  const raw = 'duplicate key value violates unique constraint "families_pkey"';
  const rpc: BranchRpc = () =>
    Promise.resolve({ data: null, error: { message: raw } });
  const res = await createBranchFamily(post(validBody), { gate: gateWith(rpc) });
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message.includes(raw), false);
  assertEquals(json.message.includes("VALIDATION:"), false);
  assertEquals(json.message.length > 0, true);
});

Deno.test("success is 201 and calls the RPC once", async () => {
  let calls = 0;
  let args: Record<string, unknown> | null = null;
  const rpc: BranchRpc = (fn, got) => {
    calls += 1;
    args = got;
    assertEquals(fn, "create_branch_family");
    return Promise.resolve({
      data: { id: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee" },
      error: null,
    });
  };
  const res = await createBranchFamily(post(validBody), { gate: gateWith(rpc) });
  const json = await res.json();
  assertEquals(res.status, 201);
  assertEquals(json.family_id, "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee");
  assertEquals(calls, 1);
  assertEquals(args?.["p_parent_family_id"], parent);
  assertEquals(args?.["p_origin_story_id"], origin);
  assertEquals(args?.["p_name"], "The Morgan-Reyes");
  assertEquals(args?.["p_branch_year"], 1970);
  assertEquals(args?.["p_owner_user_id"], owner);
  assertEquals(args?.["p_person_ids"], [person]);
});

Deno.test("a prefix at the start passes through", async () => {
  const notFound = mapRpcError("NOT_FOUND: story");
  assertEquals(notFound.status, 404);
  assertEquals(await notFound.json(), { code: "NOT_FOUND", message: "story" });
  const forbidden = mapRpcError("  FORBIDDEN: member only");
  assertEquals(forbidden.status, 403);
  assertEquals(await forbidden.json(), {
    code: "FORBIDDEN",
    message: "member only",
  });
  const validation = mapRpcError("VALIDATION: attach year must be four digits");
  assertEquals(validation.status, 400);
  assertEquals(await validation.json(), {
    code: "VALIDATION",
    message: "attach year must be four digits",
  });
});

Deno.test("a prefix in the middle of the message is generic", async () => {
  const raw = "constraint failed NOT_FOUND: story";
  const res = mapRpcError(raw);
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json, { code: "VALIDATION", message: "Try again" });
  assertEquals(json.message.includes("NOT_FOUND:"), false);
  assertEquals(json.message.includes(raw), false);
});

Deno.test("an unprefixed message is generic", async () => {
  const raw = "new row violates check constraint";
  const res = mapRpcError(raw);
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json, { code: "VALIDATION", message: "Try again" });
  assertEquals(json.message.includes(raw), false);
  assertEquals(json.message.includes("VALIDATION:"), false);
});

Deno.test("INVITE_INVALID: used passes through", async () => {
  const res = mapRpcError("INVITE_INVALID: used");
  assertEquals(res.status, 400);
  assertEquals(await res.json(), { code: "INVITE_INVALID", message: "used" });
});
