# Phase 4: Client Cutover — Index

> **For agentic workers:** This is the Phase 4 index. 4.0 lands on `feat/serverpod-migration` first. Then the slices 4a–4f run in parallel on branches off the cutover branch, each from its own detailed plan. 4z integrates them, removes Supabase from the app, and merges the cutover branch back.

**Goal:** The Flutter app runs on the Serverpod server only. Every `lib/data` gateway calls the generated client, login is a 6-digit email code, `supabase_flutter` is gone from the app, and the unit, live and e2e checks pass.

**Architecture:** Big bang, as endpoint-contract §5 requires. Supabase and Serverpod ids mean nothing to each other, so the app can't run half on each.
- **4.0** is additive and lands on `feat/serverpod-migration`; the app still runs on Supabase.
- **`feat/p4-cutover`** then branches from it. Each slice branches from the cutover branch and merges back into it.
- **4z** finishes the switch (removes Supabase from the app, runs every gate including e2e) and merges `feat/p4-cutover` into `feat/serverpod-migration` in one step.
- **During the slices** the app keeps compiling, because both backends' packages are present. Any single slice branch can run its own tests.

**Tech Stack:** Flutter 3.47.7, the generated `tell_me_a_story_client`, `serverpod_auth_core_flutter` / `serverpod_auth_idp_client` 4.1.1, just.

**Spec of record:**
- `docs/migration/endpoint-contract.md` §2 (endpoints).
- §1 and §3–§5 for intent only: they predate Phase 2, so trust the current code and this index over their line anchors.
- Business rules and decisions D1–D13 (roadmap).
- The server as built (`apps/server/lib/src/endpoints/`).

If the server and a gateway disagree, the server's endpoint and its tests win. Report the gap; don't change the server inside a client slice.

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

Each slice plan is written by its executor at slice start, following superpowers:writing-plans. Its code blocks are verified in a scratch worktree, as 3.0 and 4.0 were. The slice rows below are the scope contract.

---

## Conventions

**Gateway shape.**
- **Constructor:** the `*Api` class keeps its name and its interface. The constructor becomes `XxxApi({server.Client? client})`. The client is read lazily (`server.Client get _client => _injected ?? serverClient;`), so widget tests that build a default gateway never need a server.
- **Import the generated client with a prefix:** `import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;`. It exports `AppException`, `AppErrorCode`, `Person`, `Photo`, `Place`, `Story`, `BirthVisibility` and `StoryStatus`, which clash with the app's own classes.
- **Old seams:** drop the Supabase-era test hooks (`uploadBinary`, `removeObjects` and so on) unless the slice row keeps one.
- **Every server call** that returns a `Future` is `withServerErrors(() => _client.<endpoint>.<method>(...))`. Streams (`live.watchFamily` / `watchStory`, 4c) aren't covered: a 401 arrives as a stream error carrying `ServerpodClientUnauthorized`, and the stream code handles it.
- **Mapping:** DTO → domain mapping is a `fromDto` factory or function next to the domain class, in the gateway's own file. Use `wire.dart` for date-only values (`toWireDate` / `fromWireDate`), roles and precision. Ids cross as `UuidValue.fromString(id)` / `id.toString()`.
- **Parameter defaults:** the generated client makes server-side defaults required (`allowUndated`, `withinDays`, `limit`, `personIds`). Pass them explicitly.
- **Blobs:** `media.get(key)` / `media.getMany(keys)` return `ByteData`; convert with `Uint8List.sublistView`. Uploads go start → `FileUploader(desc).uploadByteData(...)` → finish. `uploadByteData` returning false is `StorageFailedException`.

**Tests.**
- Replace each `fromJson` mapper test with a `fromDto` test that builds DTOs directly; no server needed.
- Delete tests of Supabase-only helpers together with the helpers.
- Every gateway method gets at least one `live` test in `test/live/<gateway>_live_test.dart`:
  - tag it `@Tags(['live'])` and call `setUpAll(waitForLiveServer)`;
  - use `signInLive(freshEmail(...))` for each user involved;
  - assert the domain values the features read, not DTO wiring;
  - `signInLive` replaces the global `serverClient`. A test with more than one user passes each gateway its own `client:` (the value `signInLive` returns) instead of relying on the default.
- A slice is green only with `flutter test` passing, `flutter analyze` at no more than 23 issues, and `just test-live` passing against `just server`.
- `test/theme/no_hardcoded_colors_test.dart`: keep file paths stable. If a listed file loses its last color hit, remove it from the skip list. Never add one; new UI uses `album_theme.dart` tokens.

**Interface changes are owned by one slice each,** and that slice updates every fake of that interface in `test/` (the fake inventory: `agent://ScoutTests` §2, repeated in each slice plan). The interface changes:
- 4b: `InviteGateway.sendInviteEmail` gains the token; `AcceptInviteResult` loses `membershipId`.
- 4d: `ProfileGateway` loses `updateEmail` (D1); `Place` loses `familyId`.
- 4e: `Comment` / `Perspective` gain `canDelete` (default false).
- 4c: `SearchGateway` gains `facets`; `StoryDatePrecision` loses `decade` (D9).

**Branches and merges.**
- `feat/p4<x>-<name>` branches off `feat/p4-cutover` and merges back with `--no-ff`.
- Conflicts in test fakes are resolved by keeping both sides' changes. `pubspec.lock` should not conflict, because 4.0 added every package.

**Out of scope:**
- A client UI for `people.setDeathDate` (D10) or `people.delete` (D5): no UX spec yet.
- Kinships.
- Photo-edit save/reset.
- Deleting `supabase/`, the Deno functions and pgTAP: that is Phase 5.

---

## Slices

### 4a Shell and auth
- **Owns:**
  - `lib/main.dart`;
  - `lib/core/config/env.dart` (drop the Supabase defines; `validate()` requires an absolute http(s) `SERVER_URL`);
  - `lib/core/supabase/` (delete);
  - `lib/core/router/auth_refresh.dart`;
  - `lib/core/server/app_session.dart`;
  - `lib/features/auth/` (keep `magic_link_page.dart` and `invite_sign_in_page.dart` as file names; delete `magic_link_redirect.dart`).
- **Change:**
  - **Startup:** `main` calls `initServer()`. `AuthRefresh` listens to `serverClient.auth.authInfoListenable`. On sign-in it binds `ProfileSession` and `FamilySelection` to the user; that work moves out of `invite_api.dart`.
  - **Session:** `AppSession.instance` becomes `ServerAppSession`: `currentUserId` = `authInfo?.authUserId.toString()`, `signOut` = `signOutDevice()`. Startup must survive an unreadable saved session: if `initServer()` throws while restoring (for example a corrupted secure-storage entry on web), clear the stored session and start signed out, with a test.
  - **Login pages:** both pages switch to email → code entry. The invite page keeps its `_onAuth` → `_accept()` flow. `EmailAccountRequestException` reasons map to the copy below.
- **Tests:**
  - Delete `auth_callback_test`, `magic_link_redirect_test`.
  - Rewrite `env_test`, `app_session_test`, the `family_selection`/`profile_session` listener tests (`ValueNotifier<AuthSuccess?>`), `m13_fit_finish_test` (`_Otp implements OtpSignIn`, plus code-entry tests), `router_test` (`MagicLinkPage` finders still work if the class name stays), and the `m14_3` tearDown.
  - Add a live test: `ServerOtpSignIn` signs in with `111111` and `AppSession.currentUserId` is the user.
- **Copy (approved by the product owner, 2026-11-07):**
  - Note under the landing headline: "We'll email you a 6-digit code. No password needed."
  - Send button: "Email me a sign-in code" / "Sending…"
  - Code step:
    - heading: "Check your email";
    - body: "We sent a 6-digit code to {email}.";
    - field label: "Sign-in code";
    - button: "Sign in" / "Signing in…";
    - secondary actions: "Send a new code", "Use a different email".
  - Errors: wrong code "That code isn't right. Check it and try again."; expired "That code has expired. Send a new one."; too many tries "Too many tries. Wait a few minutes, then send a new code."; anything else: the existing "Request failed".
  - Invite page: "We sent a code to {email}. Enter it to join {family}."

### 4b Families, directory, covers, invites
- **Owns:**
  - `lib/data/families_api.dart` (`FamiliesGateway`, `FamilyDirectoryGateway`);
  - `lib/data/family_covers.dart`;
  - `lib/data/manage_families_api.dart`;
  - `lib/data/invite_api.dart` (`InviteGateway`, `InviteLinkGateway`);
  - the `sendInviteEmail` callers `features/invites/invite_modal.dart` (`_pendingSend` keeps the token), `features/people/add_person_modal.dart` and `edit_person_dialog.dart` (send call only).
- **Change:**
  - **Mapping:** `MemberFamily` / `StewardFamily` / `TreeFamily` / `FamilyRoster` / `FamilyDetail` take server `sentAt`/`createdAt`. Roles use `roleName`.
  - **Delete:** `familiesCoverColumnMissing`, `_originError` (server errors now arrive as `AppException`), `familyCoverObjectPath` and the bucket constants.
  - **Covers:** `setCoverPhoto` = start (`image/jpeg`) → upload → finish; `clearCoverPhoto` = `family.clearCover`.
  - **`loadDetail`:** keeps returning null for a family the caller can't see, by mapping `forbidden`/`notFound` to null in that one method.
  - **`currentFamilyId`:** uses `family.listMine` and `FamilySelection`. Drop its `ProfileSession`/`FamilySelection.bindUser` calls; 4a binds on sign-in.
  - **Invites:** `createInvite.expiresAt` becomes a `DateTime`. `transferOwnership` uses `roleFromName`.
- **Tests:** `family_landing_latest_test` drops its three cover-column cases. `family_menu_tree_test` fixtures move to constructors. Update every `InviteGateway` fake. Live: listMine, createRoot, rename, the directory and detail, the cover round trip, and the invite flow create → preview → accept (second user) → resend → revoke.

### 4c Stories, search, timeline live
- **Owns:** `lib/data/stories_api.dart`, `lib/data/search_api.dart`, `lib/data/timeline_live.dart`, `features/search/search_page.dart`, `timeframe_chips.dart`, `features/timeline/timeline_page.dart` (live swap only), and `story_date.dart` (legacy decade paths).
- **Change:**
  - **Stories:** `Story.fromDto`. `createDraft` passes `allowUndated` explicitly. Delete `createOrUpdateExisting`, `isDuplicateStoryKey` and `_storySelect`, because the server is idempotent. `storiesForPerson` and `downloadFirstThumbs` use `media.getMany`.
  - **Decade:** `StoryDatePrecision.decade` is removed (D9).
  - **Search:** `search` → `story.search`. `facets` → `story.facets` drives the person, place and decade chips; delete the fixed 1900–2020 decades and `filterSearchRecords`.
  - **Live updates:** `ServerTimelineLive` subscribes to `live.watchFamily` / `watchStory`, keeps the 200 ms debounce, and resubscribes after the shared WebSocket drops. `timelineEventMatters` takes a `LiveEventDto`.
- **Tests:** `stories_api_test` (delete the duplicate-key and source-scan tests; add `fromDto` tests), the search tests, `timeline_page_test` `timelineEventMatters`, and the `Story.fromJson` fixtures in `all_stories_logic`, `drafts_page` and `stories_api`. Live: the draft → publish → latest → listForPerson round trip, search with facets, and a family stream event after publish.

### 4d People, places, profile
- **Owns:** `lib/data/people_api.dart`, `lib/data/places_api.dart`, `lib/data/profile_api.dart`, `features/settings/settings_page.dart`.
- **Change:**
  - **People:** `Person.fromDto` (`familyId` ← `homeFamilyId`, `passingDate` ← `deathDate`). `relationship` and `createdBy` are removed, and the one reader (`story_reader_page:1363-1366`) drops the line; 4e owns that file and makes that one-line change. `listTreePeople` → `people.listTree`. `pictureBytes` → `media.get`.
  - **Places:** `Place.familyId` is removed; `PlaceInputDto` replaces `buildPlaceInsert`.
  - **Profile:** `ProfileApi` maps `BirthVisibility` (`year_month` ↔ `yearMonth`), and `downloadAvatar` uses `media.get`.
  - **D1:** delete `updateEmail` and `EmailUpdate`. Settings shows the email read-only, with no new copy: the existing field becomes non-editable.
- **Tests:** `people_api_test` (drop the PostgREST stub group; add `fromDto` tests), `places_api_test`, `profile_api_test`, the `settings_page`/`settings_guard` D1 tests, and the `ProfileGateway` fakes. Live: person create/update with a picture, tree list with birth coarsening, `markPassedAway`, places create/markUsed/favorite/recents, and profile saveAccount/avatar.

### 4e Photos, notes, reader
- **Owns:** `lib/data/photos_api.dart`, `lib/data/comments_api.dart`, `lib/data/perspectives_api.dart`, `features/stories/story_reader_page.dart` (the live swap, the D4 delete action and the `relationship` line), and `features/perspectives/add_perspective_page.dart` if it needs touching.
- **Change:**
  - **Photos:** `PhotosApi` = `photo.list` / start → upload → finish / `photo.delete` / `photo.setHero` / `media.get`. Keep `compressStoryPhoto`, `ensurePhotoCap`, `photosWithHeroFirst` and `comparePhotoOrder`, plus one `PhotoUploadBinary` seam for tests. Delete `deleteAllForStory`.
  - **Notes:** comments and perspectives use `note.*` with their kind, and `Comment` / `Perspective` gain `canDelete`.
  - **Reader (D4):** shows the existing delete action on any note whose `canDelete` is true, not only on the user's own notes. No new copy.
- **Tests:** `photos_api_test` (keep compression, cap and hero order; delete the storage tests), the comments/perspectives tests (`fromNote`), and a `story_reader_page_test` for a steward seeing delete on others' notes. Live: the upload/list/hero/delete round trip, comments and perspectives CRUD, and `canDelete` as owner versus member.

### 4f e2e and CI
- **Owns:** `apps/tell_me_a_story/integration_test/**`, `e2e/` (delete `relay.ts`; keep `check_flows.sh`), `.github/workflows/ci.yml` (only the e2e job), and the `justfile` `run` recipe (`--dart-define=SERVER_URL=http://127.0.0.1:8080`; the Supabase defines go in 4z).
- **Change:**
  - **Sign-in:** `e2e_test.dart` signs in by typing `111111`; `_signIn` and C1/C6 use the code step.
  - **Support files:** `prod_guard` checks that `Env.serverUrl` is local. `preconditions` signs out through `serverClient.auth`. The app is mounted the way `main.dart` does it after 4a.
  - **C1:** renamed "C1 email-code sign-in lands on timeline" in both `flows.md` and the test. Its owning paths change `core/supabase/` to `core/server/`.
  - **CI job:** starts `just server` instead of `supabase start`, waits for :8080, then runs `flutter drive` with `SERVER_URL`. Mailpit, Deno and the relay steps are dropped.
- **Verification:** `bash e2e/check_flows.sh` passes. The full e2e run happens in 4z, because it needs every gateway switched.

### 4z Integration and switch (sequential, after all slices merge into `feat/p4-cutover`)
1. **Finish the cross-slice swaps:**
   - `story_reader_page.dart` and `timeline_page.dart` construct `ServerTimelineLive()` (4c's) instead of `SupabaseTimelineLive()`;
   - `StoriesApi.discard` calls `story.discard` (4e removed client-side photo cleanup; the server queues the blobs);
   - delete `storyPhotosBucket` once no thumbnail is downloaded from Supabase storage;
   - `Story.photoPaths` are server blob keys, which `media.get` / `getMany` read;
   - the e2e calls into `StoriesApi` / `PlacesApi` match the merged signatures.
2. **Remove Supabase from the app:**
   - remove `supabase_flutter` from `apps/tell_me_a_story/pubspec.yaml`;
   - delete `lib/data/supabase_errors.dart`, `test/supabase_errors_test.dart` (keep its `appErrorMessage` test next to `app_exception`) and `test/gateway_errors_test.dart`;
   - remove the Supabase defines from the `justfile` `run` recipe.
3. **Check nothing is left:** `rg -n "supabase|Supabase|PostgrestException|GoTrue" apps/tell_me_a_story/lib apps/tell_me_a_story/test apps/tell_me_a_story/integration_test` returns nothing.
4. **Gates:**
   - format;
   - `flutter analyze` with at most 23 issues;
   - `flutter test`;
   - `just test-live` and `just server-test`;
   - `bash e2e/check_flows.sh`;
   - the e2e run locally (`flutter drive` against `just server` with ChromeDriver);
   - a manual browser smoke of sign-in → create family → story with photo → comment → invite → accept as a second user.
5. **Docs:**
   - endpoint-contract §3/§4 are marked done, with the changes made here;
   - the roadmap Phase 4 row is updated;
   - the Phase 5 plan follows (delete `supabase/`, Deno, pgTAP; rewrite `AGENTS.md`/README).
6. **Merge:** `git merge --no-ff feat/p4-cutover` into `feat/serverpod-migration`.

---

## Exit criteria for Phase 4
- The app runs against `just server` only, and no Supabase code or package is left in `apps/tell_me_a_story`.
- `flutter test` passes, `flutter analyze` reports at most 23 issues, and `just test-live`, `just server-test`, `e2e/check_flows.sh` and the local e2e run pass.
- D1 (read-only email) and D4 (steward delete on notes) are visible in the app. The new code-entry copy is the approved text.
