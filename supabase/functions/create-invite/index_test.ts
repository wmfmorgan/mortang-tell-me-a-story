import { assertEquals } from "jsr:@std/assert@1";

import { mapRpcError } from "../_shared/manage.ts";
import { createInvite, type CreateInviteDb } from "./index.ts";

const familyId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const personId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";

function post(body: unknown): Request {
  return new Request("http://local/create-invite", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body: JSON.stringify(body),
  });
}

function dbWith(opts: {
  member?: boolean;
  assertError?: string | null;
  onAssert?: (familyId: string, personId: string) => void;
  onInsert?: (personId: string | null, email: string | null) => void;
  insertError?: string | null;
}): CreateInviteDb {
  return {
    userId: () => Promise.resolve("user-1"),
    isFamilyMember: () =>
      Promise.resolve({ member: opts.member ?? true, error: null }),
    assertPerson: (family, person) => {
      opts.onAssert?.(family, person);
      return Promise.resolve(opts.assertError ?? null);
    },
    insertInvite: (row) => {
      opts.onInsert?.(row.personId, row.email);
      if (opts.insertError) {
        return Promise.resolve({ invite: null, error: opts.insertError });
      }
      return Promise.resolve({
        invite: {
          id: "invite-1",
          token: "tok",
          expires_at: "2099-01-01T00:00:00.000Z",
        },
        error: null,
      });
    },
  };
}

Deno.test("absent person_id still returns 201", async () => {
  let asserted = false;
  let inserted: string | null = "unset";
  const res = await createInvite(post({ family_id: familyId, email: "a@b.co" }), {
    db: dbWith({
      onAssert: () => {
        asserted = true;
      },
      onInsert: (person) => {
        inserted = person;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 201);
  assertEquals(json.invite_id, "invite-1");
  assertEquals(asserted, false);
  assertEquals(inserted, null);
});

Deno.test("unknown and out-of-tree people share the not-found body", async () => {
  const unknown = await createInvite(
    post({ family_id: familyId, person_id: personId }),
    { db: dbWith({ assertError: "NOT_FOUND:" }) },
  );
  const outside = await createInvite(
    post({ family_id: familyId, person_id: personId }),
    { db: dbWith({ assertError: "NOT_FOUND:" }) },
  );
  const unknownBody = await unknown.json();
  const outsideBody = await outside.json();
  assertEquals(unknown.status, 404);
  assertEquals(outside.status, 404);
  assertEquals(unknownBody, outsideBody);
  assertEquals(unknownBody.code, "NOT_FOUND");
});

Deno.test("a linked person is validation", async () => {
  const res = await createInvite(
    post({ family_id: familyId, person_id: personId }),
    { db: dbWith({ assertError: "VALIDATION: person is already linked" }) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message, "person is already linked");
});

Deno.test("a person who has passed is validation", async () => {
  const res = await createInvite(
    post({ family_id: familyId, person_id: personId }),
    { db: dbWith({ assertError: "VALIDATION: person has passed" }) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message, "person has passed");
});

Deno.test("a non-member is forbidden and an ordinary member is allowed", async () => {
  let asserted = false;
  const denied = await createInvite(post({ family_id: familyId }), {
    db: dbWith({
      member: false,
      onAssert: () => {
        asserted = true;
      },
    }),
  });
  const deniedBody = await denied.json();
  assertEquals(denied.status, 403);
  assertEquals(deniedBody.code, "FORBIDDEN");
  assertEquals(deniedBody.message, "Not a family member");
  assertEquals(asserted, false);

  const allowed = await createInvite(
    post({ family_id: familyId, person_id: personId, email: "a@b.co" }),
    { db: dbWith({ member: true }) },
  );
  assertEquals(allowed.status, 201);
});

Deno.test("a raw database insert error stays generic", async () => {
  const raw = 'duplicate key value violates unique constraint "invites_token_key"';
  const res = await createInvite(
    post({ family_id: familyId, email: "a@b.co" }),
    { db: dbWith({ insertError: raw }) },
  );
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "VALIDATION");
  assertEquals(json.message, "Could not create invite");
  assertEquals(JSON.stringify(json).includes("duplicate key"), false);
});

Deno.test("mapRpcError still has the four prefixes", () => {
  assertEquals(mapRpcError("NOT_FOUND:").status, 404);
  assertEquals(mapRpcError("FORBIDDEN: no").status, 403);
  assertEquals(mapRpcError("VALIDATION: no").status, 400);
  assertEquals(mapRpcError("INVITE_INVALID: no").status, 400);
  assertEquals(mapRpcError("OTHER: no").status, 400);
});
