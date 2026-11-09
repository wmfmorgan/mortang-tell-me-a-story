# Project Context

Generated: 2026-11-09

## What This Repo Is

mortang-tell-me-a-story: Mortang, a private family storytelling app ("Tell Me a Story"). The client is Flutter (iPad-first, plus web); the server is Serverpod 4.1.1 on PostgreSQL.

Family members capture stories (timeframe, people, place, text, photos), keep them as private drafts, and publish them to a family timeline that branches across family units in one tree. Members add comments and perspectives, invite relatives by email or link, and search by person, place and timeframe. The repo owns the app, the API, the schema and the GCP infrastructure. The value to preserve is a warm, private memory album, never a cold SaaS tool.

## Architecture

```text
Flutter client (apps/tell_me_a_story) -> generated client (packages/tell_me_a_story_client) -> Serverpod endpoints (apps/server/lib/src/endpoints) -> domain rules (apps/server/lib/src/<domain>) -> Postgres + cloud storage
```

- Client `lib/` layers: `app/` (router, composition root), `core/` (config, routes, server connection, theme tokens), `data/` (gateways, session), `ui/` (shared widgets), `features/<feature>/` (screens). Import rules are enforced by `test/architecture/import_boundaries_test.dart`.
- Server: endpoints call domain rules (`Authz`, per-domain modules); models live in `lib/src/models/*.spy.yaml`; errors are `AppException` with an `AppErrorCode`, mapped on the client in `lib/data/server/server_errors.dart`.
- Live updates use Serverpod streams; purge and blob-drain run as future calls over a `blob_deletions` outbox.

## Ownership Map

| Path | Package | Purpose |
|------|---------|---------|
| `apps/tell_me_a_story/` | `tell_me_a_story` | Flutter client (iPad + web), tests, goldens, e2e (`integration_test/`). |
| `apps/server/` | server | Serverpod 4.1.1 API, domain rules, models, migrations. |
| `packages/tell_me_a_story_client/` | `tell_me_a_story_client` | Generated Serverpod client; never edit by hand. |
| `infra/gcp/` | - | Terraform and bootstrap for the GCP project `story-line-app`. |
| `docs/` | - | Stale history only (`docs/archive/`). |

## External Integrations

- Google Cloud project `story-line-app`: API on Cloud Run, Postgres on Cloud SQL, photos/covers/avatars in a private Cloud Storage bucket, images via Cloud Build / Artifact Registry, Terraform state bucket.
- Firebase Hosting for the web app.
- Resend for email (sign-in codes, invites): `RESEND_API_KEY`, `RESEND_FROM`.
- Mapbox for the place picker: `MAPBOX_ACCESS_TOKEN` (dart-define), Secret Manager secret `story-line-mapbox-token`.
- Local dev: embedded Postgres via `just server`; secrets in git-ignored `apps/server/config/passwords.yaml` from `just server-passwords`.

## Durable Decisions

Architecture and tooling choices worth keeping, stated as decisions - not status or progress. No dates, milestones, or task tracking (those live in `.context/active/` docs or an external tracker).

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

- No account deletion UI (D7); no unpublish (D12).
- No public multi-family sharing, AI-written stories, genealogy-tree-first UX, live chat or DNA (uxd-handoff anchors).
- No server-sent SMS invites (deferred).
- No timeline playback, hide-mode filters, zoom canvas/swimlanes, or tree graph Time mode (Phase 7 out of scope).
- No tree-wide server search or facets, paging, or kinships (G4-G6).
