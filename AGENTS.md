# AGENTS.md

Canonical agent entry for Mortang · Tell Me a Story. Compact and operational. Deeper durable context lives in `.context/`. `.cursor/rules/*.mdc` only point here.

## Project Context

- [.context/project-context.md](.context/project-context.md) - what this app is, architecture, ownership map, integrations, durable decisions.
- [.context/engineering-guide.md](.context/engineering-guide.md) - commands, Dart/Flutter standards, testing, boundaries, safety.
- [.context/writing-specs.md](.context/writing-specs.md) - how to write a spec (what and why) and the spec -> DD -> TDD flow.
- [.context/writing-dds.md](.context/writing-dds.md) - how to write a design document (DD) that splits work into TDDs.
- [.context/writing-tdds.md](.context/writing-tdds.md) - how to write a Technical Design Document (TDD) for one shippable unit.
- [.context/README.md](.context/README.md) - `.context/` conventions: durable guides vs. ephemeral `active/` specs, DDs, and TDDs.

A task is governed by its active doc in `.context/active/` (spec, DD or TDD per `.context/writing-specs.md`) and the durable decisions in `.context/project-context.md`. `docs/` is stale history: background only, never a spec. If code and the active doc disagree, stop and report; don't reconcile silently. Chat is never a lock. Bill approves dependencies, tokens, copy, `AppErrorCode`s and architecture changes.

## Stack

- Client: Flutter 3.47.7 (iPad + web) in `apps/tell_me_a_story`. State + DI: Riverpod 3 with `riverpod_generator`. Routing: `go_router`. Models: `freezed` (+ `json_serializable` only for JSON the app parses itself, i.e. Mapbox). UI: `forui` skinned by `albumForuiTheme()` over the album tokens. Tests: `flutter_test` + `mocktail`; e2e with `integration_test` via `flutter drive`.
- Server: Serverpod 4.1.1 in `apps/server` on PostgreSQL (embedded locally; Cloud SQL in production).
- Generated client: `packages/tell_me_a_story_client` (`just server-generate`); never hand-edit.

## Commands

Tools are pinned in `mise.toml` (`flutter`, `just`, `terraform`). Run recipes from the repo root as `mise exec -- just <recipe>` (or plain `just` with mise activated). Recipes live in `justfile`; full table in `.context/engineering-guide.md`.

```
just                    # list recipes
just setup              # mise install: pinned tools
just codegen            # build_runner (freezed, riverpod_generator, json_serializable); outputs gitignored
just run                # web-server on 127.0.0.1:3000 against :8080 (alias: just web); runs codegen
just test               # app tests, goldens excluded; runs codegen
just test-live          # live client tests against a running `just server`; runs codegen
just test-goldens       # golden tests, macOS only (--update-goldens to regenerate); runs codegen
just analyze [ceiling]  # flutter analyze: any error fails, at most `ceiling` (default 0) issues; runs codegen
just fmt-check          # dart format check: app (minus generated) and server
just server-setup       # serverpod_cli 4.1.1, server + client packages, local passwords
just server-passwords   # write git-ignored apps/server/config/passwords.yaml (no-op if present)
just server-generate    # regenerate server protocol, client package, test tools
just server-migration <tag>  # create a migration from model changes
just server             # API on :8080, embedded Postgres, migrations applied, login code 111111
just server-test        # backend unit + integration tests (embedded Postgres)
just server-analyze     # dart analyze --fatal-infos in apps/server
just check              # fmt-check + analyze + test + server-analyze + server-test
```

### Gates

| Gate | Command | Baseline |
|---|---|---|
| All local gates | `just check` | passes: fmt 0 changed, analyze 0 issues, app tests, server analyze 0 issues, server tests |
| Goldens (UI, theme or golden changes) | `just test-goldens` on macOS | all passing; regenerate only on purpose and open every changed PNG |
| Live client tests | `just server`, then `just test-live` | all passing |
| e2e | `flutter drive` per README; CI `e2e` job | 9/9 flows |

- The test count never drops. `just test` includes `test/architecture/e2e_flow_manifest_test.dart` (`integration_test/flows.md` must match `e2e_test.dart`).
- The analyze ceiling (`justfile`, `analyze ceiling="0"`) is never raised. No `// ignore:` to pass a gate.
- CI (`.github/workflows/ci.yml`) runs `app` (fmt-check, analyze, test), `server` (server-analyze, server-test) and `e2e` on PRs to `main` and `feature/serverpod`. Goldens are not in CI.

## Standards

Client layout (`apps/tell_me_a_story/lib/`, detail in `.context/project-context.md#ownership-map`):

- `main.dart` bootstraps and is the composition root: `ProviderScope(overrides: [...])` binds every repository provider to its `Server<X>Repository`. `app.dart` holds `App` (`MaterialApp.router`).
- `core/`: `env.dart`, `router/`, `theme/`, `server/`, `domain/`, `data/`, `session/`, `widgets/`. Code used by 2+ features lives here.
- `features/<f>/{data,domain,presentation}/`. `presentation/` never imports any `data/`; it reads repositories through providers in `domain/`. A feature never imports another feature's `data/`.
- `test/` mirrors `lib/`; guards live in `test/architecture/`.

Client code:

- Riverpod with codegen: `@riverpod` functions for reads, `@riverpod class X extends _$X` notifiers for mutable/async state. `ref.watch` in `build`, `ref.read` in callbacks. Widgets never construct or receive repositories. `setState` only for state local to one widget.
- Repositories: `XRepository` interface + its provider in `domain/`, `ServerXRepository` in `data/`, overridden in `main.dart`; tests override with fakes. Every async surface renders `AsyncValue.when` with the mapped error.
- Models are immutable `@freezed` classes in `domain/`, one public model per file. Never hand-edit `*.g.dart` / `*.freezed.dart` (gitignored; `just codegen`).
- Only `lib/core/env.dart` calls `String.fromEnvironment`. Defines are compiled in: never secrets.
- Functions and `build` ≤ 40 lines, ≤ 4 positional params; extract a widget class instead of a `_buildX()` helper. Closed sets are `sealed` + exhaustive `switch`; no `is`/`runtimeType` ladders. `const` wherever possible; no `dynamic` outside commented JSON boundaries; no `!` without a comment.

Product rules:

- UI uses only album tokens (`lib/core/theme/album_theme.dart`). `test/architecture/no_hardcoded_colors_test.dart` fails on `Color(0x`/`Colors.` elsewhere; its skip list only shrinks.
- Components come from forui (`albumForuiTheme()`); Material only where forui has none.
- No new user-facing copy, theme token, `AppErrorCode`, dependency, feature, screen, endpoint or table without Bill. Pin majors; no drive-by upgrades.

Typed errors:

- Server failures are `AppException` + `AppErrorCode` (`apps/server/lib/src/models/app_error_code.spy.yaml`, shorthands in `apps/server/lib/src/errors.dart`). Never throw a `String`, number, `Map` or bare `Exception(...)`. `Error` subclasses are for programmer bugs only; never catch one to choose behaviour.
- Catch by type (`on AppException catch (e)`). A bare `catch (e)` only at a boundary that maps and shows, or rethrows. Never `catch (_) {}`. Never branch on error text; branch on type or `AppErrorCode`.
- Server errors become client errors only in `lib/core/data/server/server_errors.dart` (`withServerErrors`): the client `AppException`/`AppErrorCode` in `lib/core/domain/app_exception.dart`, or `StorageFailedException` for refused uploads. Repositories wrap calls in it, let the result pass through, and never turn a failure into null/false/empty, except documented not-found-equals-unreadable methods. Widgets show `appErrorMessage(error)` or existing copy. A failure that does not map is a stop-and-report to Bill; no new error type or enum.
- Every new `AppException` throw has a test asserting its `AppErrorCode`.

Server (`apps/server`):

- Models change only in `lib/src/models/*.spy.yaml` (DTOs in `models/dto/`), then `just server-generate`. A schema change gets `just server-migration <tag>`; never edit an existing migration or `lib/src/generated/`.
- Endpoints in `lib/src/endpoints/`, domain rules in `lib/src/<domain>/`. Every endpoint method sets `requireLogin => true` and calls `Authz` (`lib/src/authz/authz.dart`) before touching data; the only exception is `InvitePublicEndpoint.preview`. Derive the caller from the session and rights from the database; never trust client-sent user/family ids, roles or storage paths. Storage keys are built server-side (`lib/src/media/blob_keys.dart`).
- GCS stays private: signed PUT only after `Authz` via `session.storage.createUploadDescription`; reads only through `MediaEndpoint.get`/`getMany`. Detail and the avatar/person-picture exception in `.context/engineering-guide.md#server`.
- Messages never carry raw database text, reveal the required role, or reveal whether a hidden row exists: use `forbidden()` copy or the documented not-leak shape.
- No direct database or GCS access from outside `apps/server`.

Tests:

- TDD: failing test first, then code; tests ship with the code. Assert observable behaviour (finders, text, return values, `AppErrorCode`).
- Never delete, skip, weaken or re-tag a test out of `just test`; adapt the harness. `just test` makes no network calls.

## Safety

Do not read or copy `.env`, `.env.*` (except `.env.example`), `.secrets`, `*.pem`, `*.key`, `*.p8`, `*.p12`, signing keys/keystores, cloud credentials, `infra/params/*.local.json`, or `apps/server/config/passwords.yaml` (from `just server-passwords`, git-ignored). No secrets in code, docs or chat. Full list in `.context/engineering-guide.md#safety-do-not-read`.

Off limits unless Bill asks: production or hosted config (web and server hosting, DNS, mail provider keys) and the deploy recipes `just gcp-bootstrap`, `just gcp-infra`, `just deploy-server`, `just deploy-web` (README "Deployment"). No direct push or merge to `main`.

Search scope, settings, commit style and scratch files live in `.context/engineering-guide.md`.

## MCP Servers

None configured in this repo (no `.mcp.json`, `.cursor/mcp.json`, `.vscode/mcp.json` or `.codex/config.toml`).

## Skills

Read `.cursor/skills/<name>/SKILL.md` before the work it covers:

| When | Skill |
|---|---|
| Bug fix | `tdd-bug-fix` and `fix-root-causes` |
| Any change with tests | `test-behavior-not-implementation` |
| Validation, errors, adapters, or endpoints | `boundary-discipline` |
| Before declaring work done or opening a PR | `prove-it-works` |

## Where To Edit

| Path | Owns |
|---|---|
| `apps/tell_me_a_story/lib/features/<f>/` | Feature code: `data/` (feature-only `Server<X>Repository`), `domain/` (freezed models, repository interfaces + providers), `presentation/` (screens, widgets, notifiers). |
| `apps/tell_me_a_story/lib/core/` | Shared code: env, router, theme, server client/session, shared domain/data, session notifiers, shared widgets. |
| `apps/tell_me_a_story/lib/main.dart` + `lib/app.dart` | Bootstrap, provider overrides, `MaterialApp.router`. |
| `apps/tell_me_a_story/test/` + `integration_test/` | Unit/widget tests (`test/support/pump_app.dart`, fakes in `test/support/fakes/`), goldens, live tests, e2e flows (`integration_test/flows.md`). |
| `apps/tell_me_a_story/pubspec.yaml`, `analysis_options.yaml` | Client dependencies; analyzer modes and lints. |
| `apps/server/lib/src/` | Endpoints, domain rules, `*.spy.yaml` models; `migrations/` via `just server-migration`. |
| `packages/tell_me_a_story_client/` | Generated; never edit. |
| `infra/gcp/` | Terraform + bootstrap; applied only when Bill asks. |
| `justfile` + `mise.toml` | Recipes and pinned tools. |
| `.context/` | Durable architecture, decisions, active docs. Update when shape changes. |
| `AGENTS.md` | This file. Keep compact; push detail into `.context/`. |

## Maintenance

Update Commands here when `justfile` recipes, `mise.toml` tools or `pubspec.yaml` dependencies change. Update `.context/` when architecture, integrations, or durable decisions shift. Track in-flight work in a dated `.context/active/` doc; delete it when the work lands. No nested `AGENTS.md`, `CLAUDE.md` or `.cursorrules`.
