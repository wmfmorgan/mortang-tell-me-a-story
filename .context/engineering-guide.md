# Engineering Guide

Operational standards for working in this repo. Read before changing code. Gates and baselines live in [`AGENTS.md#gates`](../AGENTS.md#gates).

## Commands

Tools are pinned in `mise.toml` (`flutter` 3.47.7, which bundles Dart; `just` 1.46.0; `terraform` 1.14.5 for deploys). Run `mise install` once, then `just server-setup`. Run recipes from the repo root as `mise exec -- just <recipe>` (or plain `just` in a shell with mise activated). Recipes live in `justfile`; app recipes `cd apps/tell_me_a_story`, server recipes `cd apps/server`.

| Command | Scope |
|---|---|
| `just` | List recipes. |
| `just setup` | Install pinned tools from `mise.toml`. (`mise install`) |
| `just codegen` | Generate `*.g.dart` / `*.freezed.dart` in the app (freezed, riverpod_generator, json_serializable). Outputs are gitignored. (`dart run build_runner build --delete-conflicting-outputs`) |
| `just run` (alias `just web`) | Web-server on 127.0.0.1:3000 against `http://127.0.0.1:8080`; passes `SERVER_URL`, `INVITE_APP_ORIGIN` and, when set, `MAPBOX_ACCESS_TOKEN` as `--dart-define`s. Runs codegen first. |
| `just test` | App unit + widget tests, `--exclude-tags golden`. Includes `test/architecture/`; skips `test/live` (tag `live`) and `integration_test/`. Runs codegen first. |
| `just test-live` | `test/live` (tag `live`, `--run-skipped`) against a running `just server`. Runs codegen first. |
| `just test-goldens [--update-goldens]` | `test/goldens` (tag `golden`), macOS only. Runs codegen first. |
| `just analyze [ceiling]` | `flutter analyze` in the app: any error fails; at most `ceiling` (default `0`) other issues. Runs codegen first. This is the type checker; there is no separate typecheck. |
| `just fmt-check` | `dart format` check: app `lib`, `test`, `integration_test`, `test_driver` (generated files excluded) and `apps/server`. The generated client package is not checked. |
| `just server-setup` | Activate `serverpod_cli` 4.1.1, `pub get` server and client packages, create local passwords if missing. |
| `just server-passwords` | Write git-ignored `apps/server/config/passwords.yaml` with random development/test secrets (no-op if it exists). |
| `just server-generate` | Regenerate server protocol, client package and test tools after model/endpoint changes. |
| `just server-migration <tag>` | Create a migration from model changes. |
| `just server` | API on :8080 with embedded Postgres, migrations applied; local sign-in code is `111111`. |
| `just server-test` | Server unit + integration tests (`apps/server/test/unit`, `test/integration`) on embedded Postgres. |
| `just server-analyze` | `dart analyze --fatal-infos` in `apps/server`; any issue fails. |
| `just check` | fmt-check + analyze + test + server-analyze + server-test. Does not run goldens, live tests or e2e. |
| `just gcp-bootstrap`, `just gcp-infra`, `just deploy-server`, `just deploy-web` | GCP bootstrap, Terraform apply, Cloud Run and Firebase Hosting deploys. Only when Bill asks. |

e2e (not a recipe): start `just server` and a `chromedriver --port=4444` matching your Chrome, then from `apps/tell_me_a_story` run `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/e2e_test.dart -d web-server --web-port=3000 --web-hostname=127.0.0.1 --browser-name=chrome --driver-port=4444 --dart-define=SERVER_URL=http://127.0.0.1:8080` (README "Tests and gates"). Run codegen first. CI runs it in the `e2e` job.

State command scope exactly. Do not say "all tests pass" unless the commands you ran cover every suite: `just check` skips goldens, live tests and e2e.

## Dart

`apps/tell_me_a_story/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  exclude:
    - build/**
    - ios/**
    - web/**
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    always_use_package_imports: true
    prefer_const_constructors: true
    prefer_final_locals: true
    always_declare_return_types: true
    avoid_dynamic_calls: true
```

- Sound null safety. No `dynamic` except at isolated, commented JSON boundaries. No `!` without a one-line comment saying why it is non-null; prefer pattern matching or local promotion.
- Prefer `final` locals and fields. Mutable shared state belongs in notifiers, not in widgets or top-level variables.
- Model closed state sets as `sealed` classes and handle them with exhaustive `switch` expressions. No `is`/`runtimeType` ladders or string-keyed `if` chains.
- Functions and `build` methods ≤ 40 lines; ≤ 4 positional parameters, named past that.
- One public top-level type per file, file named after it in snake_case (generated code and `*.spy.yaml` exempt).
- Package imports only (`package:tell_me_a_story/...`).
- Parse unknown JSON at the data boundary into typed models, then trust the typed value internally.

## Flutter Patterns

- Widgets small and single-purpose: `StatelessWidget` or `ConsumerWidget` by default.
- `const` constructors wherever possible so the framework can skip rebuilds.
- Extract a private widget class instead of a `Widget _buildX()` helper method.
- Async surfaces render loading / data / error explicitly via `AsyncValue.when`. The error branch shows the mapped message (`appErrorMessage(error)` or existing copy); never swallow failures.
- Theme: colours, radii, spacing, breakpoints and text roles come only from album tokens in `lib/core/theme/album_theme.dart` (`albumTheme()`); components come from forui themed by `albumForuiTheme()` (`lib/core/theme/album_forui_theme.dart`), Material only where forui has none. `MaterialApp.router` uses `builder: albumAppBuilder`. No `ColorScheme.fromSeed`. `Color(0x` and `Colors.` outside `album_theme.dart` fail `test/architecture/no_hardcoded_colors_test.dart`; its skip list names files by exact path from `lib/` and only shrinks.
- Navigation only through `go_router` (`context.go` / `context.push`). The route table and `appRouterProvider` live in `lib/core/router/app_router.dart`, paths in `lib/core/router/app_routes.dart`.
- Interactive widgets carry a kebab-case `Key('<feature>-<thing>')` (e.g. `Key('timeline-filters-open')`). Tests and e2e find widgets by these keys; never rename one in passing.

## State Management

Riverpod 3 with codegen (`riverpod_generator`).

- `@riverpod` functions (family by id) for derived or async reads.
- `@riverpod class X extends _$X` notifiers (`AsyncNotifier`) for mutable or async state.
- Widgets that read app data are `ConsumerWidget` / `ConsumerStatefulWidget`: `ref.watch` in `build`, `ref.read` in callbacks.
- Repositories: `abstract interface class XRepository` plus its provider in `domain/x_repository.dart`:
  `@Riverpod(keepAlive: true) XRepository xRepository(Ref ref) => throw UnimplementedError('Overridden in main.dart');`
  The implementation `class ServerXRepository implements XRepository` lives in `data/server_x_repository.dart`. `lib/main.dart` overrides each provider (`xRepositoryProvider.overrideWithValue(ServerXRepository())`); tests override with fakes.
- Widgets never construct repositories or receive them through constructors.
- Shared keepAlive session state (family selection, profile session, auth refresh, timeline live) lives in `lib/core/session/`.
- No global singletons. `setState` only for state local to one widget (text controllers, animation, hover, expanded/collapsed, form fields).

## Code Generation

- Deps: `build_runner`, `freezed` + `freezed_annotation`, `json_serializable` + `json_annotation`, `riverpod_generator` + `riverpod_annotation` (+ `flutter_riverpod`).
- Every annotated file declares its parts: `part 'x.g.dart';` and/or `part 'x.freezed.dart';`.
- Models are immutable `@freezed` classes in `domain/`, one public model per file named after it. Custom getters/methods via `const X._();`, defaults via `@Default`. Enums stay Dart enums.
- `json_serializable` only where the app parses JSON itself (Mapbox search). Serverpod wire mapping stays in named mapping functions in `lib/core/data/server/wire.dart` or the repository.
- Generated `*.g.dart` / `*.freezed.dart` are gitignored and rebuilt by `just codegen` (automatic before `analyze`, `test`, `test-goldens`, `test-live`, `run`, `deploy-web`). Never hand-edit them; change the source and regenerate.
- Serverpod output is separate: `apps/server/lib/src/generated/` and `packages/tell_me_a_story_client/` come from `just server-generate`, are committed, and are never hand-edited.

## Testing

- `test/` mirrors `lib/` exactly (`test/architecture/test_layout_test.dart`); move tests with their sources.
- TDD: write the failing test, make it pass, then refactor green. Tests ship with the code they cover.
- Widget tests pump through `test/support/pump_app.dart` (`pumpApp(tester, child, {overrides, router, ...})`), which wraps `ProviderScope(overrides:)` and `MaterialApp(theme: albumTheme(), builder: albumAppBuilder, ...)`.
- Override repository providers with fakes from `test/support/fakes/` (`FakeXRepository` in `fake_x_repository.dart`, implementing the domain interface) or `mocktail` mocks. Prefer the shared fakes.
- Provider unit tests use `ProviderContainer` with `addTearDown(container.dispose)`.
- Assert what a user or caller observes: finders and text, return values, `AppErrorCode`. Never assert on private members. Every new `AppException` throw has a test asserting its code.
- `just test` makes no network calls. Live tests live in `test/live` (tag `live`) and need `just server`.
- Goldens live in `test/goldens` (tag `golden`, own `flutter_test_config.dart`), run only via `just test-goldens` on macOS, and are excluded from `just test` and CI. Run them for UI, theme or golden changes; regenerate only on purpose (`just test-goldens --update-goldens`) and open every changed PNG.
- e2e flows live in `integration_test/e2e_test.dart` and are listed in `integration_test/flows.md`; `test/architecture/e2e_flow_manifest_test.dart` fails if they disagree. Baseline 9/9.
- Never delete, skip, weaken or re-tag a test out of `just test`; adapt its harness. Keys, finders and expectations stay. The test count never drops.

## Boundaries

Client (`apps/tell_me_a_story/lib/`), guarded by `test/architecture/import_boundaries_test.dart`:

- `presentation/` never imports any `data/` folder; it reads repositories only through providers in `domain/`.
- A feature never imports another feature's `data/`. It may import another feature's `presentation/` (screens it opens) or `domain/`.
- Code used by 2+ features lives in `lib/core/`. Feature-only data: `auth` (OTP sign-in), `family` (family covers, recovery window), `search` (search repository, search recents).
- The Serverpod client and session live in `lib/core/server/`; repositories in `data/` own every server call and return domain models.
- HTTP: the generated Serverpod client for the API; `package:http` only for Mapbox (`lib/core/data/mapbox_search_repository.dart`).
- Repositories wrap server calls in `withServerErrors` (`lib/core/data/server/server_errors.dart`), the only place server errors become client `AppException` / `StorageFailedException`. They let those pass through and never turn a failure into null/false/empty, except documented not-found-equals-unreadable methods.

Generated code (`packages/tell_me_a_story_client/`, `apps/server/lib/src/generated/`, `*.g.dart`, `*.freezed.dart`) is never hand-edited. Shared schema, endpoint and client changes are contract work: regenerate and update every consumer together.

## Server

- Models change only in `apps/server/lib/src/models/*.spy.yaml` (DTOs in `models/dto/`), then `just server-generate`. A schema change gets `just server-migration <tag>` (writes `apps/server/migrations/`). Never edit an existing migration.
- Endpoints in `lib/src/endpoints/`, domain rules in `lib/src/<domain>/`. Server layer imports are convention only; there is no server import-boundary test.
- Every endpoint method authenticates and calls `Authz` (`lib/src/authz/authz.dart`) before it touches data, with `requireLogin => true`. Derive the caller from `session.authenticated` (`Authz.userId`, `requireUser()`) and family, tree and story rights from the database through `Authz`. Never trust a client-sent user id, permission family id, role or storage path.
- Storage keys are built on the server (`lib/src/media/blob_keys.dart`); never parse a key the client sends. `MediaEndpoint` resolves each key to its holding row, then checks `Authz`.
- GCS stays private. Issue a signed PUT only after `Authz`, through `session.storage.createUploadDescription` (`PhotoEndpoint.startUpload`, `FamilyEndpoint.startCoverUpload`). Read blobs only through `MediaEndpoint.get` / `getMany`; unknown, unreadable and missing blobs all look the same (null or omitted). The only upload exception: `ProfileEndpoint.saveAvatar` and `PeopleEndpoint` person pictures store JPEG bytes with `session.storage.storeFile` after `Authz`, still with a server-built key and read through `media.get`. No second upload path.
- `InvitePublicEndpoint.preview` is the only `requireLogin => false` method and does not call `Authz`. Unknown, deleted, accepted, revoked and expired tokens all return `valid: false` with no family and no inviter.
- Throw `AppException` with an `AppErrorCode` (`lib/src/models/app_error_code.spy.yaml`, shorthands in `lib/src/errors.dart`). Messages are user-facing copy: no raw database text, no hint of the required role or of whether a hidden row exists. New code uses the default `forbidden()` copy ("You don't have access to that.") or the method's documented not-leak shape (empty list, null, or `notFound` for both missing and unreadable). The older role-named messages (`member only`, `owner or co-owner only`, `owner only` in `authz.dart`, plus `LiveEndpoint.watchFamily`, `LiveEndpoint.watchTree`, `FamilyEndpoint.detail`, `FamilyEndpoint.recover`, and `PeopleEndpoint.delete` for a missing person) stay; rewriting them is a security-copy change for Bill.
- No direct database or GCS access from outside `apps/server`.

## Devcontainer

`.devcontainer/devcontainer.json` installs mise and the pinned tools (`flutter`, `just`, `terraform`). Then run `just server-setup`. It covers codegen, analyze, `just test`, `just server`/`just server-test` (embedded Postgres, as in CI on Ubuntu) and web. iPad builds, the iOS simulator and goldens (`just test-goldens`) need macOS on the host. Port 8080 (the `just server` API) is forwarded; forward 3000 to preview `just run` from the host browser.

## Search Scope

When grepping, finding, or reading within the repo, exclude dependency, cache, generated, and build output. They pollute results, slow `find`, and hold no source-of-truth content.

- `.dart_tool/`
- `build/`
- `.pub-cache/`, `ios/Pods/`, `ios/.symlinks/`
- `.flutter-plugins*`
- `coverage/`
- `*.g.dart`, `*.freezed.dart`
- `apps/server/lib/src/generated/` and `packages/tell_me_a_story_client/` (generated; read for signatures, never edit)

```bash
rg --hidden -g '!{.dart_tool,build,ios/Pods,ios/.symlinks,coverage}/**' -g '!*.{g,freezed}.dart' -g '!.flutter-plugins*' '<pattern>'
```

Metadata reads are fine when the file itself is the source of truth: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `justfile`, `mise.toml`.

## Settings

`lib/core/env.dart` is the only file in `lib/` that calls `String.fromEnvironment`. Everything else reads `Env`.

| Define | Required | Use |
|---|---|---|
| `SERVER_URL` | yes | Serverpod API, absolute http(s) URL. `Env.validate()` fails closed at startup when missing or invalid. |
| `INVITE_APP_ORIGIN` | no (default `http://127.0.0.1:3000`) | Origin for shareable invite links. |
| `MAPBOX_ACCESS_TOKEN` | no | Public Mapbox token for geocoding and basemap. Missing or placeholder (`Env.hasMapboxToken` false) shows the place-picker failure UX instead of crashing. |

Rules:

- Declarations are `const`; non-const `String.fromEnvironment` calls return the default at runtime.
- Values come from `--dart-define`s: `just run` (local), `just deploy-web` (production; Mapbox token from `$MAPBOX_ACCESS_TOKEN` or the `story-line-mapbox-token` secret) and the `flutter drive` command. There is no `env.json`.
- Values are compiled into the app binary and can be extracted. Never put secrets there; secrets stay server-side.
- New define: extend `Env`, pass it in every recipe that builds the app, and document it in README "Run locally".
- Tests read `Env` defaults or override the providers that consume it. Test-only `LIVE_SERVER_URL` (default `http://127.0.0.1:8080`) is read in `test/live/support/live_server.dart`.
- Server config comes from Serverpod's `apps/server/config/*.yaml` and the git-ignored `config/passwords.yaml` (`just server-passwords`).

## Safety: Do Not Read

- `.env`, `.env.*` (except `.env.example`)
- `.secrets/`, `secrets.toml`, `.envrc`
- `apps/server/config/passwords.yaml`
- `infra/params/*.local.json`, Terraform state (`infra/gcp/*.tfstate*`)
- `*.pem`, `*.key`, `*.p8`, `*.p12`, `*.pfx`, copied certs
- Signing material: `*.jks`, `*.keystore`, `*.mobileprovision`
- Cloud credential files (`~/.config/gcloud`, service account JSON, `service-role*`)
- Local DSNs, connection strings, bearer headers checked in by accident
- Tokens, API keys (Resend, Mapbox secret), session cookies pasted into commits
- Raw provider payload dumps and responses that contain user data

Metadata reads are fine: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `justfile`, `mise.toml`.

Generated or local artifacts are never edited by hand: `build/`, `coverage/`, `.dart_tool/`, `*.g.dart`, `*.freezed.dart`, `apps/server/lib/src/generated/`, `packages/tell_me_a_story_client/`.

Off limits unless Bill asks: production or hosted config (web and server hosting, DNS, mail provider keys) and `just gcp-bootstrap`, `just gcp-infra`, `just deploy-server`, `just deploy-web`. Preserve unrelated dirty work: never revert files you did not intentionally change.

## Commits

- **One concern per commit.** Do not bundle a refactor with a feature with a dep bump.
- **Subject <= 72 chars, imperative mood.** Conventional prefix when useful (`feat:`, `fix:`, `chore:`, `refactor:`, `docs:`).
- **Body explains *why*, not *what*.** The diff shows what.
- **`pubspec.lock` commits with the `pubspec.yaml` change** that triggered it. New or changed dependencies need Bill's approval; pin majors, no drive-by upgrades.
- **Serverpod output rides with its source.** `just server-generate` output and new migrations commit with the `*.spy.yaml` or endpoint change.
- **Never commit `*.g.dart` / `*.freezed.dart`.**
- **Never commit secrets.** Real tokens, DSNs, bearer headers, cloud credentials, `passwords.yaml`.
- **No direct push or merge to `main`.**
- **Preserve unrelated dirty work.** Never restage or revert files you did not intentionally touch.

## Local Agent Scratch

Agents drop transient working files at repo root while in the middle of a task: `PLAN.md`, `NOTES.md`, `SCRATCH.md` and the to-do list file. These reflect one session's in-flight reasoning. They are not durable design docs and should not enter git; all four are listed under `# Local agent scratch` in `.gitignore`.

- `AGENTS.md` is **durable** and stays committed. It is the canonical entrypoint, not scratch - do not add it to `.gitignore`.
- Durable architecture, decisions, and short-lived focus notes belong in `.context/` (committed). Scratch belongs at root (ignored).
- A plan worth keeping graduates into a dated design doc under `.context/active/` (see `.context/README.md`) or into the PR description before the scratch file is discarded. Do not park it in a root scratch file.

## Context Maintenance

- Keep `AGENTS.md` compact. Push detail into these files.
- Update `Commands` (here and in `AGENTS.md`) when `justfile` recipes, `mise.toml` tools or `pubspec.yaml` dependencies change.
- Update `.context/project-context.md` when architecture, integrations, or ownership shift.
- Record durable decisions in `.context/project-context.md`.
- In-flight specs, DDs, and TDDs live in `.context/active/`; see `.context/writing-specs.md#lifecycle` for naming and lifecycle.
- `docs/` is stale history; never update it to describe current behaviour.
