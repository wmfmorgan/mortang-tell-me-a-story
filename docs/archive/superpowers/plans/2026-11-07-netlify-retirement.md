# Retire Netlify (follow-up to `feat/gcp-hosting`)

## Context
Web app ships to Firebase Hosting (`https://story-line-app.web.app`) via `just deploy-web`. API on Cloud Run. `feat/gcp-hosting` deleted `netlify.toml`, only Netlify file in repo. Remaining cleanup outside repo or in docs.

Netlify project: `mortang-tellmeastory` (`app.netlify.com/projects/mortang-tellmeastory`, from Netlify bot comment on PR #54). Netlify bot posted no statuses/comments on PRs #172–#177. Netlify webhook or branch-protection check not confirmable from CLI: `gh` token lacks `admin:repo_hook`.

## Order matters
Netlify builds only what lands on `main`. `feat/gcp-hosting` merges into `feature/serverpod`. Once `feature/serverpod` merges to `main`, `main` has no `netlify.toml`, so Netlify builds with UI settings: no ignore script, no SPA rewrite. **Stop Netlify builds (step 1) before that merge.**

## Steps

|#|What|Where|Who|When|
|---|---|---|---|---|
|1|Stop builds: Project configuration → Build & deploy → Continuous deployment → **Stop builds**|Netlify UI|David|Before merging `feature/serverpod` to `main`|
|2|Copy still-needed Netlify env vars (`MAPBOX_ACCESS_TOKEN`) to shell or password manager. `just deploy-web` reads `MAPBOX_ACCESS_TOKEN` from env|Netlify UI → Environment variables|David|Before step 6|
|3|Mapbox token URL restrictions: add `https://story-line-app.web.app`, then remove `*.netlify.app` URL|Mapbox account → Tokens|David|Before step 6|
|4|Old links: let `mortang-tellmeastory.netlify.app` die, or hand-deploy one-file `_redirects` (`/* https://story-line-app.web.app/:splat 301!`), keep few weeks|Netlify UI (manual deploy)|David (decide)|Optional, before step 6|
|5|Custom domain/DNS: check Domain management for custom domain pointing at Netlify. If found, repoint to Firebase Hosting (`firebase hosting:sites` → Add custom domain)|Netlify UI, DNS provider|David|Before step 6|
|6|Delete Netlify project `mortang-tellmeastory` (also drops env vars, deploy previews, deploy keys)|Netlify UI → Project configuration → Delete project|David|After Firebase serves real use ~1 week|
|7|Remove Netlify GitHub App access to repo. Delete any `api.netlify.com` webhook and Netlify deploy key|github.com → Settings → Applications → Netlify (account `wmfmorgan`, repo owner); repo Settings → Webhooks / Deploy keys|wmfmorgan (repo admin)|After step 6|
|8|Docs PR (one commit, `docs:`):<br>• `docs/archive/migration/audit.md:84`: record hosting decision (Cloud Run + Cloud SQL, Firebase Hosting, photos/covers/avatars in private GCS bucket via `NativeGoogleCloudStorage`; local dev + test keep `DatabaseCloudStorage`)<br>• `docs/archive/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md:44` (Phase 5 row): replace "`netlify.toml` (or Serverpod web hosting) rewritten" with "web on Firebase Hosting (`firebase.json`); `netlify.toml` deleted"<br>• same file `:17`: note prod blobs use GCS via `serverpod_cloud_storage_gcp` (`NativeGoogleCloudStorage`, Cloud Run service-account creds), not `serverpod_cloud_storage_s3_compat`|repo|agent|After `feat/gcp-hosting` merges|
|9|Spec divergence report (no edit): `docs/archive/impl-spec/impl-spec.md:1219` still says web host "Vercel **or** Netlify … still unlocked". Spec owned in Notion, so per `AGENTS.md`, report diff (host locked to Firebase Hosting, API on Cloud Run) to Gilfoyle/Bill for Spec amendment. `:3084` historical record; leave|Notion / owners|David → Gilfoyle, Bill|Any time|

## Verification
- After step 1: push to `main` creates no new deploy under Deploys in Netlify project.
- After step 3: `https://story-line-app.web.app`, rebuilt with `MAPBOX_ACCESS_TOKEN=pk.… just deploy-web`, loads map in story place picker. Also unblocks remaining two-tab live-notes smoke test.
- After step 6: `curl -sI https://mortang-tellmeastory.netlify.app` returns 404 (or 301 to Firebase if step 4 redirect chosen).
- After step 7: repo Settings → Webhooks and Deploy keys list nothing Netlify-related. New PRs get no Netlify bot comment.
- After step 8: case-insensitive repo search for `netlify` outside `docs/archive/` finds only this plan.

## Out of scope
- Hosted Supabase project + its auth redirect URLs (separate Supabase retirement).
- Renaming app or packages to "Story Line".