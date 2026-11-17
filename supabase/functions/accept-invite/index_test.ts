import { assertEquals } from "jsr:@std/assert@1";

import { jsonPost } from "../_shared/json_post.ts";
import { acceptInvite, type AcceptInviteDb } from "./index.ts";

const acceptUrl = "http://local/accept-invite";

const rawDb =
  'duplicate key value violates unique constraint "memberships_pkey"';

const pending = {
  id: "invite-1",
  family_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  status: "pending",
  expires_at: "2099-01-01T00:00:00.000Z",
  person_id: null as string | null,
  accepted_by: null as string | null,
  email: null as string | null,
  family_deleted: false,
};

function post(body: unknown): Request {
  return jsonPost(acceptUrl, JSON.stringify(body));
}

const invalidJson = { code: "VALIDATION", message: "Invalid JSON body" };

async function expectInvalidJson(body: string): Promise<void> {
  const res = await acceptInvite(jsonPost(acceptUrl, body));
  assertEquals(res.status, 400);
  assertEquals(await res.json(), invalidJson);
}

function dbWith(opts: {
  membershipId?: string | null;
  membershipError?: string | null;
  insertError?: string | null;
  personId?: string | null;
  linkError?: string | null;
  inviteError?: string | null;
  status?: string;
  acceptedBy?: string | null;
  userEmail?: string | null;
  inviteEmail?: string | null;
  familyDeleted?: boolean;
  onInsert?: () => void;
  onLink?: (personId: string) => void;
  onAccept?: () => void;
}): AcceptInviteDb {
  return {
    userId: () => Promise.resolve("user-owner"),
    userEmail: () => Promise.resolve(opts.userEmail ?? null),
    inviteByToken: () =>
      Promise.resolve({
        row: opts.inviteError
          ? null
          : {
            ...pending,
            person_id: opts.personId ?? null,
            status: opts.status ?? pending.status,
            accepted_by: opts.acceptedBy ?? null,
            email: opts.inviteEmail ?? null,
            family_deleted: opts.familyDeleted ?? false,
          },
        error: opts.inviteError ?? null,
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
    claimInvite: () => {
      if (opts.linkError) return Promise.resolve(opts.linkError);
      if (opts.personId) opts.onLink?.(opts.personId);
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

Deno.test("an unlinked person_id still accepts", async () => {
  let claimed = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      personId: "person-1",
      onLink: () => {
        claimed = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 200);
  assertEquals(json.membership_id, "mem-new");
  assertEquals(json.family_id, pending.family_id);
  assertEquals(claimed, true);
});

Deno.test(
  "accept-invite still accepts a pending invite on a flagged person",
  async () => {
    const res = await acceptInvite(post({ token: "abc" }), {
      db: dbWith({ personId: "flagged-person" }),
    });
    const json = await res.json();
    assertEquals(res.status, 200);
    assertEquals(json.family_id, pending.family_id);
    assertEquals(json.membership_id, "mem-new");
  },
);

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

Deno.test("a missing person is not a sign-in error", async () => {
  let accepted = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      personId: "missing-person",
      linkError: "NOT_FOUND:",
      onAccept: () => {
        accepted = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 404);
  assertEquals(json.code, "NOT_FOUND");
  assertEquals(accepted, false);
});

Deno.test("a person outside the tree is not a sign-in error", async () => {
  let accepted = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      personId: "other-tree-person",
      linkError: "NOT_FOUND:",
      onAccept: () => {
        accepted = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 404);
  assertEquals(json.code, "NOT_FOUND");
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

Deno.test("a mismatched invite email is refused", async () => {
  let accepted = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      userEmail: "other@test.local",
      inviteEmail: "Guest@test.local",
      onAccept: () => {
        accepted = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "INVITE_INVALID");
  assertEquals(json.message, "Invite is not valid");
  assertEquals(accepted, false);
});

Deno.test("an invite email matches without case", async () => {
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      userEmail: "Guest@test.local",
      inviteEmail: "guest@test.local",
    }),
  });
  assertEquals(res.status, 200);
});

Deno.test("a second accept of one invite is refused", async () => {
  let claims = 0;
  const db: AcceptInviteDb = {
    ...dbWith({}),
    claimInvite: () => {
      claims += 1;
      if (claims > 1) {
        return Promise.resolve("INVITE_INVALID: Invite is not valid");
      }
      return Promise.resolve(null);
    },
  };
  const [first, second] = await Promise.all([
    acceptInvite(post({ token: "abc" }), { db }),
    acceptInvite(post({ token: "abc" }), { db }),
  ]);
  const statuses = [first.status, second.status].sort();
  assertEquals(statuses, [200, 400]);
  const loser = first.status === 400 ? first : second;
  const json = await loser.json();
  assertEquals(json.code, "INVITE_INVALID");
});

Deno.test("a soft-deleted family invite is refused", async () => {
  let accepted = false;
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({
      familyDeleted: true,
      onAccept: () => {
        accepted = true;
      },
    }),
  });
  const json = await res.json();
  assertEquals(res.status, 400);
  assertEquals(json.code, "INVITE_INVALID");
  assertEquals(json.message, "Invite is not valid");
  assertEquals(accepted, false);
});

Deno.test("invite lookup failures hide raw database text", async () => {
  const res = await acceptInvite(post({ token: "abc" }), {
    db: dbWith({ inviteError: rawDb }),
  });
  const body = await res.text();
  assertEquals(res.status, 400);
  assertEquals(body.includes(rawDb), false);
  assertEquals(body.includes("Could not look up invite"), true);
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

Deno.test("accept-invite rejects a token that is not a string", async () => {
  const res = await acceptInvite(post({ token: 12 }));
  assertEquals(res.status, 400);
  assertEquals(await res.json(), {
    code: "VALIDATION",
    message: "token is required",
  });
});

Deno.test("accept-invite rejects an empty body", () => expectInvalidJson(""));

Deno.test("accept-invite rejects invalid JSON", () => expectInvalidJson("{"));

Deno.test("accept-invite rejects a non-object body", async () => {
  await expectInvalidJson("[1]");
  await expectInvalidJson("\"hi\"");
});
