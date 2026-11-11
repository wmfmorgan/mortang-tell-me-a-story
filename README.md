# Tell Me a Story

Private family storytelling app (Mortang): a Flutter client for iPad and web on a Serverpod (Dart) server with PostgreSQL.

## Layout

- `apps/tell_me_a_story/`: Flutter client (iPad + web).
  - `lib/main.dart`: bootstrap and composition root (`ProviderScope` overrides every repository provider); `lib/app.dart`: app widget (`MaterialApp.router`).
  - `lib/core`: env, router, theme tokens, server connection, shared domain models and repositories, session state, and widgets used by several features (`core/widgets`).
  - `lib/features/<feature>/{data,domain,presentation}`: feature-only repositories, models and repository providers, and screens with their providers.
  - `test/` mirrors `lib/`; `test/architecture` holds the guards; `test/support/pump_app.dart` pumps widgets with provider overrides; `test/support/fakes` holds the shared repository fakes; `test/goldens` (tag `golden`, macOS only); `test/live` (tag `live`); `integration_test/` (e2e).
- `apps/server/`: Serverpod 4.1.1 server.
  - Endpoints: `lib/src/endpoints`.
  - Rules: `lib/src/<domain>`.
  - Models: `lib/src/models/*.spy.yaml`.
  - Migrations: `migrations/`.
  - Tests: `test/unit`, `test/integration`.
- `packages/tell_me_a_story_client/`: generated client (`just server-generate`); never edit by hand.
- `.context/`: agent context: `project-context.md` (purpose, architecture, durable decisions), `engineering-guide.md`, and in-flight specs/DDs/TDDs in `active/`.
- `docs/`: history only (stale).

## Setup

Needs [mise](https://mise.jdx.dev). From the repo root:

```bash
mise install            # Flutter 3.47.7, just 1.46.0 and Terraform 1.14.5 from mise.toml
just server-setup       # serverpod_cli 4.1.1, server and client packages, local passwords
(cd apps/tell_me_a_story && flutter pub get)
just codegen            # build_runner: freezed, riverpod_generator, json_serializable (outputs are gitignored)
```

Commands below assume mise is activated in your shell (`mise activate`); otherwise prefix each with `mise exec --`, e.g. `mise exec -- just check`.

`just server-passwords` writes `apps/server/config/passwords.yaml` with random local secrets. It is git-ignored; never commit it.

## Run locally

```bash
just server   # API on http://127.0.0.1:8080; embedded Postgres; migrations applied
just run      # web app on http://127.0.0.1:3000 (alias: just web)
```

Sign in with any email. A local server does not send mail: the sign-in code is always `111111`. For the map and place search, pass a public Mapbox token: `MAPBOX_ACCESS_TOKEN=pk... just run`.

App defines (`--dart-define`): `SERVER_URL` (required), `INVITE_APP_ORIGIN` (default `http://127.0.0.1:3000`), `MAPBOX_ACCESS_TOKEN` (optional).

## UI system

Tokens live in `apps/tell_me_a_story/lib/core/theme/album_theme.dart`. Components come from [forui](https://forui.dev), themed by `albumForuiTheme()` in `lib/core/theme/album_forui_theme.dart`. Shared app widgets live in `lib/core/widgets/`. The Material theme (`albumTheme()`) still styles screens not yet migrated.

## Tests and gates

```bash
just check       # fmt-check, analyze (ceiling 0), test, server-analyze, server-test
just codegen     # build_runner codegen; analyze, test, test-goldens, test-live and run run it first
just test        # app unit and widget tests (includes the e2e flow manifest check)
just server-test # server unit and integration tests (embedded Postgres)
just test-live   # app repositories against a running `just server`
just test-goldens   # golden images, macOS only; --update-goldens to regenerate
```

End-to-end tests: run `just codegen`, start `just server`, start a `chromedriver --port=4444` that matches your Chrome, then:

```bash
cd apps/tell_me_a_story
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/e2e_test.dart \
  -d web-server --web-port=3000 --web-hostname=127.0.0.1 \
  --browser-name=chrome --driver-port=4444 \
  --dart-define=SERVER_URL=http://127.0.0.1:8080
```

`integration_test/flows.md` lists the flows. `just test` fails if it and `e2e_test.dart` disagree.

## Server changes

Edit models in `apps/server/lib/src/models/*.spy.yaml` or endpoints, then:

```bash
just server-generate          # regenerates server protocol, client package, test tools
just server-migration <tag>   # only when the database schema changed
```

Never edit a migration that already exists.

## Deployment

Production runs on Google Cloud project `story-line-app` (`infra/gcp`): the API on Cloud Run, Postgres on Cloud SQL, photos, covers and avatars in a private Cloud Storage bucket, and the web app on Firebase Hosting (`https://story-line-app.web.app`).

Needs `terraform` (pinned in `mise.toml`), plus `gcloud` and `firebase` signed in to an account that may create projects and link billing (`gcloud auth login`, `gcloud auth application-default login`, `firebase login`). From the repo root:

```bash
# 1. Once: project, billing, APIs, Terraform state bucket, Resend secrets, Firebase
BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX RESEND_API_KEY=... \
  RESEND_FROM='Story Line <no-reply@your-domain>' just gcp-bootstrap
# 2. Infrastructure (Cloud SQL, Cloud Run service, bucket, secrets, IAM): terraform init + apply
just gcp-infra
# 3. Server: Cloud Build image tagged with the commit, rolled out to Cloud Run
just deploy-server
# 4. Web: Flutter release build against the Cloud Run API, deployed to Firebase Hosting
just deploy-web
```

`just deploy-server` refuses to run while `apps/server` has uncommitted changes. Steps 3 and 4 are the routine deploy; rerun step 2 after changing `infra/gcp`.

`just deploy-web` uses a public Mapbox token for the place picker: `MAPBOX_ACCESS_TOKEN` if that is set, and otherwise the Secret Manager secret `story-line-mapbox-token`. Without a token it deploys anyway, with a warning, and the place picker is off. Create the secret once with `printf %s 'pk…' | gcloud secrets create story-line-mapbox-token --data-file=- --project story-line-app`. In the Mapbox account, restrict the token's URLs to `https://story-line-app.web.app` and `https://story-line-app.firebaseapp.com`.
