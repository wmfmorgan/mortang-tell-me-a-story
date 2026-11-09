# Phase 4: Client Cutover — Index

> **For agentic workers:** Phase 4 index. 4.0 lands on `feat/serverpod-migration` first. Then slices 4a–4f run parallel on branches off cutover branch, each from own detailed plan. 4z integrates, removes Supabase from app, merges cutover branch back.

**Goal:** Flutter app runs on Serverpod server only. Every `lib/data` gateway calls generated client, login = 6-digit email code, `supabase_flutter` gone from app, unit/live/e2e checks pass.

**Architecture:** Big bang, per endpoint-contract §5. Supabase and Serverpod ids not interchangeable, so app can't run half on each.
- **4.0** additive, lands on `feat/serverpod-migration`; app still on Supabase.
- **`feat/p4-cutover`** branches from it. Each slice branches from cutover branch, merges back into it.
- **4z** finishes switch (removes Supabase from app, runs every gate incl. e2e), merges `feat/p4-cutover` into `feat/serverpod-migration` in one step.
- **During slices** app keeps compiling, since both backends' packages present. Any single slice branch can run own tests.

**Tech Stack:** Flutter 3.47.7, generated `tell_me_a_story_client`, `serverpod_auth_core_flutter` / `serverpod_auth_idp_client` 4.1.1, just.

**Spec of record:**
- `docs/migration/endpoint-contract.md` §2 (endpoints).
- §1 and §3–§5 intent only: predate Phase 2, so trust current code + this index over their line anchors.
- Business rules + decisions D1–D13 (roadmap).
- Server as built (`apps/server/lib/src/endpoints/`).

Server and gateway disagree → server endpoint + its tests win. Report gap; don't change server inside client slice.

---

## Status

| Part | Plan | Status |
|---|---|---|
| 4.0 Shared foundation | `2026-11-07-serverpod-phase4-0-foundation.md` | landed (`f92a1d6`..`5858d75`; app 723 + live 2) |
| 4a Shell and auth | `2026-11-07-serverpod-phase4a-shell-auth.md` | landed (merge `7cbd522`) |
| 4b Families, directory, covers, invites | `2026-11-07-serverpod-phase4b-families-invites.md` | landed |
| 4c Stories, search, timeline live | `2026-11-07-serverpod-phase4c-stories-search.md` | landed (merge `f4fd012`) |
| 4d People, places, profile | `2026-11-07-serverpod-phase4d-people-places-profile.md` | landed (merge `5508cd7`) |
| 4e Photos, notes, reader | `2026-11-07-serverpod-phase4e-photos-notes.md` | landed (merge `14a253d`) |
| 4f e2e and CI | `2026-11-07-serverpod-phase4f-e2e-ci.md` | landed (merge `d276e3a`) |
| 4z Integration and switch | this index, §4z | done (`bf406ea`..`319e0ed`); see §Exit criteria |

Executor writes each slice plan at slice start, per superpowers:writing-plans. Code blocks verified in scratch worktree, like 3.0 and 4.0. Slice rows below = scope contract.

---

## Conventions

**Gateway shape.**
- **Constructor:** `*Api` class keeps name + interface. Constructor becomes `XxxApi({server.Client? client})`. Client read lazily (`server.Client get _client => _injected ?? serverClient;`), so widget tests building default gateway never need server.
- **Import generated client with prefix:** `import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;`. Exports `AppException`, `AppErrorCode`, `Person`, `Photo`, `Place`, `Story`, `BirthVisibility`, `StoryStatus`, which clash with app's own classes.
- **Old seams:** drop Supabase-era test hooks (`uploadBinary`, `removeObjects` etc.) unless slice row keeps one.
- **Every server call** returning `Future` = `withServerErrors(() => _client.<endpoint>.<method>(...))`. Streams (`live.watchFamily` / `watchStory`, 4c) not covered: 401 arrives as stream error carrying `ServerpodClientUnauthorized`; stream code handles it.
- **Mapping:** DTO → domain = `fromDto` factory/function next to domain class, in gateway's own file. Use `wire.dart` for date-only values (`toWireDate` / `fromWireDate`), roles, precision. Ids cross as `UuidValue.fromString(id)` / `id.toString()`.
- **Parameter defaults:** generated client makes server-side defaults required (`allowUndated`, `withinDays`, `limit`, `personIds`). Pass explicitly.
- **Blobs:** `media.get(key)` / `media.getMany(keys)` return `ByteData`; convert via `Uint8List.sublistView`. Uploads: start → `FileUploader(desc).uploadByteData(...)` → finish. `uploadByteData` returning false = `StorageFailedException`.

**Tests.**
- Replace each `fromJson` mapper test with `fromDto` test building DTOs directly; no server.
- Delete tests of Supabase-only helpers with the helpers.
- Every gateway method gets ≥1 `live` test in `test/live/<gateway>_live_test.dart`:
  - tag `@Tags(['live'])`, call `setUpAll(waitForLiveServer)`;
  - `signInLive(freshEmail(...))` per user involved;
  - assert domain values features read, not DTO wiring;
  - `signInLive` replaces global `serverClient`. Multi-user test passes each gateway own `client:` (value `signInLive` returns), not default.
- Slice green only when `flutter test` passes, `flutter analyze` ≤23 issues, `just test-live` passes against `just server`.
- `test/theme/no_hardcoded_colors_test.dart`: keep file paths stable. Listed file loses last color hit → remove from skip list. Never add; new UI uses `album_theme.dart` tokens.

**Interface changes owned by one slice each**; that slice updates every fake of that interface in `test/` (fake inventory: `agent://ScoutTests` §2, repeated in each slice plan). Changes:
- 4b: `InviteGateway.sendInviteEmail` gains token; `AcceptInviteResult` loses `membershipId`.
- 4d: `ProfileGateway` loses `updateEmail` (D1); `Place` loses `familyId`.
- 4e: `Comment` / `Perspective` gain `canDelete` (default false).
- 4c: `SearchGateway` gains `facets`; `StoryDatePrecision` loses `decade` (D9).

**Branches and merges.**
- `feat/p4<x>-<name>` branches off `feat/p4-cutover`, merges back `--no-ff`.
- Test-fake conflicts: keep both sides' changes. `pubspec.lock` shouldn't conflict; 4.0 added every package.

**Out of scope:**
- Client UI for `people.setDeathDate` (D10) or `people.delete` (D5): no UX spec yet.
- Kinships.
- Photo-edit save/reset.
- Deleting `supabase/`, Deno functions, pgTAP: Phase 5.

---

## Slices

### 4a Shell and auth
- **Owns:**
  - `lib/main.dart`;
  - `lib/core/config/env.dart` (drop Supabase defines; `validate()` requires absolute http(s) `SERVER_URL`);
  - `lib/core/supabase/` (delete);
  - `lib/core/router/auth_refresh.dart`;
  - `lib/core/server/app_session.dart`;
  - `lib/features/auth/` (keep `magic_link_page.dart` and `invite_sign_in_page.dart` file names; delete `magic_link_redirect.dart`).
- **Change:**
  - **Startup:** `main` calls `initServer()`. `AuthRefresh` listens to `serverClient.auth.authInfoListenable`. On sign-in binds `ProfileSession` + `FamilySelection` to user; work moves out of `invite_api.dart`.
  - **Session:** `AppSession.instance` becomes `ServerAppSession`: `currentUserId` = `authInfo?.authUserId.toString()`, `signOut` = `signOutDevice()`. Startup must survive unreadable saved session: `initServer()` throws while restoring (e.g. corrupted secure-storage entry on web) → clear stored session, start signed out, with test.
  - **Login pages:** both switch to email → code entry. Invite page keeps `_onAuth` → `_accept()` flow. `EmailAccountRequestException` reasons map to copy below.
- **Tests:**
  - Delete `auth_callback_test`, `magic_link_redirect_test`.
  - Rewrite `env_test`, `app_session_test`, `family_selection`/`profile_session` listener tests (`ValueNotifier<AuthSuccess?>`), `m13_fit_finish_test` (`_Otp implements OtpSignIn`, plus code-entry tests), `router_test` (`MagicLinkPage` finders still work if class name stays), `m14_3` tearDown.
  - Add live test: `ServerOtpSignIn` signs in with `111111`, `AppSession.currentUserId` is user.
- **Copy (approved by product owner, 2026-11-07):**
  - Note under landing headline: "We'll email you a 6-digit code. No password needed."
  - Send button: "Email me a sign-in code" / "Sending…"
  - Code step:
    - heading: "Check your email";
    - body: "We sent a 6-digit code to {email}.";
    - field label: "Sign-in code";
    - button: "Sign in" / "Signing in…";
    - secondary actions: "Send a new code", "Use a different email".
  - Errors: wrong code "That code isn't right. Check it and try again."; expired "That code has expired. Send a new one."; too many tries "Too many tries. Wait a few minutes, then send a new code."; else: existing "Request failed".
  - Invite page: "We sent a code to {email}. Enter it to join {family}."

### 4b Families, directory, covers, invites
- **Owns:**
  - `lib/data/families_api.dart` (`FamiliesGateway`, `FamilyDirectoryGateway`);
  - `lib/data/family_covers.dart`;
  - `lib/data/manage_families_api.dart`;
  - `lib/data/invite_api.dart` (`InviteGateway`, `InviteLinkGateway`);
  - `sendInviteEmail` callers `features/invites/invite_modal.dart` (`_pendingSend` keeps token), `features/people/add_person_modal.dart` and `edit_person_dialog.dart` (send call only).
- **Change:**
  - **Mapping:** `MemberFamily` / `StewardFamily` / `TreeFamily` / `FamilyRoster` / `FamilyDetail` take server `sentAt`/`createdAt`. Roles use `roleName`.
  - **Delete:** `familiesCoverColumnMissing`, `_originError` (server errors now arrive as `AppException`), `familyCoverObjectPath`, bucket constants.
  - **Covers:** `setCoverPhoto` = start (`image/jpeg`) → upload → finish; `clearCoverPhoto` = `family.clearCover`.
  - **`loadDetail`:** still returns null for family caller can't see, by mapping `forbidden`/`notFound` to null in that one method.
  - **`currentFamilyId`:** uses `family.listMine` + `FamilySelection`. Drop its `ProfileSession`/`FamilySelection.bindUser` calls; 4a binds on sign-in.
  - **Invites:** `createInvite.expiresAt` becomes `DateTime`. `transferOwnership` uses `roleFromName`.
- **Tests:** `family_landing_latest_test` drops three cover-column cases. `family_menu_tree_test` fixtures move to constructors. Update every `InviteGateway` fake. Live: listMine, createRoot, rename, directory + detail, cover round trip, invite flow create → preview → accept (second user) → resend → revoke.

### 4c Stories, search, timeline live
- **Owns:** `lib/data/stories_api.dart`, `lib/data/search_api.dart`, `lib/data/timeline_live.dart`, `features/search/search_page.dart`, `timeframe_chips.dart`, `features/timeline/timeline_page.dart` (live swap only), `story_date.dart` (legacy decade paths).
- **Change:**
  - **Stories:** `Story.fromDto`. `createDraft` passes `allowUndated` explicitly. Delete `createOrUpdateExisting`, `isDuplicateStoryKey`, `_storySelect`; server idempotent. `storiesForPerson` and `downloadFirstThumbs` use `media.getMany`.
  - **Decade:** `StoryDatePrecision.decade` removed (D9).
  - **Search:** `search` → `story.search`. `facets` → `story.facets` drives person, place, decade chips; delete fixed 1900–2020 decades and `filterSearchRecords`.
  - **Live updates:** `ServerTimelineLive` subscribes to `live.watchFamily` / `watchStory`, keeps 200 ms debounce, resubscribes after shared WebSocket drops. `timelineEventMatters` takes `LiveEventDto`.
- **Tests:** `stories_api_test` (delete duplicate-key + source-scan tests; add `fromDto` tests), search tests, `timeline_page_test` `timelineEventMatters`, `Story.fromJson` fixtures in `all_stories_logic`, `drafts_page`, `stories_api`. Live: draft → publish → latest → listForPerson round trip, search with facets, family stream event after publish.

### 4d People, places, profile
- **Owns:** `lib/data/people_api.dart`, `lib/data/places_api.dart`, `lib/data/profile_api.dart`, `features/settings/settings_page.dart`.
- **Change:**
  - **People:** `Person.fromDto` (`familyId` ← `homeFamilyId`, `passingDate` ← `deathDate`). `relationship` and `createdBy` removed; sole reader (`story_reader_page:1363-1366`) drops line; 4e owns that file, makes that one-line change. `listTreePeople` → `people.listTree`. `pictureBytes` → `media.get`.
  - **Places:** `Place.familyId` removed; `PlaceInputDto` replaces `buildPlaceInsert`.
  - **Profile:** `ProfileApi` maps `BirthVisibility` (`year_month` ↔ `yearMonth`); `downloadAvatar` uses `media.get`.
  - **D1:** delete `updateEmail` and `EmailUpdate`. Settings shows email read-only, no new copy: existing field becomes non-editable.
- **Tests:** `people_api_test` (drop PostgREST stub group; add `fromDto` tests), `places_api_test`, `profile_api_test`, `settings_page`/`settings_guard` D1 tests, `ProfileGateway` fakes. Live: person create/update with picture, tree list with birth coarsening, `markPassedAway`, places create/markUsed/favorite/recents, profile saveAccount/avatar.

### 4e Photos, notes, reader
- **Owns:** `lib/data/photos_api.dart`, `lib/data/comments_api.dart`, `lib/data/perspectives_api.dart`, `features/stories/story_reader_page.dart` (live swap, D4 delete action, `relationship` line), `features/perspectives/add_perspective_page.dart` if needs touching.
- **Change:**
  - **Photos:** `PhotosApi` = `photo.list` / start → upload → finish / `photo.delete` / `photo.setHero` / `media.get`. Keep `compressStoryPhoto`, `ensurePhotoCap`, `photosWithHeroFirst`, `comparePhotoOrder`, plus one `PhotoUploadBinary` seam for tests. Delete `deleteAllForStory`.
  - **Notes:** comments + perspectives use `note.*` with their kind; `Comment` / `Perspective` gain `canDelete`.
  - **Reader (D4):** existing delete action shown on any note with `canDelete` true, not only user's own. No new copy.
- **Tests:** `photos_api_test` (keep compression, cap, hero order; delete storage tests), comments/perspectives tests (`fromNote`), `story_reader_page_test` for steward seeing delete on others' notes. Live: upload/list/hero/delete round trip, comments + perspectives CRUD, `canDelete` as owner vs member.

### 4f e2e and CI
- **Owns:** `apps/tell_me_a_story/integration_test/**`, `e2e/` (delete `relay.ts`; keep `check_flows.sh`), `.github/workflows/ci.yml` (e2e job only), `justfile` `run` recipe (`--dart-define=SERVER_URL=http://127.0.0.1:8080`; Supabase defines go in 4z).
- **Change:**
  - **Sign-in:** `e2e_test.dart` signs in by typing `111111`; `_signIn` and C1/C6 use code step.
  - **Support files:** `prod_guard` checks `Env.serverUrl` local. `preconditions` signs out via `serverClient.auth`. App mounted same way `main.dart` does after 4a.
  - **C1:** renamed "C1 email-code sign-in lands on timeline" in both `flows.md` and test. Owning paths change `core/supabase/` → `core/server/`.
  - **CI job:** starts `just server` instead of `supabase start`, waits for :8080, runs `flutter drive` with `SERVER_URL`. Mailpit, Deno, relay steps dropped.
- **Verification:** `bash e2e/check_flows.sh` passes. Full e2e run in 4z, needs every gateway switched.

### 4z Integration and switch (sequential, after all slices merge into `feat/p4-cutover`)
1. **Finish cross-slice swaps:**
   - `story_reader_page.dart` and `timeline_page.dart` construct `ServerTimelineLive()` (4c's) instead of `SupabaseTimelineLive()`;
   - `StoriesApi.discard` calls `story.discard` (4e removed client-side photo cleanup; server queues blobs);
   - delete `storyPhotosBucket` once no thumbnail downloaded from Supabase storage;
   - `Story.photoPaths` = server blob keys, read by `media.get` / `getMany`;
   - e2e calls into `StoriesApi` / `PlacesApi` match merged signatures.
2. **Remove Supabase from app:**
   - remove `supabase_flutter` from `apps/tell_me_a_story/pubspec.yaml`;
   - delete `lib/data/supabase_errors.dart`, `test/supabase_errors_test.dart` (keep its `appErrorMessage` test next to `app_exception`), `test/gateway_errors_test.dart`;
   - remove Supabase defines from `justfile` `run` recipe.
3. **Check nothing left:** `rg -n "supabase|Supabase|PostgrestException|GoTrue" apps/tell_me_a_story/lib apps/tell_me_a_story/test apps/tell_me_a_story/integration_test` returns nothing.
4. **Gates:**
   - format;
   - `flutter analyze` ≤23 issues;
   - `flutter test`;
   - `just test-live` and `just server-test`;
   - `bash e2e/check_flows.sh`;
   - e2e run locally (`flutter drive` against `just server` with ChromeDriver);
   - manual browser smoke: sign-in → create family → story with photo → comment → invite → accept as second user.
5. **Docs:**
   - endpoint-contract §3/§4 marked done, with changes made here;
   - roadmap Phase 4 row updated;
   - Phase 5 plan follows (delete `supabase/`, Deno, pgTAP; rewrite `AGENTS.md`/README).
6. **Merge:** `git merge --no-ff feat/p4-cutover` into `feat/serverpod-migration`.

---

## Exit criteria for Phase 4
- App runs against `just server` only; no Supabase code or package left in `apps/tell_me_a_story`.
- `flutter test` passes, `flutter analyze` ≤23 issues, and `just test-live`, `just server-test`, `e2e/check_flows.sh`, local e2e run pass.
- D1 (read-only email) and D4 (steward delete on notes) visible in app. New code-entry copy = approved text.