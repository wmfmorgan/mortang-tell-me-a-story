# CI — LOCKED 2026-10-20 (Gilfoyle), rev 5

Rev 4 (2026-10-19, M14.8 #60) was Bill's ask to run lint, typecheck and unit tests on every PR. Rev 5 (#43, Bill 2026-10-20: "let's do 43") adds pgTAP and a `dart format` check. CI never touches prod.

## Shape
One file, `.github/workflows/ci.yml`, three parallel jobs, no secrets.

| Job | Runs in | Steps |
|---|---|---|
| `flutter` | `apps/tell_me_a_story` | `flutter pub get --enforce-lockfile` → `dart format --output=none --set-exit-if-changed .` → analyze ceiling (below) → `flutter test` |
| `deno` | repo root | `deno check supabase/functions/*/index.ts supabase/functions/_shared/*.ts` → `deno test --allow-env supabase/functions` |
| `pgtap` | repo root | install pinned Supabase CLI (sha256-verified) → `supabase db start` → `supabase test db` |

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
- CI fails on any failing test. Counts aren't parsed in CI. PR bodies quote them: flutter ≥ 495, Deno ≥ 43, pgTAP from the `pgtap` log (`Files=24, Tests=799` at rev 5).
- A red `pgtap` is never fixed by editing tests, migrations, `config.toml` or `seed.sql` in the same PR without a Gilfoyle lock. Fresh-database differences are findings.

## Required checks
- `flutter`, `deno` and `pgtap` are required on `main`. Branch protection is a GitHub setting Bill changes by hand; no PR touches it. `pgtap` is added after the first green push run on main following the #43 merge.

## Repo docs
- `AGENTS.md` CI line: CI runs `dart format`, analyze, flutter test, Deno and pgTAP on every PR. Local `supabase test db` is still how you check a migration before pushing.
- `docs/design-doc/README.md` index line: `` `ci.md` — CI (LOCKED 2026-10-20, Gilfoyle, rev 5) ``.
