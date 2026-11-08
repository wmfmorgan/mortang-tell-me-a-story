# Serverpod Migration Roadmap

> **For agentic workers:** This is the roadmap. Each phase gets its own detailed plan in `docs/superpowers/plans/` before it starts. Execute those with superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Replace Supabase (Postgres RLS, GoTrue, Storage, Realtime, Deno edge functions) with a Serverpod 4 Dart backend on plain Postgres. The result is one language (Dart), runs locally with `mise` + `just` and no Docker, and works on both iPad and web.

**Architecture:** The Flutter client stays. Its `lib/data` gateways are re-pointed from `supabase_flutter` to a generated Serverpod client. Authorization moves out of RLS and SECURITY DEFINER SQL into Dart services keyed on family and tree. Blobs go to local disk in dev and S3-compatible storage in prod. Live updates use Serverpod streams. The daily purge becomes a Serverpod future call.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, Serverpod 4.1.1 (email one-time-code login needs 4.1+; 4.x needs Postgres ≥16), PostgreSQL: Serverpod's embedded Postgres 16 in dev/test (`dataPath` in `config/*.yaml`, not mise-managed) and managed Postgres ≥16 in prod, mise, just.

**Decisions locked (2026-11-06):**
- Fresh start. Existing Supabase data is test data, so nothing is migrated and the hosted project gets retired.
- iPad + web stay the targets. Login is a 6-digit email code typed in the app, so no deep links are needed.
- Deno and Python are removed. Deno is already out of `mise.toml`; the Supabase CLI stays there only until Phase 5.
- The repo's previous spec process (`AGENTS.md`, `docs/impl-spec`) does not govern this work. `AGENTS.md` is rewritten in Phase 5.
- Dev and test Postgres is Serverpod's **embedded Postgres** (`dataPath` in `config/*.yaml`; PG 16, fetched by Serverpod's build hooks). There is no Docker, no system Postgres and no extra mise tool; this was checked in a scratch 4.1.1 scaffold, where `dart test` passed against embedded PG 16. Prod uses managed Postgres ≥16.
- Dev blob storage is Serverpod's `DatabaseCloudStorage` (with `maxRequestSize` raised). Prod is S3-compatible (`serverpod_cloud_storage_s3_compat`).
- Sign-up stays open, as today. The 4.1.1 email IDP has only `onAfterAccountCreated` and no pre-create hook, so every data endpoint gates on membership or invite.
- Package layout: `apps/server` (package `tell_me_a_story_server`) and `packages/tell_me_a_story_client` (generated). These are standalone packages, not a pub workspace, so the Flutter app's lockfile is untouched until cutover.
- Cutover is **big-bang**. Supabase users and Serverpod auth users have separate ids, so gateways can't switch one at a time. The client is first given seams while still on Supabase, the server is built and tested standalone, and then a single phase switches every gateway.

**Reference inputs** (produced by the 2026-11-06 audit):
- `docs/archive/migration/audit.md`: current-state audit
- `docs/archive/migration/business-rules.md`: authorization matrix, invariants and workflows to port
- `docs/archive/migration/schema-design.md`: new schema as Serverpod models
- `docs/archive/migration/data-model-review.md`: data-model review (2026-11-07) applied to the schema
- `docs/archive/migration/endpoint-contract.md`: gateway → endpoint map and client change list
- `docs/archive/migration/serverpod-notes.md`: Serverpod 4.1 APIs used by these plans

---

## Phases

Every phase ends green on `just test` (client) and `just server-test` (backend, once it exists), and the app stays runnable after each one. Phases 1 and 2 run in parallel. Phase 3 slices run in parallel once Phase 1 lands.

**Branches (from 2026-11-08):** `feature/serverpod`, cut from `main`, is the integration branch. Each phase gets its own PR into it: #174 for Phases 1–3 + 4.0 (`feat/serverpod-migration`), #175 for Phase 4 (`feat/p4-cutover`), then `feat/p5-cleanup` and `feat/p6-restructure`. `main` receives one final PR from `feature/serverpod` once every phase has landed.

| Phase | Outcome | Detailed plan |
|---|---|---|
| 1. Server foundation | `apps/server` + `packages/tell_me_a_story_client` scaffolded at 4.1.1; just recipes; embedded PG; full new schema + first migration; email-OTP login with a fixed dev code; `AppException`; `Authz` core with ported invariant tests | `2026-11-06-serverpod-phase1-server-foundation.md` |
| 2. Client seams (still on Supabase) | One `AppSession` replaces direct `Supabase.instance` reads; one `AppException` client error; duplicate-key handling and story discard moved into gateways; image URLs become bytes; direct query removed from `add_perspective_page` | `2026-11-06-serverpod-phase2-client-seams.md` |
| 3. Server endpoints (parallel slices) | 3a families/memberships/tree/origin/manage + places + profile; 3b people; 3c stories/drafts/story_people + search + notes; 3d photos + `MediaEndpoint`; 3e invites; 3f live streams + purge and blob-drain future calls. Shared foundation (3.0) lands first. Each slice ports its business-rules test cases. Decisions D2–D6 apply (invite email binding, live-family checks, moderation, person delete, full purge, branch person rows). | `2026-11-07-serverpod-phase3-server-endpoints.md` (index) and `2026-11-07-serverpod-phase3-0-foundation.md` |
| 4. Client cutover | Every `*Api` body switched to the Serverpod client; 6-digit code login pages; `supabase_flutter` removed; tests updated. Settings email becomes read-only (D1); reader shows delete on others' comments/perspectives for stewards via `NoteDto.canDelete` (D4). 4.0 foundation first, then slices 4a–4f on `feat/p4-cutover`, then 4z merges the switch in one step. **Landed 2026-11-07:** app 685, live 27, server 425, local e2e 9/9 flows. | `2026-11-07-serverpod-phase4-client-cutover.md` (index) and `2026-11-07-serverpod-phase4-0-foundation.md` |
| 5. Cleanup | Delete `supabase/`, `scripts/advisors/`, `e2e/`, the Supabase CLI from mise; CI on mise + just (`flutter test`, `server-test`); `AGENTS.md`, README and `netlify.toml` (or Serverpod web hosting) rewritten; e2e reads the dev OTP code; every existing doc archived to `docs/archive/` **Landed 2026-11-07:** app 686, server 425, live 27, e2e 9/9; CI on mise + just (first CI run pending push); Task 7 (netlify.toml) skipped for the GCP hosting branch. | `2026-11-08-serverpod-phase5-cleanup.md` |
| 6. Restructure | `lib/app` composition root, shared `lib/ui`, import-boundary guards, MagicLink → SignIn rename, colours fixed in skip-listed files before they move, tests mirror `lib/`, shared test fakes. Runs before the timeline UI rework. | `2026-11-08-serverpod-phase6-restructure.md` |

Plans for Phases 1–4 are in `docs/archive/superpowers/plans/`.

## Product decisions (2026-11-07)

| # | Topic | Decision |
|---|---|---|
| D1 | Email change in Settings | **Dropped.** There is no change-email flow. In Phase 4, Settings shows the email read-only. |
| D2 | Invite binding | An invite **with an email** can only be accepted while signed in as that email. Compare after trimming and lowercasing. A link-only invite (email null) works for anyone holding it. |
| D3 | Who invites | Unchanged: any **live** member can create and send invites. Only owners and co-owners can resend or revoke. |
| D4 | Moderation | Owners and co-owners of the story's family can delete **anyone's comments and perspectives** on published stories in that family. They cannot delete other people's stories. |
| D5 | Person delete | Only owners and co-owners of the person's (live) family may delete a person, and a person linked to an account (`userId != null`) can never be deleted. |
| D6a | Accept into deleted family | Refused, with `AppErrorCode.inviteInvalid`, the same as preview. |
| D6b | Access to deleted families | Every write and every member read requires a **live** family. Owners and co-owners keep read access to a soft-deleted family's row and memberships, so the recovery screen can work. Nothing else stays readable while deleted, including the cover. |
| D6c | Purge | Deletes **every** blob in the family: covers, story photos (original and edited), and the person avatars of the family's people. It fails closed: if blob deletion fails, the family row stays. |
| D6d | Branch owner person row | Creating a branch makes sure the branch owner and each picked member has a linked person in the tree. They reuse their existing linked person if they already have one; otherwise one is created in the branch. |
| D7 | Account deletion | Not offered now. The schema supports it; no endpoint or UI. |
| D8 | Tree semantics | Kept. "Same tree" means equal `treeId` among live families; a deleted middle family no longer splits a tree. |
| D9 | `decade` precision | Kept dropped. |
| D10 | Linked person's death date (2026-11-07) | Only the owner of the person's live home family sets it (`people.setDeathDate`), never the person themselves. Co-owners can still toggle the passed-away flag. |
| D11 | Upload for a story deleted before finish (2026-11-07) | Accepted: the blob stays in storage; no cleanup sweep. |
| D12 | Unpublish (2026-11-07) | No unpublish endpoint. |
| D13 | Sign-up display name (2026-11-07) | Email-code sign-up stores none; a new linked person falls back to the email local part. Accepted. |

Remove member (business-rules §6 item 9) still removes the member from **every** family in the tree, including soft-deleted ones. Otherwise recovering a deleted family would bring the removed member back. "Closed" (D6b) limits access; it does not narrow removal.

With the data-model review, people are tree-scoped. D5's "person's family" is the person's `homeFamilyId`. Under D6c, a purge of a family that is not the last in its tree reassigns that family's people to a sibling family, so they keep their avatars; a person's avatar is deleted when the person is. "Fails closed" is met by the `blob_deletions` outbox: the keys are queued in the purge transaction, a failed transaction leaves the family row, and the drain retries failed blob deletes (schema-design.md §4.3).

Phase 3 slices implement business-rules.md §2/§3/§7 as amended; nothing remains open.
