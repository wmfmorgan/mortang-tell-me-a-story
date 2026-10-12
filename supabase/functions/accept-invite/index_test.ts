import { assertEquals } from "jsr:@std/assert@1";

import { acceptInvite, type AcceptInviteDb } from "./index.ts";

const rawDb =
  'duplicate key value violates unique constraint "memberships_pkey"';

const pending = {
  id: "invite-1",
  family_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  status: "pending",
  expires_at: "2099-01-01T00:00:00.000Z",
};

function post(body: unknown): Request {
  return new Request("http://local/accept-invite", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body: JSON.stringify(body),
  });
}

function dbWith(opts: {
  membershipId?: string | null;
  membershipError?: string | null;
  insertError?: string | null;
  onInsert?: () => void;
}): AcceptInviteDb {
  return {
    userId: () => Promise.resolve("user-owner"),
    inviteByToken: () => Promise.resolve({ row: pending, error: null }),
    membershipId: () =>
      Promise.resolve({
        id: opts.membershipId ?? null,
        error: opts.membershipError ?? null,
      }),
    insertMember: () => {
      opts.onInsert?.();
      return Promise.resolve({
        id: opts.insertError ? null : "mem-new",
        error: opts.insertError ?? null,
      });
    },
    markAccepted: () => Promise.resolve(null),
  };
}

Deno.test("an owner who opens their own invite stays owner", async () => {
  let inserted = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      membershipId: "mem-owner",
      onInsert: () => {
        inserted = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 200);
  assertEquals(json.membership_id, "mem-owner");
  assertEquals(json.family_id, pending.family_id);
  assertEquals(inserted, false);
});

Deno.test("membership failures hide raw database text", async () => {
  const lookup = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({ membershipError: rawDb }),
  });
  const lookupBody = await lookup.text();
  assertEquals(lookup.status, 400);
  assertEquals(lookupBody.includes(rawDb), false);
  assertEquals(lookupBody.includes("Could not check membership"), true);

  const insert = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({ insertError: rawDb }),
  });
  const insertBody = await insert.text();
  assertEquals(insert.status, 400);
  assertEquals(insertBody.includes(rawDb), false);
  assertEquals(insertBody.includes("Could not create membership"), true);
});
