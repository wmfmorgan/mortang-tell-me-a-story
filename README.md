# Tell Me a Story

Private family storytelling app (Mortang). Specs in Notion are law — see Impl Spec §0 / §15.

## Monorepo layout (repo map §3)

- `apps/tell_me_a_story/` — Flutter client (iOS/iPad + web)
  - `lib/core/` — env, supabase init, router
  - `lib/features/auth/` — magic-link entry
  - `lib/features/timeline/` — `/timeline` stub (post-auth redirect only)
  - `lib/data/` — empty scaffold (`.gitkeep`); no repositories in M1
- `supabase/` — migrations, config, RLS/pgTAP tests
- `docs/superpowers/plans/` — implementation plans

M2+ (family create, Edge invites, Mapbox, Flutter upload, product screens) is **not started**.

## Secrets (forbidden in git)

Inject via `--dart-define` / CI — **never commit**:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN` (M3+)

Edge-only (never in Flutter): `RESEND_API_KEY`, Supabase **service role**.

Do not commit `.env*`, service role keys, or Resend keys.

## Local data plane (M1 agent)

Local `supabase start` is the **agent data plane** for migrations, RLS tests, and magic-link verification.

Ports are remapped to **5732x** in `supabase/config.toml` (avoids collisions with default 5432x):

| Service | Port |
|---------|------|
| API / Project URL | `57321` |
| Postgres | `57322` |
| Studio | `57323` |
| Mailpit (magic-link inbox) | `57324` |
| Pooler | `57329` |
| Shadow DB | `57320` |
| Analytics | `57327` |

```bash
# From repo root
supabase start
supabase db reset
supabase status -o env   # copy API_URL / ANON_KEY for dart-define (do not commit)
```

**OPEN (Bill):** Cloud staging project + Email magic link enabled there. Local does **not** close First 10 #2 / §15 staging. Do **not** claim full §15 M1 complete until staging exists (or Bill waives in writing).

## Flutter run (dart-define example)

Auth `site_url` is pinned to **`http://127.0.0.1:3000`**. Serve the app on that port so magic-link `redirect_to` lands on a live origin.

### Recommended for magic-link testing: `web-server`

`flutter run -d chrome` ties the debug app to the Chrome window Flutter launched. Mailpit opens the verify redirect in a **new tab**, which loads the DWDS debug assets without that tooling connection and stays a **white blank page**. Use **`web-server`** so any tab can run the app:

```bash
# From repo root — copy real values (never paste literal "..." placeholders):
supabase status -o env | rg '^(API_URL|ANON_KEY)='

cd apps/tell_me_a_story

flutter run -d web-server --web-hostname=127.0.0.1 --web-port=3000 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:57321 \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0 \
  --dart-define=INVITE_APP_ORIGIN=http://127.0.0.1:3000
```

Local demo `ANON_KEY` above is the standard Supabase local key from `supabase status` (safe for local only). If your ports differ, use your `API_URL` / `ANON_KEY` from status.

`INVITE_APP_ORIGIN` defaults to `http://127.0.0.1:3000`. Invite links are `{INVITE_APP_ORIGIN}/timeline?invite=<token>`. Later MS: change only this define/env to the shareable host — do not invent a second invite system.

Then open **http://127.0.0.1:3000/** in Chrome yourself.

1. Enter email → **Send magic link**
2. Open Mailpit: http://127.0.0.1:57324  
3. Click the link (new tab is OK with `web-server`)
4. You should land on port **3000** with `?code=...`, then redirect to `/timeline`
5. On Timeline, **+ Invite** opens Email / Link modal (no SMS). Link copy / email send use locked toasts.

### Edge functions (M2 invites) — local only

```bash
# From repo root (Docker required)
supabase start
supabase functions serve --env-file supabase/.env.local
# Optional in .env.local (never commit secrets):
# INVITE_APP_ORIGIN=http://127.0.0.1:3000
# RESEND_API_KEY=...   # OPEN (Bill) — without it send-invite-email returns structured failure
```

Family create is **data/API** (`create_family` RPC) — no Create Family screen in M2. First invite may bootstrap a family via API when none exists. Joining is via invite accept on `/timeline?invite=`.

If you change Auth redirect settings in `supabase/config.toml`, restart local Supabase (`supabase stop && supabase start`).

### Troubleshooting

| Symptom | Cause | Fix |
|---------|--------|-----|
| “This site can’t be reached” | Nothing on port 3000 | Use `--web-port=3000` and confirm `supabase` + Flutter are running |
| White blank page after clicking the email link | Opened against `flutter run -d chrome` DWDS from a new tab | Switch to `-d web-server` as above; request a **new** magic link |
| Link works but stays signed out | PKCE code verifier missing / old link reused | Request OTP from the same origin (`127.0.0.1:3000`), click a fresh Mailpit message |

iOS sim: same dart-defines (`-d ios`). **OPEN (tooling):** full Xcode required for iOS compile; CLT-only machines can use `flutter test` + `flutter build web`.

## Tests

```bash
# From repo root — local Supabase must be running
supabase db reset
supabase test db

cd apps/tell_me_a_story && flutter test
```

## Auth chrome (M1)

- Signed-out → magic-link entry (`/`)
- Signed-in → `/timeline` stub
- Matches chrome locks redirects / no redesign

**OPEN (Mugatu):** exact auth chrome label strings; M1 uses minimal functional labels only.
