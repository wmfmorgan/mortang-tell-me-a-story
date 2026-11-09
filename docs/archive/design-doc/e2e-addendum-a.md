# #48 E2E regression tests: design lock rev 2, Addendum A

> **Status: Addendum A to rev 2, LOCKED 2026-10-21 (Gilfoyle), answers to M18 spec rev 1**
> Answers Big Head's §15 M18 item rev 1 (draft, "READY rev 1 2026-10-21. NOT APPROVED"). It amends `docs/design-doc/e2e.md` (lock rev 2, sha256 `bdeef481a69bf8a42edbc8348a6c3b9497547cbf5e73f7148a1733a815025806`). Where the two differ, this addendum wins. Gilfoyle wins on tech.
> Bill's decisions bind, and nothing here goes past them: (1) the 9 thin flows C1–C9; (2) local Supabase in CI only, never prod; (3) about 8–11 min of CI growth; (4) `e2e` is report-only until 10 consecutive green runs, then required; (5) the Flutter SDK `integration_test` dev dependency is approved (Bill, 2026-10-21).
> Checked against `main` = `46957e2749f2ea9410c40c347d566ddd4ac2fe2c` (head re-checked 2026-10-21 about 6:25 PM CT) with read-only cursor-github calls: `.github/workflows/ci.yml` (132 lines, sha256 `a379fa4c5f9894ec87bd177d0e22d253f186edd55ceee7c4e24dfb8ea9495d0a`), `AGENTS.md`, `docs/impl-spec/impl-spec.md`, `docs/design-doc/README.md`, `docs/design-doc/ci.md` (rev 5), `supabase/config.toml`, `apps/tell_me_a_story/pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/core/config/env.dart`, `lib/core/supabase/supabase_init.dart`, `lib/core/router/app_router.dart`, and the full git tree (not truncated). The tree has no `integration_test/`, `test_driver/`, `e2e/`, `package.json` or shared test-helper folder. `test/` holds 39 `*_test.dart` files plus `test/theme/`, each self-contained.
> CI input: the reconciled **ci.md rev 6** ("CI — LOCKED 2026-10-21 (Gilfoyle), rev 6", 84 lines, sha256 `4c3611b3715dbf8f02c05e2216c7e945ce9c77a678842fcffd11456ea0493723`) and #75 Addendum A §A3.

## Numbering map
The spec's OPEN numbers differ from the ones in this addendum's brief. This addendum uses the brief's numbers.

| This addendum | Spec rev 1 | Topic |
|---|---|---|
| OPEN 1 | OPEN 1 | `e2e` job YAML and the PR3 manifest step |
| (ruling R0) | OPEN 2 + rev 6 CONFLICT | ci.md rev 6 |
| OPEN 2 | OPEN 3 | AGENTS.md CI line |
| OPEN 3 | OPEN 4 | impl-spec l.319 |
| OPEN 4 | OPEN 5 | design-doc README index |
| OPEN 5 | OPEN 6 | paths, driver, helpers, relay, build mode |
| OPEN 6 | OPEN 7 | test names, `flows.md`, manifest check, owning folders |

OPEN 8 (Mugatu, C8 screen state) and OPEN 9 (Jared, conditional Mapbox pin) are not Gilfoyle's and are unchanged.

---

## R0. ci.md rev 6 (closes spec OPEN 2 and the two-rev-6 CONFLICT)
- **M17b (#75) lands one reconciled rev 6, byte for byte, carrying both exceptions** (P1 prod advisors and E2E). The file is `docs/design-doc/ci.md` rev 6, sha256 `4c3611b3715dbf8f02c05e2216c7e945ce9c77a678842fcffd11456ea0493723`.
- **M18 PR0 does NOT touch `docs/design-doc/ci.md`.** M18 cites rev 6 and does not repeat it.
- **M18 PR1 starts only after M17b is merged on `main`.** PR1 is the first PR that adds the `e2e` job, and that job is legal only under rev 6. PR0 (docs only) can merge before or after M17b.
- Rev 6 also updates ci.md l.6 (the job count: "Exception E2E adds a fourth job, `e2e`, to this file") and README l.20 (`ci.md` → rev 6). Those edits are M17b's. M18 does not make them.
- The lock's PR0 row "ci.md rev 6", lock l.6 "Nothing is built before PR0 (ci.md rev 6) lands" and Risk 1 now read: nothing is built before **M17b (rev 6)** and **M18 PR0** are both on `main`.
- **Rev 6 E2E exception (l.67–73), verbatim.** The OPEN 1 YAML conforms to it clause by clause:
  > **Exception E2E (#48). Local Supabase only, never prod.**
  > One job, `e2e` in `ci.yml`, may:
  > - run `supabase start` against the **local** Supabase stack on the runner (exclusions `studio,imgproxy,vector,logflare,supavisor,postgres-meta`);
  > - build and drive a debug/profile Flutter web app (`flutter drive -d web-server`);
  > - pass `--dart-define` values sourced **only** from `supabase status -o env` (local demo values).
  >
  > It is **local Supabase only, never prod.** It uses no `${{ secrets.* }}`, no `link`, no `--linked`, no `--db-url`, no `db push/pull/reset`, and no `migration` command. Its permissions are `contents: read`. It uses only the allowlisted SHA-pinned actions, and `timeout-minutes: 25`. The job is report-only (not required) until 10 consecutive green runs on main, then it is a required check. Everything else in the Shape bullets on prod isolation and 🚫 (l.17–19) still applies to every job.
- **pgTAP baseline:** G2's pgTAP count is `main`'s count at the PR's base: `Files=25, Tests=803` before M17a, `826` after M17a, and **`Files=25, Tests=825` after M17b** (rev 6 l.51 and l.77). PR1–PR3 run after M17b, so they expect **825**. PR0 expects whatever its base shows.

---

## OPEN 1. The `e2e` job YAML (closes spec OPEN 1)

### Choice: the runner's preinstalled Chrome plus its matching ChromeDriver, with a fail-closed version check
- **Chosen:** `google-chrome` on PATH and `$CHROMEWEBDRIVER/chromedriver` from the GitHub-hosted image. The step fails the job unless the two agree on MAJOR.MINOR.BUILD, which is ChromeDriver's compatibility rule.
- **Why not a Chrome-for-Testing pin now:**
  - Google publishes no sha256 for CfT zips. We would hash our own download, and the hash would pin a Chrome that the image's ChromeDriver doesn't match. We would then need two pinned downloads (Chrome plus ChromeDriver, about 170 MB) on every run.
  - The image ships Chrome and ChromeDriver as a matched pair. It is the same trust root as the `ubuntu-latest` runner the other three jobs already use, so it adds no new tool, no new download, and no new action.
  - Drift (lock Risk 5) can't pass silently: a mismatch fails the job, not the test.
- **If the check fails** (for example after `ubuntu-latest` moves to Ubuntu 26.04 in November 2026, #75 Addendum A §A6), stop and report to Gilfoyle. The CfT fallback lands only through a Gilfoyle addendum that names an exact CfT version plus a sha256 for each zip, fetched with `curl` and checked with `sha256sum -c`. **Never download Chrome or ChromeDriver unpinned.**

### Semantics
- **Report-only = not in branch protection.** No `continue-on-error` key appears anywhere in the job, at job or step level. `continue-on-error: true` would show a failing `e2e` as passing, which hides real reds and makes the "10 consecutive green runs" count meaningless. A red `e2e` shows red on the PR, but it blocks nothing until Bill adds it to required checks (rev 6 l.80).
- `timeout-minutes: 25` (rev 6 l.73). Job-level `permissions: contents: read`. The workflow-level `permissions` stay as they are. No `needs:`, so it runs in parallel with the other three jobs. No `paths`, no cache, no `services:`, no `container:`.
- **No secrets.** URL and anon key are read at runtime from `supabase status -o env` (the CLI's fixed local demo values). The workflow re-checks that `API_URL` is exactly `http://127.0.0.1:57321` before driving. The service_role key is never exported, written to a file, or passed anywhere.
- **Background start:** `supabase start` runs in the background while flutter-action, pub get, setup-deno, ChromeDriver and the relay come up (lock sizing). It is awaited with `tail --pid` under `timeout 600`, which is a bounded wait on process exit, not a sleep.
- **Readiness waits** for ChromeDriver and the relay are `curl --retry-connrefused` with `--retry-max-time 30`: bounded polls on a condition (see Ambiguity A1).
- **Logs:** the `supabase start` log is printed with JWTs, `sb_*` keys and long hex strings redacted. The relay and ChromeDriver logs are printed on every outcome (`if: always()`).
- **Workflow test-data prod guard:** the workflow aborts unless `API_URL` is `http://127.0.0.1:57321`. The harness keeps the lock's own guard (lock (b)).

### Exact YAML, PR1 (append after the `pgtap` job; one blank line before `  e2e:`)
```yaml
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 25
    permissions:
      contents: read
    defaults:
      run:
        shell: bash
    env:
      SUPABASE_CLI_VERSION: "2.121.0"
      SUPABASE_CLI_SHA256: "4b481189efbdc57cf2d37bdee5f1a0d29574314398564b32a6dfb76c0fcf275f"
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          persist-credentials: false

      - name: install supabase cli
        run: |
          tgz="$RUNNER_TEMP/supabase.tar.gz"
          curl -fsSL -o "$tgz" "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_${SUPABASE_CLI_VERSION}_linux_amd64.tar.gz"
          echo "${SUPABASE_CLI_SHA256}  ${tgz}" | sha256sum -c -
          mkdir -p "$RUNNER_TEMP/bin"
          tar -xzf "$tgz" -C "$RUNNER_TEMP/bin" supabase supabase-go
          echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"

      - name: supabase --version
        run: supabase --version

      - name: supabase start (background)
        run: |
          ( set +e
            supabase start -x studio,imgproxy,vector,logflare,supavisor,postgres-meta > "$RUNNER_TEMP/supabase-start.log" 2>&1
            echo $? > "$RUNNER_TEMP/supabase-start.rc"
          ) &
          echo $! > "$RUNNER_TEMP/supabase-start.pid"

      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
        with:
          flutter-version: "3.47.7"

      - name: flutter --version
        working-directory: apps/tell_me_a_story
        run: flutter --version

      - name: flutter pub get
        working-directory: apps/tell_me_a_story
        run: flutter pub get --enforce-lockfile

      - uses: denoland/setup-deno@22d081ff2d3a40755e97629de92e3bcbfa7cf2ed # v2.0.5
        with:
          deno-version: "2.9.4"

      - name: deno --version
        run: deno --version

      - name: chrome and chromedriver (preinstalled, versions must match)
        run: |
          chrome="$(command -v google-chrome)"
          driver="${CHROMEWEBDRIVER:?CHROMEWEBDRIVER is not set}/chromedriver"
          test -x "$driver"
          cv="$("$chrome" --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
          dv="$("$driver" --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
          echo "chrome ${cv} (${chrome})"
          echo "chromedriver ${dv} (${driver})"
          if [ -z "$cv" ] || [ -z "$dv" ] || [ "${cv%.*}" != "${dv%.*}" ]; then
            echo "e2e: chromedriver ${dv} does not match Chrome ${cv} (MAJOR.MINOR.BUILD)" >&2
            exit 1
          fi
          "$driver" --port=4444 > "$RUNNER_TEMP/chromedriver.log" 2>&1 &
          curl -fsS --retry 20 --retry-connrefused --retry-max-time 30 http://127.0.0.1:4444/status > /dev/null
          echo "chromedriver listening on 127.0.0.1:4444"

      - name: start e2e relay
        run: |
          deno run --no-prompt --allow-net=127.0.0.1:57390,127.0.0.1:57321,localhost:57321,127.0.0.1:57324 e2e/relay.ts > "$RUNNER_TEMP/relay.log" 2>&1 &
          curl -fsS --retry 20 --retry-connrefused --retry-max-time 30 http://127.0.0.1:57390/health

      - name: await supabase start
        run: |
          pid="$(cat "$RUNNER_TEMP/supabase-start.pid")"
          set +e
          timeout 600 tail --pid="$pid" -f /dev/null
          waited=$?
          set -e
          sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/[redacted-jwt]/g; s/sb_(secret|publishable)_[A-Za-z0-9_-]+/[redacted-key]/g; s/[0-9a-f]{32,}/[redacted-hex]/g' "$RUNNER_TEMP/supabase-start.log"
          if [ "$waited" -ne 0 ]; then
            echo "e2e: supabase start did not finish within 600 s" >&2
            exit 1
          fi
          rc="$(cat "$RUNNER_TEMP/supabase-start.rc")"
          echo "supabase start: exit ${rc}"
          test "$rc" = 0

      - name: flutter drive (e2e)
        working-directory: apps/tell_me_a_story
        run: |
          status="$(cd "$GITHUB_WORKSPACE" && supabase status -o env)"
          url="$(printf '%s\n' "$status" | sed -n 's/^API_URL="\(.*\)"$/\1/p')"
          anon="$(printf '%s\n' "$status" | sed -n 's/^ANON_KEY="\(.*\)"$/\1/p')"
          unset status
          if [ "$url" != "http://127.0.0.1:57321" ]; then
            echo "e2e: API_URL '${url}' is not the local stack http://127.0.0.1:57321" >&2
            exit 1
          fi
          if [ -z "$anon" ]; then
            echo "e2e: no ANON_KEY in supabase status -o env" >&2
            exit 1
          fi
          flutter drive \
            --driver=test_driver/integration_test.dart \
            --target=integration_test/e2e_test.dart \
            -d web-server --web-port=3000 --web-hostname=127.0.0.1 \
            --profile \
            --browser-name=chrome --driver-port=4444 --headless \
            --chrome-binary="$(command -v google-chrome)" \
            --dart-define=SUPABASE_URL="$url" \
            --dart-define=SUPABASE_ANON_KEY="$anon"

      - name: e2e logs (relay, chromedriver)
        if: always()
        run: |
          for f in relay.log chromedriver.log; do
            if [ -f "$RUNNER_TEMP/$f" ]; then
              echo "== $f"
              sed -E 's/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/[redacted-jwt]/g' "$RUNNER_TEMP/$f"
            fi
          done
```
- On the `main` @ `46957e2` `ci.yml` (sha256 `a379fa4c…5d0a`), appending exactly this block gives a 260-line file, sha256 `1a95133a6ddd8ef6a2337d80e1bad05acb679bd9f70ceab80dfa615de68a97a7`. PR1's real base is after M17b, which changes the `pgtap` job, so the gate is the diff: `git diff main -- .github/workflows/ci.yml` must add only this block, after the last line of `pgtap`.

### Exact PR3 manifest-check step
In PR3, insert this step in the `e2e` job **immediately after the checkout step** and before `install supabase cli`, so a manifest drift fails in seconds:
```yaml
      - name: e2e flow manifest
        run: bash e2e/check_flows.sh
```
- On the same `46957e2` base, the full PR3 file is 263 lines, sha256 `a19d74033cdcb6f2291b2f735bbccea9010269a024eb8a5a4caad40bb33e463e`. The diff gate is the same: only lines inside `e2e`.

### Clause-by-clause conformance to rev 6 l.67–73
| Rev 6 clause | YAML |
|---|---|
| "run `supabase start` against the **local** Supabase stack on the runner (exclusions `studio,imgproxy,vector,logflare,supavisor,postgres-meta`)" | `supabase start -x studio,imgproxy,vector,logflare,supavisor,postgres-meta`, no `--workdir` other than the checkout, no remote flags |
| "build and drive a debug/profile Flutter web app (`flutter drive -d web-server`)" | `flutter drive … -d web-server … --profile` |
| "pass `--dart-define` values sourced **only** from `supabase status -o env` (local demo values)" | exactly two: `SUPABASE_URL` ← `API_URL`, `SUPABASE_ANON_KEY` ← `ANON_KEY`, both parsed from `supabase status -o env` in the same step. No `MAPBOX_ACCESS_TOKEN`, no `INVITE_APP_ORIGIN`, no relay URL, no run id |
| "no `${{ secrets.* }}`, no `link`, no `--linked`, no `--db-url`, no `db push/pull/reset`, and no `migration` command" | none present (G4 grep below) |
| "Its permissions are `contents: read`" | job `permissions: contents: read`, and the workflow-level block is unchanged |
| "only the allowlisted SHA-pinned actions" | checkout `11d5960…` v4.4.0 (`persist-credentials: false`), flutter-action `1a44944…` v2.23.0 (Flutter `3.47.7`), setup-deno `22d081f…` v2.0.5 (Deno `2.9.4`). Same SHAs and versions as today |
| "`timeout-minutes: 25`" | `timeout-minutes: 25` |
| "report-only (not required) until 10 consecutive green runs on main" | no `continue-on-error`; not in required contexts (Bill's step) |
| l.17–19 still apply: no `link`/`--linked`/`--db-url`/`db push`/`db reset`/`db pull`/`migration`; caching beyond setup defaults banned | none present; no cache step. The CLI install is the `pgtap` step copied exactly (same `SUPABASE_CLI_VERSION`/`SUPABASE_CLI_SHA256` job env) |

### G4 values for the spec (replace spec G4 numbers)
- Jobs are exactly `flutter`, `deno`, `pgtap`, `e2e` (plus whatever M17b adds to `pgtap` steps; no other job in `ci.yml`).
- `grep -c 'uses:' .github/workflows/ci.yml` → `8`. `grep -c 'persist-credentials: false'` → `4`. `grep -n 'timeout-minutes'` → `15`, `15`, `20`, `25`.
- `grep -nE 'secrets\.|supabase link|--linked|--db-url|db (push|pull|reset)|migration |setup-cli|pull_request_target|paths|continue-on-error|cache|sleep ' .github/workflows/ci.yml` prints nothing.
- `grep -c 'dart-define' .github/workflows/ci.yml` → `2`, both inside `e2e`.
- `grep -c 'contents: read' .github/workflows/ci.yml` → `2` (workflow + `e2e`), plus any M17b line. Workflow `env` still `ANALYZE_CEILING: 27` only.

---

## OPEN 2. AGENTS.md CI line (closes spec OPEN 3): NO CHANGE
- **Ruling: M18 does not touch `AGENTS.md`.** Rev 6 l.83 quotes the AGENTS.md CI line as M17b sets it:
  > `AGENTS.md` CI line: CI runs `dart format`, analyze, flutter test, Deno and pgTAP, and Supabase advisors (splinter) against a baseline on every PR. Local `supabase test db` is still how you check a migration before pushing.
- If M18 changed l.43, rev 6's quote would go stale, and M18 PR0 may not edit ci.md. The `e2e` job is report-only and is fully described in rev 6's Exceptions section, so agents don't need it on l.43 to follow the gates. No change is enough.
- After M17b, `AGENTS.md` l.43 (cited by content: the line starting `- CI runs`) reads exactly:
  ```text
  - CI runs `dart format`, analyze, flutter test, Deno and pgTAP, and Supabase advisors (splinter) against a baseline on every PR. Local `supabase test db` is still how you check a migration before pushing. **The PR body is the evidence**: paste fresh counts and command output from the PR's head commit.
  ```
  That edit is M17b's. Today on `46957e2` it is l.43, without the advisors clause.
- The lock's "Also in PR0: the AGENTS.md CI line" is **withdrawn**. The spec drops `AGENTS.md` from PR0's files. G1 PR0: `git diff main -- AGENTS.md` is empty.
- When Bill makes `e2e` required, a line change (AGENTS.md and rev 6 l.83 together) is a separate docs PR owned by Gilfoyle. It is not M18.

---

## OPEN 3. impl-spec l.319 (closes spec OPEN 4)
- **Line:** on `main` @ `46957e2`, `docs/impl-spec/impl-spec.md` **l.319**. The lock's "l.317" is the old number: Big Head's +2 offset is confirmed by content. The line starts ``> **Locked (Bill / Design Doc plumbing):** Inject via `--dart-define` locally or at deploy time only:``. Open PR #78 only appends after l.4917, so l.319 doesn't move.
- **Replace exactly this sentence** (one occurrence on l.319):
  `CI injects no dart-defines and no secrets.`
- **With exactly:**
  ```text
  CI injects no secrets and no dart-defines, except that the `e2e` job (ci.md rev 6, Exception E2E) passes `SUPABASE_URL` and `SUPABASE_ANON_KEY` taken only from `supabase status -o env` on the runner's local stack (local demo values, never prod).
  ```
- **Full new l.319:**
  ```text
  > **Locked (Bill / Design Doc plumbing):** Inject via `--dart-define` locally or at deploy time only: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MAPBOX_ACCESS_TOKEN` (public, restricted by iOS bundle ID / web URL). CI injects no secrets and no dart-defines, except that the `e2e` job (ci.md rev 6, Exception E2E) passes `SUPABASE_URL` and `SUPABASE_ANON_KEY` taken only from `supabase status -o env` on the runner's local stack (local demo values, never prod). Edge-only (never in Flutter): `RESEND_API_KEY`, Supabase service role key.
  ```
- **Only l.319 changes.** l.284, l.289, l.294 and l.1942 ("CI injects none") describe where the app's deploy values come from. The local e2e values aren't deploy values, and the lock names one line, so they stay. The copies at l.4107, l.4132 and l.4136 are inside the closed M14.8 item and stay.
- After PR0, `grep -c 'CI injects no dart-defines and no secrets' docs/impl-spec/impl-spec.md` drops by one. The closed M15 gate that once counted it is history, not a live gate.

---

## OPEN 4. design-doc README index (closes spec OPEN 5)
- The lock adds a new design-doc file, `docs/design-doc/e2e.md`, and this addendum lands as `docs/design-doc/e2e-addendum-a.md`. So README gets **two new lines**. The `ci.md` line (l.20) is M17b's edit to rev 6, and M18 does not touch it.
- Insert these two lines **immediately after the line that starts with `` - `ci.md` — ``** (l.20 today, whichever rev text it holds at PR0's base):
```
- `e2e.md` — E2E regression tests #48 (LOCKED 2026-10-20, Gilfoyle, rev 2)
- `e2e-addendum-a.md` — E2E Addendum A, answers to the M18 spec rev 1 (LOCKED 2026-10-21, Gilfoyle)
```
- No other README change. G1 PR0: `git diff main -U0 -- docs/design-doc/README.md` shows exactly these two added lines.

### PR0 file list (replaces spec "PR0 (docs)")
1. `docs/design-doc/e2e.md`: the lock rev 2 with exactly the two citation edits in Ambiguity A5. Result: 241 lines, 20,264 bytes, sha256 `464bfcf262d0edcd4e310e4671b74dcd79bbc752f115003de0b472ad0386a4a0`. This replaces the spec's "byte for byte, 240 lines, `bdeef481…`".
2. `docs/design-doc/e2e-addendum-a.md`: this addendum, byte for byte (its sha256 is reported with it).
3. `docs/design-doc/README.md`: the two lines above.
4. `docs/impl-spec/impl-spec.md`: l.319 (OPEN 3), plus the APPROVED M18 item appended at the end of the file.
- **Not in PR0:** `docs/design-doc/ci.md` (R0), `AGENTS.md` (OPEN 2), `.github/`.

---

## OPEN 5. Locations, driver, helpers, relay, build mode (closes spec OPEN 6)

### Paths
- `apps/tell_me_a_story/integration_test/`: Flutter resolves it from the package root, next to `test/`. `flutter test` (the `flutter` job) runs only `test/`, so the 504 count is unchanged. `flutter analyze` and `dart format` cover the new folders (ceiling 27, lock Risk 8).
- `apps/tell_me_a_story/test_driver/`
- `e2e/` at the repo root: Deno and bash, not app code (the same pattern as `supabase/functions/`).

### Files (exhaustive; anything else needs a Gilfoyle ruling)
| Path | PR | Content |
|---|---|---|
| `apps/tell_me_a_story/integration_test/e2e_test.dart` | PR1 (C1), PR2 (+C2–C4), PR3 (+C5–C9) | The one entry. `main()` calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`, runs the prod guard in `setUpAll`, and holds **every** `testWidgets(` call. The app is booted through `package:tell_me_a_story/main.dart` and `lib/` APIs only. |
| `apps/tell_me_a_story/test_driver/integration_test.dart` | PR1 | **Driver filename: `integration_test.dart`** (Flutter's standard). Exact content below. |
| `apps/tell_me_a_story/integration_test/support/prod_guard.dart` | PR1 | The lock (b) guard on `Env.supabaseUrl`: aborts unless it is `http://127.0.0.1:57321` or `http://localhost:57321`, and fails on any `supabase.co` or `lchytafmnuefrgkguynt` match. |
| `apps/tell_me_a_story/integration_test/support/relay_client.dart` | PR1 | `const kRelayOrigin = 'http://127.0.0.1:57390';` and `Future<Uri> magicLinkLocation(String email)` over `package:http` (already a direct dependency). |
| `apps/tell_me_a_story/integration_test/support/test_users.dart` | PR1 | Run id, `e2e-<run_id>-<flow>-<n>@example.test` emails, unique family names. |
| `apps/tell_me_a_story/integration_test/support/waits.dart` | PR1 | `pumpUntilFound` / `pumpUntilGone(tester, finder, {timeout})`: frame pumps until a finder condition holds or a deadline throws `TestFailure`. |
| `apps/tell_me_a_story/integration_test/support/preconditions.dart` | PR2 (optional) | Precondition setup through `lib/data/*_api.dart` gateways as the signed-in user, or the real Edge functions (lock D1). |
| `apps/tell_me_a_story/integration_test/flows.md` | PR3 | The manifest (OPEN 6). |
| `e2e/relay.ts` | PR1 | The Mailpit relay (contract below). |
| `e2e/check_flows.sh` | PR3 | The manifest check (OPEN 6). |

- **Helper files are allowed**, but only the five under `integration_test/support/` listed above. They hold helpers only: no `main(`, no `testWidgets(` (the manifest check enforces this), no `sleep`/`Future.delayed`. Imports allowed: `package:flutter_test`, `package:integration_test`, `package:http`, `package:supabase_flutter`, `package:tell_me_a_story/...`. No other package.
- Not created in M18 (confirming Big Head's INFERs): `integration_test/quarantine/`, `e2e/fixtures/`, the U2 advisory annotation.

### Driver, exact content of `apps/tell_me_a_story/test_driver/integration_test.dart`
```dart
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
```

### How the test reaches the relay: a fixed localhost port (no dart-define)
- **Chosen: the fixed port `127.0.0.1:57390`**, as a Dart `const` in `support/relay_client.dart` and the `--allow-net`/listen port in the YAML.
- **Not a dart-define.** Rev 6 allows `--dart-define` values "sourced **only** from `supabase status -o env`", and a relay URL isn't one of them. A fixed port also keeps the drive line identical locally and in CI.
- 57390 is outside every port in `supabase/config.toml` (57320–57324, 57327, 57329, 8083) and away from 3000 and 4444.
- Why a relay at all: the test code runs inside Chrome. It can't read Mailpit's API cross-origin, and it can't see a `302 Location` (browser `fetch` with `redirect: manual` returns an opaque response). The relay runs on the runner host and does both.
- **Run id** (no dart-define): `DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36)`, computed once per harness run. Emails are `e2e-<run_id>-c<N>-<n>@example.test`, lowercase, with `n` starting at 1.

### `e2e/relay.ts` contract (PR1)
- Deno built-ins only: no `import` of `jsr:`, `npm:` or a URL. Run as `deno run --no-prompt --allow-net=127.0.0.1:57390,127.0.0.1:57321,localhost:57321,127.0.0.1:57324 e2e/relay.ts`, with no `--allow-env`, `--allow-read` or `--allow-run`. It listens on `Deno.serve({ hostname: "127.0.0.1", port: 57390 })`.
- `GET /health` → `200` `ok`.
- `GET /magic-link?email=<addr>`:
  1. Return `400` unless `addr` matches `^e2e-[a-z0-9]+-c[1-9]-[0-9]+@example\.test$`.
  2. Poll `GET http://127.0.0.1:57324/api/v1/search?query=to:<addr>` (lock (c)) every 250 ms, with a 30 s overall deadline. Return `504` at the deadline. Return `409` if more than one message matches: each address gets exactly one magic link per run.
  3. `GET http://127.0.0.1:57324/api/v1/message/<ID>`, then take the first `…/auth/v1/verify?…` URL from the text body (the HTML body as a fallback, with `&amp;` decoded).
  4. **Prod guard:** the verify URL's origin must be `http://127.0.0.1:57321` or `http://localhost:57321`. Any URL containing `supabase.co` or `lchytafmnuefrgkguynt` → `500`.
  5. `fetch(verifyUrl, { redirect: "manual" })`. Expect a 3xx with a `Location` starting `http://127.0.0.1:3000` or `http://localhost:3000` (else `502`). Return `200` `{"location":"<Location>"}`.
- CORS: every response sends `Access-Control-Allow-Origin: http://127.0.0.1:3000` and `Vary: Origin`. GET only, simple requests, no preflight.
- Logging: method, path without the query, and status only. **Never log email bodies, verify URLs, tokens, codes or `Location`.**
- The M2 `generate_link` fallback is **not** built unless the PR1 spike shows a rate limit biting (lock (c)). If it is, it needs a Gilfoyle ruling on the endpoint and the `--allow-env` scope.
- The test calls `recoverSessionFromAuthCallback(Uri.parse(location))` (`lib/core/supabase/supabase_init.dart`) in the same browser, so a PKCE `code` exchanges with the verifier that `signInWithOtp` stored. That is spike item 2.

### Build mode: `--profile`
- **Chosen: `--profile`** (dart2js). This is the rev 6 "debug/profile" allowance.
- Why:
  - It builds one compiled `main.dart.js` instead of DDC's hundreds of lazily loaded modules. That removes the slow-DDC-load and module-timeout flake class (lock Risk 6) and runs the flows faster, inside the 3–5 min sizing.
  - It is closer to the shipped web artifact.
  - The cost is that framework asserts are off. Those assert paths are already covered by the 504 debug-mode widget tests. E2E proves wiring, not widgets (lock §0).
- If the PR1 spike shows that `--profile` can't drive the flows, stop and report. Switching to debug is a one-line Gilfoyle ruling, never an agent's choice.

---

## OPEN 6. Test names, `flows.md`, manifest check, owning folders (closes spec OPEN 7)

### Test names (exact `testWidgets` descriptions)
Rule: each name starts with its flow id and a space, uses only `[a-z0-9 ,/-]` after it, is ≤ 64 characters, and is a single string literal that is never split. Each literal appears only as its `testWidgets` description.
| Flow | Test name | PR |
|---|---|---|
| C1 | `C1 magic-link sign-in lands on timeline` | PR1 |
| C2 | `C2 start a family lands on its empty timeline` | PR2 |
| C3 | `C3 capture and publish shows the card on the timeline` | PR2 |
| C4 | `C4 draft autosaves, resumes from drafts and publishes` | PR2 |
| C5 | `C5 reader adds a comment and a perspective` | PR3 |
| C6 | `C6 invite link lets a second user join and see the timeline` | PR3 |
| C7 | `C7 search by person, place and timeframe finds the story` | PR3 |
| C8 | `C8 user from another family sees no content on a story url` | PR3 |
| C9 | `C9 sign out redirects guarded routes to the landing page` | PR3 |

### `apps/tell_me_a_story/integration_test/flows.md`, exact content (PR3)
- Spec sources are cited by section, not by line, so the manifest doesn't drift with impl-spec edits.
- Owning paths are relative to `apps/tell_me_a_story/lib/` and are checked to exist.
- C9's owner is `core/theme/album_header.dart`, because the sign-out control lives in `lib/core/theme/album_header.dart`, not under `lib/features/`.
```markdown
# E2E flow manifest

Lock: `docs/design-doc/e2e.md` (U1) and `docs/design-doc/e2e-addendum-a.md`. `e2e/check_flows.sh` checks this file in the `e2e` job. One row per flow. The test name is the exact `testWidgets` description in `e2e_test.dart`. Owning paths are relative to `apps/tell_me_a_story/lib/`.

| Flow | Test name | Spec source | Owning paths |
|---|---|---|---|
| C1 | `C1 magic-link sign-in lands on timeline` | §8 sign-in; M1; M8; `m08-profile.md`; §14 Automated #4 | `features/auth/`, `features/settings/`, `core/supabase/`, `core/router/`, `data/profile_session.dart` |
| C2 | `C2 start a family lands on its empty timeline` | US-1; M10; `m10-manage-families.md` | `features/family/`, `features/timeline/`, `data/families_api.dart` |
| C3 | `C3 capture and publish shows the card on the timeline` | US-3/3a/10; M3; M4; M14.1; publish lock; §14 Manual #1 | `features/stories/`, `features/people/`, `features/places/`, `features/timeline/`, `data/stories_api.dart`, `data/places_api.dart` |
| C4 | `C4 draft autosaves, resumes from drafts and publishes` | US-11; M14.4; `m14.4-drafts.md` | `features/drafts/`, `features/stories/`, `data/stories_api.dart` |
| C5 | `C5 reader adds a comment and a perspective` | US-6/6a; M5; M9; `m09-avatar-reader.md` | `features/stories/`, `features/comments/`, `features/perspectives/`, `data/comments_api.dart`, `data/perspectives_api.dart` |
| C6 | `C6 invite link lets a second user join and see the timeline` | US-2; M2; §8 accept-invite; `00-foundation.md` §5 | `features/invites/`, `features/auth/`, `features/timeline/`, `data/invite_api.dart` |
| C7 | `C7 search by person, place and timeframe finds the story` | US-9; M7 | `features/search/`, `data/search_api.dart` |
| C8 | `C8 user from another family sees no content on a story url` | §14 Automated #1; §13 | `features/stories/`, `core/router/` |
| C9 | `C9 sign out redirects guarded routes to the landing page` | router signed-out guard; M10 nav | `core/theme/album_header.dart`, `core/router/` |
```
(sha256 of this file: `91e5609169227bf18579869761b234b08a749b5ff3223669cf847fdc77c48b37`)

### Manifest check: `e2e/check_flows.sh`, bash (no Node, no Deno)
- This amends lock U1's "small Deno check" to **bash**. It needs no runtime, reads files only, and runs before Flutter setup.
- It fails on any of these:
  - ids that are duplicated or malformed;
  - more than 10 flows (U4);
  - a name that breaks the naming rule;
  - an owning path that is missing;
  - the set of names in `flows.md` ≠ the set of `'C<n> …'` literals in `e2e_test.dart`;
  - a `testWidgets(` count that differs from the row count;
  - any `testWidgets(` under `integration_test/support/`.
- Verified on a mock of the real `lib/` tree: it passes on the 9 rows above and fails on a renamed test and on a missing owner path.
- Exact content (58 lines, sha256 `9081d559b86c74dda132b25b73d1673af7ef90d4b74ad5e04f00a3f8d9eb3af6`):
```bash
#!/usr/bin/env bash
# E2E flow manifest check (lock U1, Addendum A). Run from the repo root.
# Fails if integration_test/flows.md and the testWidgets names in
# integration_test/e2e_test.dart diverge. Reads files only; no network.
set -euo pipefail

app="apps/tell_me_a_story"
manifest="$app/integration_test/flows.md"
entry="$app/integration_test/e2e_test.dart"
support="$app/integration_test/support"
fail=0
err() { echo "check_flows: $*" >&2; fail=1; }

[ -f "$manifest" ] || { echo "check_flows: missing $manifest" >&2; exit 1; }
[ -f "$entry" ] || { echo "check_flows: missing $entry" >&2; exit 1; }

rows="$(grep -E '^\| C[0-9]+ \|' "$manifest" || true)"
[ -n "$rows" ] || { echo "check_flows: no flow rows in $manifest" >&2; exit 1; }

ids="$(printf '%s\n' "$rows" | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}')"
names="$(printf '%s\n' "$rows" | awk -F'|' '{gsub(/^ +| +$/, "", $3); gsub(/`/, "", $3); print $3}')"
count="$(printf '%s\n' "$ids" | wc -l)"

dup="$(printf '%s\n' "$ids" | sort | uniq -d)"
[ -z "$dup" ] || err "duplicate flow ids: $dup"
[ "$count" -le 10 ] || err "$count flows is over the U4 budget of 10"

while IFS='|' read -r _ id name _ paths _; do
  id="$(echo "$id" | sed -E 's/^ +| +$//g')"
  name="$(echo "$name" | sed -E 's/^ +| +$//g; s/`//g')"
  case "$name" in
    "$id "*) ;;
    *) err "$id: test name '$name' does not start with '$id '" ;;
  esac
  printf '%s\n' "$name" | grep -qE '^C[0-9]+ [a-z0-9 ,/-]+$' ||
    err "$id: test name '$name' has characters outside [a-z0-9 ,/-]"
  [ "${#name}" -le 64 ] || err "$id: test name is over 64 characters"
  for p in $(printf '%s\n' "$paths" | grep -oE '`[^`]+`' | tr -d '`'); do
    [ -e "$app/lib/$p" ] || err "$id: owning path lib/$p does not exist"
  done
done <<< "$rows"

tests="$(grep -oE "'C[0-9]+ [^']*'" "$entry" | tr -d "'" | sort || true)"
want="$(printf '%s\n' "$names" | sort)"
if [ "$tests" != "$want" ]; then
  err "flows.md and e2e_test.dart disagree:"
  diff <(printf '%s\n' "$want") <(printf '%s\n' "$tests") >&2 || true
fi

calls="$(grep -c 'testWidgets(' "$entry" || true)"
[ "$calls" -eq "$count" ] || err "e2e_test.dart has $calls testWidgets calls; flows.md has $count rows"

if [ -d "$support" ] && grep -rlE 'testWidgets\(' "$support" >/dev/null; then
  err "testWidgets( found under $support; tests live only in e2e_test.dart"
fi

[ "$fail" -eq 0 ] || exit 1
echo "check_flows: $count flows match ($manifest <-> $entry)"
```

---

## CONFLICT rulings
- **(a) CONFIRMED.**
  - Allowed: exactly two added lines in `apps/tell_me_a_story/pubspec.yaml` under `dev_dependencies`, directly after the `flutter_test` entry:
    ```yaml
      integration_test:
        sdk: flutter
    ```
  - Plus the `pubspec.lock` changes that `flutter pub get` (Flutter 3.47.7) makes to resolve that one entry, and nothing else. The lock's "lockfile update only" means "no other pubspec change".
  - If any existing `pubspec.lock` entry changes version, or anything other than SDK-pinned packages and their transitive pins is added, stop and report (Trinity checks).
  - No direct `flutter_driver` entry.
- **(b) CONFIRMED.** The lock's "§15 item (M16)" (lock "Lock amendments" and the "Sizing" row PR0) is wrong: M16 is #72. The item is **M18**. M17 is #75 (M17a/M17b/M17c).
- **(c) CONFIRMED.** One M18 milestone item covers 4 ordered PRs (PR0 docs, PR1, PR2, PR3), all approved together by Bill's approval of the item. This is a named exception to `AGENTS.md` l.18 "One §15 milestone per PR". It matches the lock's "1 milestone, 1 docs PR and 3 code PRs".
  - Each PR is on its own `feat/m18-…` branch, cut from `main` after the previous one merges.
  - PR1 additionally waits for M17b (R0).
  - Only one M18 PR is open at a time.
- **impl-spec +2 offset: CONFIRMED** by content (l.317 → l.319, and so on). Cite impl-spec by content plus the current line number.

## Ambiguity rulings
- **A1. Waits.**
  - A bounded poll on an external condition, with an explicit overall timeout, is **allowed**. That covers:
    - the relay's Mailpit poll (250 ms interval, 30 s deadline). This is the only delay in `e2e/relay.ts`, and the PR must list it;
    - the `curl --retry-connrefused --retry-max-time 30` readiness probes;
    - `timeout 600 tail --pid`;
    - `pumpUntilFound` frame pumps with a deadline.
  - **Forbidden:** any wait not tied to a condition: `sleep`, `Future.delayed`, `setTimeout` used as a pause, or a fixed `pump(Duration(seconds: N))` used to "let things settle".
  - G5's `rg 'sleep|Future\.delayed'` over `integration_test/` and `test_driver/` must print nothing.
- **A2. Playwright/Node fallback: FORBIDDEN.** Lock Risk 2's "fall back to Playwright on the release build (rev 1 option T3) for C1 only" is withdrawn. If the web callback hand-off fails in the spike, stop and report to Gilfoyle. No Node, npm, `package.json` or Playwright, in any PR.
- **A3. Chrome-for-Testing:** not used (OPEN 1). Any future CfT pin needs an exact version plus a sha256 per zip, verified with `sha256sum -c`. Otherwise the job fails closed. Never unpinned.
- **A4. The 10 green runs.**
  - What counts: runs of workflow `CI` triggered by `push` to `main` whose `e2e` job concluded `success` on **run attempt 1**.
  - The count starts with the first such run after **PR3 merges** (the full C1–C9 suite plus the manifest check).
  - What resets it to 0: any `e2e` failure, cancellation or timeout on a main push run, or any rerun of one.
  - PR runs and manual reruns never count.
  - Who counts: **Gilfoyle or Trinity**, using read-only `list_workflow_runs` / `list_workflow_run_jobs`. They post the 10 run ids and head SHAs to Bill.
  - **Bill alone flips** `e2e` into `main`'s required checks by hand (rev 6 l.80). No agent touches branch protection.
- **A5. The two docs `e2e.md` cites that aren't in the repo**, found by checking every file citation in the lock against the `46957e2` tree. Every other cited file exists.
  - lock l.7 cites `e2e-design-options-rev1.md` (the rev 1 options draft, never committed). **Drop the citation.** l.7 becomes two lines:
    ```text
    > Supersedes the rev 1 options draft (never committed to the repo). The option menus are removed and only the chosen path remains.
    > Amended by Addendum A (`e2e-addendum-a.md`, LOCKED 2026-10-21). Where the two differ, Addendum A wins.
    ```
  - lock l.171 cites `advisors-clean-lock-rev2.md` (the #75 lock, outside the repo). **Correct it**: replace ``(see `advisors-clean-lock-rev2.md`)`` with `(M17b, which lands the reconciled rev 6)`.
  - No other edit to `e2e.md`. Stale lock statements (PR0 lands ci.md rev 6, M16, the AGENTS.md CI line, the Deno manifest check, the Playwright fallback) are overridden by this addendum, not rewritten in the lock.

## Handoff to Big Head (spec rev 2)
- PR0 files = the OPEN 4 list. Drop ci.md and AGENTS.md. Drop OPEN 2 (ci.md) and the rev 6 CONFLICT as CLOSED (R0).
- PR1 is gated on M17b merged. Copy the OPEN 1 YAML and the OPEN 5 files and driver exactly.
- PR3 adds `flows.md`, `e2e/check_flows.sh` and the manifest step exactly.
- G1 PR0: `e2e.md` is 241 lines, sha256 `464bfcf2…a4a0`. `git diff main -- AGENTS.md docs/design-doc/ci.md .github/` is empty.
- G2 pgTAP = base count (825 after M17b).
- G4 = the values above.
- The INFER "no `continue-on-error`" is confirmed. The INFER "relay polling" is confirmed (A1). The INFER "10 green" is confirmed with the A4 details.
