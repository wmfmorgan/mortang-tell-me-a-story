import { assertEquals } from "jsr:@std/assert@1";

import { acceptInvite, type AcceptInviteDb } from "./index.ts";

const rawDb =
  'duplicate key value violates unique constraint "memberships_pkey"';

const pending = {
  id: "invite-1",
  family_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  status: "pending",
  expires_at: "2099-01-01T00:00:00.000Z",
  person_id: null as string | null,
  accepted_by: null as string | null,
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
  personId?: string | null;
  linkError?: string | null;
  status?: string;
  acceptedBy?: string | null;
  onInsert?: () => void;
  onLink?: (personId: string) => void;
  onAccept?: () => void;
}): AcceptInviteDb {
  return {
    userId: () => Promise.resolve("user-owner"),
    inviteByToken: () =>
      Promise.resolve({
        row: {
          ...pending,
          person_id: opts.personId ?? null,
          status: opts.status ?? pending.status,
          accepted_by: opts.acceptedBy ?? null,
        },
        error: null,
      }),
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
    linkPerson: (personId) => {
      opts.onLink?.(personId);
      return Promise.resolve(opts.linkError ?? null);
    },
    markAccepted: () => {
      opts.onAccept?.();
      return Promise.resolve(null);
    },
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

Deno.test("an unlinked person_id is linked before the invite is accepted", async () => {
  const order: string[] = [];
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      personId: "person-1",
      onLink: () => order.push("link"),
      onAccept: () => order.push("accept"),
    }),
  });
  assertEquals(res.status, 200);
  assertEquals(order, ["link", "accept"]);
});

Deno.test("a null person_id does not link", async () => {
  let linked = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      onLink: () => {
        linked = true;
      },
    }),
  });
  assertEquals(res.status, 200);
  assertEquals(linked, false);
});

Deno.test("an already linked person still accepts", async () => {
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({ personId: "person-1", linkError: null }),
  });
  const json = await res.json();
  assertEquals(res.status, 200);
  assertEquals(json.membership_id, "mem-new");
});

Deno.test("a missing uid while linking is 401 and does not accept", async () => {
  let accepted = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      personId: "person-1",
      linkError: "NOT_FOUND:",
      onAccept: () => {
        accepted = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 401);
  assertEquals(json.code, "AUTH_REQUIRED");
  assertEquals(accepted, false);
});

Deno.test("the same user can open an accepted invite again", async () => {
  let marked = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      status: "accepted",
      acceptedBy: "user-owner",
      membershipId: "mem-owner",
      onAccept: () => {
        marked = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 200);
  assertEquals(json.family_id, pending.family_id);
  assertEquals(json.membership_id, "mem-owner");
  assertEquals(marked, false);
});

Deno.test("someone else cannot reuse an accepted invite", async () => {
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      status: "accepted",
      acceptedBy: "user-other",
      membershipId: "mem-other",
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "INVITE_ACCEPTED");
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
