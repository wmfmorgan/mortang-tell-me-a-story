# AGENTS.md: Mortang · Tell Me a Story

Rules for any coding agent working in this repo. This file is the rule text. `.cursor/rules/mortang-contract.mdc` always applies and only points here. `.cursor/rules/architecture.mdc` and `.cursor/rules/coding.mdc` only point at sections of this file. They add no rules and hold no gates. `.cursor/rules/pstack-models.mdc` always applies the Bill-approved medium pstack budget; cheap lanes are in § Cheap lanes and docs. It is not a pointer and is not restated here.

## What governs a task
1. The one section of the task's plan in `docs/superpowers/plans/`, or the one Notion spec section the task links, and the product decisions that section cites (roadmap, "Product decisions"). § Build contract item 1 is the intake rule.
2. This file: layout, gates, code rules, § Architecture and layers, and § Build contract.
3. Older notes in `docs/impl-spec/`, `docs/plans/`, `docs/ux/`, and `docs/m14-review/` are history. Read one only when the linked plan section cites it. `docs/design-doc/` holds locked decisions, including `docs/design-doc/ci.md`. A current plan wins over that history.

If the code and the plan disagree, stop and report the difference. Do not reconcile silently. Chat is never a lock. If a Notion spec and a repo plan both cover the task and they disagree, stop and report in a draft PR body. Do not pick a winner.

## Layout
- `apps/tell_me_a_story/`: Flutter client (iOS, iPad, and web). Dependencies are in `apps/tell_me_a_story/pubspec.yaml`. The client uses `supabase_flutter` and `go_router`.
  - `lib/main.dart` starts the app and calls `initSupabase()`. `lib/app.dart` holds the app widget.
  - `lib/core/config/env.dart` reads `--dart-define` values. `lib/core/supabase/supabase_init.dart` builds the anon client. `lib/core/` also holds navigation, the router, and theme tokens.
  - `lib/data/`: PostgREST and edge-function gateways (`*_api.dart`) and session helpers. RPC error text goes through `mapRpcError` in `lib/data/rpc_error.dart`.
  - `lib/features/<feature>/`: screens.
  - `test/`: Flutter tests. The color guard is `test/core/theme/no_hardcoded_colors_test.dart`.
  - `integration_test/`: end-to-end flows (`integration_test/flows.md` and `integration_test/e2e_test.dart`). The manifest check is `e2e/check_flows.sh` at the repo root.
- `supabase/migrations/`: schema, row level security, storage policies, and SQL functions. A schema change is a new file here. Never edit a migration that has been applied.
- `supabase/functions/`: Deno edge functions. Shared code is in `supabase/functions/_shared/`. Tests are `supabase/functions/*_test.ts`.
- `supabase/tests/`: pgTAP.
- `Makefile` and the README Tests block are the local commands. Tool versions are pinned in `.github/workflows/ci.yml`.

## Work rules
- Build only what the plan lists. Do not add or remove a feature, screen, endpoint, table, or dependency on your own. If it is unclear, stop and ask.
- No direct push to `main`. Do not merge into `main`.
- TDD: write the failing test, make it pass, then refactor with the tests green.
- A schema change is a new SQL file under `supabase/migrations/`. Never edit a migration that has been applied.
- Every PR follows § Build contract (intake, scope, pre-PR checks, stop-and-report). It adds to these rules and relaxes none of them.

## Cheap lanes and docs

Lanes 1 (copy), 4 (bug fix), and docs use the cheap rules below; lanes 2 (UI), 3 (big feature), and 5 (small feature) use the full medium setup in `.cursor/rules/pstack-models.mdc`.

Lane 1 (copy), lane 4 (bug fix), and docs agents omit the Task `model` and run on the parent model. Do not use arena, swarm, interrogate, or architect.

Docs agents work alone with no subagents. Skip local Makefile targets and Flutter or Deno test runs; CI runs them. Edit only the files named in the brief; do not explore beyond them. At most one review-fix round.

## Gates
Run from the repo root unless the command names another directory. Paste the output in the PR body. CI is `.github/workflows/ci.yml`. It runs four jobs, `flutter`, `deno`, `pgtap`, and `e2e`, on pull requests to `main` and on pushes to `main`. There is no path filter.

| Gate | Command | Baseline |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed .` in `apps/tell_me_a_story` | 0 files changed |
| Analyze | the `flutter` job's analyze step | at most `ANALYZE_CEILING` issues (27), and no `error •` line |
| Flutter tests | `make test` | all passing, and never fewer tests |
| Deno | `deno check supabase/functions/*/index.ts supabase/functions/_shared/*.ts`, then `deno test --allow-env supabase/functions` | check clean, tests passing |
| pgTAP | `make db-test` | all passing |
| Flow manifest | `bash e2e/check_flows.sh` | exits 0 |
| End-to-end drive | the CI `e2e` job | `flutter drive` of `integration_test/e2e_test.dart` on local Supabase |

- `make test` runs `flutter test` in `apps/tell_me_a_story`. `make db-test` runs `supabase test db`.
- The README Tests block is `supabase db reset`, then `supabase test db`, then `cd apps/tell_me_a_story && flutter test`. Local Supabase has to be up for the database commands.
- `e2e/check_flows.sh` fails when `apps/tell_me_a_story/integration_test/flows.md` and the `testWidgets` names in `apps/tell_me_a_story/integration_test/e2e_test.dart` disagree. The manifest lists flows C1 through C9.
- The analyze ceiling is `ANALYZE_CEILING: 27` in `.github/workflows/ci.yml`. Lower it when you fix issues. Never raise it. Do not add `// ignore:` or `// ignore_for_file:` to pass a gate.
- `docs/design-doc/ci.md` is the CI lock. It names the same four jobs.

## Code rules
- No swallowed errors. Every catch shows or returns a mapped message, or rethrows.
- Database failures that the product handles use one of these prefixes on the exception message: `NOT_FOUND:`, `FORBIDDEN:`, `VALIDATION:`, `INVITE_INVALID:`. The client reads them only in `mapRpcError` (`lib/data/rpc_error.dart`). The edge-function copy is `mapRpcError` in `supabase/functions/_shared/manage.ts`. A new prefix needs Bill's approval. Messages are user-facing detail after the prefix. Do not put raw database text in them.
- UI uses only `lib/core/theme/album_theme.dart` tokens. `test/core/theme/no_hardcoded_colors_test.dart` fails on `Color(0x` or `Colors.` anywhere else in `lib/`. Its skip list names files by exact path from `lib/` and only shrinks. Never add a path. A new token needs Bill's approval.
- No new user-facing copy without Bill's approval.
- No new dependencies without Bill's approval. Pin majors. Do not upgrade a package in passing. An approved dependency also needs the dependency note in § Build contract item 6. A note never stands in for the approval.
- `lib/` layer rules are only in § Architecture and layers item 1. Follow that item.
- Only `lib/core/config/env.dart` calls `String.fromEnvironment`. Defines are compiled in. They are never secrets in git.

## Architecture and layers

Extends Layout, Work rules, and Gates. Item 1 is the only statement of the `lib/` layer rules. `.cursor/rules/architecture.mdc` points here and adds no rules.

1. `lib/main.dart` calls `initSupabase()` in `lib/core/supabase/supabase_init.dart`. That function builds the anon client from `Env` in `lib/core/config/env.dart`. It does not read the service role key. `lib/app.dart` holds the router widget. `lib/core/` holds config, navigation, the router, Supabase init, and theme. `lib/data/` holds `*_api.dart` gateways and session helpers. `lib/features/<feature>/` holds screens. Session state lives in `lib/data/`. Import rules for `lib/` (paths are relative to `apps/tell_me_a_story/lib/`; `import` and `export` both count, whether written as `package:tell_me_a_story/` or as a relative path):
   - `state/` does not exist. No file may be added under it, and nothing may import it.
   - `main.dart` and `app.dart` may import anything under `lib/`.
   - `core/router/` may import `core/`, `data/`, and `features/`. It is the only part of `core/` that wires screens to routes.
   - The rest of `core/`, meaning `core/config/`, `core/supabase/`, `core/theme/`, and `core/navigation/`, may import only `core/`. It must not import `data/` or `features/`.
   - `data/` may import only `data/`, `core/config/`, and `core/supabase/`. It must not import `features/`, `core/router/`, `core/theme/`, or `core/navigation/`.
   - `features/<feature>/` may import `core/`, `data/`, and other features. Imports from one feature to another are allowed and are not checked. Code that is not a screen and is shared by two or more features belongs in `data/` or `core/`.
   `test/architecture/lib_import_boundaries_test.dart` enforces these rules. Violations that already exist are listed in that test's `temporaryImportBoundaryViolations`, one `importer -> target` entry per import, with no line numbers. The list may only shrink. The test fails when an entry no longer matches. Adding an entry, loosening a rule, or creating `state/` is a stop-and-report to Gilfoyle.
2. The client talks to Supabase through `supabase_flutter`. New wrappers go in `apps/tell_me_a_story/lib/data/<name>_api.dart`. Screens go in `lib/features/<feature>/`. Follow the constructor pattern already in that folder. A screen takes the gateway as an optional argument and uses the live `*Api()` only when the argument is null. Tests pass a fake.
3. Schema, row level security, storage policies, and SQL functions live in `supabase/migrations/`. `supabase/migrations/20260923000004_rls.sql` enables row level security. `supabase/migrations/20260923000005_storage.sql` creates the private `story-photos` bucket. A change is a new migration file. Never edit a migration that has been applied.
4. Edge functions live in `supabase/functions/<name>/index.ts`. Shared helpers live in `supabase/functions/_shared/`. `userClient` and `serviceClient` are in `supabase/functions/_shared/supabase.ts`. pgTAP lives in `supabase/tests/`.
5. Rights come from row level security and from SQL functions that read `auth.uid()`. Do not trust a client-sent user id, family id, or role as permission. An edge function that changes data takes the caller's bearer token and uses `userClient`. `serviceClient` stays in edge functions. The Flutter app does not construct it.
6. The `story-photos` bucket is private. Storage policies on `storage.objects` check family membership. Read and write photos through the data gateways and those policies. `validate-invite-token` is the public invite preview. A rejected token returns `valid: false` and a null family name.
7. A handled database failure uses `raise exception` with one of `NOT_FOUND:`, `FORBIDDEN:`, `VALIDATION:`, or `INVITE_INVALID:`. `mapRpcError` in `lib/data/rpc_error.dart` returns the detail after the prefix, or null when the message has none of them. `mapRpcError` in `supabase/functions/_shared/manage.ts` maps the same four prefixes to HTTP status codes. Do not add a fifth prefix. Do not scan for those prefixes anywhere else. Do not reveal raw database text. Leave an existing message in place. Rewriting one is a copy change for Bill.
8. The Flutter app does not open Postgres on its own. It uses the Supabase client. The service role key, `RESEND_API_KEY`, and `RESEND_FROM` stay out of the client and out of git.
9. CI (`.github/workflows/ci.yml`) runs `flutter`, `deno`, `pgtap`, and `e2e` on every pull request to `main` and every push to `main`. There is no path filter.
   - `flutter` runs in `apps/tell_me_a_story`: `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed .`, the analyze ceiling, and `flutter test`.
   - `deno` runs `deno check supabase/functions/*/index.ts supabase/functions/_shared/*.ts` and `deno test --allow-env supabase/functions`.
   - `pgtap` runs `supabase db start`, `supabase test db`, and the splinter advisors check against `supabase/advisors-baseline.json`.
   - `e2e` runs `bash e2e/check_flows.sh`, then `flutter drive` against local Supabase. The drive target is `apps/tell_me_a_story/integration_test/e2e_test.dart`.
   Tool pins in that workflow are Flutter `3.47.7`, Deno `2.9.4`, and Supabase CLI `2.121.0`. A bump of any pin is its own PR and needs Bill's approval.

## Build contract

Extends Work rules, Gates, and Code rules. Architecture, layers, access control, and which CI jobs must stay green live in § Architecture and layers. This section does not change those rules. Each item has a Check that a reviewer can read from the diff or the PR body. Send the PR back when a Check fails.

### 1. Intake
1. Read only the one plan or spec section the task links (path and heading), the product decisions that section cites, this file, and the files that section names. Read `docs/impl-spec/`, `docs/plans/`, `docs/ux/`, or `docs/m14-review/` only when that section cites it.
2. Copy that section's acceptance items into the PR body as a checklist under **Spec**, with the path and heading.
3. Stop and report (item 5) when the section is missing, unclear, contradicts the code, contradicts another linked section, or needs something it does not list. Do not improvise. When a Notion spec and a repo plan both cover the task and they differ, stop and report in a draft PR body. Do not pick a winner.
Check: The PR body has **Spec** with one path and heading and the acceptance checklist. Every changed file traces to an item in it.

### 2. Branch and PR scope
1. One PR is one milestone of one plan, and one lane. Branch from current `main`. Never push to `main` or merge into `main`.
2. Touch only files the milestone needs. No drive-by refactors, renames, reformatting of untouched files, or upgrades.
3. A new file under `supabase/migrations/` is in scope only when the milestone changes the schema. Never edit a migration that has been applied.
4. A lane is the path set the milestone declares. The lanes are the client at `apps/tell_me_a_story/`, the backend at `supabase/`, and docs at `AGENTS.md`, `.cursor/`, and `docs/`.
5. Name the branch `<lane>/<milestone>-<slug>`. Name a docs branch `docs/<slug>`, with no milestone.
6. Keep the PR to about 400 changed lines. Do not count migration SQL. Split the work when it is larger than that.
Check: The PR body names **Milestone** and **Lane**. `git diff --stat main...HEAD` lists only files in that lane and milestone. The diff has no unrelated hunks and stays within the size cap.

### 3. Code rules for new and changed code
1. Keep a new or changed function or method body to at most 40 lines. Count a Flutter `build` method, and extract a private widget instead of letting `build` grow past that. Take at most 4 positional parameters. Use named parameters past that.
2. Give each new file one public top-level type, and name the file after that type in snake_case. SQL migrations and edge-function `index.ts` files are exempt.
3. Follow the gateway pattern already in the folder. A screen in `lib/features/` takes the gateway (`lib/data/*_api.dart`) as an optional constructor argument. The live `*Api()` is only the default when that argument is null. Tests pass a fake. `lib/main.dart` may construct the live gateways it passes into the router.
4. When behavior varies by kind, use a Dart `sealed` class and an exhaustive `switch`. Do not add a chain of `is` checks, `runtimeType` checks, or a string-keyed `if` ladder.
5. Do not add a state-management, dependency-injection, error-handling, or result library, and do not add a new error or result pattern. That is a dependency (item 6) and an architecture question. Stop and report. A new error pattern means anything other than the four rules in Client gateway errors.
Check: Function bodies and parameter lists in the diff stay within these limits, or the PR body names each exception and the reason. A new screen that calls a gateway takes that gateway as a constructor argument. The diff adds no new `is` or `runtimeType` dispatch chain.

### Which skill when

Read the skill at `.cursor/skills/<name>/SKILL.md` before the work in that row.

| When | Read |
|---|---|
| Bug fix | `tdd-bug-fix` and `fix-root-causes` |
| Any change with tests | `test-behavior-not-implementation` |
| Validation, errors, adapters, or endpoints | `boundary-discipline` |
| Before you declare the work done, or before you open the PR | `prove-it-works` |

### 4. Pre-PR checklist
Run these commands. They are the commands in the four jobs of `.github/workflows/ci.yml`. Paste the output in the PR body.

1. In `apps/tell_me_a_story`, run `flutter pub get --enforce-lockfile`.
2. In `apps/tell_me_a_story`, run `dart format --output=none --set-exit-if-changed .`.
3. In `apps/tell_me_a_story`, run the analyze step from the `flutter` job. The issue count is at most 27. An `error •` line fails.
4. Run `make test` from the repo root. It must pass. The test count does not drop.
5. From the repo root, run `deno check supabase/functions/*/index.ts supabase/functions/_shared/*.ts` and `deno test --allow-env supabase/functions`.
6. With local Supabase up, run `make db-test`. The README Tests block runs `supabase db reset`, then `supabase test db`, then Flutter tests.
7. Run `bash e2e/check_flows.sh`. It must exit 0. The CI `e2e` job also runs `flutter drive`. In **Gates**, write exactly `e2e: check_flows passed locally. flutter drive runs in the CI e2e job.`
8. Paste `git diff --stat main...HEAD` and a clean `git status`.
9. Under **Skills**, name every skill from the table above that applied. Write `None` only when no row applies.
Check: The PR body has a **Gates** section with the output of each command above, or the exact end-to-end line from step 7. **Skills** names the skills that applied, or `None`.

### 5. Stop-and-report
Stop work on the blocked file. Keep doing unblocked work in the same milestone. Put the block below under **Stop-and-report** in the PR body. Always open that PR as a draft. Stop-and-report always goes in a draft PR body. Use the same block when a Notion spec and a repo plan disagree, and do not pick a winner.

- Task: plan or spec path and heading, Milestone, and Lane.
- Blocked by: quote the exact spec line or rule, and its path.
- Found: what the code or the repo actually has, with the path, symbol, or command output.
- Gap: what is missing or in conflict, in one sentence.
- Options: up to 3. Implement none of them.
- Done meanwhile: the unblocked items you finished.
- Owner: Gilfoyle for architecture. Erlich or Bill for process, scope, copy, and dependencies.
Check: Every deviation from the spec appears in this block. The diff contains no code for an option that nobody has chosen.

### 6. Dependency note
Any added or changed entry in `apps/tell_me_a_story/pubspec.yaml`, or any version pin in `.github/workflows/ci.yml` (Flutter, Deno, or the Supabase CLI), needs Bill's approval (Code rules) and this block under **Dependency note** in the PR body. A note never stands in for that approval.

- Package and version: `name: ^x.y.z` (major pinned) in `apps/tell_me_a_story/pubspec.yaml`, or the tool pin and its file.
- What it is: one sentence.
- Why this spec item needs it.
- Alternatives considered: at least (a) no new dependency, using code or an SDK already in the repo, and (b) one other package. Say why not, for each.
- Approval: Bill, and where he approved it.
Check: The diff touches a dependency in `apps/tell_me_a_story/pubspec.yaml`, `apps/tell_me_a_story/pubspec.lock`, or a tool pin in `.github/workflows/ci.yml` only when the PR body has a complete **Dependency note**, and a complete note is present only when such a diff exists. The lockfile has no version bump of an unrelated package.

### 7. Typed errors
1. In Dart, never throw a `String`, a number, a `Map`, or a bare `Exception(...)`. A handled database failure uses one of `NOT_FOUND:`, `FORBIDDEN:`, `VALIDATION:`, or `INVITE_INVALID:` on the message. The client maps that message only in `lib/data/rpc_error.dart`. The edge-function copy is `supabase/functions/_shared/manage.ts`. A new prefix needs Bill's approval.
2. Use `Error` subclasses (`StateError`, `ArgumentError`, and the rest) for programmer bugs only. Never catch one to choose a behavior.
3. Catch by type, with `on PostgrestException catch (e)`, `on FunctionException catch (e)`, `on AuthException catch (e)`, or another named type. A bare `catch (e)` is allowed only at a boundary that maps the error and shows it, or that rethrows. On the client, showing the product message goes through `mapRpcError`. Never write `catch (_) {}`.
4. Never branch on raw error text outside the two `mapRpcError` functions. Do not write `toString().contains(`, `message.contains(`, or a `startsWith` check for those prefixes in a screen, a gateway, or a new edge function. Branch by calling `mapRpcError`.
5. Every new prefixed failure has a test that asserts the prefix or the mapped detail.
Check: The added lines contain none of `throw '`, `throw "`, `throw Exception(`, `catch (_) {}`, `.toString().contains(`, or `message.contains(`. Each new prefixed failure has a matching test. A new prefix scan exists only inside the two `mapRpcError` functions.

### 8. Tests
1. Ship tests in the same PR as the code. Write the test first (Work rules: TDD). The PR body has a **TDD log** with each new test name and the failure line from before the fix.
2. A changed non-generated file under `apps/tell_me_a_story/lib/` has a new or changed test under `apps/tell_me_a_story/test/`. A changed migration has a new or changed pgTAP file under `supabase/tests/`. A changed edge function has a new or changed `supabase/functions/*_test.ts`. Name any exception in the PR body, with a reason.
3. Never lower the test count. Do not delete a test. Do not add `skip:`, `@Skip`, or a tag change that moves a test out of `flutter test`, `deno test`, or `supabase test db`, unless the spec says so.
4. Assert what a user or a caller can observe: widget finders and text, return values, and the mapped RPC detail. Do not assert on private members. `make test` passes with no `--dart-define` and does not call the hosted project.
5. Do not edit `test/core/theme/no_hardcoded_colors_test.dart` to make a color pass, except to shrink its skip list.
Check: The diff pairs each changed source file with a test change. It removes or skips no test. The **TDD log** is present. Any color-guard edit only shrinks the skip list.

### 9. Do not
1. Push to `main`, or merge into `main`.
2. Edit outside the PR's lane or milestone, or bundle two milestones.
3. Add a dependency, feature, screen, endpoint, table, error prefix, theme token, or user-facing copy that the spec does not list and Bill has not approved.
4. Raise the analyze ceiling, add a path to a skip list, or add `// ignore:` or `// ignore_for_file:` to get past a gate.
5. Delete, skip, or weaken a test to go green.
6. Edit a migration that has been applied.
7. Edit the plan or the spec so that it matches your code.
8. Add a `TODO` or `FIXME` without a Stop-and-report entry for it.
9. Deploy Netlify, or change the hosted Supabase project `lchytafmnuefrgkguynt`, unless Bill asks. The GCP project `story-line-app` is not this repo's target. Do not put a secret in code, docs, or chat (Off limits).
10. Improvise around a spec gap. Stop and report.
11. Add a nested `AGENTS.md`, a `CLAUDE.md`, or a `.cursorrules`.
Check: None of these appear in the diff or the PR body.

### Client gateway errors

Product failures from Postgres reach the screen through `mapRpcError`.

1. Gateways in `lib/data/` let `PostgrestException` and `FunctionException` pass through. They map only by letting the caller use `mapRpcError`. They do not turn a failure into null, false, or an empty result. The one exception is a method whose locked spec says not-found and unreadable look the same.
2. `mapRpcError` in `lib/data/rpc_error.dart` reads a `PostgrestException` message. It returns the trimmed detail after `NOT_FOUND:`, `FORBIDDEN:`, `VALIDATION:`, or `INVITE_INVALID:`. It returns null when none of those prefixes match. Screens show that detail, or the copy already on the screen when the result is null.
3. The edge-function copy is `mapRpcError` in `supabase/functions/_shared/manage.ts`. It maps the same four prefixes to status codes. A new edge function uses that function. It does not keep a second list of prefixes.
4. A failure that matches none of the four prefixes is a stop-and-report to Gilfoyle. Do not invent a type or a fifth prefix.

A new error pattern means anything other than these four rules.

### PR body sections

Use this order. Spec, Milestone, Lane, Changes, Gates, TDD log, Tests, Skills, Dependency note (or "None"), Stop-and-report (or "None").

## Off limits
- No secrets in code, docs, or chat. Keep the Supabase service role key (`SUPABASE_SERVICE_ROLE_KEY`), `RESEND_API_KEY`, and `RESEND_FROM` out of git. Do not commit `.env` files. `supabase/functions/.env.example` is the example and holds no secret values.
- No production or hosted config changes (web hosting, DNS, the Supabase project, mail provider keys) unless Bill asks.
- Hosted deploy is Netlify (`netlify.toml`) plus the Supabase project `lchytafmnuefrgkguynt`. Run it only when Bill asks.
- The GCP project `story-line-app` is not this repo's target.
