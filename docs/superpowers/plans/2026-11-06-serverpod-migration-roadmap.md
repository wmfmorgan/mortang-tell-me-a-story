# Serverpod Migration Roadmap

> **For agentic workers:** This is the roadmap. Each phase gets its own detailed plan in `docs/superpowers/plans/` before it starts. Execute those with superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Replace Supabase (Postgres RLS, GoTrue, Storage, Realtime, Deno edge functions) with a Serverpod 4 Dart backend on plain Postgres. The result is one language (Dart), runs locally with `mise` + `just` and no Docker, and works on both iPad and web.

**Architecture:** The Flutter client stays. Its `lib/data` gateways are re-pointed from `supabase_flutter` to a generated Serverpod client. Authorization moves out of RLS and SECURITY DEFINER SQL into Dart services keyed on family and tree. Blobs go to local disk in dev and S3-compatible storage in prod. Live updates use Serverpod streams. The daily purge becomes a Serverpod future call.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, Serverpod 4.1.1 (email one-time-code login needs 4.1+; 4.x needs Postgres ≥16), PostgreSQL 17 (mise-managed binaries, repo-local data dir), mise, just.

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
- `docs/migration/audit.md`: current-state audit
- `docs/migration/business-rules.md`: authorization matrix, invariants and workflows to port
- `docs/migration/schema-design.md`: new schema as Serverpod models
- `docs/migration/data-model-review.md`: data-model review (2026-11-07) applied to the schema
- `docs/migration/endpoint-contract.md`: gateway → endpoint map and client change list
- `docs/migration/serverpod-notes.md`: Serverpod 4.1 APIs used by these plans

---

## Phases

Every phase ends green on `just test` (client) and `just server-test` (backend, once it exists), and the app stays runnable after each one. Phases 1 and 2 run in parallel. Phase 3 slices run in parallel once Phase 1 lands.

| Phase | Outcome | Detailed plan |
|---|---|---|
| 1. Server foundation | `apps/server` + `packages/tell_me_a_story_client` scaffolded at 4.1.1; just recipes; embedded PG; full new schema + first migration; email-OTP login with a fixed dev code; `AppException`; `Authz` core with ported invariant tests | `2026-11-06-serverpod-phase1-server-foundation.md` |
| 2. Client seams (still on Supabase) | One `AppSession` replaces direct `Supabase.instance` reads; one `AppException` client error; duplicate-key handling and story discard moved into gateways; image URLs become bytes; direct query removed from `add_perspective_page` | `2026-11-06-serverpod-phase2-client-seams.md` |
| 3. Server endpoints (parallel slices) | 3a families/memberships/tree/origin/manage + places + profile; 3b people; 3c stories/drafts/story_people + search + notes; 3d photos/avatars/covers + `MediaEndpoint`; 3e invites; 3f live streams + purge future call. Each slice ports its business-rules test cases | written at Phase 1 close |
| 4. Client cutover | Every `*Api` body switched to the Serverpod client; 6-digit code login pages; `supabase_flutter` removed; tests updated | written at Phase 3 close |
| 5. Cleanup | Delete `supabase/`, `scripts/advisors/`, `e2e/`, the Supabase CLI from mise; CI on mise + just (`flutter test`, `server-test`); `AGENTS.md`, README and `netlify.toml` (or Serverpod web hosting) rewritten; e2e reads the dev OTP code | written at Phase 4 close |

## Open product decisions
These need an answer before the phase that touches them.
1. **Email change in Settings.** The 4.1.1 email IDP has no change-email flow. Either build a custom code-confirmed flow or drop the feature (Phase 4).
2. **The behaviours listed in `business-rules.md` §6**: accept on a soft-deleted family, invites not bound to an email, moderation, purge leaving photo blobs behind, decade precision unusable, and so on. Keep each as-is or fix it while porting (Phase 3).
3. **Tree semantics.** Tree reads are now `treeId` equality among live families. The old recursive walk split a tree at a soft-deleted middle family; the new one doesn't. Phase 1 adopts the simpler rule; reverse it only if the split mattered.
4. **`decade` date precision is dropped** (`schema-design.md` §0.3). It was already impossible to create; the client's `legacyDecade` paths are removed at cutover.
