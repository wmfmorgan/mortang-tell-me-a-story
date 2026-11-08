# Tell Me a Story: audit for moving off Supabase

This is a read-only audit (6 parallel agents) as of `ae271b0`. Nothing was built or run. File:line evidence is in the agent outputs at `agent://DataModel`, `agent://EdgeFns`, `agent://ClientData`, `agent://ClientUI`, `agent://ProductScope` and `agent://TestsInfra`.

## Current runtimes
| Runtime | Where | LOC | Verdict |
|---|---|---|---|
| Dart / Flutter | `apps/tell_me_a_story` | 31.6k lib (26k UI, 4.1k data) + 31k tests | Keep the UI. Rewrite `lib/data` (about 5k LOC touched) |
| SQL / plpgsql | 38 migrations, about 63 functions (about 50 SECURITY DEFINER), 14 triggers, 51 RLS policies | 6.5k + 12k pgTAP | Redesign. Move authorization into app code. Port about 25 business-rule test themes |
| Deno TS | 15 edge functions + `_shared` + `e2e/relay.ts` | about 2.2k | Remove. Only about 650 LOC is real logic; 10 of the 15 functions are one-RPC wrappers |
| Python | `scripts/advisors` (Supabase splinter lint gate) | about 1.9k | Remove. It only exists because PostgREST exposes the DB directly |
| Supabase CLI + Docker | local dev, CI pgtap/e2e | n/a | Remove |
| Bash | `e2e/check_flows.sh`, CI | about 150 | Small enough to ignore |

## Supabase features in use and what replaces them
| Supabase piece | How it is used | Replacement |
|---|---|---|
| GoTrue magic link (PKCE), `auth.users` triggers | the only login method | backend `login_tokens` + `sessions` tables; email via Resend in prod, printed to the console / dev mail sink locally |
| PostgREST | 11 tables, 57 `.from()` calls with embeds (`families!inner`, `profiles!author_id`, …) | about 40–50 JSON endpoints that do the joins on the server |
| RPCs | 8 called from the client; about 30 definer RPCs in total | backend service methods |
| Edge functions | 15 (invites, family management) | backend endpoints; make accept-invite a single transaction and hash the tokens |
| Storage | 4 buckets, path regex policies, signed URLs (3600s) | blob interface: local disk for dev, S3/R2 in prod, signed URLs from the backend |
| Realtime | `postgres_changes` on stories/photos/comments/perspectives, filtered by family, 200ms debounce | SSE `/families/:id/events` from the backend (isolated behind `TimelineLive`) |
| pg_cron + http + vault | 60-day purge of deleted families, including covers | in-process scheduled job in the backend |
| RLS + column grants + GUC bypass flags + owner-name check | the whole security model | ordinary authz functions keyed on `tree_id`, covered by integration tests |

## Data model problems
- Hotfix churn: the `families_guard_update` trigger was redefined 4×, `list_unlinked_people` 4×, and the `people_tree_read` view was created 4× before being dropped as a security hole.
- `comments` and `perspectives` are identical tables.
- The family tree is computed by a recursive `parent_family_id` CTE that runs inside RLS for every row. A stored `tree_id` would avoid this.
- Columns are duplicated: `family_id` on photos/comments/perspectives (needed only for RLS and realtime), `people.name` synced from `profiles.display_name`, `profiles.email` copied from auth.
- `created_at` is missing on invites, places, photos and memberships. Profile foreign keys use NO ACTION, so deleting an account fails.
- The `invite_status 'expired'` value duplicates `expires_at`. Story dates are nullable and checked in two places.
- One-shot data-fix functions (`merge_copied_people`, `backfill_linked_person_names`) are still installed.
- `docs/design-doc/data-model.md` is stale.

### Proposed minimal schema
users, login_tokens, sessions, trees, families(tree_id, parent_id, origin_story_id, deleted_at), memberships(PK family+user, role), people(user_id unique per tree), places, stories, story_people, photos(original_key, edited_key, edit_version), story_notes(kind = comment|perspective), invites(token_hash, revoked_at, created_at).

## Client coupling
- Gateways (`abstract class XGateway`) already exist for all 14 data files, so the seam is in place.
- Supabase leaks outside `lib/data`:
  - 11 feature files call `Supabase.instance` (9 just read `currentUser.id`; `add_perspective_page` runs a query directly).
  - `PostgrestException` is caught in `new_story_page` and `families_api`.
  - 3 different error-mapping paths: `rpc_error.dart`, `originRpcException`, and the `_invoke` envelopes.
- There is no DI: `widget.api ?? XApi()` appears about 50×, and the router does network calls inside `redirect`.
- Tests: about 17 files are tied to PostgREST URLs and response shapes. Hand-written fakes are copy-pasted across about 31 files.
- iOS has no deep links / associated domains, so magic links can't return to the app. Web is the only working target today.

## Rules locked by the spec (amendments needed)
- Impl Spec §1 and §2 lock Flutter + Supabase + Edge + Resend + Mapbox.
- §9 forbids a "custom REST API outside PostgREST + Edge".
- §8 locks Supabase Auth. §14 and AGENTS.md lock the gates (`supabase test db`, deno, 47/51 policies, a 32-entry SECURITY DEFINER allowlist).
- The spec says "no starting over" (spec:1912) and "never edit an earlier migration".
- These need sign-off from the spec owners (Jared, Gilfoyle, Bill) before any migration PR can land under the current process.

## Target-stack options
| Option | Runtimes | Local dev | Tradeoffs |
|---|---|---|---|
| **A. Dart everywhere** (Flutter + Dart backend: shelf / dart_frog, or Serverpod) + Postgres (SQLite locally optional) | 1 language + SQL | `dart run bin/server.dart` + SQLite or a Postgres container, local disk for blobs, magic link printed to the console | Models and validation can be shared with the client; the team already writes Dart. Smaller backend ecosystem; Serverpod is opinionated |
| **B. Flutter + Go or TS backend** + Postgres | 2 languages | single binary (Go) or `node`/`bun` | Mature backend ecosystem. Two languages, and DTOs are duplicated |
| **C. Full TS rewrite** (React/Next + Postgres) | 1 language | `bun dev` | Throws away 26k UI + 31k tests, including the gesture-driven timeline. iOS becomes a PWA or React Native |

Recommendation: **A**. Keep the Flutter UI, add a Dart backend package in the same repo, and use Postgres in prod and either Postgres or SQLite locally. This is the only option that gets to one language without discarding the client.

## Migration order (strangler)
1. Get the spec amendment approved; freeze new feature work against Supabase.
2. Client prep, still on Supabase:
   - one `Session` service in place of the `currentUser` reads;
   - a single `{code, message}` error envelope;
   - DI for gateways;
   - remove the direct query in `add_perspective_page`.
3. Backend skeleton:
   - new schema migrations (plain SQL, no `auth.*` / `storage.*` references);
   - auth (magic link + sessions);
   - authz module;
   - port the business-rule tests from the pgTAP themes (tenant isolation, role matrix, tree read, origin, authorship, drafts, DOB, invites, photo cap and edit versioning).
4. Re-point the gateways one at a time: families/memberships → people/places → stories/story_people → notes → photos (blob store) → invites → realtime (SSE).
5. Data migration from the hosted project `lchytafmnuefrgkguynt`:
   - `auth.users` + `profiles` → `users`;
   - copy the bucket objects into S3/R2;
   - remap storage paths to keys.
6. Delete `supabase/`, the Deno functions, `scripts/advisors`, `e2e/relay.ts`, and the `supabase_flutter` dependency. Rewrite CI as dart analyze/test + a backend integration job against Postgres. Make e2e use a test-only login-token endpoint.
7. Hosting (decided, shipped on `feat/gcp-story-line`): the API runs on Cloud Run with Cloud SQL Postgres 16; the web build is on Firebase Hosting; photos are stored in Postgres through `DatabaseCloudStorage` (no R2/S3); infra is Terraform in `infra/gcp`.
