# #48 E2E regression tests: design lock, rev 2

> **Status: rev 2, LOCKED 2026-10-20 (Gilfoyle; decisions by Bill 1:57 PM CT)**
> Bill, 2026-10-20 1:57 PM CT, verbatim: "#48: go with Gilfoyle's recommendations on all four (9 flows, ~11 min CI with the e2e exception, report-only until 10 green then required, lock after #72)".
> Locked against `main` = `46957e2749f2ea9410c40c347d566ddd4ac2fe2c` ("M16: drop people_tree_read (#72) (#76)"), merged 2:00 PM CT. Its only parent is `b025b75` (the rev 1 base). That diff touches no file this doc cites by line except `impl-spec.md`, and those four 1-for-1 line edits (l.1495–1786) shift no line numbers, so every line reference below still holds. CI run 39479748507 on 46957e2 is green.
> Gate met: #72 (people_tree_read hotfix) is merged and verified on prod (Gate 6 PASS, 2026-10-20). Next: Big Head writes the §15 item. Nothing is built before PR0 (ci.md rev 6) lands.
> Supersedes the rev 1 options draft (never committed to the repo). The option menus are removed and only the chosen path remains.
> Amended by Addendum A (`e2e-addendum-a.md`, LOCKED 2026-10-21). Where the two differ, Addendum A wins.

---

## 0. Intake facts (evidence)

**Issue #48**
- Body: "Placeholder only. Bill said do not start. Blocked by the CI issue. Gilfoyle locks the E2E design after CI lands, and only on Bill's go." Labels `blocked` and `in-pipeline`. No owner.
- Bill's comment (2026-10-20 10:11 AM CT: "Yes, have Gilfoyle design and size #48 after #72") asked for the design and sizing across four decisions: flows, target, sign-in and test data, and upkeep. All four are decided in this lock (Bill, 1:57 PM CT), and the #72 gate is cleared.
- **Acceptance:** "Nothing gets built until Bill approves the design and Big Head writes the spec item." Test-level acceptance comes from this lock plus the §15 item.

**CI today** (`.github/workflows/ci.yml`, lock `docs/design-doc/ci.md` rev 5)
- Three jobs, each on `ubuntu-latest`: `flutter` (ci.yml l.20–76), `deno` (l.78–100) and `pgtap` (l.102–132). Permissions are `contents: read`, with no secrets (ci.md l.6, l.17).
- Actions are pinned by SHA:
  - checkout `11d5960…` v4.4.0 (l.28/85/112)
  - flutter-action `1a44944…` v2.23.0, with Flutter 3.47.7 (l.32–34)
  - setup-deno `22d081f…` v2.0.5, with Deno 2.9.4 (l.89–91)
- The allowlist names exactly these three actions (ci.md l.39; impl-spec l.4285).
- Supabase CLI 2.121.0 comes from a release tarball checked with `sha256sum -c` (l.109–123). The job then runs `supabase db start` (l.128–129) and `supabase test db` (l.131–132).
- Main run 39479748507 (46957e2) logs:
  - `Flutter 3.47.7`, `Formatted 107 files (0 changed)`, `27 issues (ceiling 27, exit 0)`, `504 tests passed`
  - Deno: `43 passed | 0 failed`
  - pgTAP: `supabase.tar.gz: OK`, **`Files=25, Tests=803`**, `All tests successful`
- **pgTAP baseline: 25 files / 803 tests** (it was 24/799 before #72, which added `catalog_acl_guard.sql`).
- Measured job times (rev 1 measurement on b025b75): `flutter` 187 s, `deno` 13 s, `pgtap` 89 s (of which `db start` was 78 s). Run wall time is about 3 min.
- **The lock today bans what E2E needs:**
  - ci.md l.18: "🚫 Not in CI: … `supabase start` (full stack), E2E, `flutter build` …"
  - ci.md l.19: "🚫 No `--dart-define` and no secrets in CI."
  - impl-spec l.317: "CI injects no dart-defines and no secrets."
  - ci.md l.17: "No `link`, `--linked`, `--db-url`, `db push`, `db reset` … in CI, ever."
  - These are resolved by the **ci.md rev 6 e2e exception** (§ Lock amendments). It lands in the same rev 6 as the #75 advisors exception.
- The repo is public, so standard GitHub-hosted runner minutes are free.

**App** (`apps/tell_me_a_story`)
- Routes (`lib/core/router/app_router.dart` l.34–45): `/` (magic link), `/timeline`, `/stories/new`, `/stories/:id`, `/stories/:id/edit`, `/stories/:id/perspective`, `/invite/:token`, `/drafts`, `/search`, `/settings`, `/manage-families`, `/manage-families/:id`.
- Redirects (l.103–131):
  - A signed-out user goes to `/`, except on `/invite/*`.
  - `?invite=` rewrites to `/invite/:token`.
  - A signed-in user on `/` goes to `appStartPath` (l.62–76).
- Auth:
  - `magic_link_page.dart` l.31–32 calls `auth.signInWithOtp(email:, emailRedirectTo:)`. The redirect is the page origin, falling back to `http://127.0.0.1:3000` (`magic_link_redirect.dart` l.2–15).
  - Keys: `Key('magic-link-email')` l.362 and `Key('magic-link-error')` l.442.
  - `supabase_init.dart` l.17 sets `detectSessionInUri: false`. `recoverSessionFromAuthCallback(uri)` is at l.24–34.
- Env (`lib/core/config/env.dart`):
  - `SUPABASE_URL` and `SUPABASE_ANON_KEY` are required (l.5–6, l.30–51).
  - `INVITE_APP_ORIGIN` defaults to `http://127.0.0.1:3000` (l.9–12).
  - `MAPBOX_ACCESS_TOKEN` is soft: a missing token gives the failure UX (l.14–29). The picker gates on `_tokenOk` (`place_picker_modal.dart` l.86) and keeps the Favorites and Recents tabs (l.22, l.500–503).
  - `test/env_test.dart` l.5–31 asserts the defines are empty under `flutter test`. That stays true because E2E is a separate invocation.
- External calls: Mapbox (`mapbox_search.dart` l.98–115, `place_map.dart` l.9–11), `google_fonts` runtime fetch (pubspec l.45), and on the Edge side Resend or Mailpit (`_shared/invite_email.ts`).
- Platforms: `ios/` and `web/` only.
- **No E2E today.** pubspec dev_deps are `flutter_test` and `flutter_lints` only (pubspec l.47–56). Adding the Flutter SDK `integration_test` package is part of the chosen tooling (T1).
- 39 widget/unit test files with fake gateways cover the UI branches. E2E proves wiring, not widgets.

**Supabase local** (`supabase/config.toml`)
- Ports: API 57321 (l.10), DB 57322 (l.35), Studio 57323 (l.97), Mailpit **57324** (l.105–108). `project_id = "feat-m01-foundation"` (l.5).
- Auth:
  - `site_url = "http://127.0.0.1:3000"` (l.161). Redirect allow-list is 127.0.0.1/localhost:3000 plus `/invite/**` (l.165–170).
  - `enable_signup = true`, `enable_confirmations = false` (l.234), `max_frequency = "1s"` (l.238). OTP is 6 digits with a 3600 s expiry (l.240–242). Anonymous sign-in is off (l.185).
- Rate limits: `email_sent = 2`/h (l.206), `sign_in_sign_ups = 30`/5 min (l.214), `token_verifications = 30`/5 min (l.216).
- `[edge_runtime] enabled = true` (l.382–391). `validate-invite-token` has `verify_jwt = false` (l.425–426).
- `[db.seed] enabled = true` (l.66–68), and `supabase/seed.sql` is 0 bytes. ci.md l.52 forbids editing `seed.sql` to change pgTAP results.
- Rules:
  - AGENTS.md l.21: never edit an earlier migration.
  - AGENTS.md l.22: never `db reset`, `db pull` or `migration down`.
  - impl-spec l.315: no service-role key in the app.
  - §8 (l.557+): email magic link is the only sign-in.

**Spec sources:** §1 US-1…US-11 (l.55–130); §14 test plan (Automated l.1066–1074, Manual l.1075–1082); the publish lock (l.916–928); the milestone table (l.1095–1215); `docs/design-doc/*.md`.

---

## (a) Flows: LOCKED, thin critical path C1–C9 (one milestone)

| ID | Flow | Source |
|---|---|---|
| C1 | Magic-link sign-in: enter email → link from Mailpit → callback → profile bootstrap → required name (M8) → lands on `/timeline` | §8 l.557+, M1 l.1095, M8 l.1135, `m08-profile.md`, §14 Auto #4 |
| C2 | Start a family → lands on its empty timeline | US-1, M10 l.1160 / l.1279, `m10-manage-families.md` |
| C3 | Capture: title, text, timeframe, add person (create new), place from Favorites → **Publish** → card on timeline | US-3/3a/10, M3 l.1105, M4 l.1110, M14.1 l.1195, publish lock l.916–928, §14 Manual #1 |
| C4 | Draft: autosave → leave → resume from `/drafts` → publish. Not on the timeline before publish. | US-11, M14.4, `m14.4-drafts.md` |
| C5 | Reader: open story → comment → add perspective | US-6/6a, M5 l.1120, M9 l.1155, `m09-avatar-reader.md` |
| C6 | Invite via **Link** tab → second user opens `/invite/:token` → signs in → accepts → sees the family's timeline | US-2, M2 l.1100, §8 accept-invite, `00-foundation.md` §5 |
| C7 | Search by person, place and timeframe finds the published story | US-9, M7 l.1130 |
| C8 | Tenant isolation in the UI: user B (other family) opening A's `/stories/:id` sees no content | §14 Auto #1, §13 |
| C9 | Sign out → guarded routes redirect to `/` | router l.113–115, M10 nav |

- A broader flow is promoted only when a real regression escapes, one flow at a time, within the U4 budget.
- Mapbox search, iPad gestures and photo picking stay in manual smoke (§14 Manual).

---

## (b) Target and tooling: LOCKED

### Target: local Supabase inside the CI job
- A new 4th job, `e2e`, copies the `pgtap` job's CLI install step exactly (same version and sha256 env). It is copied, not a composite action.
- It runs `supabase start -x studio,imgproxy,vector,logflare,supavisor,postgres-meta`. That keeps db, auth, rest, realtime, storage, kong, Mailpit and edge-runtime.
- **No secrets.** URL and anon key come from `supabase status -o env` at runtime (local demo values).
- C1–C9 need no `supabase functions serve`, because the invite uses the Link tab.
- **External keys:**
  - No `MAPBOX_ACCESS_TOKEN`, so the picker shows the soft-fail UX (env.dart l.19–29).
  - The publish place comes from Favorites, which the test creates through the Places API as the signed-in user.
  - No Resend key, and no stub defines in app code.
- **Mapbox-pinned place:** if the spike (PR1) shows that publish needs a Mapbox-pinned place the Favorites path can't supply, that is **a Jared call**. It is raised only if the spike needs it. A test-only bypass is not an option.
- **Prod guard (test code only):** the harness aborts unless `SUPABASE_URL` is `http://127.0.0.1:57321` or `http://localhost:57321`, and fails on any `supabase.co` or `lchytafmnuefrgkguynt` match.
- Hosted targets (preview branches, staging, prod) are out for the PR gate.

### Tooling: `integration_test` + `flutter drive -d web-server`
- Dart, with the same `Key`s and finders as the 504 widget tests.
- New dependency: the Flutter SDK `integration_test` package (lockfile update only). Chrome and ChromeDriver are preinstalled on ubuntu-24.04 (`$CHROMEWEBDRIVER`). The fallback is a Chrome-for-Testing zip fetched with curl and checked with sha256.
- Actions: checkout, flutter-action, and setup-deno for the relay. All three are allowlisted.
- All flows live in **one** `integration_test/e2e_test.dart` entry, because each `flutter drive` rebuilds the app.
- Flags: `--web-port=3000 --web-hostname=127.0.0.1`. That matches `site_url` (l.161), the redirect allow-list (l.165–170) and the `INVITE_APP_ORIGIN` default.
- The artifact is a debug or profile web build. Photos (the file chooser) are not drivable, so they stay manual or go through an API-level helper.

---

## (c) Sign-in and test data: LOCKED

### Sign-in: Mailpit through a test-only Deno relay (M1)
- The UI sends the real `signInWithOtp`.
- The relay (`e2e/relay.ts`):
  - polls `GET :57324/api/v1/search?query=to:<email>`;
  - extracts the verify URL;
  - fetches it with `redirect: manual` to get `Location`.
- The test calls `recoverSessionFromAuthCallback(Uri.parse(location))` (supabase_init.dart l.24). There are no `lib/` changes.
- Expect about 12 sign-ins per run, under the 30/5 min limits. Whether `email_sent` 2/h applies to the local catcher is a spike item.
- **Fallback, only if the spike shows a limit biting:** admin `generate_link` with the local demo service_role key (M2). It is used for precondition users only, never for C1. The key comes from `supabase status -o env` and stays in the relay process only: never in the Flutter bundle, the repo or GitHub secrets.
- Password sign-in (M3) is **forbidden**.

### Test data: create through the app and API per test (D1)
- The flow under test goes through the UI.
- Preconditions (a favorite place, a second family, a published story for C5/C7/C8) go through the same Dart gateways, as the signed-in test user (anon key + RLS) or the real Edge functions.
- SQL fixtures (`e2e/fixtures/*.sql`, applied with local default credentials) are allowed **only** for states the app can't reach, and each file needs a Gilfoyle sign-off. Fixtures never go in `supabase/seed.sql` or a migration.
- **Isolation:** each test makes its own tenant. Emails are `e2e-<run_id>-<flow>-<n>@example.test`, and family names are unique.
- **No reset.** Each job gets a fresh `supabase start` and the stack dies with the runner. A reset command never appears in the workflow or the harness.
- Local runs on Bill's machine only add e2e-namespaced rows. There is no cleanup and no reset, and only one local stack runs at a time.

---

## (d) Upkeep: LOCKED (U1–U5)

**U1. Flow manifest.** `integration_test/flows.md` maps flow id → spec source → test name → owning feature folders. A small Deno check in the `e2e` job fails if the manifest and the tests diverge.

**U2. Same-PR updates.** Every §15 item carries "E2E flows touched: C3, C4" or "none". Big Head writes it and Gilfoyle confirms it. The PR body lists the flows with the e2e run link, and Dinesh and Big Head check it in review.
- An optional advisory annotation fires when a mapped `lib/features/<x>/` path changes without its flow's test. It never fails the build.

**U3. Required check timing: report-only until 10 green, then required.**
- **Phase 1, report-only:** the `e2e` job runs on every PR and push to main. It is **not** a required check.
- **Phase 2, required:** after **10 consecutive green runs on main** (0 flakes), Bill adds `e2e` to required checks in branch protection by hand (the ci.md l.55 pattern).

**U4. Pruning each milestone.** At each milestone CLOSED stamp, Gilfoyle reviews the manifest:
- drop flows now fully covered by widget, pgTAP or Deno tests;
- merge overlapping flows;
- keep the budget: **≤ 10 thin flows and ≤ 12 min e2e job wall time**, pruning before adding.

**U5. Flake policy.**
- No `sleep` and no fixed delays: wait on finders with a timeout.
- No automatic retries once the check is required. During report-only, one diagnostic rerun is allowed.
- A flow that flakes twice in 10 main runs moves to `integration_test/quarantine/` with a tracking issue, and is fixed or deleted within the milestone. At most 2 flows can be in quarantine; a third blocks new flows.
- Never fix a red run by editing pgTAP, migrations, `config.toml` or `seed.sql`.

---

## Lock amendments: ci.md rev 6, e2e exception

ci.md rev 6 carries exactly two exceptions: this one and the #75 advisors post-deploy job (M17b, which lands the reconciled rev 6). The e2e text:

> **Exception E2E (#48).** One job, `e2e`, may:
> - run `supabase start` against the **local** Supabase stack on the runner (exclusions `studio,imgproxy,vector,logflare,supavisor,postgres-meta`);
> - build and drive a debug/profile Flutter web app (`flutter drive -d web-server`);
> - pass `--dart-define` values sourced **only** from `supabase status -o env` (local demo values).
>
> It is **local Supabase only, never prod.** It uses no `${{ secrets.* }}`, no `link`, no `--linked`, no `--db-url`, no `db push/pull/reset`, and no `migration` command. Its permissions are `contents: read`. It uses only the allowlisted SHA-pinned actions, and `timeout-minutes: 25`. The job is report-only (not required) until 10 consecutive green runs on main, then it is a required check. Everything else in rev 5 l.17–19 still applies to every job.

Also in PR0:
- the AGENTS.md CI line;
- impl-spec l.317, amended to name the e2e local-only dart-define exception;
- the §15 item (M16).

---

## Sizing (locked path)

| PR | Content | Notes |
|---|---|---|
| PR0 (docs) | `docs/design-doc/e2e.md` (this lock), **ci.md rev 6**, AGENTS.md CI line, impl-spec §15 item M16 | Must land before any code PR |
| PR1 | Harness, the spike, and C1, as a report-only `e2e` job | Spike questions: ChromeDriver match, PKCE vs implicit hand-off, Mailpit search API, the email rate limit, the picker without a Mapbox token (→ Jared call only if needed). Adds the `integration_test` dev dep, `test_driver/`, `e2e/relay.ts` and the prod guard. |
| PR2 | C2, C3, C4 (family, capture → publish, drafts) | |
| PR3 | C5–C9 (reader, two-user invite, search, isolation, sign-out) | Adds the manifest check |
| (Bill) | Make `e2e` required after 10 consecutive green main runs | Branch protection, by hand |

- That is **1 milestone, 1 docs PR and 3 code PRs.**
- **CI growth (accepted by Bill):** the `e2e` job takes about **8–11 min wall** and runs in parallel with the other three jobs. Total run wall time goes from about 3 min to about 11 min.
  - Rough breakdown: flutter-action 1 min, CLI 0.1, `supabase start` 2.5–4 (backgrounded during Flutter setup), pub get 0.2, web build plus 9 flows 3–5, relay 0.1.
- About 30 runner-min per PR, which is free on a public repo. `timeout-minutes: 25`.

---

## Risks
1. **Lock churn.** PR0 (ci.md rev 6) must land first, or every E2E PR breaks the lock.
2. **Web callback hand-off.** The relay plus `recoverSessionFromAuthCallback` is unproven, and the PR1 spike must answer it. If it fails, fall back to Playwright on the release build (rev 1 option T3) for C1 only.
3. **Publish needs a place with a pin** (l.921), and there is no Mapbox token. If the spike shows Favorites can't satisfy it, that is a Jared call. A test-only bypass is not an option.
4. **Auth rate limits** (config.toml l.206/214/216). The M2 fallback applies to precondition users only.
5. **ChromeDriver and Chrome drift** on runner image updates. The fallback is a pinned Chrome-for-Testing download with sha256.
6. **`flutter drive` web flakiness** (infinite animations, slow DDC builds). Use bounded pumps, and profile mode if needed.
7. **External network** (`google_fonts`, Docker pulls, Mapbox 401s). Acceptable, but a flake source.
8. **Analyze ceiling 27 and dart format** apply to the new `integration_test/` and `test_driver/` code.
9. **Coverage gaps.** iPad and photo picking stay in manual smoke.

---

## FORBIDDEN
- Any hosted Supabase as an E2E target. **Prod `lchytafmnuefrgkguynt` is never a target**, and neither are its preview branches. Also banned in the e2e job: `supabase link`, `--linked`, `--db-url`, `db push/pull/reset` and any `migration` command.
- Real secrets anywhere in E2E: no `${{ secrets.* }}` in the `e2e` job, no Resend key and no Mapbox token. Only local demo values from `supabase status -o env`.
- The service_role key in the Flutter bundle or repo (impl-spec l.315). The local key stays inside the relay process only (M2 fallback).
- Test-only code in shipped builds: no `kE2E` or `bool.fromEnvironment('E2E')` hooks, no password sign-in, no debug routes and no auth bypass in `lib/`.
- Unpinned actions. Any action besides checkout, flutter-action and setup-deno, including `supabase/setup-cli` and local composite actions. Any tool not pinned by version plus sha256 or an integrity-hashed lockfile.
- Editing existing migrations. E2E fixtures in `supabase/seed.sql` or migrations.
- `supabase db reset` anywhere.
- Fixing a red E2E run by editing pgTAP, migrations or `config.toml`. Raising `ANALYZE_CEILING`.
- `sleep`-based waits. Automatic retries in the required gate.
- `pull_request_target`, `permissions` wider than `contents: read`, and `paths` filters on the e2e job.

---

## Decision record
| # | Decision | Locked as | By |
|---|---|---|---|
| 1 | Flows | Thin C1–C9 (9 flows), broad only on an escaped regression | Bill 1:57 PM CT |
| 2 | Target and tooling | Local Supabase in the CI job; `integration_test` + `flutter drive` web | Bill 1:57 PM CT ("recommendations on all four") |
| 3 | Sign-in and data | Mailpit + Deno relay (M2 fallback for precondition users only, M3 forbidden); per-test tenants, no reset, fixtures by exception | Bill 1:57 PM CT |
| 4 | Upkeep | U1–U5; report-only until 10 consecutive green main runs, then required | Bill 1:57 PM CT |
| – | CI growth | Accept about 8–11 min (about 11 min total wall) with the ci.md rev 6 e2e exception | Bill 1:57 PM CT |
| – | Timing | Locked after #72 merged (main 46957e2) | Bill 1:57 PM CT |
| – | Mapbox-pinned place | Jared call, only if the spike needs it | open, conditional |
