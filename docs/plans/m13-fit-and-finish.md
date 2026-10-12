# M13 Fit & Finish — plan

> Planning only. No app code in this pass.
> After approval, put this file at `docs/plans/m13-fit-and-finish.md` on branch `feat/m13-fit-and-finish` from `origin/main` `59f91a98da1921a6141581fffbe2148d0f46db49` (PR #28). Open a **draft** PR titled `plan(m13): Fit & Finish`. Do not push to main. Do not merge. The build, after Bill approves the plan, continues on this same PR.
>
> Re-read 2026-10-12T01:11Z. Impl Spec §15 M13 is **READY**. Where this plan and §15 differ, §15 wins. Where §15 and the Design Doc differ on SQL, RLS, or contracts, the Design Doc section "M13 Fit & Finish" wins. Chat is not a lock.
>
> Trinity's review of this draft is deferred to H1 by Bill ("hold off on trinity until the hardening milestone"). Do not touch H1. Do not stamp READY or CLOSED.

## What ships

Eight items. One migration. One Edge edit (`validate-invite-token`). One new route (`/invite/:token`) and one edit route (`/stories/:storyId/edit`). No new table, Edge function, or package. No storage policy change. Policy count stays 44.

| Item | What | Files |
| --- | --- | --- |
| 1 Blurred modals | Whole page behind every modal dimmed and blurred. Parchment card, Newsreader title. No `AlertDialog`. Dropdown menus stay unblurred. | `lib/core/theme/album_chrome.dart` (`showAlbumDialog` is still `showDialog`), `lib/features/invites/invite_modal.dart`, `lib/features/people/add_person_modal.dart`, `lib/features/places/place_picker_modal.dart`, `lib/features/perspectives/add_perspective_page.dart`, `lib/features/family/start_family_dialog.dart`, `lib/features/family/family_blur_dialog.dart`, `lib/features/family/delete_family_dialog.dart`, `lib/features/family/transfer_ownership_dialog.dart`, `lib/features/family/add_co_owner_dialog.dart`, `lib/features/stories/story_reader_page.dart` (Set as origin, origin delete warning), `lib/features/search/search_page.dart` (two `AlertDialog`s). Start a family keeps its existing sigma 5. Other confirms use the existing sigma-4 / scrim `0x662C2416` shell. |
| 2 Plus-circle creates | No "+" glyph in a create label. Filled circle left of the label: terracotta circle, white plus, on parchment or outline; parchment circle, terracotta plus, on the filled terracotta New story button. About 20px on chips and small buttons, 32px on the Add photo tile. Labels: "New story", "Add co-owner", "Start a family", "Add person", "Create new person", "Add photo". Add co-owner still hides at two. Invite stays a plain button, no circle. Do not strip "+" from "+ Add comment" or "+ Add your perspective". | `lib/core/theme/album_header.dart`, `lib/features/family/manage_families_page.dart`, `lib/features/family/manage_family_page.dart`, `lib/features/people/add_person_modal.dart`, `lib/features/stories/new_story_page.dart`, `lib/features/stories/story_reader_page.dart` (photo add; today "Add photos"), `lib/features/stories/photo_strip.dart`. |
| 3 Partial dates | Enum, columns, backfill, CHECK, trigger, index. Three boxes on the Timeframe card. One sort key. One decade rule. | Migration below. `lib/data/stories_api.dart`, `lib/features/stories/timeframe_chips.dart` (delete capture use), `lib/features/stories/reader_meta.dart`, `lib/features/stories/new_story_page.dart`, `lib/features/stories/story_reader_page.dart`, `lib/features/drafts/drafts_page.dart`, `lib/features/timeline/timeline_page.dart`, `lib/features/timeline/timeline_zoom.dart`, `lib/data/search_api.dart`. New `lib/features/stories/story_date.dart`. |
| 4 Macro dot | Tap a story dot on Macro opens the reader modal. Close returns to Macro at the same spot. Year chip and decade label still open Mid. Mid rail circle still opens Full Cards. | `lib/features/timeline/timeline_page.dart`. Supersedes the §10 sentence that still sends the Macro story dot to Mid. |
| 5 Empty-space zoom | Click or tap on empty space: Full Cards → Mid → Macro. Macro does nothing. Dots, stubs, cards, chips, rings, labels, header, and the zoom switch keep their taps. The pill still slides. | `lib/features/timeline/timeline_page.dart`. |
| 6 and 7 Landing | Route `/` rebuilt to Stitch `1939575036dd4c9396d124461df8572f` and `6cdb77ad4e204d29be8cc3dc875e6607`. Magic link only. | `lib/features/auth/magic_link_page.dart`. Signed-in redirect stays `appStartPath` in `lib/core/router/app_router.dart`. |
| 7 Invite sign-in | Public `/invite/:token`. Legacy `?invite=` rewrites here, then the query carry-through comes out. | `lib/core/router/app_router.dart`, `lib/features/auth/invite_sign_in_page.dart` (new), `lib/features/invites/invite_accept.dart`, `lib/data/invite_api.dart` (`buildInviteUrl`), `supabase/functions/validate-invite-token/index.ts`, `supabase/config.toml`. |
| 8 Edit | Author, or owner/co-owner of the story's own live family, edits a published story. Author still edits their draft. Route `/stories/:storyId/edit`. | Migration below. `lib/features/stories/new_story_page.dart`, `lib/features/stories/story_reader_page.dart`, `lib/core/router/app_router.dart`, `lib/data/stories_api.dart`. |

Stitch project `12192342757314667328`. Screens: date picker `a9fd84de2e094f6e9e234c8fb9387a94` (not `5b929a4c`); Add person blur `d1f8f94f2e0c45ffb59836f7c2636c22`; family detail creates `4173413ee3894a5c9fe7e8081981235a`; landing `1939575036dd4c9396d124461df8572f`; check email `6cdb77ad4e204d29be8cc3dc875e6607`; invite sign-in `830d27ceec9c412a8826d8303d56689b`; invite check email `5f80ed88432f42a2a9ca78faee4db746`; reader partial date `d4eb7bc3dc19455b8adb2d3cb312160e`; dead link `8855fdcf599348ec8150295218ccd1d0`; reader with Edit `bdedfd1f423046ed9a1567b739eb2ea2`; New story top `125b2d23e0ef4e42a4f4b9a81e07a86b`; New story bottom `c91ba67e72bc4cc7b369ae7785e87dfb`. Items 4 and 5 have no screen.

Build the UXD rule where a mock disagrees: keep the two-column New story layout `30237cf012c74948b863c02cb860223a` and swap only the Timeframe card and the create chips. Ignore the date-picker mock's word count, "All changes saved", and the literal "nn". Preview is one line, "Shows as: March 14, 1987". Year and Day values are left-aligned. Ignore the full-form mocks' icon badges, heading sizes, card gaps, "STORY ENTRY", and "RIVERTOWN". On Family detail the plus-circle sits inline left of "New story". Add person blur covers the full viewport. The reader keeps the M9 hero photo, no caption, no Print, no Share. Tokens: terracotta `#8B5E4B`, parchment `#FBF7F2`, ink `#2C2416`.

## Migration

One file, `supabase/migrations/20261011210000_fit_and_finish.sql`. It sorts after `20261011200000_start_a_timeline.sql`. Do not edit earlier migrations. Apply with `supabase migration up --local` only. Never `db reset`, `db pull`, or `migration down`. If a statement needs a fix, re-run only the changed statements locally.

`stories_date_guard` and `can_edit_story` and `stories_edit_guard` use `set search_path = ''` and schema-qualified names. `(select auth.uid())`. A null uid fails closed (`can_edit_story` returns false).

Contents, and nothing else:

- `public.story_date_precision as enum ('decade', 'year', 'month', 'day')`. Declaration order is the sort order. Clients never write `decade`.
- Add `stories.date_precision` nullable, backfill, then `not null`.
- Add `stories.created_at timestamptz not null default now()`. Backfill `coalesce(published_at, now())`.
- Backfill `timeframe_end = timeframe_start` where null, then `timeframe_end` is `not null`.
- Shapes: `day` start = end. `month` is the 1st through the last day of that month. `year` is Jan 1 through Dec 31. `decade` (legacy only) is Jan 1 of a year ending in 0 through Dec 31 nine years later.
- Backfill `date_precision` from those four shapes after the null-end fix. Any other row `raise exception` and lists the ids. No guessing.
- CHECK `stories_date_shape` enforces each shape plus `extract(year from timeframe_start) between 1000 and 9999`. Drop `stories_timeframe_end_gte_start` (`supabase/migrations/20260923000002_ddl.sql`). The shape implies end ≥ start.
- Trigger `stories_date_guard` BEFORE INSERT OR UPDATE. INSERT of `decade` raises `VALIDATION: year required`. UPDATE that sets `decade` is allowed only when the old row was `decade` and both dates are unchanged.
- Drop index `stories_family_id_timeframe_idx`. Create `stories_family_id_order_idx on (family_id, timeframe_start, date_precision, created_at, id)`.
- Realtime replica identity stays full. No publication change.
- `public.can_edit_story(sid uuid) returns boolean`, security definer, stable. True when the story exists, its family is live, and either the caller is `author_id` and `public.is_live_family_member(family_id)` (drafts and published), or the story is `published` and the caller is `owner` or `co_owner` of that story's own `family_id`. Parent and child owners in the same tree do not qualify. Revoke from `public` and `anon`. Execute to `authenticated` only.
- Drop `stories_update_author`. Create `stories_update_editor` with `using` / `with check (public.can_edit_story(stories.id))`.
- `story_people` insert, update, and delete swap the author check for `public.can_edit_story(story_id)`. Names: `story_people_insert_editor`, `story_people_update_editor`, `story_people_delete_editor`. Insert and update keep the TMAS-24-01 same-family person check.
- In `photos_update_uploader_or_author` and `photos_delete_uploader_or_author`, replace only the story-author branch with `public.can_edit_story(photos.story_id)`. Keep the names. Keep the M11a family gate (`can_contribute_to_story` on update; `is_family_member(photos.family_id) or can_contribute_to_story(...)` on delete) and the uploader branch. Photo INSERT unchanged. `photos_guard_update` and `photos_cap_insert` unchanged. No storage policy is dropped or created. `story_photos_delete_member` stays as pinned in M11a.2.
- Trigger `stories_edit_guard` BEFORE UPDATE, security invoker. Raises `FORBIDDEN: field is locked` on any change to `author_id`, `family_id`, or `created_at`. When the caller is not `author_id`, it also locks `status` and `published_at`.

Policy count stays 44. The six recreated policies are pinned in the new pgTAP file by exact name and exact `qual` / `with_check`, copied from this migration. `supabase/tests/origin_stories_hardening.sql` today pins the pre-M13 text of `photos_update_uploader_or_author` and `photos_delete_uploader_or_author`. Those two asserts, and any assert in that file for `stories_update_author` or `story_people_*_author`, move out. The new file owns the new text. Every pin for a policy this migration does not touch stays in the hardening file and must still pass. That test edit is not an edit of an earlier migration.

`stories_delete_author` is unchanged. Comments and perspectives stay own-author only.

## Sort and dates on the client

Canonical order, server `.order` and client sorts: `timeframe_start asc, date_precision asc, created_at asc, id asc`. Newest-first views use the exact reverse of that full key. Never sort on `timeframe_start` alone. That covers `listPublished`, `listMyDrafts`, `decadeBands`, decade sorts, timeline rows, and the search result sort. Today `stories_api.dart` orders `listPublished` and drafts by `timeframe_start` only, and `updateDraft` skips a null `timeframe_end`. The patch must be able to set `timeframe_end`.

Decade of a story is `decadeStartYear(timeframe_start)` for every precision. That feeds Macro and Mid bands, `farEdgeOpacity` (band math unchanged), branch-ring decade placement, and Search. Search decade filter changes from range overlap (`search_api.dart`) to `decadeStartYear(timeframe_start) in selectedDecades`. Search keeps its own decade chip list. Delete capture `TimeframeChips`, capture `DecadeRange`, the reader decade pill, and the reader/timeline `decadeChipLabel`. `search_api.dart`'s `decadeChipLabel(List<int>)` stays; it labels the filter chip, not a story.

`StoryDate` is `{ int year; int? month; int? day; }` plus a legacy `decade` case read from rows only. Methods: `precision`, `toRange()`, `fromRow(start, end, precision)`. `storyDateLabel`: "1980s" / "1987" / "March 1987" / "March 14, 1987". Used by the reader "Recorded event" line, drafts, the Macro tooltip, timeline year labels, and "Shows as".

Picker: three plain boxes, Year / Month / Day. No precision selector. Year required, four digits. Month is a January–December dropdown. Day is 1–31, disabled until a month is set. Clearing Month clears and disables Day. Helper: "Year is required. Add the month or day only if you remember. Day unlocks after Month." Preview: "Shows as: 1987" · "Shows as: March 1987" · "Shows as: March 14, 1987". Inline errors: "Enter a four-digit year." · "That day isn't in that month." Writes send `timeframe_start`, `timeframe_end`, and `date_precision` from `toRange()`. Client validates first. On `23514` or `VALIDATION`, show the existing save-failed surface.

A legacy `decade` row shows "1980s" on the reader. The picker opens empty. Save draft, Publish, and Save changes stay disabled until a Year is entered.

Add photo is enabled only when the form's `StoryDate` has a year. No new photo policy.

Reader, screen `d4eb7bc3`: add "Recorded event: …" from `storyDateLabel` at the precision entered. It replaces the decade chip. The M9 "Documented … by {author}" line and avatar stay. Do not ship "4 min read".

M11a origin placement is unchanged. M11b year prefill is unchanged: it already reads `timeframeStart.year`.

## Edit client

Route `/stories/:storyId/edit`, registered as a literal beside the reader, reuses the New story form. Title "Edit story". Header actions "Cancel" and "Save changes" (terracotta) instead of Save draft / Publish. Prefilled, including the three boxes. Save uses the existing draft-update path (story row, `story_people` diff, photos) and returns to the reader. Cancel returns with no write. No new RPC. Last write wins. No locking.

Outlined Edit button with a pencil at the top right of the story content, next to the title. The reader header is otherwise unchanged. Show it when the caller is the author, or when the story is published and the caller's membership in `story.family_id` is `owner` or `co_owner`. The server is the real gate.

Photo Remove shows when `canEditStory || (_canWrite && photo.uploaderId == uid)`. This replaces the M11a.2 own-photos-only gate. A parent owner or co-owner sees Remove on a child member's photo on the origin story. A child-timeline owner does not. A child member whose origin changed sees no Remove on their own photo. Storage path stays `<story family>/<story>/<photo>.<ext>`. Parent owners already pass `is_family_member` on that folder. No storage policy change.

## Landing and invite

Copy, exactly: headline "Your family's stories, kept together." Card "Sign in or get started" and "Enter your email to access your family archive." Button "Email me a sign-in link". Sent state "Check your email". Footer "Private to your family. Stories stay inside the family you share them with." `signInWithOtp(email, emailRedirectTo: origin)`. "Send it again" repeats that call. A 429 keeps the sent card and shows the existing inline request-failed error. No new sentence. "Use a different email" resets the form. A bad email is client-side: "Please enter a full email address." No password, Google, Apple, or "Forgot password". Signed-in visitors still follow the M10 landing rule.

`buildInviteUrl` becomes `${INVITE_APP_ORIGIN}/invite/<token>`. The router rewrites `/timeline?invite=X` and `/?invite=X` to `/invite/X`. After that rewrite, remove the `?invite=` carry in `app_router.dart` and the auth callback.

`/invite/:token` calls `validate-invite-token` on load. Add `inviter_name` (`profiles.display_name` of `invited_by`, or null). A null name omits "{Inviter} invited you to {Family}." Do not invent a name. A soft-deleted family returns `valid: false` with `code: "INVITE_INVALID"`. Invalid results stay HTTP 200: `valid: false`, `code` one of `INVITE_INVALID`, `INVITE_EXPIRED`, `INVITE_ACCEPTED`, and a fixed `message`. This function does not call `mapRpcError`. Keys, and no others: `{valid, code, message, family_id, family_name, inviter_name, status, expires_at}`. No emails. No ids beyond `family_id`.

Codes already on main, and M13 does not remap them: a `revoked` invite returns `INVITE_INVALID` with `status: "revoked"`. A stored status `expired` returns `INVITE_INVALID`. `INVITE_EXPIRED` is only a `pending` invite whose `expires_at` has passed. `code` does not match `status` one-to-one. The client does not branch on `code`. Any `valid: false` paints screen `8855fdcf` and the sentence "This invite link no longer works. Ask your family for a new one."

Signed out: `signInWithOtp` with `emailRedirectTo: ${origin}/invite/<token>`. Signed in, or back from the link: call `accept-invite` once. Success opens that family's timeline through `FamilySelection`. Failure shows the dead-link state. Do not swallow the error.

Page copy: family monogram (M10 rule), kicker "YOU'RE INVITED", title "Join {Family}", body "{Family} keeps its stories on Tell Me a Story. Sign in with your email to read them and add your own.", then "{Inviter} invited you to {Family}." Sent state: "We sent a sign-in link to {email}. Tap it to join {Family}." No inviter photo.

`mapRpcError` in `supabase/functions/_shared/manage.ts` stays the four prefixes `NOT_FOUND:`, `FORBIDDEN:`, `VALIDATION:`, `INVITE_INVALID:`, matched with `startsWith`. No fifth prefix. An unprefixed database error stays `Try again`. New M13 database errors use one of those four prefixes. `VALIDATION: year required` and `FORBIDDEN: field is locked` already fit.

§12 catalog is unchanged: `AUTH_REQUIRED`, `FORBIDDEN`, `NOT_FOUND`, `VALIDATION`, `INVITE_INVALID`, `INVITE_EXPIRED`, `INVITE_ACCEPTED`, `RATE_LIMITED`, `STORAGE_FAILED`. Shape `{ "code", "message" }`. The validate 200 body is the exception the playbook already describes. It is not a new code.

## Auth redirects

`supabase/config.toml` `additional_redirect_urls` today lists `http://127.0.0.1:3000` and `http://localhost:3000`. Add `http://127.0.0.1:3000/invite/**` and `http://localhost:3000/invite/**`. Landing `emailRedirectTo` stays the origin, which is already listed. Do not add a production host in this PR. See Blocked.

## Tests

Red first, then the code that turns them green. Paste `supabase test db`, `deno test`, `flutter test`, and `flutter analyze` in the PR body. There is no CI.

### pgTAP — `supabase/tests/fit_and_finish.sql`

- Backfill gives a decade range `decade` and sets a null end to start.
- The CHECK rejects a bad shape for each precision and a year outside 1000–9999.
- INSERT with `decade` is refused (`VALIDATION: year required`).
- A legacy decade row survives an unrelated update but can't move its dates while staying `decade`.
- Ordering of decade, year, month, and day at the same start, then `created_at`.
- `can_edit_story`: author true on a draft and on a published story. Owner and co-owner true on a published story, false on someone else's draft. Member, non-member, and no-uid caller false. A parent-family owner and a child-family owner false. Nobody in a soft-deleted family.
- Edit guard: a non-author editor changing `status` or `published_at` raises `FORBIDDEN: field is locked`. Anyone changing `author_id`, `family_id`, or `created_at` raises `FORBIDDEN: field is locked`. An owner's title, body, or date edit on a published story succeeds.
- An editor can insert, update, and delete `story_people` and delete photos. A cross-family person link is still rejected.
- Origin-story photo, on the real path `<story family>/<story>/<photo>.<ext>`: a parent owner and a parent co-owner delete a child member's photo. Both the `photos` row and the `story-photos` object are gone. The child-timeline owner deletes 0 rows and 0 objects and cannot update the origin `stories` row.
- Unchanged: `can_contribute_to_story` still denies an outsider. `photos_guard_update` still raises on a locked column. The 20-photo cap still holds.
- `can_edit_story` has `search_path=""` in `pg_proc.proconfig` and is called once with no "does not exist" errors. Anon has no execute. Policy count is 44.
- Exact `qual` / `with_check` pins, counted from the migration: `stories_update_editor`, `story_people_insert_editor`, `story_people_update_editor`, `story_people_delete_editor`, `photos_update_uploader_or_author`, `photos_delete_uploader_or_author`.

### Deno — `supabase/functions/validate-invite-token`

- Returns `inviter_name`, and null when the inviter has no name.
- A soft-deleted family returns HTTP 200, `valid: false`, `code: "INVITE_INVALID"`, and does not go through `mapRpcError`.
- An invalid result is HTTP 200 with `valid: false`, `code` one of `INVITE_INVALID`, `INVITE_EXPIRED`, `INVITE_ACCEPTED`, and a fixed `message`.
- The JSON has no keys beyond `{valid, code, message, family_id, family_name, inviter_name, status, expires_at}`.
- Every existing Edge test passes unchanged.
- A separate assertion, if one is added beside `create-branch-family/index_test.ts`, confirms `mapRpcError` still has exactly those four prefixes and no fifth. Do not change `mapRpcError` to make that true.

### Flutter

- `StoryDate` round-trip and `storyDateLabel` for all four precisions.
- The picker derives precision from the filled boxes (year, year+month, year+month+day). Year is required. Month is a January–December dropdown. Day stays disabled until a month is picked. Clearing Month clears and disables Day. Both inline errors. The "Shows as" preview. No precision selector and no decade chips in the form.
- A legacy decade story opens with an empty picker and cannot be saved.
- Photo gating needs a year.
- Canonical sort, including the reverse for newest-first views.
- `decadeStartYear(timeframe_start)` for every precision feeds bands, branch-ring decade placement, and the Search decade filter on partial dates.
- The reader shows "Recorded event: …" at the entered precision, in place of the decade chip. The "Documented … by {author}" line and avatar stay. No "4 min read".
- Edit button: author yes. Owner or co-owner of `story.family_id` on a published story yes. Member, other-family owner, and child-timeline owner no.
- Edit mode is titled "Edit story", with Cancel and Save changes, prefilled. Both return to the reader. The update patch sets `timeframe_end`.
- Remove shows for the uploader, and for an editor (author, or parent owner/co-owner on a child member's origin-story photo). Hidden for neither, including a child-timeline owner on the origin story.
- Every listed modal uses the blurred shell. No `AlertDialog`. Create labels have no "+" and show the plus-circle. Invite has none.
- A Macro dot opens the reader, and closing returns to Macro.
- Empty-space taps step Full Cards → Mid → Macro and do nothing on Macro. Taps on dots, cards, chips, rings, and labels do not zoom out.
- Landing: form, bad-email error, sent state, "Send it again", "Use a different email", the line "Enter your email to access your family archive." A 429 on "Send it again" shows the existing request-failed inline error and keeps the sent card.
- `/invite/:token` live, dead, and signed-in paths, plus the legacy `?invite=` rewrite. `emailRedirectTo` carries the invite path. The inviter line is omitted when `inviter_name` is null.

### Gates

- `flutter analyze` in `apps/tell_me_a_story` reports 29 or fewer issues. Do not clean up the existing 29.
- `flutter test` in `apps/tell_me_a_story` passes, and the count is at least 374.
- `supabase test db` passes. `deno test` passes.

Bill local smoke is the exit and is not claimed by the agent. The eight smoke steps are the playbook's list: three precisions sort and read back; a legacy decade story; owner edit and member with no Edit; parent owner removes a child member's origin photo and the child owner sees neither Edit nor Remove; Macro dot opens the reader and empty space zooms out one level; sign-in from the landing page; old `?invite=` and new `/invite/<token>`, signed out and signed in, and a used link shows the dead sentence; spot-check blur and plus-circles.

## Blocked

- **Production `/invite/**` host.** `config.toml` has no production site URL, and cloud staging is still OPEN. This plan adds only the two local invite wildcards. Owner: Bill, when a staging origin exists. Do not invent the host.

No other OPEN. §15 OPENs 1–8 are resolved. Jared's pending rewording of the PRD note does not block the locked "Recorded event" sentence (OPEN 7).

Stale sentences to ignore, not blocks: §1 still says Add photo waits for a decade. §6 and §10 are already amended. §10's timeline row still sends the Macro story dot to Mid. §10 still says no deep invite route. Follow §15 for those three.

## Risks

- Backfill `raise exception` stops `migration up` if any local story is not a decade range or a null-end single day. Do not guess a precision. Fix the row only if Bill says so. Do not reset the database.
- Recreating six policies will fail `origin_stories_hardening.sql` until the superseded pin asserts move. The count must stay 44, so a dropped policy has to be recreated in the same migration before the test runs.
- Removing `?invite=` carry before the rewrite is in place drops tokens on magic-link return. Land the rewrite and `/invite/**` together.
- `showAlbumDialog` is shared. A blur added there covers every caller. Dropdowns and popup menus must stay on their own widgets, not this helper.
- Search sorts and timeline bands that still key off `timeframe_start` alone will order a day before its year. The tests above are the check.
- `stories.created_at` contradicts the older M9 Design Doc line that forbade the column. The M13 Design Doc section adds it. Use the M13 section.

## Out of scope

Anything beyond the eight items. Owner or co-owner story delete. Edit rights for another timeline in the tree. An owner editing someone else's draft. Comment or perspective edits by anyone but the author. Unpublish or republish by a non-author. Edit locking. A precision selector or decade chips in capture. A server photo-date rule. Password, social, or "Forgot password". Inviter photos. Invite handling beyond the one dead-link state. Automatic invite linking (M14). Blur on dropdown menus. A new table, Edge function, or package. A storage policy change. Reopening M11a, M11a.2, M11b, or M12. H1, including Trinity's M13 review, Dinesh's M11a.2 nits 1–6, and Trinity follow-ups 01/02/03/05/06/07. The indented whole-tree Related families view. Editing earlier migrations. `db reset`, `db pull`, `migration down`. A fifth `mapRpcError` prefix. Stamping CLOSED.
