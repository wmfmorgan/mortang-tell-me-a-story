import { assertEquals } from "jsr:@std/assert@1";

import { decideInvite } from "./invite_decision.ts";

const keys = [
  "valid",
  "code",
  "message",
  "family_id",
  "family_name",
  "inviter_name",
  "status",
  "expires_at",
];

const live = {
  family_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  status: "pending",
  expires_at: "2099-01-01T00:00:00.000Z",
  family_name: "Morgan",
  family_deleted: false,
  inviter_name: "Ada",
};

Deno.test("a live invite returns the inviter name", () => {
  const body = decideInvite(live);
  assertEquals(body.valid, true);
  assertEquals(body.inviter_name, "Ada");
  assertEquals(body.family_name, "Morgan");
  assertEquals(Object.keys(body).sort(), [...keys].sort());
});

Deno.test("a missing inviter name is null", () => {
  const body = decideInvite({ ...live, inviter_name: null });
  assertEquals(body.valid, true);
  assertEquals(body.inviter_name, null);
});

Deno.test("a soft-deleted family is INVITE_INVALID and stays 200-shaped", () => {
  const body = decideInvite({ ...live, family_deleted: true });
  assertEquals(body.valid, false);
  assertEquals(body.code, "INVITE_INVALID");
  assertEquals(body.message, "Invite is not valid");
  assertEquals(Object.keys(body).sort(), [...keys].sort());
});

Deno.test("invalid results use the locked codes", () => {
  const accepted = decideInvite({ ...live, status: "accepted" });
  assertEquals(accepted.code, "INVITE_ACCEPTED");
  const revoked = decideInvite({ ...live, status: "revoked" });
  assertEquals(revoked.code, "INVITE_INVALID");
  assertEquals(revoked.status, "revoked");
  const storedExpired = decideInvite({ ...live, status: "expired" });
  assertEquals(storedExpired.code, "INVITE_INVALID");
  const past = decideInvite(
    { ...live, expires_at: "2000-01-01T00:00:00.000Z" },
    Date.parse("2020-01-01T00:00:00.000Z"),
  );
  assertEquals(past.code, "INVITE_EXPIRED");
  assertEquals(past.valid, false);
});
