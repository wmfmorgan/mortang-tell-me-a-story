# CI (minimal) — LOCKED 2026-10-19 (Gilfoyle), rev 3

Bill's ask, 1:55 PM CT: run lint, typecheck and unit tests on every PR. Nothing Supabase. Lands verbatim as `docs/design-doc/ci.md` in the CI PR.

## Shape
One file, `.github/workflows/ci.yml`, two parallel jobs, no secrets, no services.

| Job | Runs in | Steps |
|---|---|---|
| `flutter` | `apps/tell_me_a_story` | `flutter pub get --enforce-lockfile` → analyze ceiling (below) → `flutter test` |
| `deno` | repo root | `deno check supabase/functions/*/index.ts supabase/functions/_shared/*.ts` → `deno test --allow-env supabase/functions` |

- `flutter analyze` is the lint and the typecheck for Dart. `flutter test` is the unit tests.
- `deno test` type-checks only the modules its tests load (5 of the 14 functions). `deno check` covers every `index.ts` and all of `_shared` (rev 2). If `deno check` fails on main, the build agent stops and reports the errors. It does not fix code in this PR. The 43 Deno tests use injected fake DBs (`AcceptInviteDb` etc.) and need only `--allow-env`, so no database is needed.
- 🚫 Not in this slice: `deno lint` (never gated, so it has no baseline), pgTAP, `supabase start`, migrations, `flutter build`, coverage, caching beyond what the setup actions do by default.
- 🚫 No `--dart-define` and no secrets in CI. `env_test.dart` asserts that the defines are empty, so passing any would break it.

## Triggers
```yaml
on:
  pull_request:
    branches: [main]          # opened, synchronize, reopened (defaults)
  push:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}   # rev 3: pushes to main never cancel each other
permissions:
  contents: read
```
- No `paths` filter, so docs-only PRs also report status and the check can later become required.
- `timeout-minutes: 15` per job.

## Version pinning
- Flutter: one exact version (`x.y.z`, stable channel) via `subosito/flutter-action`, `flutter-version: <exact>`. No `channel: stable` floating. It must satisfy `pubspec.lock` (`flutter >=3.47.0`, `dart >=3.13.4`).
- Deno: one exact version via `denoland/setup-deno`, `deno-version: <exact>`. No `v2.x` range.
- Actions: every `uses:` is pinned by full commit SHA, with the tag in a trailing comment. That includes `actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0` in both jobs (rev 3, TMAS-M148-01; I verified the SHA against the tag). Staying on v4 is deliberate, because a major bump is its own PR.
- Both checkouts set `with: persist-credentials: false` (rev 3, TMAS-M148-02). No step needs the token after checkout.
- These two are part of the lock. The spec's FORBIDDEN and no-hardening rules don't apply to them.
- Dependencies: Flutter uses `--enforce-lockfile`, so CI fails instead of silently resolving new versions. Deno's `jsr:`/`npm:` imports aren't locked (there's no `deno.lock`). That's accepted for this slice because prod Edge deploys resolve the same way. A `deno.lock` gets its own GitHub issue.
- ❓ OPEN (Bill): the exact Flutter and Deno versions. Default is what's on the machine Bill smokes on (`flutter --version`, `deno --version`), so CI and the local smoke agree. A bump is its own PR.

## Analyze: ceiling, not zero
- Gate: the total issue count is ≤ 27 and errors = 0. It fails on either.
- How: run `flutter analyze --no-fatal-infos --no-fatal-warnings`, capture the output, then fail if any line contains `error •`, or if the `N issues found` count is > `ANALYZE_CEILING`. "No issues found!" counts as 0.
- `ANALYZE_CEILING: 27` is a workflow `env`. It only ratchets down: a PR that fixes issues lowers it in the same PR, and no PR raises it without a Gilfoyle/Bill lock.
- Reaching zero is a separate cleanup item, not this one.

## Test counts
- CI fails on any failing test. Count floors (flutter ≥ 495, Deno ≥ 43) stay as PR-body evidence for now. They aren't parsed in CI.

## Repo docs touched by the CI PR
- README l.23 and impl-spec l.319 get corrected: CI injects no dart-defines and no secrets. Defines are local or deploy-time only.
- `AGENTS.md` "The repo has no CI" line becomes: CI runs analyze, flutter test and Deno on every PR. pgTAP still runs locally, and its output goes in the PR body.
- 🚫 Branch protection and required checks are GitHub settings, which count as hosted config. They're Bill's to turn on after the first green run, and the PR doesn't do it.
