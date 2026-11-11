# Serverpod Migration Roadmap

> **For agentic workers:** Roadmap. Each phase gets own detailed plan in `docs/superpowers/plans/` before start. Execute with superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Replace Supabase (Postgres RLS, GoTrue, Storage, Realtime, Deno edge functions) with Serverpod 4 Dart backend on plain Postgres. Result: one language (Dart), runs locally with `mise` + `just`, no Docker, works on iPad + web.

**Architecture:** Flutter client stays. `lib/data` gateways re-pointed from `supabase_flutter` to generated Serverpod client. Authz moves out of RLS + SECURITY DEFINER SQL into Dart services keyed on family + tree. Blobs → local disk in dev, S3-compatible in prod. Live updates via Serverpod streams. Daily purge → Serverpod future call.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, Serverpod 4.1.1 (email one-time-code login needs 4.1+; 4.x needs Postgres ≥16), PostgreSQL: Serverpod embedded Postgres 16 in dev/test (`dataPath` in `config/*.yaml`, not mise-managed), managed Postgres ≥16 in prod, mise, just.

**Decisions locked (2026-11-06):**
- Fresh start. Existing Supabase data = test data; nothing migrated, hosted project retired.
- Targets stay iPad + web. Login = 6-digit email code typed in app; no deep links.
- Deno + Python removed. Deno already out of `mise.toml`; Supabase CLI stays there only until Phase 5.
- Repo's old spec process (`AGENTS.md`, `docs/archive/impl-spec`) not governing this work. `AGENTS.md` rewritten in Phase 5.
- Dev/test Postgres = Serverpod **embedded Postgres** (`dataPath` in `config/*.yaml`; PG 16, fetched by Serverpod build hooks). No Docker, no system Postgres, no extra mise tool; verified in scratch 4.1.1 scaffold, `dart test` passed against embedded PG 16. Prod = managed Postgres ≥16.
- Dev blob storage = Serverpod `DatabaseCloudStorage` (`maxRequestSize` raised). Prod = S3-compatible (`serverpod_cloud_storage_s3_compat`).
- Sign-up stays open, as today. 4.1.1 email IDP has only `onAfterAccountCreated`, no pre-create hook, so every data endpoint gates on membership or invite.
- Package layout: `apps/server` (package `tell_me_a_story_server`) + `packages/tell_me_a_story_client` (generated). Standalone packages, not pub workspace, so Flutter app lockfile untouched until cutover.
- Cutover **big-bang**. Supabase users + Serverpod auth users have separate ids, so gateways can't switch one at a time. Client gets seams first while still on Supabase, server built + tested standalone, then single phase switches every gateway.

**Reference inputs** (from 2026-11-06 audit):
- `docs/archive/migration/audit.md`: current-state audit
- `docs/archive/migration/business-rules.md`: authz matrix, invariants, workflows to port
- `docs/archive/migration/schema-design.md`: new schema as Serverpod models
- `docs/archive/migration/data-model-review.md`: data-model review (2026-11-07) applied to schema
- `docs/archive/migration/endpoint-contract.md`: gateway → endpoint map + client change list
- `docs/archive/migration/serverpod-notes.md`: Serverpod 4.1 APIs used by plans

---

## Phases

Every phase ends green on `just test` (client) and `just server-test` (backend, once exists); app stays runnable after each. Phases 1 + 2 parallel. Phase 3 slices parallel once Phase 1 lands.

**Branches (from 2026-11-08):** `feature/serverpod`, cut from `main`, = integration branch. Each phase own PR into it: #174 for Phases 1–3 + 4.0 (`feat/serverpod-migration`), #175 for Phase 4 (`feat/p4-cutover`), then `feat/p5-cleanup` and `feat/p6-restructure`. `main` gets one final PR from `feature/serverpod` once all phases landed.

| Phase | Outcome | Detailed plan |
|---|---|---|
| 1. Server foundation | `apps/server` + `packages/tell_me_a_story_client` scaffolded at 4.1.1; just recipes; embedded PG; full new schema + first migration; email-OTP login with fixed dev code; `AppException`; `Authz` core with ported invariant tests | `2026-11-06-serverpod-phase1-server-foundation.md` |
| 2. Client seams (still on Supabase) | One `AppSession` replaces direct `Supabase.instance` reads; one `AppException` client error; duplicate-key handling + story discard moved into gateways; image URLs → bytes; direct query removed from `add_perspective_page` | `2026-11-06-serverpod-phase2-client-seams.md` |
| 3. Server endpoints (parallel slices) | 3a families/memberships/tree/origin/manage + places + profile; 3b people; 3c stories/drafts/story_people + search + notes; 3d photos + `MediaEndpoint`; 3e invites; 3f live streams + purge and blob-drain future calls. Shared foundation (3.0) first. Each slice ports its business-rules test cases. D2–D6 apply (invite email binding, live-family checks, moderation, person delete, full purge, branch person rows). | `2026-11-07-serverpod-phase3-server-endpoints.md` (index) and `2026-11-07-serverpod-phase3-0-foundation.md` |
| 4. Client cutover | Every `*Api` body switched to Serverpod client; 6-digit code login pages; `supabase_flutter` removed; tests updated. Settings email read-only (D1); reader shows delete on others' comments/perspectives for stewards via `NoteDto.canDelete` (D4). 4.0 foundation first, then slices 4a–4f on `feat/p4-cutover`, then 4z merges switch in one step. **Landed 2026-11-07:** app 685, live 27, server 425, local e2e 9/9 flows. | `2026-11-07-serverpod-phase4-client-cutover.md` (index) and `2026-11-07-serverpod-phase4-0-foundation.md` |
| 5. Cleanup | Delete `supabase/`, `scripts/advisors/`, `e2e/`, Supabase CLI from mise; CI on mise + just (`flutter test`, `server-test`); `AGENTS.md`, README, `netlify.toml` (or Serverpod web hosting) rewritten; e2e reads dev OTP code; all existing docs archived to `docs/archive/` **Landed 2026-11-07:** app 686, server 425, live 27, e2e 9/9; CI on mise + just (first CI run pending push); Task 7 (netlify.toml) skipped for GCP hosting branch. | `2026-11-08-serverpod-phase5-cleanup.md` |
| 6. Restructure | `lib/app` composition root, shared `lib/ui`, import-boundary guards, MagicLink → SignIn rename, colours fixed in skip-listed files before move, tests mirror `lib/`, shared test fakes. Runs before timeline UI rework. **Landed 2026-11-07:** app 689, server 425, live 27, e2e 9/9; colour skip list 23 → 17 with nine new pixel-identical tokens; CI pending push. | `2026-11-08-serverpod-phase6-restructure.md` |
| 7. Timeline UI | Lab import, golden harness, timeline tokens + primitives, rail split + restyle with iPad input, dim-only filters, server tree reads (`listPublishedInTree`, `watchTree`), whole-tree page with treemap + family tree graph. **Landed 2026-11-08:** app 973, server 447, live 29, e2e 9/9, goldens 14 (macOS, `just test-goldens`); colour skip list 17 → 16; 7.M iPad passed on owner's verdict; timeline lab deleted at 7.z (O7). Deployed to `story-line-app` from `3429aff`. | `2026-11-08-phase7-timeline-ui.md` |

Plans for Phases 1–4 in `docs/archive/superpowers/plans/`.

## Product decisions (2026-11-07)

| # | Topic | Decision |
|---|---|---|
| D1 | Email change in Settings | **Dropped.** No change-email flow. Phase 4 Settings shows email read-only. |
| D2 | Invite binding | Invite **with email** acceptable only while signed in as that email. Compare after trim + lowercase. Link-only invite (email null) works for anyone holding it. |
| D3 | Who invites | Unchanged: any **live** member creates + sends invites. Only owners + co-owners resend or revoke. |
| D4 | Moderation | Owners + co-owners of story's family can delete **anyone's comments and perspectives** on published stories in that family. Cannot delete others' stories. |
| D5 | Person delete | Only owners + co-owners of person's (live) family may delete person; person linked to account (`userId != null`) never deletable. |
| D6a | Accept into deleted family | Refused with `AppErrorCode.inviteInvalid`, same as preview. |
| D6b | Access to deleted families | Every write + every member read requires **live** family. Owners + co-owners keep read access to soft-deleted family row + memberships so recovery screen works. Nothing else readable while deleted, incl. cover. |
| D6c | Purge | Deletes **every** blob in family: covers, story photos (original + edited), avatars of family's people. Fails closed: blob deletion fails → family row stays. |
| D6d | Branch owner person row | Creating branch ensures branch owner + each picked member has linked person in tree. Reuse existing linked person if present; else create one in branch. |
| D7 | Account deletion | Not offered now. Schema supports it; no endpoint or UI. |
| D8 | Tree semantics | Kept. "Same tree" = equal `treeId` among live families; deleted middle family no longer splits tree. |
| D9 | `decade` precision | Stays dropped. |
| D10 | Linked person's death date (2026-11-07) | Only owner of person's live home family sets it (`people.setDeathDate`), never person themselves. Co-owners still toggle passed-away flag. |
| D11 | Upload for story deleted before finish (2026-11-07) | Accepted: blob stays in storage; no cleanup sweep. |
| D12 | Unpublish (2026-11-07) | No unpublish endpoint. |
| D13 | Sign-up display name (2026-11-07) | Email-code sign-up stores none; new linked person falls back to email local part. Accepted. |

Remove member (business-rules §6 item 9) still removes member from **every** family in tree, incl. soft-deleted. Else recovering deleted family would restore removed member. "Closed" (D6b) limits access; doesn't narrow removal.

Per data-model review, people tree-scoped. D5 "person's family" = person's `homeFamilyId`. Under D6c, purge of family not last in its tree reassigns its people to sibling family, so avatars kept; person's avatar deleted when person deleted. "Fails closed" met by `blob_deletions` outbox: keys queued in purge transaction, failed transaction leaves family row, drain retries failed blob deletes (schema-design.md §4.3).

Phase 3 slices implement business-rules.md §2/§3/§7 as amended; nothing open.