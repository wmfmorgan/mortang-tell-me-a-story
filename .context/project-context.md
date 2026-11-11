# Project Context

Durable architecture and ownership. Update when the shape of the app changes, not on every commit.

## What This Repo Is

mortang-tell-me-a-story: Mortang, a private family storytelling app ("Tell Me a Story"). The client is Flutter (iPad-first, plus web); the server is Serverpod 4.1.1 on PostgreSQL.

Family members capture stories (timeframe, people, place, text, photos), keep them as private drafts, and publish them to a family timeline that branches across family units in one tree. Members add comments and perspectives, invite relatives by email or link, and search by person, place and timeframe. The repo owns the app, the API, the schema and the GCP infrastructure. The value to preserve is a warm, private memory album, never a cold SaaS tool.

## Architecture (Data Flow)

```
user interaction
  -> widget (ConsumerWidget, features/<f>/presentation or core/widgets)
  -> provider / notifier (riverpod_generator)
  -> repository interface (domain/) -> Server<X>Repository (data/)
  -> generated Serverpod client (packages/tell_me_a_story_client, via core/server)
  -> endpoint (apps/server/lib/src/endpoints) -> Authz + domain rules (apps/server/lib/src/<domain>)
  -> Postgres / private GCS bucket
  -> wire DTO -> freezed domain model (core/data/server/wire.dart or the repository)
  -> AsyncValue
  -> render loading / data / error (mapped AppException copy)
```

- Source of truth for UI state lives in the client (Riverpod providers; shared session state in `lib/core/session/`). Source of truth for domain data lives behind the API. The app keeps no domain state beyond what the current view needs.
- `lib/main.dart` is the composition root: it overrides every repository provider with its `Server<X>Repository`; tests override them with fakes.
- Server errors are `AppException` with an `AppErrorCode`; `withServerErrors` in `lib/core/data/server/server_errors.dart` turns them into the client `AppException` (`lib/core/domain/app_exception.dart`) or `StorageFailedException`.
- Live updates use Serverpod streams (`lib/core/session/timeline_live.dart` on the client); purge and blob-drain run as future calls over a `blob_deletions` outbox.

## Ownership Map

| Path | Owns |
|---|---|
| `apps/tell_me_a_story/` | Flutter client (iPad + web): `lib/`, tests, goldens, e2e (`integration_test/`). |
| `lib/main.dart` | Bootstrap: binding, URL strategy, `Env.validate()`, server init, `runApp(ProviderScope(overrides: [...], child: App()))`. Overrides every repository provider. |
| `lib/app.dart` | `App` (`ConsumerWidget`): `MaterialApp.router` with `albumTheme()`, `builder: albumAppBuilder`, forui localizations, router from `appRouterProvider`. |
| `lib/core/env.dart` | Compile-time env (`String.fromEnvironment`). Only file that reads it. |
| `lib/core/router/` | `app_router.dart` (go_router table, `appRouterProvider`), `app_routes.dart` (paths), `url_strategy_*.dart`. |
| `lib/core/theme/` | `album_theme.dart` (the only tokens), `album_forui_theme.dart` (forui skin, `albumAppBuilder`). |
| `lib/core/server/` | Serverpod client and auth session. |
| `lib/core/domain/` | Shared freezed models, `AppException`, shared repository interfaces + their providers. |
| `lib/core/data/` | Shared `Server<X>Repository` implementations; `server/` (wire mapping, `server_errors.dart`, media batches). |
| `lib/core/session/` | Shared keepAlive notifiers: family selection, profile session, auth refresh, timeline live. |
| `lib/core/widgets/` | Widgets used by 2+ features (`album/`, `avatar/`, `controls/`, `dialogs/`, `family/`, `navigation/`, `story/`, `timeline/`). |
| `lib/features/<f>/data/` | Repository implementations used only by `<f>` (`auth` OTP sign-in, `family` covers and recovery window, `search`). |
| `lib/features/<f>/domain/` | Models and repository interfaces/providers used only by `<f>`. |
| `lib/features/<f>/presentation/` | Screens, widgets, and that feature's notifiers/providers. |
| `test/` | Mirrors `lib/`. `architecture/` guards, `support/` (`pump_app.dart`, `fakes/`), `live/` (tag `live`), `goldens/` (tag `golden`, macOS). |
| `integration_test/` | e2e flows (`e2e_test.dart`) and manifest (`flows.md`). |
| `apps/server/` | Serverpod 4.1.1 API: `lib/src/endpoints`, domain rules `lib/src/<domain>`, models `lib/src/models/*.spy.yaml`, `migrations/`, tests `test/unit` + `test/integration`. |
| `packages/tell_me_a_story_client/` | Generated Serverpod client (`just server-generate`); never edit by hand. |
| `infra/gcp/` | Terraform and bootstrap for the GCP project `story-line-app`. |
| `justfile`, `mise.toml` | Recipes; pinned tools (Flutter, just, Terraform). |
| `.context/` | Agent-readable durable context and active docs. |
| `docs/` | Stale history only (`docs/archive/`). |
| `README.md` | Human-facing setup, run, tests and deployment. |

## External Integrations

- Google Cloud project `story-line-app`: API on Cloud Run, Postgres on Cloud SQL, photos/covers/avatars in a private Cloud Storage bucket, images via Cloud Build / Artifact Registry, Terraform state bucket. Credentials: the operator's `gcloud` login; nothing in the repo or app binary.
- Firebase Hosting for the web app (`https://story-line-app.web.app`).
- Resend for email (sign-in codes, invites): `RESEND_API_KEY`, `RESEND_FROM`, stored as server secrets by `just gcp-bootstrap`; never in the app.
- Mapbox for the place picker: public `MAPBOX_ACCESS_TOKEN` (dart-define, safe to compile in, URL-restricted in the Mapbox account), Secret Manager secret `story-line-mapbox-token` for `just deploy-web`.
- Local dev: embedded Postgres via `just server`; secrets in git-ignored `apps/server/config/passwords.yaml` from `just server-passwords`.

## Durable Decisions

Architecture and tooling choices worth keeping, stated as decisions - not status or progress. In-flight work and known gaps live in `.context/active/` docs, issues, or PRs, never here.

- Riverpod 3 with codegen is the state/DI layer; repositories are domain interfaces with providers overridden in `main.dart` (Bill, 2026-11-10) - one composition root, fakes override providers in tests.
- Models are immutable `freezed` classes in `domain/`; `json_serializable` only for JSON the app parses itself (Mapbox); Serverpod wire mapping stays in named functions - generated DTOs never leak into presentation.
- Client layout is `lib/core/` + `lib/features/<f>/{data,domain,presentation}`; shared code used by 2+ features lives in `lib/core` - presentation reaches data only through domain providers.
- Generated `*.g.dart` / `*.freezed.dart` are gitignored; `just codegen` rebuilds them (and runs before analyze, test, goldens, live tests and run) - no generated diffs in review.
- The app analyze ceiling is 0 under `strict-casts`, `strict-inference` and `strict-raw-types` - the type checker stays clean.
- Settings shows the email read-only; no change-email flow (D1) - dropped to keep sign-in identity simple.
- An invite with an email can only be accepted signed in as that email (trimmed, lowercased); link-only invites work for anyone holding them (D2) - binds invites to their recipient.
- Any live member can create and send invites; only owners/co-owners resend or revoke (D3) - open growth, controlled cleanup.
- Owners/co-owners can delete anyone's comments and perspectives on published stories in their family, never others' stories (D4) - moderation without erasing authorship.
- Only owners/co-owners of the person's live home family delete a person; a person linked to an account is never deleted (D5) - protects real members.
- Accepting an invite into a deleted family is refused with `inviteInvalid` (D6a); every write and member read requires a live family, owners/co-owners keep recovery reads (D6b) - soft delete really closes a family.
- Purge deletes every blob of the family and fails closed via the `blob_deletions` outbox (D6c) - no orphaned private photos.
- Creating a branch ensures the branch owner and picked members have a linked person in the tree (D6d) - branches stay connected to people.
- "Same tree" means equal `treeId` among live families (D8); `decade` precision stays dropped (D9).
- Only the owner of a linked person's live home family sets their death date; co-owners may toggle passed-away (D10).
- An upload for a story deleted before finish keeps its blob, no sweep (D11); email-code sign-up stores no display name, linked person falls back to the email local part (D13) - accepted trade-offs.
- Timeline keeps the Decades/Years/Days rails, restyled, no sliver rebuild (Q1); zoom ladder and branch callouts behave as locked in `docs/archive/ux/branch-callout.md`.
- Two whole-tree views ship: family tree graph (Family mode) and treemap with family/decade/person groupings (Q2, O5), reached from a family menu row opening `/family/:id/tree` (O1).
- No playback (Q3); timeline filters dim only, never hide, reusing All Stories matching (Q4); no filters on the tree views (O6).
- Visual system: continuous corners, the marker system, terracotta selected toggle (Q5); owner screenshots at 1280x800 and 744x1133 sign off UI changes before merge.
- Goldens are macOS-local, tagged `golden`, excluded from CI, run by `just test-goldens` (Q8).
- Timeline lab is deleted; no `labs/` package (O7). Approved copy C1-C19 is used verbatim (O2); token names from 7.2 approved (O3).
- Look: warm memory album, iPad-first, forms that breathe, large tap targets for elders - never cold SaaS (uxd-handoff anchors). Tokens follow DESIGN.md (parchment, terracotta, ink, sage; Newsreader headlines, Source Sans 3 labels) and live only in `album_theme.dart`.
- Search is full-screen from the header; invites use one modal with Email + Link only; drafts stay private until published (uxd-handoff locked UX).
- Comments (short) and perspectives (full alternate tellings) stay separate; anyone can attach pictures, the author edits core + pictures (uxd-handoff anchors).
- R2 shared header: wordmark, family menu (sets the family for the session), Timeline, Drafts, search chip, ink Invite, and New story as the only filled terracotta button (uxd-handoff R2).
- UI components come from forui (^0.27), skinned to the Memory Album tokens by `albumForuiTheme()`; Material stays only where forui has no equivalent.

## Non-Goals

- No secrets in the app binary.
- No direct database or GCS access from the client or anywhere outside `apps/server`.
- No global mutable state outside Riverpod.
- No account deletion UI (D7); no unpublish (D12).
- No public multi-family sharing, AI-written stories, genealogy-tree-first UX, live chat or DNA (uxd-handoff anchors).
- No server-sent SMS invites (deferred).
- No timeline playback, hide-mode filters, zoom canvas/swimlanes, or tree graph Time mode (Phase 7 out of scope).
- No tree-wide server search or facets, paging, or kinships (G4-G6).
