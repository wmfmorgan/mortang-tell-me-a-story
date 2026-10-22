# CI — LOCKED 2026-10-21 (Gilfoyle), rev 6

Rev 4 (2026-10-19, M14.8 #60) was Bill's ask to run lint, typecheck and unit tests on every PR. Rev 5 (#43, Bill 2026-10-20: "let's do 43") adds pgTAP and a `dart format` check. Rev 6 (#75, Bill 2026-10-20: "Make an exception: allow one read-only post-deploy GitHub job against prod for #75"; #48, Bill 2026-10-20 1:57 PM CT) adds the Supabase advisors (splinter) step to `pgtap` and exactly two exceptions, listed under Exceptions. CI never touches prod, except the one read-only job in Exception P1.

## Shape
One file, `.github/workflows/ci.yml`, three parallel jobs, no secrets. Exception E2E adds a fourth job, `e2e`, to this file. Exception P1 is the only other workflow, `.github/workflows/advisors-prod.yml`.

| Job | Runs in | Steps |
|---|---|---|
| `flutter` | `apps/tell_me_a_story` | `flutter pub get --enforce-lockfile` → `dart format --output=none --set-exit-if-changed .` → analyze ceiling (below) → `flutter test` |
| `deno` | repo root | `deno check supabase/functions/*/index.ts supabase/functions/_shared/*.ts` → `deno test --allow-env supabase/functions` |
| `pgtap` | repo root | install pinned Supabase CLI (sha256-verified) → `supabase db start` → `supabase test db` → fetch pinned splinter (commit + sha256) → advisors check against `supabase/advisors-baseline.json` |

- `flutter analyze` is the lint and the typecheck for Dart. `flutter test` is the unit tests. `dart format` runs after pub get because the formatter's style follows the package language version.
- `deno test` type-checks only the modules its tests load. `deno check` covers every `index.ts` and all of `_shared`. The Deno tests use injected fake DBs and need only `--allow-env`.
- `pgtap` starts only the local database container (with the auth, storage and realtime schemas `config.toml` enables), applies every migration to an empty database, then runs `supabase/tests`. Not bare Postgres: the migrations depend on Supabase's `auth`, `storage`, roles, `extensions` schema and realtime publication.
- Prod isolation: the job has no secrets, so the CLI has no token and cannot reach the hosted project. No `link`, `--linked`, `--db-url`, `db push`, `db reset`, `db pull` or `migration` commands in CI, ever.
- 🚫 Not in CI: `deno lint` (never gated, no baseline), `supabase start` (full stack), E2E, `flutter build`, coverage, caching beyond what the setup actions do by default.
- 🚫 No `--dart-define` and no secrets in CI. `env_test.dart` asserts that the defines are empty.

## Triggers
```yaml
on:
  pull_request:
    branches: [main]          # opened, synchronize, reopened (defaults)
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}   # pushes to main never cancel each other
permissions:
  contents: read
```
- No `paths` filter, so every PR reports all three checks and they can all be required.
- `timeout-minutes: 15` for `flutter` and `deno`, `20` for `pgtap`.

## Version pinning
- Flutter: exact `3.47.7` (Dart 3.13.5) via `subosito/flutter-action`. Deno: exact `2.9.4` via `denoland/setup-deno`. Supabase CLI: exact `2.121.0`, downloaded from the GitHub release and checked against a pinned sha256 (`SUPABASE_CLI_SHA256`, job `env`). Not `supabase/setup-cli`, which resolves from npm and pulls more actions. A bump of any of the three is its own PR.
- Actions: every `uses:` is pinned by full commit SHA with the tag in a trailing comment, including `actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0` in all three jobs, each with `persist-credentials: false`. The allowed actions are checkout, flutter-action and setup-deno. These pins are part of the lock, not extra hardening.
- Dependencies: Flutter uses `--enforce-lockfile`. Deno's `jsr:`/`npm:` imports aren't locked (no `deno.lock`); that gets its own issue.

## Analyze: ceiling, not zero
- Gate: the total issue count is ≤ 27 and errors = 0. It fails on either.
- How: run `flutter analyze --no-fatal-infos --no-fatal-warnings`, capture the output, then fail if any line contains `error •`, or if the `N issues found` count is > `ANALYZE_CEILING`. "No issues found!" counts as 0.
- `ANALYZE_CEILING: 27` is a workflow `env`. It only ratchets down: a PR that fixes issues lowers it in the same PR, and no PR raises it without a Gilfoyle/Bill lock.

## Format
- `dart format` with default settings (page width 80, no `formatter:` override). The #43 PR's first commit was formatter output only, so main starts clean. Format churn in a feature PR is still only allowed in files the PR changes on purpose.

## Test counts
- CI fails on any failing test. Counts aren't parsed in CI. PR bodies quote them: flutter ≥ 495, Deno ≥ 43, pgTAP from the `pgtap` log (`Files=25, Tests=825` at rev 6).
- A red `pgtap` is never fixed by editing tests, migrations, `config.toml` or `seed.sql` in the same PR without a Gilfoyle lock. Fresh-database differences are findings.

## Exceptions (rev 6)
The rules above apply to every job and workflow. Only these two exceptions exist.

**Exception P1: prod advisors (#75). The only CI exception to "CI never touches prod".**
Exactly one job, `prod-advisors` in `.github/workflows/advisors-prod.yml`, may read from prod `lchytafmnuefrgkguynt`.
- It calls only `GET https://api.supabase.com/v1/projects/lchytafmnuefrgkguynt/advisors/security` and `GET …/advisors/performance`. It runs no SQL and no writes, calls no other Supabase endpoint and runs no Supabase CLI.
- It triggers only on `push` to `main` (after confirming the Supabase deploy check for that commit) and `workflow_dispatch`. A deploy that is not confirmed, including a timeout, is red. It has no other trigger, and it is never triggered by `workflow_run`, `pull_request_target`, `repository_dispatch` or `issue_comment`.
- Its `permissions` are `contents: read` and `checks: read`, and its only action is SHA-pinned checkout. `checks: read` exists only for the deploy-wait step, which sends the job's `GITHUB_TOKEN` only to `api.github.com` to read that commit's check runs.
- It reads one secret, `SUPABASE_ADVISORS_TOKEN`, from the dedicated `prod-advisors` environment (deployment branches: `main` only). That token is a Supabase scoped PAT for this one project with only "Advisors: Read". Classic PATs are forbidden.
- It is never a required check.
- No other job, step or workflow may use that environment, that secret, `api.supabase.com`, or any prod connection.
- `ci.yml` keeps "no secrets" unchanged.

**Exception E2E (#48). Local Supabase only, never prod.**
One job, `e2e` in `ci.yml`, may:
- run `supabase start` against the **local** Supabase stack on the runner (exclusions `studio,imgproxy,vector,logflare,supavisor,postgres-meta`);
- build and drive a debug/profile Flutter web app (`flutter drive -d web-server`);
- pass `--dart-define` values sourced **only** from `supabase status -o env` (local demo values).

It is **local Supabase only, never prod.** It uses no `${{ secrets.* }}`, no `link`, no `--linked`, no `--db-url`, no `db push/pull/reset`, and no `migration` command. Its permissions are `contents: read`. It uses only the allowlisted SHA-pinned actions, and `timeout-minutes: 25`. The job is report-only (not required) until 10 consecutive green runs on main, then it is a required check. Everything else in the Shape bullets on prod isolation and 🚫 (l.17–19) still applies to every job.

**Also in rev 6:**
- The `pgtap` job runs splinter (pinned by commit plus sha256; a bump is its own PR) against `supabase/advisors-baseline.json`. New findings fail, stale entries fail, and an ERROR can never be accepted. The step fails closed if `psql` is missing.
- pgTAP count note: 25 files / 825 tests after the M17a policy and index asserts (+23) and the definer-allowlist fold (−1).

## Required checks
- `flutter`, `deno` and `pgtap` are required on `main`. Branch protection is a GitHub setting Bill changes by hand; no PR touches it. `pgtap` is added after the first green push run on main following the #43 merge. `e2e` is added only after 10 consecutive green runs on `main` (Exception E2E). `prod-advisors` is never a required check (Exception P1).

## Repo docs
- `AGENTS.md` CI line: CI runs `dart format`, analyze, flutter test, Deno and pgTAP, and Supabase advisors (splinter) against a baseline on every PR. Local `supabase test db` is still how you check a migration before pushing.
- `docs/design-doc/README.md` index line: `` `ci.md` — CI (LOCKED 2026-10-21, Gilfoyle, rev 6) ``.
