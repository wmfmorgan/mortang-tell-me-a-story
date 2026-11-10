# AGENTS.md: Mortang · Tell Me a Story

Rules for any coding agent working in this repo. `.cursor/rules/mortang-contract.mdc` is the only rule set. `.cursor/rules/architecture.mdc` and `.cursor/rules/coding.mdc` only point at sections of this file. They add no rules and hold no gates.

## What governs a task
1. The one section of the task's plan in `docs/superpowers/plans/`, or the one Notion spec section the task links, and the product decisions that section cites (roadmap, "Product decisions"). § Build contract item 1 is the intake rule.
2. This file: layout, gates, code rules, § Architecture and layers, and § Build contract.
3. `docs/archive/` is history (the old impl spec, design doc, UX notes, migration specs and earlier plans). Read it only when that linked section cites it. A current plan wins over the archive.

If the code and the plan disagree, stop and report the difference; don't reconcile silently. Chat is never a lock. If a Notion spec and a repo plan both cover the task and they disagree, stop and report in a draft PR body. Do not pick a winner.

## Layout
- `apps/tell_me_a_story/`: Flutter client (iPad + web).
  - `lib/app`: router and app widget.
  - `lib/core`: config, route paths, server connection, theme tokens.
  - `lib/data`: gateways and session state.
  - `lib/ui`: widgets used by several features.
  - `lib/features/<feature>`: screens.
  - `test/` mirrors `lib/`; `test/architecture` holds the guards; `test/support/fakes` holds the shared gateway fakes; `test/live` (tag `live`); `test/goldens` (tag `golden`, macOS only, own `flutter_test_config.dart`; run by `just test-goldens`, excluded from `just test` and CI); `integration_test/` (e2e).
- `apps/server/`: Serverpod 4.1.1 server. Endpoints are in `lib/src/endpoints`, rules in `lib/src/<domain>`, models in `lib/src/models/*.spy.yaml`, migrations in `migrations/`.
- `packages/tell_me_a_story_client/`: generated; never edit by hand.

## Work rules
- Build only what the plan lists. Don't add or remove a feature, screen, endpoint, table or dependency on your own; if it's unclear, stop and ask.
- No direct push to `main`. Don't merge into `main`.
- TDD: write the failing test, make it pass, then refactor with the tests green.
- Server models change only in `*.spy.yaml`, followed by `just server-generate`. A schema change gets a new migration (`just server-migration <tag>`). Never edit an existing migration.
- Every PR follows § Build contract (intake, scope, pre-PR checks, stop-and-report). It adds to these rules and relaxes none of them.

## Gates
Run from the repo root as `mise exec -- just …` (or in a shell with mise activated) and paste the output in the PR body.

| Gate | Command | Baseline |
|---|---|---|
| All local gates | `just check` | passes |
| …format | `just fmt-check` | 0 changed |
| …app analyze | `just analyze` | ≤ 6 issues, no errors |
| …app tests | `just test` | all passing; never fewer tests |
| …server analyze | `just server-analyze` | no issues |
| …server tests | `just server-test` | all passing |
| Live client tests | `just server`, then `just test-live` | all passing |
| Goldens (macOS) | `just test-goldens` | all passing; regenerate only on purpose (`just test-goldens --update-goldens`) and open every changed PNG |
| e2e | `flutter drive` per README | 9/9 flows |

- `just test` includes `test/architecture/e2e_flow_manifest_test.dart`, which fails if `integration_test/flows.md` and `e2e_test.dart` disagree.
- The analyze ceiling lives in `justfile` (`analyze ceiling="6"`). Lower it when you fix issues; never raise it.
- CI runs the same recipes (`app`, `server` and `e2e` jobs).
- `just check` runs `just test`. § Build contract item 4 says which other rows a PR must paste (goldens, live, e2e).
- Every pull request to `main` or `feature/serverpod` must pass `just check` and the CI `e2e` job. `just check` does not run e2e. Goldens are not a CI job. Run live tests (`just server`, then `just test-live`) when the milestone closes.
- Planned CI, not required yet: an outsider endpoint test, `terraform fmt` and `terraform validate` on `infra/gcp`, and a secrets scan. § Architecture and layers states what each one is. Do not add them in a drive-by.

## Code rules
- No swallowed errors. Every catch shows or returns a mapped message, or rethrows.
- Server errors are `AppException` with an `AppErrorCode` (`apps/server/lib/src/models/app_error_code.spy.yaml`; shorthands in `apps/server/lib/src/errors.dart`). Messages are user-facing copy; never put raw database text in them. The client maps them in `lib/data/server/server_errors.dart`. A new code needs the owner's approval.
- UI uses only `lib/core/theme/album_theme.dart` tokens. `test/architecture/no_hardcoded_colors_test.dart` fails on `Color(0x` or `Colors.` anywhere else in `lib/`. Its skip list names files by exact path from `lib/` and only shrinks: never add a path. A new token needs the owner's approval.
- No new user-facing copy without the owner's approval.
- No new dependencies without approval. Pin majors; no drive-by upgrades. An approved dependency also needs the dependency note in § Build contract item 6. Approval is Bill's. A note never stands in for it.
- `lib/` layers: `app/` (composition root) may import anything; `core/` imports `core/`; `data/` imports `core/` and `data/`; `ui/` imports `core/`, `data/` and `ui/`; `features/<f>/` imports those plus lower-rank features (`featureRank` in `test/architecture/import_boundaries_test.dart`). Only `app/` (with `main.dart`), `data/` and `core/server/` import the generated client or `serverpod*`. The test enforces this; change a rank only with the owner's approval.

## Architecture and layers

Extends Layout, Work rules, Gates, and the `lib/` layers bullet under Code rules. `.cursor/rules/architecture.mdc` points here and adds no rules.

1. Honor `apps/tell_me_a_story/test/architecture/import_boundaries_test.dart`. `app/` and `main.dart` may import anything. `core/` imports `core/` only, except `core/server/` may import `package:tell_me_a_story_client/` and `serverpod*`. `data/` imports `core/`, `data/`, and those server packages, and never imports Flutter UI libraries, `ui/`, or `features/`. `ui/` imports `core/`, `data/`, and `ui/`, and never imports the generated client. `features/<f>/` imports those plus lower-rank features only (`featureRank` in the test). There is no `lib/state/`. Session state lives in `lib/data/`. Server layer imports are convention only. There is no server import-boundary test. Do not invent one.
2. Only `app/`, `data/`, and `core/server/` import the generated client (`packages/tell_me_a_story_client/`) or `serverpod*`. Never edit that package or `apps/server/lib/src/generated/` by hand.
3. Put new endpoints in `apps/server/lib/src/endpoints/`. Put domain rules in `apps/server/lib/src/<domain>/`. Put models in `apps/server/lib/src/models/*.spy.yaml`, and DTOs in `models/dto/`. Then run `just server-generate`. A schema change also gets `just server-migration <tag>`, which writes `apps/server/migrations/`. Never edit an existing migration.
4. Put new client API wrappers in `apps/tell_me_a_story/lib/data/<name>_api.dart`. Put screens in `lib/features/<feature>/`. When `<feature>` is new, add it to `featureRank`. Change an existing rank only with the owner's approval. Put shared widgets in `lib/ui/`. Put infra in `infra/gcp/` (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `bootstrap.sh`). Do not run `just gcp-infra` unless the owner asks.
5. Every endpoint method authenticates and calls `Authz` (`apps/server/lib/src/authz/authz.dart`) before it touches data. Set `requireLogin => true` unless the method is the documented public invite preview. Never trust a client-sent user id, family id used for permission, role, or storage path. Derive the caller from `session.authenticated` (`Authz.userId` and `requireUser()`). Derive family, tree, and story rights from the database through `Authz`. Build storage keys on the server (`apps/server/lib/src/media/blob_keys.dart`). Do not parse a key the client sends. `MediaEndpoint` resolves each key to the holding row, then checks `Authz`.
6. GCS stays private. Issue a signed PUT only after `Authz`, through `session.storage.createUploadDescription`. `PhotoEndpoint.startUpload` and `FamilyEndpoint.startCoverUpload` are that path. Read blobs only through `MediaEndpoint.get` and `getMany`. Unknown, unreadable, and missing blobs all look the same: null or omitted. `ProfileEndpoint.saveAvatar` and `PeopleEndpoint` person pictures may store JPEG bytes with `session.storage.storeFile` after `Authz`. That is the only upload exception. Still use a server-built key, and still read them through `media.get`. Do not invent a second upload path. `InvitePublicEndpoint.preview` is the only `requireLogin => false` method, and it does not call `Authz`. Unknown, deleted, accepted, revoked, and expired tokens all return `valid: false` with no family and no inviter.
7. Throw `AppException` with an `AppErrorCode` (`apps/server/lib/src/models/app_error_code.spy.yaml`, shorthands in `apps/server/lib/src/errors.dart`). Do not put raw database text in the message. Do not reveal which role was required, or whether a hidden row exists. Use the default `forbidden()` copy ("You don't have access to that.") or the method's documented not-leak shape: an empty list, null, or `notFound` for both missing and unreadable. New code uses that generic copy. Leave the older role-named messages in place. They are `member only`, `owner or co-owner only`, and `owner only` in `apps/server/lib/src/authz/authz.dart`, plus `LiveEndpoint.watchFamily`, `LiveEndpoint.watchTree`, `FamilyEndpoint.detail`, `FamilyEndpoint.recover`, and `PeopleEndpoint.delete` when the person is missing. Rewriting them is a security-copy change for Trinity or Bill. Do not do it in passing.
8. No direct database or GCS access from outside `apps/server`.
9. CI (`.github/workflows/ci.yml`) runs the `app`, `server`, and `e2e` jobs on every pull request to `main` and `feature/serverpod`. There is no path filter. The `app` job runs `just fmt-check`, `just analyze`, and `just test`, which keeps `import_boundaries_test.dart` green. The `server` job runs `just server-analyze` and `just server-test` on embedded Postgres. The `e2e` job runs `flutter drive` on every such pull request. Do not add goldens to CI. `e2e_flow_manifest_test.dart`, `no_hardcoded_colors_test.dart`, and `test_layout_test.dart` live in the same test folder and are not import-boundary tests.
   Planned, and not required until a later PR adds them:
   - Outsider endpoint test. Enumerate every Serverpod endpoint method. Call each one as a signed-in non-member and as an unauthenticated caller. Require `FORBIDDEN`, an unauthenticated failure, or that method's documented not-leak response. Fail when a new endpoint method has no coverage. Allow `InvitePublicEndpoint.preview`. Self-scoped methods (`ProfileEndpoint.*`, `FamilyEndpoint.createRoot`, `listMine`, `listStewarded`, `directory`, and `InviteEndpoint.accept`) must not expose another family's data. `apps/server/test/integration/authz_test.dart` is not this test.
   - `terraform fmt` and `terraform validate` on `infra/gcp`.
   - A secrets scan. Gilfoyle's architecture draft does not specify one. A later PR may add it. Do not invent a scanner here.

## Build contract

Extends Work rules, Gates, and Code rules. Architecture, layers, access control, and which CI jobs must stay green live in § Architecture and layers. This section does not change those rules. Each item has a Check that a reviewer can read from the diff or the PR body. Send the PR back when a Check fails.

### 1. Intake
1. Read only the one plan or spec section the task links (path and heading), the product decisions that section cites, this file, and the files that section names. Read `docs/archive/` only when that section cites it.
2. Copy that section's acceptance items into the PR body as a checklist under **Spec**, with the path and heading.
3. Stop and report (item 5) when the section is missing, unclear, contradicts the code, contradicts another linked section, or needs something it does not list. Do not improvise. When a Notion spec and a repo plan both cover the task and they differ, stop and report in a draft PR body. Do not pick a winner.
Check: The PR body has **Spec** with one path and heading and the acceptance checklist. Every changed file traces to an item in it.

### 2. Branch and PR scope
1. One PR is one milestone of one plan, and one lane. Branch from current `main`. Never push to `main` or merge into `main`.
2. Touch only files the milestone needs. No drive-by refactors, renames, reformatting of untouched files, or upgrades.
3. Generated output (`just server-generate`) and a new migration (`just server-migration <tag>`) are in scope only when the milestone changes `*.spy.yaml` or endpoints.
4. A lane is the path set the milestone declares. The lanes are the client at `apps/tell_me_a_story/`, the server at `apps/server/` with its generated client at `packages/tell_me_a_story_client/`, and infra at `infra/gcp/`.
5. Name the branch `<lane>/<milestone>-<slug>`.
6. Keep the PR to about 400 changed lines. Do not count generated code, migrations, or golden PNGs. Split the work when it is larger than that.
Check: The PR body names **Milestone** and **Lane**. `git diff --stat main...HEAD` lists only files in that lane and milestone. The diff has no unrelated hunks and stays within the size cap.

### 3. Code rules for new and changed code
1. Keep a new or changed function or method body to at most 40 lines. Count a Flutter `build` method, and extract a private widget instead of letting `build` grow past that. Take at most 4 positional parameters. Use named parameters past that.
2. Give each new file one public top-level type, and name the file after that type in snake_case. Generated code and `*.spy.yaml` models are exempt.
3. Pass gateways in. Do not construct them in the widget. New code in `lib/ui/` and `lib/features/` receives gateways (`lib/data/*_api.dart`) through a constructor or the existing composition in `app/`. Follow the pattern already used in that folder.
4. When behavior varies by kind, use a Dart `sealed` class and an exhaustive `switch`. Do not add a chain of `is` checks, `runtimeType` checks, or a string-keyed `if` ladder.
5. Do not add a state-management, dependency-injection, error-handling, or result library, and do not add a new error or result pattern. That is a dependency (item 6) and an architecture question. Stop and report. O6 below stays open, so this ban includes a new typed client failure.
Check: Function bodies and parameter lists in the diff stay within these limits, or the PR body names each exception and the reason. The diff adds no `XxxApi(` constructor call under `lib/ui/` or `lib/features/`. The diff adds no new `is` or `runtimeType` dispatch chain.

### Which skill when

Read the skill at `.cursor/skills/<name>/SKILL.md` before the work in that row.

| When | Read |
|---|---|
| Bug fix | `tdd-bug-fix` and `fix-root-causes` |
| Any change with tests | `test-behavior-not-implementation` |
| Validation, errors, adapters, or endpoints | `boundary-discipline` |
| Before you declare the work done, or before you open the PR | `prove-it-works` |

### 4. Pre-PR checklist
Run these from the repo root. Paste the output in the PR body.

1. On a fresh checkout, run `mise install`. Then run `mise exec -- just server-setup` before any server test.
2. When `*.spy.yaml` or endpoints changed, run `mise exec -- just server-generate`. For a schema change, also run `mise exec -- just server-migration <tag>`. Commit that output. Running generate again leaves `git status` clean.
3. Run `mise exec -- just check`. It must pass at the baselines in § Gates. The output includes the `just test` run. Tests are all passing, and there are never fewer tests.
4. When the diff touches `apps/tell_me_a_story/lib/ui/`, `apps/tell_me_a_story/lib/features/`, `apps/tell_me_a_story/lib/core/theme/`, or `apps/tell_me_a_story/test/goldens/`, run `mise exec -- just test-goldens` on macOS. When that diff is on any other OS, write exactly `Goldens: not run (OS: <os>). Needs a macOS run.` When the diff touches none of those paths, write exactly `Goldens: not run (no UI, theme, or golden changes).` Regenerate goldens only on purpose with `just test-goldens --update-goldens`, and list every changed PNG.
5. The CI `e2e` job is required on every pull request to `main` or `feature/serverpod`. Do not skip it and do not drop it from the workflow. A local `flutter drive` is not an extra pre-PR command. CI runs it. In **Gates**, write exactly `e2e: required in CI. Not run locally.` Run live tests (`just server`, then `just test-live`) when the milestone closes. Until then, write exactly `Live: not run (milestone still open).`
6. Paste `git diff --stat main...HEAD` and a clean `git status`.
7. Under **Skills**, name every skill from the table above that applied. Write `None` only when no row applies.
Check: The PR body has a **Gates** section with the output of each command above, or the exact not-run line for that row. **Skills** names the skills that applied, or `None`.

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
Any added or changed entry in a `pubspec.yaml`, or any tool in `mise.toml`, needs Bill's approval (Code rules) and this block under **Dependency note** in the PR body. A note never stands in for that approval.

- Package and version: `name: ^x.y.z` (major pinned) in `<path>/pubspec.yaml`.
- What it is: one sentence.
- Why this spec item needs it.
- Alternatives considered: at least (a) no new dependency, using code or an SDK already in the repo, and (b) one other package. Say why not, for each.
- Approval: Bill, and where he approved it.
Check: The diff touches a dependency in `pubspec.yaml`, `pubspec.lock`, or `mise.toml` only when the PR body has a complete **Dependency note**, and a complete note is present only when such a diff exists. The lockfile has no version bump of an unrelated package.

### 7. Typed errors
1. Never throw a `String`, a number, a `Map`, or a bare `Exception(...)`. A server failure is an `AppException` with an `AppErrorCode`, thrown through the shorthands in `apps/server/lib/src/errors.dart`. A new code needs the owner's approval.
2. Use `Error` subclasses (`StateError`, `ArgumentError`, and the rest) for programmer bugs only. Never catch one to choose a behavior.
3. Catch by type, with `on AppException catch (e)` or another named type. A bare `catch (e)` is allowed only at a boundary that maps the error and shows it, or that rethrows. On the client, that mapping lives in `lib/data/server/server_errors.dart`. Never write `catch (_) {}`.
4. Never branch on error text. Do not write `toString().contains(`, `message.contains(`, or a string compare on an error. Branch on the type or the `AppErrorCode`.
5. Every new `AppException` throw has a test that asserts its `AppErrorCode`.
Check: The added lines contain none of `throw '`, `throw "`, `throw Exception(`, `catch (_) {}`, `.toString().contains(`, or `message.contains(`. Each new `AppException` throw has a matching test.

### 8. Tests
1. Ship tests in the same PR as the code. Write the test first (Work rules: TDD). The PR body has a **TDD log** with each new test name and the failure line from before the fix.
2. Each changed non-generated file under `apps/tell_me_a_story/lib/` has a new or changed test at the mirrored path under `test/`. Each changed file under `apps/server/lib/src/` outside `generated/` has a new or changed test under `apps/server/test/`. Name any exception in the PR body, with a reason.
3. Never lower the test count. Do not delete a test. Do not add `skip:`, `@Skip`, or a tag change that moves a test out of `just test`, unless the spec says so.
4. Assert what a user or a caller can observe: widget finders and text, return values, and `AppErrorCode`. Do not assert on private members. Put shared gateway fakes in `test/support/fakes`. `just test` makes no network calls. Live tests use the tag `live`.
5. Never edit a guard under `test/architecture/` to make code pass. The only allowed edits are the ones § Architecture and layers and Code rules already allow: add a new feature to `featureRank`, or shrink the hard-coded-colors skip list.
Check: The diff pairs each changed source file with a test change. It removes or skips no test. The **TDD log** is present. Any `test/architecture/` edit stays inside the list above.

### 9. Do not
1. Push to `main`, or merge into `main`.
2. Edit outside the PR's lane or milestone, or bundle two milestones.
3. Add a dependency, feature, screen, endpoint, table, `AppErrorCode`, theme token, or user-facing copy that the spec does not list and the owner has not approved.
4. Raise the analyze ceiling, add a path to a skip list, or add `// ignore:` or `// ignore_for_file:` to get past a gate.
5. Delete, skip, or weaken a test to go green.
6. Hand-edit generated code, or an existing migration.
7. Edit the plan or the spec so that it matches your code.
8. Add a `TODO` or `FIXME` without a Stop-and-report entry for it.
9. Run `gcp-bootstrap`, `gcp-infra`, `deploy-server`, or `deploy-web` unless the owner asks. Do not put a secret in code, docs, or chat (Off limits).
10. Improvise around a spec gap. Stop and report.
11. Add a nested `AGENTS.md`, a `CLAUDE.md`, or a `.cursorrules`.
Check: None of these appear in the diff or the PR body.

### Open

O6 is open with Gilfoyle. The question is whether a `lib/data` gateway should expose a typed client failure instead of letting `AppException` pass through to `lib/data/server/server_errors.dart`. Until he rules, item 3.5 forbids any new error or result pattern. Do not add one.

### PR body sections

Use this order. Spec, Milestone, Lane, Changes, Gates, TDD log, Tests, Skills, Dependency note (or "None"), Stop-and-report (or "None").

## Off limits
- No secrets in code, docs or chat. `apps/server/config/passwords.yaml` comes from `just server-passwords` and is git-ignored.
- No production or hosted config changes (web and server hosting, DNS, mail provider keys).
- Deployment (README "Deployment"; needs terraform from `mise.toml`, gcloud and firebase): once `BILLING_ACCOUNT=… RESEND_API_KEY=… RESEND_FROM=… just gcp-bootstrap`, then `just gcp-infra` → `just deploy-server` → `just deploy-web`. These change hosted resources, so run them only when the owner asks.
