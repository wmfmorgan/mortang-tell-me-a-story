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

```bash
cd apps/tell_me_a_story

# Values from `supabase status -o env` — example local URL only:
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:57321 \
  --dart-define=SUPABASE_ANON_KEY=<anon-from-supabase-status>
```

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
