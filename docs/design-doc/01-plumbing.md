## Plumbing locks (Bill green-light 2026-09-19)
Closes Impl Spec OPENs for repo layout, env/CI injection, and test commands.
### Repo layout
Flutter monorepo:
- `apps/tell_me_a_story/` — Flutter client (iOS/iPad + web)
- `supabase/` — migrations, Edge Functions, seed/RLS tests
- Root README + analysis_options as needed
> 🚫 FORBIDDEN: Separate per-platform repos for v1; inventing extra packages not required by SAD/Design Doc.
### Environment and secrets
Inject via `--dart-define` locally and CI env vars in pipelines:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `MAPBOX_ACCESS_TOKEN` (public, restricted by bundle ID / web URL)
Edge-only (never in Flutter):
- `RESEND_API_KEY`
- Supabase service role key (Edge / migrations only)
### Test commands
- Client: `flutter test` (from `apps/tell_me_a_story`)
- Data/RLS: Supabase SQL tests against migrations (two-family leak test mandatory)
@Big Head: plumbing folded into Accepted Impl Spec (2026-09-19).
