# Tell Me a Story

Private family storytelling app (Mortang): a Flutter client for iPad and web on a Serverpod (Dart) server with PostgreSQL.

## Layout

- `apps/tell_me_a_story/`: Flutter client.
  - `lib/core`: config, server connection, router, theme tokens.
  - `lib/data`: one gateway per backend area (models, `XGateway`, `XApi` on the generated client).
  - `lib/features/<feature>`: screens.
  - Tests: `test/` (unit and widget), `test/live` (needs `just server`), `integration_test/` (e2e).
- `apps/server/`: Serverpod 4.1.1 server.
  - Endpoints: `lib/src/endpoints`.
  - Rules: `lib/src/<domain>`.
  - Models: `lib/src/models/*.spy.yaml`.
  - Migrations: `migrations/`.
  - Tests: `test/unit`, `test/integration`.
- `packages/tell_me_a_story_client/`: generated client (`just server-generate`); never edit by hand.
- `docs/`: `superpowers/plans/` holds current plans; `archive/` holds history.

## Setup

Needs [mise](https://mise.jdx.dev). From the repo root:

```bash
mise install            # Flutter 3.47.7 and just 1.46.0 from mise.toml
just server-setup       # serverpod_cli 4.1.1, server and client packages, local passwords
(cd apps/tell_me_a_story && flutter pub get)
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

## Tests and gates

```bash
just check       # fmt-check, analyze (ceiling 6), test, server-analyze, server-test
just test        # app unit and widget tests (includes the e2e flow manifest check)
just server-test # server unit and integration tests (embedded Postgres)
just test-live   # app gateways against a running `just server`
```

End-to-end tests: start `just server`, start a `chromedriver --port=4444` that matches your Chrome, then:

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

Deployment: see the GCP hosting work (pending).
