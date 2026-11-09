# Engineering Guide

Generated: 2026-11-09

## Commands

Tools are pinned in `mise.toml`; run recipes from the repo root as `mise exec -- just <recipe>`. Gates and baselines: see [`AGENTS.md#gates`](../AGENTS.md#gates) (not copied here).

- `just` / `just default` - list recipes.
- `just setup` - install pinned tools from `mise.toml`.
- `just test` - flutter test in `apps/tell_me_a_story` (goldens excluded: they are macOS-only).
- `just test-live` - live client tests against a running `just server`.
- `just test-goldens [--update-goldens]` - golden tests, macOS only.
- `just run` (alias `just web`) - Flutter web-server on 127.0.0.1:3000 (`MAPBOX_ACCESS_TOKEN=pk... just run`).
- `just server-setup` - install serverpod_cli 4.1.1, fetch server/client packages, create local passwords if missing.
- `just server-passwords` - write `apps/server/config/passwords.yaml` with random dev/test secrets (no-op if it exists).
- `just server-generate` - regenerate server protocol, client package and test tools after model/endpoint changes.
- `just server-migration <tag>` - create a migration from model changes.
- `just server` - run the API on :8080 (embedded Postgres, migrations applied, login code 111111).
- `just server-test` - backend integration tests (embedded Postgres).
- `just fmt-check` - dart format check for app and server (generated client not checked).
- `just analyze [ceiling]` - flutter analyze in the app; any error fails, at most `ceiling` (default 6) other issues.
- `just server-analyze` - dart analyze in `apps/server`; any issue fails.
- `just check` - every local gate: fmt-check, analyze, test, server-analyze, server-test.
- `just gcp-bootstrap`, `just gcp-infra`, `just deploy-server`, `just deploy-web` - GCP bootstrap, Terraform, Cloud Run and Firebase deploys; owner-requested only.

Command scope rule: cite exact scope only. Do not claim a command runs every test or builds every package unless scripts prove it.

## Dart / Flutter

- `lib/` layers (per `AGENTS.md` "Code rules"): `app/` may import anything; `core/` imports `core/`; `data/` imports `core/` and `data/`; `ui/` imports `core/`, `data/` and `ui/`; `features/<f>/` imports those plus lower-rank features (`featureRank` in `test/architecture/import_boundaries_test.dart`). Only `app/`, `main.dart`, `data/` and `core/server/` import the generated client or `serverpod*`.
- Colours, radii, spacing, breakpoints and text roles come only from `lib/core/theme/album_theme.dart` tokens; `Color(0x` and `Colors.` elsewhere fail `no_hardcoded_colors_test.dart`. Components come from forui themed by `albumForuiTheme()`.
- Interactive widgets carry a kebab-case `Key('<feature>-<thing>')` (e.g. `Key('timeline-filters-open')`); tests and e2e find widgets by these keys.
- Server errors are `AppException` + `AppErrorCode`; no swallowed errors.

## Testing Patterns

- `just test` is the default app test command; `just server-test` for the server.
- `test/` mirrors `lib/` (enforced by `test/architecture/test_layout_test.dart`); `test/architecture` holds the guards (import boundaries, colours, layout, e2e manifest).
- Shared gateway fakes live in `test/support/fakes`; prefer them over ad-hoc mocks.
- Goldens live in `test/goldens` (tag `golden`) and run only via `just test-goldens` on macOS; regenerate on purpose and open every changed PNG.
- e2e flows live in `integration_test/e2e_test.dart` and are listed in `integration_test/flows.md`; the manifest test fails if they disagree.
- Live client tests in `test/live` (tag `live`) need `just server`.

## Boundaries

- Keep external boundary parsing close to HTTP handlers, CLI args, env readers, file readers, queue consumers, and provider SDK wrappers.
- Keep business logic out of transport glue when practical.
- Keep generated API/types/codegen artifacts out of manual edits unless repo docs say otherwise.
- For monorepos, treat shared schema, public API, worker, runtime, and client changes as contract work. Update all consumers together.

## Search Scope

When grepping, finding, or reading within the repo, exclude dependency, cache, and build output. They pollute results, slow `find`, and hold no source-of-truth content.

- `.dart_tool/`
- `build/`
- `.pub-cache/`, `.symlinks/`
- `coverage/`
- `apps/server/lib/src/generated/` and `packages/tell_me_a_story_client/` (generated; read, never edit)

```bash
rg --hidden -g '!{.dart_tool,build,coverage}/**' '<pattern>'
```

Metadata reads inside excluded dirs are fine when the file itself is the source of truth (lockfiles, vendored manifests).

## Settings

Client config enters through `--dart-define` values read in `lib/core` config (`SERVER_URL`, `INVITE_APP_ORIGIN`, `MAPBOX_ACCESS_TOKEN`). Server config comes from Serverpod's `config/*.yaml` and the git-ignored `config/passwords.yaml`. Feature code never reads defines or env directly.

## Safety

- Do not read or copy `.env`.
- Do not read or copy `.env.* except .env.example`.
- Do not read or copy `.secrets`.
- Do not read or copy `*.pem`.
- Do not read or copy `*.key`.
- Do not read or copy `*.p12`.
- Do not read or copy `infra/params/*.local.json`.
- Do not read or copy `copied certs`.
- Do not read or copy `raw provider payload dumps`.

- Avoid editing generated/local artifacts: `dist`.
- Avoid editing generated/local artifacts: `build`.
- Avoid editing generated/local artifacts: `coverage`.
- Avoid editing generated/local artifacts: `node_modules`.
- Avoid editing generated/local artifacts: `.turbo`.
- Avoid editing generated/local artifacts: `.next`.
- Avoid editing generated/local artifacts: `.vite`.
- Avoid editing generated/local artifacts: `.cache`.
- Avoid editing generated/local artifacts: `out`.

- Use `.env.example` only for variable names when needed.
- Do not commit real tokens, bearer headers, database URLs, DSNs, AWS secrets, or local credential values.
- Preserve unrelated dirty work. Never revert files you did not intentionally change.

## Detected Configs

- `mise.toml`
- `justfile`

## Commits

- **One concern per commit.** Do not bundle a refactor with a feature with a dep bump.
- **Subject <= 72 chars, imperative mood.** Conventional prefix when useful (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`).
- **Body explains *why*, not *what*.** The diff shows what.
- **Generated artifacts ride with their source change.** Lockfile updates, codegen outputs, migration SQL - commit with the source edit that triggered them.
- **Never commit secrets.** Real tokens, DSNs, bearer headers, cloud credentials. `.env.example` is for variable names only.
- **Preserve unrelated dirty work.** Never restage or revert files you did not intentionally touch.

## Local Agent Scratch

Agents drop transient working files at repo root while in the middle of a task: `PLAN.md`, `NOTES.md`, `SCRATCH.md` and the to-do list file. These reflect one session's in-flight reasoning. They are not durable design docs and should not enter git; all four are listed under `# Local agent scratch` in `.gitignore`.

- `AGENTS.md` is **durable** and stays committed. It is the canonical entrypoint, not scratch - do not add it to `.gitignore`.
- Durable architecture, decisions, and caveats belong in `.context/` (committed). Scratch belongs at root (ignored).
- A plan worth keeping graduates into a dated design doc under `.context/active/` (see `.context/README.md`) or into the PR description before the scratch file is discarded. Do not park it in a root scratch file.

## Context Maintenance

- Keep `AGENTS.md` compact and operational.
- Put durable architecture, decisions, and caveats in `.context/` guides. Guides never hold progress or status - see `.context/README.md`.
- In-flight specs, DDs, and TDDs live in `.context/active/`. Naming and the delete-on-completion lifecycle are defined in `.context/writing-specs.md#lifecycle`. Never leave a finished active doc behind.
