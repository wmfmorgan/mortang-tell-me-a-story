# Retire Netlify (follow-up to `feat/gcp-story-line`)

## Context
The web app now ships to Firebase Hosting (`https://story-line-nra.web.app`) through `just deploy-web`, and the API runs on Cloud Run. `feat/gcp-story-line` deleted `netlify.toml`, the only Netlify file in the repo. The rest of the cleanup is outside the repo or in docs.

Netlify project: `mortang-tellmeastory` (`app.netlify.com/projects/mortang-tellmeastory`, from the Netlify bot's comment on PR #54). The Netlify bot hasn't posted statuses or comments on PRs #172–#177. No Netlify webhook or branch-protection check could be confirmed from the CLI, because the `gh` token lacks `admin:repo_hook`.

## Order matters
Netlify builds whatever lands on `main`. Once `feat/gcp-story-line` is merged, `main` has no `netlify.toml`, so Netlify would build using its UI settings: no ignore script and no SPA rewrite. **Stop Netlify builds (step 1) before that merge.**

## Steps

|#|What|Where|Who|When|
|---|---|---|---|---|
|1|Stop builds: Project configuration → Build & deploy → Continuous deployment → **Stop builds**|Netlify UI|David|Before merging `feat/gcp-story-line` to `main`|
|2|Copy any Netlify env vars still needed (`MAPBOX_ACCESS_TOKEN`) to your shell or a password manager; `just deploy-web` reads `MAPBOX_ACCESS_TOKEN` from the environment|Netlify UI → Environment variables|David|Before step 6|
|3|Mapbox token URL restrictions: add `https://story-line-nra.web.app`, then remove the `*.netlify.app` URL|Mapbox account → Tokens|David|Before step 6|
|4|Old links: either let `mortang-tellmeastory.netlify.app` die, or deploy a one-file `_redirects` (`/* https://story-line-nra.web.app/:splat 301!`) by hand and keep it for a few weeks|Netlify UI (manual deploy)|David (decide)|Optional, before step 6|
|5|Custom domain/DNS: check Domain management for any custom domain pointing at Netlify; if one exists, repoint it to Firebase Hosting (`firebase hosting:sites` → Add custom domain)|Netlify UI, DNS provider|David|Before step 6|
|6|Delete the Netlify project `mortang-tellmeastory` (this also drops its env vars, deploy previews and deploy keys)|Netlify UI → Project configuration → Delete project|David|After Firebase has served real use for about a week|
|7|Remove the Netlify GitHub App's access to this repo; delete any `api.netlify.com` webhook and Netlify deploy key|github.com → Settings → Applications → Netlify (account `wmfmorgan`, the repo owner); repo Settings → Webhooks / Deploy keys|wmfmorgan (repo admin)|After step 6|
|8|Docs PR (one commit, `docs:`):<br>• `docs/migration/audit.md:84`: record the hosting decision (Cloud Run + Cloud SQL, Firebase Hosting, photos in Postgres through `DatabaseCloudStorage`)<br>• `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md:42` (Phase 5 row): replace "`netlify.toml` (or Serverpod web hosting) rewritten" with "web on Firebase Hosting (`firebase.json`); `netlify.toml` deleted"<br>• same file `:17`: note that the S3 plan was replaced by `DatabaseCloudStorage`|repo|agent|After `feat/gcp-story-line` merges|
|9|Spec divergence report (no edit): `docs/impl-spec/impl-spec.md:1219` still says the web host is "Vercel **or** Netlify … still unlocked". The Spec is owned in Notion, so per `AGENTS.md`, report the diff (host locked to Firebase Hosting, API on Cloud Run) to Gilfoyle/Bill for a Spec amendment. `:3084` is a historical record; leave it|Notion / owners|David → Gilfoyle, Bill|Any time|

## Verification
- After step 1: a push to `main` creates no new deploy under Deploys in the Netlify project.
- After step 3: `https://story-line-nra.web.app`, rebuilt with `MAPBOX_ACCESS_TOKEN=pk.… just deploy-web`, loads the map in the story place picker. This also unblocks the remaining two-tab live-notes smoke test.
- After step 6: `curl -sI https://mortang-tellmeastory.netlify.app` returns 404 (or 301 to Firebase if you chose the redirect in step 4).
- After step 7: repo Settings → Webhooks and Deploy keys list nothing Netlify-related, and new PRs get no Netlify bot comment.
- After step 8: searching the repo for `netlify` (case-insensitive) finds only the historical `impl-spec.md:3084` line and this plan.

## Out of scope
- The hosted Supabase project and its auth redirect URLs (a separate Supabase retirement).
- Renaming the app or packages to "Story Line".
