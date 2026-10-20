# AGENTS.md — Mortang · Tell Me a Story (cloud agent repo rules)

Rules for any coding agent (Cursor cloud agents) working in this repo.
Source: Grok Build CLI Contract + Impl Spec §0 / §15 (Notion). If this file and Notion diverge, prefer Notion and report it.

## Instruction hierarchy
1. APPROVED Impl Spec — Spec §0 is app law. Your task is one §15 item.
2. Contract (this file) — shared PR / TDD / gate rules.
3. Design Doc wins on SQL, RLS, Storage, Edge contracts and error codes. UXD / Stitch wins on look and copy (the written copy rule beats the mocks).
4. Chat is never a lock.

Work under pstack in poteto-mode; the contract gates below still win.

## Contract
- Only build the user-facing behavior listed in the PRD and that milestone's section of the impl spec (§15). Don't add or remove a feature on your own. If it's unclear, stop and ask.
- Implement **only** what the §15 item lists. Match names, paths, schemas and Stitch ids exactly. Never rename components, tables, or routes.
- Do **not** "improve" auth, schema, or API shape beyond the Spec / SAD / Design Doc. Do not invent screens, APIs, tables, auth, or stack.
- One §15 milestone per PR, on a `feat/mN-…` branch off `main`. No direct push to `main`.
- If an OPEN blocks a file, skip it, do the unblocked work, and report the OPEN.
- If code and the Spec disagree, **stop and report the diff**. Do not silently reconcile.
- Migrations: add new files in `supabase/migrations/` that sort after the latest one. **Never edit an earlier migration.**
- Local DB: `supabase migration up --local` only. **Never** `supabase db reset`, `supabase db pull` or `supabase migration down`. If a fix is needed locally, re-run only the changed statements.

## TDD (pstack / poteto-mode: plan, TDD, prove it works)
1. Plan from the §15 item before writing code.
2. Write the failing test first and **commit it**.
3. Make it pass.
4. Refactor with the tests green.
5. Prove it works: run the gates below and paste the output.

## Gates before opening the PR
The §15 item's own gates override these baselines. Otherwise, no regressions, and add new tests:

| Gate | Command | Baseline |
|---|---|---|
| Analyze | `cd apps/tell_me_a_story && flutter analyze` | ≤ 27 issues (current count) |
| Flutter | `cd apps/tell_me_a_story && flutter test` | all passing, ≥ 415, 0 failing |
| pgTAP | `supabase test db` (repo root, local Supabase running) | all passing, ≥ 530 |
| Deno | `deno test --allow-env supabase/functions` | all passing, ≥ 41 |

- Policy count is asserted by `supabase/tests/fit_and_finish.sql:611` and runs in `supabase test db`; it changes only when the Design Doc changes it (47 today).

- CI runs analyze, flutter test and Deno on every PR. pgTAP still runs locally, and its output goes in the PR body. **The PR body is the evidence**: paste fresh counts and command output from the PR's head commit.
- PR body / completion note: commands run, counts, Spec-allowed fills, OPENs left, and screenshots of each locked screen touched.

## Code quality
- No swallowed errors. Every catch shows or returns a mapped message or rethrows.
- UI uses only `album_theme.dart` tokens (`apps/tell_me_a_story/lib/core/theme/album_theme.dart`), no hardcoded colors; build from the Stitch screen of record, and the written UXD rules win over quirks in the mock.
- Enforced by a Flutter test (added in the AGENTS.md PR, runs in `flutter test`): it fails on any `Color(0x` or `Colors.` in `lib/` outside `album_theme.dart`. Temporary skip list: the 23 files that had hardcoded colors on 2026-10-15 (`lib/features/settings/settings_page.dart` plus the 22 in Dinesh's PR #31 review), each listed by exact path from `lib/`, never by bare file name; the `album_theme.dart` exemption is also an exact-path match. Each follow-up PR that fixes a file removes it from the list. The list only shrinks: never add a path to it.
- No new user-facing copy without approval. Copy comes from the UXD copy rule only.
- Errors use the shared `mapRpcError` (`supabase/functions/_shared/manage.ts`) with exactly four prefixes: `VALIDATION:`, `NOT_FOUND:`, `FORBIDDEN:`, `INVITE_INVALID:`. A new prefix goes to Gilfoyle first. Never return raw Postgres error text to the client; log it server-side.
- Definer functions: `set search_path = ''`, schema-qualified names, `(select auth.uid())`, and a null uid fails closed.
- No new dependencies without approval. Pin majors; no drive-by upgrades mid-milestone.
- a11y / i18n / analytics / observability only if the PRD or Spec opts in.

## Off limits
- No secrets in code, Notion or chat. `.env.example` only.
- No production or hosted config changes (hosted Supabase, auth redirects, Edge secrets).
- No merging. **Stop after opening the PR.**
- Do not stamp the Spec READY or CLOSED.

## After the PR (for reference)
Lane reviews: Gilfoyle (architecture), Big Head (spec), Mugatu (visual vs Stitch screenshots), Dinesh (code quality). Jared only if product scope drifted. Bill merges and smokes locally. Big Head stamps §15 CLOSED. A failed smoke means revert.

## Doesn't fit
Build stops → report → owner amends (Jared / Mugatu / Gilfoyle) → Spec update → Bill APPROVES → resume from the Spec only.
