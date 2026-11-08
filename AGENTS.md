# AGENTS.md: Mortang · Tell Me a Story

Rules for any coding agent working in this repo. `.cursor/rules/mortang-contract.mdc` points here.

## What governs a task
1. The task's plan in `docs/superpowers/plans/` and the product decisions it cites (roadmap, "Product decisions").
2. This file: layout, gates and code rules.
3. `docs/archive/` is history (the old impl spec, design doc, UX notes, migration specs and earlier plans). Read it for background; a current plan wins.

If the code and the plan disagree, stop and report the difference; don't reconcile silently. Chat is never a lock.

## Layout
- `apps/tell_me_a_story/`: Flutter client (iPad + web).
  - `lib/app`: router and app widget.
  - `lib/core`: config, route paths, server connection, theme tokens.
  - `lib/data`: gateways and session state.
  - `lib/ui`: widgets used by several features.
  - `lib/features/<feature>`: screens.
  - `test/` mirrors `lib/`; `test/architecture` holds the guards; `test/support/fakes` holds the shared gateway fakes; `test/live` (tag `live`); `integration_test/` (e2e).
- `apps/server/`: Serverpod 4.1.1 server. Endpoints are in `lib/src/endpoints`, rules in `lib/src/<domain>`, models in `lib/src/models/*.spy.yaml`, migrations in `migrations/`.
- `packages/tell_me_a_story_client/`: generated; never edit by hand.

## Work rules
- Build only what the plan lists. Don't add or remove a feature, screen, endpoint, table or dependency on your own; if it's unclear, stop and ask.
- No direct push to `main`. Don't merge into `main`.
- TDD: write the failing test, make it pass, then refactor with the tests green.
- Server models change only in `*.spy.yaml`, followed by `just server-generate`. A schema change gets a new migration (`just server-migration <tag>`). Never edit an existing migration.

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
| e2e | `flutter drive` per README | 9/9 flows |

- `just test` includes `test/architecture/e2e_flow_manifest_test.dart`, which fails if `integration_test/flows.md` and `e2e_test.dart` disagree.
- The analyze ceiling lives in `justfile` (`analyze ceiling="6"`). Lower it when you fix issues; never raise it.
- CI runs the same recipes (`app`, `server` and `e2e` jobs).

## Code rules
- No swallowed errors. Every catch shows or returns a mapped message, or rethrows.
- Server errors are `AppException` with an `AppErrorCode` (`apps/server/lib/src/models/app_error_code.spy.yaml`; shorthands in `apps/server/lib/src/errors.dart`). Messages are user-facing copy; never put raw database text in them. The client maps them in `lib/data/server/server_errors.dart`. A new code needs the owner's approval.
- UI uses only `lib/core/theme/album_theme.dart` tokens. `test/architecture/no_hardcoded_colors_test.dart` fails on `Color(0x` or `Colors.` anywhere else in `lib/`. Its skip list names files by exact path from `lib/` and only shrinks: never add a path. A new token needs the owner's approval.
- No new user-facing copy without the owner's approval.
- No new dependencies without approval. Pin majors; no drive-by upgrades.
- `lib/` layers: `app/` (composition root) may import anything; `core/` imports `core/`; `data/` imports `core/` and `data/`; `ui/` imports `core/`, `data/` and `ui/`; `features/<f>/` imports those plus lower-rank features (`featureRank` in `test/architecture/import_boundaries_test.dart`). Only `app/` (with `main.dart`), `data/` and `core/server/` import the generated client or `serverpod*`. The test enforces this; change a rank only with the owner's approval.

## Off limits
- No secrets in code, docs or chat. `apps/server/config/passwords.yaml` comes from `just server-passwords` and is git-ignored.
- No production or hosted config changes (web and server hosting, DNS, mail provider keys).
- Deployment: see the GCP hosting work (pending).
