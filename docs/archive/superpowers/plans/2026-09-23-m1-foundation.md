# M1 Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` after human approval. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Gate:** Plan-only until human approves. Do not write application code until approval.

**Goal:** Deliver agent-complete M1 Foundation work against **local** Supabase: schema + RLS per Design Doc; magic link (local); profile trigger; empty Flutter app wired (iOS + web). **Do not claim full §15 M1 exit criteria complete** until Bill closes cloud staging OPEN (or waives in writing).

**Architecture:** Flutter monorepo client at `apps/tell_me_a_story` + `supabase/` for migrations, config, and RLS SQL tests. Local `supabase start` is the **intended M1 agent data plane** (migrations, RLS tests, magic-link verification). Cloud staging is **OPEN (Bill decision)** — First 10 #2 / §15 “Supabase project + staging” stays open until a staging project exists with Email magic link enabled there.

**Tech Stack (locked):** Flutter 3.x, `supabase_flutter`, Supabase Postgres/Auth/Storage/RLS, Email magic link. Secrets via `--dart-define` only: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (Mapbox deferred to M3).

## Global Constraints

- **SoT precedence:** PRD must/must-not → Mugatu screens/copy → SAD names → Design Doc DDL/RLS/Storage/Edge/error codes → Impl Spec §10 routes/behavior → Client copy & chrome locks for strings.
- **M1 scope only:** First 10 actions **1–5** + **#10** (RLS isolation). Defer **#6–8** (family create, Edge invites, Mapbox). First 10 **#9 split:** M1 = private `story-photos` bucket + path-prefix policies in migrations only; Flutter upload spike = **M4**.
- **Repo map §3:** `apps/tell_me_a_story/` + `supabase/` only. Include empty `lib/data/` scaffold. No extra packages beyond SAD/Design Doc need.
- **Out of v1 (do not touch):** SMS, offline drafts, video, Android-required polish, public multi-family, AI stories, genealogy primary UX, live chat, DNA.
- **Secrets:** Never commit `.env`, service role, or Resend keys. Inject later via dart-define/CI. Do **not** invent or create a cloud Supabase project.
- **Git:** Branch `feat/m01-foundation` from latest `main` in one worktree. Open PR; do not merge. No `--no-verify`, no force-push shared branches. Do not start M2 until M1 PR approved and merged.
- **Auth UI:** Chrome locks require signed-out → magic-link entry; post-auth → `/timeline`. Minimal magic-link entry only — no invented Stitch auth screen; no freestyle marketing copy (Mugatu OPEN if labels missing).
- **Supabase project:** Local `supabase start` = agent test plane. **Cloud staging = OPEN (Bill).** Local does **not** close First 10 #2 / §15 staging criterion.

## Preconditions / blockers (report, do not invent around)

| Item | Status at plan time |
|------|---------------------|
| Repo `wmfmorgan/mortang-tell-me-a-story` | Local `main` has **zero commits**; remote may be empty |
| Flutter SDK | **Not on PATH** (`flutter` missing) — install Flutter 3.x before client tasks |
| Supabase CLI | Present (`2.114.0`) |
| Cloud staging project | **OPEN (Bill)** — agent must not create; local stack for M1 agent work |

## Spec match (M1)

| Exit criterion (§15 M1) | M1 agent delivery | Status |
|-------------------------|-------------------|--------|
| Supabase project + staging | Local `supabase start` only; **no cloud project created by agent** | **OPEN (Bill)** — First 10 #2 |
| Schema + RLS per Design Doc | Migrations matching Design Doc enums/DDL/`handle_new_user`/`is_family_member` + RLS matrix + storage policies | Agent closes on local |
| Magic link | Email auth in local `config.toml`; Flutter magic-link entry verified locally | Local yes; staging magic link **OPEN (Bill)** |
| Profile trigger | `handle_new_user` after insert on `auth.users` | Agent closes |
| Empty Flutter app wired (iOS + web) | Skeleton + `lib/core`, `lib/features/...`, **`lib/data/`** + `supabase_flutter` via dart-define | Agent closes (needs Flutter SDK) |
| Checks (§14 slice) | `flutter test`; RLS SQL two-family leak test; profile trigger test (against local) | Agent closes on local |

**PR title/body stance:** `M1 Foundation (local + staging OPEN)` — do not claim full §15 M1 complete until staging exists and Email magic link is enabled there (or Bill waives in writing).

## Files to touch (repo map §3)

### Create

| Path | Responsibility |
|------|----------------|
| `.gitignore` | Dart/Flutter, Supabase `.branches`/`.temp`, `.env*`, IDE, `.worktrees/` |
| `README.md` | Monorepo layout, dart-define vars, `supabase start`, test commands, Bill staging note |
| `analysis_options.yaml` (root or app) | As needed per plumbing lock |
| `apps/tell_me_a_story/` | Flutter create target (iOS + web) |
| `apps/tell_me_a_story/lib/main.dart` | Entry; bootstrap |
| `apps/tell_me_a_story/lib/app.dart` | MaterialApp + router shell |
| `apps/tell_me_a_story/lib/core/config/env.dart` | Read `SUPABASE_URL`, `SUPABASE_ANON_KEY` from dart-define |
| `apps/tell_me_a_story/lib/core/supabase/supabase_init.dart` | `Supabase.initialize` (anon only) |
| `apps/tell_me_a_story/lib/core/router/app_router.dart` | Routes: magic-link entry; `/timeline` stub; auth redirect per chrome locks |
| `apps/tell_me_a_story/lib/features/auth/` | Magic-link sign-in screen + session gate |
| `apps/tell_me_a_story/lib/features/timeline/` | Minimal `/timeline` placeholder (empty shell for post-auth redirect only — full timeline UX is M6) |
| `apps/tell_me_a_story/lib/data/` | **Empty scaffold only** (Impl Spec §3) — create directory (e.g. `.gitkeep`); no repositories/models invented in M1 |
| `apps/tell_me_a_story/test/` | Smoke tests: env wiring, auth redirect gate (no live network required where possible) |
| `supabase/config.toml` | `supabase init` defaults; Email auth on |
| `supabase/migrations/YYYYMMDDHHMMSS_enums.sql` | `story_status`, `invite_status`, `membership_role` |
| `supabase/migrations/YYYYMMDDHHMMSS_ddl.sql` | All Design Doc tables + indexes + timeframe check |
| `supabase/migrations/YYYYMMDDHHMMSS_profile_trigger.sql` | `handle_new_user` + trigger |
| `supabase/migrations/YYYYMMDDHHMMSS_rls.sql` | `is_family_member` + explicit policies per Design Doc matrix |
| `supabase/migrations/YYYYMMDDHHMMSS_storage.sql` | Private bucket `story-photos` + path-prefix `is_family_member` policies (First 10 #9 M1 half) |
| `supabase/tests/rls_two_family_isolation.sql` | Mandatory two-family zero cross-read |
| `supabase/tests/profile_trigger.sql` | New auth user → profiles row without client upsert |
| `docs/superpowers/plans/2026-09-23-m1-foundation.md` | Copy of this plan in-repo (optional on implement) |

### Explicitly NOT in M1 (later milestones)

- `supabase/functions/*` (M2) — First 10 #7
- Family create + membership insert path (M2) — First 10 #6
- Mapbox token / place picker (M3) — First 10 #8
- Flutter compress-and-upload spike / any upload client code (M4) — First 10 #9 client half
- Product UI: `features/family`, `invites`, `people`, `places`, `stories`, `comments`, `perspectives`, `search`, `drafts`

### First 10 #9 split (must appear in PR body)

| Half | Milestone | Deliverable |
|------|-----------|-------------|
| Storage foundation | **M1** | Private `story-photos` bucket + path-prefix policies per Design Doc §3 in migrations |
| Upload spike | **M4** | Client compress-and-upload; **no Flutter upload code in M1** |

## OPEN / CONFLICT to list in PR if encountered

- **OPEN (Bill) — First 10 #2 / §15 staging:** Cloud staging project + Email magic link enabled there. Agent uses local only. Do not invent/create cloud project. Full M1 exit criteria remain incomplete until Bill closes this (or waives in writing).
- **OPEN (tooling):** Flutter SDK must be installed on the agent machine before `flutter create` / `flutter test`. Report blocker; do not invent around it.
- **CONFLICT:** If `flutter create` layout disagrees with Impl Spec §3 (`lib/core`, `lib/features/...`, `lib/data`) — **stop, report, reshape immediately**. Do **not** defer `lib/data/`.
- **OPEN (Mugatu):** If exact magic-link button/field labels are missing from chrome locks, use minimal functional labels only and list OPEN — do not freestyle Memory Album marketing copy.

---

### Task 1: Repo bootstrap + worktree

**Files:**
- Create: `.gitignore`, empty-commit baseline on `main` if still empty
- Create worktree: `.worktrees/feat-m01-foundation` on branch `feat/m01-foundation`

**Interfaces:**
- Consumes: none
- Produces: isolated branch ready for M1 commits

- [ ] **Step 1: Verify isolation state**

```bash
cd /Users/jabroni/Projects/mortang-tell-me-a-story
GIT_DIR=$(cd "$(git rev-parse --git-dir)" && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
git rev-parse --show-superproject-working-tree 2>/dev/null
git status
git ls-remote origin
```

- [ ] **Step 2: Ensure `.worktrees/` is ignored**

Add `.worktrees/` to `.gitignore`. Confirm:

```bash
git check-ignore -q .worktrees
```

- [ ] **Step 3: Create initial `main` commit if empty**

```bash
# Only if no commits yet — minimal .gitignore + README stub allowed as chore bootstrap
git add .gitignore README.md
git commit -m "chore: initialize monorepo baseline for M1"
```

If remote already has commits: `git pull origin main` first; do not rewrite history.

- [ ] **Step 4: Create worktree + branch**

```bash
git worktree add .worktrees/feat-m01-foundation -b feat/m01-foundation
cd .worktrees/feat-m01-foundation
```

---

### Task 2: Supabase local project + Design Doc migrations

**Files:**
- Create: `supabase/config.toml`
- Create: `supabase/migrations/*_enums.sql`, `*_ddl.sql`, `*_profile_trigger.sql`, `*_rls.sql` (and storage bucket policies for `story-photos` per Design Doc §3)

**Interfaces:**
- Consumes: Design Doc §1–§4 (enums, DDL, RLS matrix, profile trigger, storage)
- Produces: Migrated local DB matching Design Doc exactly

- [ ] **Step 1: Init Supabase in worktree**

```bash
supabase init
```

Enable Email auth in `config.toml` (magic link). Do not enable SMS providers.

- [ ] **Step 2: Write enums migration (exact names)**

```sql
create type story_status as enum ('draft', 'published');
create type invite_status as enum ('pending', 'accepted', 'revoked', 'expired');
create type membership_role as enum ('member');
```

- [ ] **Step 3: Write DDL migration**

Tables/columns/indexes exactly as Design Doc: `profiles`, `families`, `memberships`, `people`, `places`, `stories` (with `timeframe_start date not null`, `timeframe_end date` nullable + check end ≥ start), `story_people`, `photos`, `comments`, `perspectives`, `invites` (token unique, `expires_at`, single-use semantics enforced in Edge later).

- [ ] **Step 4: Profile bootstrap trigger**

```sql
-- after insert on auth.users → handle_new_user() inserts profiles (id, email, display_name)
-- No client upsert for bootstrap
```

- [ ] **Step 5: RLS helper + policies**

Implement `public.is_family_member(fid uuid)` as Design Doc. Enable RLS on all public tables. Expand Design Doc matrix to explicit `create policy` statements. Never weaken membership checks. Memberships INSERT/UPDATE/DELETE: Edge/security definer only.

- [ ] **Step 6: Storage foundation (First 10 #9 — M1 half only)**

Migration creates private bucket `story-photos` and policies requiring `is_family_member` on path prefix `{family_id}/...`. Allowed extensions `.jpg` `.jpeg` `.png` `.webp`. **No Flutter upload code.**

- [ ] **Step 7: Start local stack and apply**

```bash
supabase start
supabase db reset   # applies migrations
```

Expected: clean apply, no invent columns. This is the agent data plane — it does **not** close cloud staging OPEN.

- [ ] **Step 8: Commit**

```bash
git add supabase/
git commit -m "feat(m01): add Design Doc DDL, profile trigger, and RLS migrations"
```

---

### Task 3: RLS + profile SQL tests (§14)

**Files:**
- Create: `supabase/tests/rls_two_family_isolation.sql`
- Create: `supabase/tests/profile_trigger.sql`

**Interfaces:**
- Consumes: migrated schema
- Produces: pass/fail evidence for PR body

- [ ] **Step 1: Two-family isolation test**

Script creates two users, two families/memberships, inserts tenant rows, asserts User A cannot SELECT family 2 `stories`/`photos`/`people`/`places`/`invites`.

- [ ] **Step 2: Profile trigger test**

Insert into `auth.users` (local test helper / service role in SQL test harness) → assert `profiles` row exists; assert client-style upsert is unnecessary.

- [ ] **Step 3: Author-rule smoke (minimal §14 #2 if cheap)**

Non-author cannot UPDATE story core; optional in M1 if time-boxed — prefer full §14 #1 and #8 mandatory for M1 gate.

- [ ] **Step 4: Run tests and capture output**

```bash
# Exact runner depends on supabase test harness available; prefer:
supabase test db
# or documented psql against local DB with output saved for PR
```

Expected: PASS two-family leak test.

- [ ] **Step 5: Commit**

```bash
git add supabase/tests/
git commit -m "test(m01): add two-family RLS isolation and profile trigger tests"
```

---

### Task 4: Flutter app skeleton + Supabase wire-up

**Files:**
- Create: full `apps/tell_me_a_story/` via `flutter create`
- Create/modify: `lib/main.dart`, `lib/app.dart`, `lib/core/config/env.dart`, `lib/core/supabase/supabase_init.dart`, `lib/core/router/app_router.dart`, `lib/features/auth/*`, `lib/features/timeline/*` stub, tests

**Interfaces:**
- Consumes: `SUPABASE_URL`, `SUPABASE_ANON_KEY` via `--dart-define`
- Produces: empty app that initializes Supabase anon client; signed-out → magic-link entry; signed-in → `/timeline` stub

- [ ] **Step 1: Install Flutter 3.x if missing** (machine prerequisite)

```bash
which flutter || (echo "BLOCKED: install Flutter 3.x" && exit 1)
flutter --version
```

- [ ] **Step 2: Create app**

```bash
mkdir -p apps
flutter create --org com.mortang --platforms=ios,web apps/tell_me_a_story
```

Reshape `lib/` to §3 **immediately**: `core/`, `features/auth/`, `features/timeline/`, **`data/`** (empty scaffold with `.gitkeep`). If template layout disagrees with §3 — stop, report CONFLICT, reshape; **do not defer `lib/data/`**.

- [ ] **Step 3: Add dependency**

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: # current stable compatible with Flutter 3.x
  go_router: # or equivalent; routes must match chrome lock paths
```

```bash
cd apps/tell_me_a_story && flutter pub get
```

- [ ] **Step 4: Env + init (anon only)**

```dart
// env.dart — String.fromEnvironment('SUPABASE_URL'), String.fromEnvironment('SUPABASE_ANON_KEY')
// supabase_init.dart — Supabase.initialize(url:, anonKey:) — never service role
```

- [ ] **Step 5: Router + auth gate**

Routes locked for M1 use:
- Magic-link entry (signed-out)
- `/timeline` stub (signed-in home)
- Redirect: signed-out → magic-link entry; post-auth → `/timeline`

Do not implement full §10 product screens in M1.

- [ ] **Step 6: Magic-link screen**

Email field + request magic link via `supabase.auth.signInWithOtp` (email). Session listener updates router. Verify against local Supabase Inbucket/Mailpit for link completion in manual check.

- [ ] **Step 7: Tests**

```bash
cd apps/tell_me_a_story
flutter test
```

Expected: PASS smoke tests (env missing fails closed; router redirects without session).

- [ ] **Step 8: Commit**

```bash
git add apps/tell_me_a_story/
git commit -m "feat(m01): scaffold Flutter iOS/web app wired to supabase_flutter"
```

---

### Task 5: README + PR (lane pass)

**Files:**
- Modify: `README.md`
- Create: PR via `gh`

**PR title:** `feat(m01): Foundation (local + staging OPEN)`

**PR body must include:**
1. Milestone **M1** → exact §15 exit criteria listed; agent-complete vs **OPEN (Bill)** called out
2. Files touched vs repo map §3 (including empty `lib/data/`)
3. One-line “spec match / conflicts” — local closed; **First 10 #2 / staging = OPEN (Bill)**
4. UI: magic-link entry + `/timeline` stub only; “matches chrome locks redirects / no redesign”
5. Test commands + pass/fail output (`flutter test`, RLS SQL against **local**)
6. Design Doc notes: migrations match enums/DDL/RLS/`handle_new_user`/storage bucket policies
7. **First 10 #9 split:** M1 = `story-photos` bucket + path-prefix policies; **no Flutter upload spike** (M4)
8. Explicit: do **not** claim full §15 M1 complete until staging exists with Email magic link (or Bill waives in writing)

- [ ] **Step 1: Document runbook**

README: monorepo layout; `supabase start` as agent data plane; dart-define example; test commands; forbidden secrets; **OPEN (Bill) staging**; M2+ not started.

- [ ] **Step 2: Push + open PR**

```bash
git push -u origin feat/m01-foundation
gh pr create --title "feat(m01): Foundation (local + staging OPEN)" --body-file /tmp/pr-m01.md
```

- [ ] **Step 3: Stop**

Do **not** merge. Do **not** start M2 until PR approved and merged.

---

## First 10 agent actions — M1 coverage map

| # | Action | M1? |
|---|--------|-----|
| 1 | Flutter skeleton + `supabase_flutter` | **Yes** (`lib/core`, `lib/features/...`, `lib/data/` scaffold) |
| 2 | Supabase staging project | **OPEN (Bill)** — local `supabase start` is agent data plane only; does not close #2 |
| 3 | Migrations Design Doc DDL + enums | **Yes** |
| 4 | RLS + profile trigger | **Yes** |
| 5 | Magic-link sign-in iOS + web | **Yes** (verify on local; staging magic link OPEN with #2) |
| 6 | Family create + membership | **No — M2** |
| 7 | Edge invite functions | **No — M2** |
| 8 | Mapbox place picker spike | **No — M3** |
| 9 | Storage | **Split:** M1 bucket+policies; M4 Flutter upload spike |
| 10 | Multi-family RLS isolation test | **Yes** (local; gate before M4) |

## Verification commands (report output in PR)

```bash
# From worktree
supabase start
supabase db reset
supabase test db   # or equivalent SQL runner for supabase/tests/*

cd apps/tell_me_a_story
flutter test
# Manual: flutter run -d chrome / iOS sim with:
# --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Execution order after approval

1. Task 1 worktree
2. Task 2 migrations
3. Task 3 SQL tests
4. Task 4 Flutter (after Flutter SDK available)
5. Task 5 PR → **stop for human merge**
