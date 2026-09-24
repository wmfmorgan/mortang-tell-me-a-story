# Tell Me a Story

Private family storytelling app (Mortang). Specs in Notion are law — see Impl Spec §0 / §15.

## Layout (locked)

- `apps/tell_me_a_story/` — Flutter client (iOS/iPad + web)
- `supabase/` — migrations, Edge Functions, RLS tests

## Secrets

Inject via `--dart-define` / CI (never commit):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN` (M3+)

Edge-only (never in Flutter): `RESEND_API_KEY`, Supabase service role.

## Local data plane (M1 agent)

```bash
supabase start
supabase db reset
```

**OPEN (Bill):** Cloud staging project + Email magic link there. Local does not close First 10 #2 / §15 staging.

## Tests

```bash
# RLS / SQL (from repo root, local Supabase running)
# see supabase/tests/

cd apps/tell_me_a_story && flutter test
```
