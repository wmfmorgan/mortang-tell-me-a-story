## M13 Fit & Finish (Gilfoyle, LOCKED by Bill 2026-10-11)
The product and UI are locked on the PRD M13 section and on the UXD section "M13 — Fit & Finish (LOCKED Bill 2026-10-11)" (Stitch project `12192342757314667328`, 12 screens). Build order: M11b ships first and M13 is held until then. The M13 migration sorts after M11b's `20261011200000_start_a_timeline.sql`, and it assumes the M11a, M11a.2 and M11b policies and helpers are on main. Every new function and trigger follows the M11a.2 hardening standard: `set search_path = ''` and schema-qualified names. Items 1, 2, 4 and 5 (blurred modals, create buttons, Macro dot opening the reader, zoom out on empty space) are client-only and need no architecture. This section covers item 3 (partial dates), item 6 (landing and sign in), item 7 (invite sign in) and item 8 (Edit a story).
### Partial dates: data (new migration; do not edit earlier files)
- New enum `public.story_date_precision as enum ('decade', 'year', 'month', 'day')`. The declaration order is the sort order: less precise sorts first. Clients may never write `decade`. It exists only for legacy rows.
- `stories.date_precision public.story_date_precision not null`. The migration adds it nullable, backfills it, then sets it not null.
- `stories.created_at timestamptz not null default now()`. Backfill is `coalesce(published_at, now())`. This is the tie-break that clarification 5 needs.
- `timeframe_start` and `timeframe_end` stay as the canonical storage. A partial date is stored as the full period it covers, and `timeframe_end` becomes `not null`. Backfill sets `timeframe_end = timeframe_start` where it is null.
	- `day`: start = end.
	- `month`: start is the 1st, end is the last day of that month.
	- `year`: Jan 1 to Dec 31 of that year.
	- `decade` (legacy only): Jan 1 of a year ending in 0 to Dec 31 nine years later.
- Backfill derives `date_precision` from the shape of the range, using the four patterns above, after the end-null fix. Any row that matches none of them makes the migration `raise exception`, listing the ids. No silent guessing. Today's capture writes only decade ranges, so this should be empty apart from decades.
- CHECK `stories_date_shape` enforces the shape for each precision, plus `extract(year from timeframe_start) between 1000 and 9999`. It replaces `stories_timeframe_end_gte_start`, because the shape implies it.
- Trigger `stories_date_guard` (BEFORE INSERT OR UPDATE):
	- INSERT with `decade` raises `VALIDATION: year required`.
	- UPDATE that sets `decade` is allowed only when the old row was `decade` and both dates are unchanged. A legacy story can keep its decade through unrelated updates, but nobody can create a decade.
- Index: drop `stories_family_id_timeframe_idx` and create `stories_family_id_order_idx on (family_id, timeframe_start, date_precision, created_at, id)`.
- Realtime already uses replica identity full, so the new columns come along with no change.
### Partial dates: one ordering, one decade rule
- Canonical order everywhere (server `.order` and client sorts): `timeframe_start asc, date_precision asc, created_at asc, id asc`. That gives 1980s, then 1987, then January 1987, then January 1, 1987, then ties by created. A partial date sits at the start of its period because it is stored there.
- Newest-first views (decade bands and rows) use the exact reverse of that full key. Never sort on `timeframe_start` alone again. `listPublished`, `listMyDrafts`, `decadeBands`, the decade sorts, rows and the search result sort all use it.
- Decade of a story = `decadeStartYear(timeframe_start)` for every precision. This one rule feeds the Macro and Mid decade bands, decade dimming (`farFadeBand` logic is unchanged, it just gets the bands), branch-ring decade placement, and the Search Timeframe filter (clarification 4). Search changes from range overlap to `decadeStartYear(timeframe_start) in selectedDecades`.
- M11a origin placement: no change. The origin dot is drawn at its own `timeframe_start` and takes the canonical order. The parent ring sits beside it as locked. `branch_year` is untouched.
- M11b year prefill: the create modal reads the year of the origin's `timeframe_start`, which is correct for every precision. No change.
### Partial dates: client contract
- One Dart value type, `StoryDate { int year; int? month; int? day; }`, plus a legacy `decade` case read from rows only. Methods: `precision`, `toRange()` (start and end per the shapes above), `fromRow(start, end, precision)`.
- One formatter, `storyDateLabel(start, precision)`: `decade` gives "1980s", `year` gives "1987", `month` gives "March 1987", `day` gives "March 14, 1987". The reader meta line ("Recorded event: …"), drafts list, Macro tooltip, timeline year labels and the date picker's "Shows as" preview all use it. `decadeChipLabel`, the reader decade pill, `TimeframeChips` and `DecadeRange` capture are deleted. Search keeps its own decade chip list for the filter.
- Writes send `timeframe_start`, `timeframe_end` and `date_precision` from `StoryDate.toRange()`. The update patch must be able to set `timeframe_end`, so remove the skip-when-null branch.
- The picker validates in the client first, with the UXD inline errors ("Enter a four-digit year.", "That day isn't in that month."). The server CHECK and trigger are the backstop. On a server `23514` or `VALIDATION`, show the existing save-failed surface.
- A legacy `decade` story: the reader shows "1980s". The picker opens empty, so Save draft, Publish and Save changes stay disabled until a Year is entered (clarification 2).
- Photo gating (clarification 3): Add photo is enabled only when the form's `StoryDate` has a year. This stays client-side, as it is today. No new photo policy.
### Edit a story (item 8): access
- New helper `public.can_edit_story(sid uuid) returns boolean`, security definer, stable, `set search_path = ''`, `(select auth.uid())`. A null uid returns false. It is true when the story exists, its family is live, and either:
	- the caller is `author_id` and `is_live_family_member(family_id)` (drafts and published), or
	- the story is `published` and the caller is `owner` or `co_owner` of the story's own `family_id`.
- Owners and co-owners of a parent or child family in the same tree do not qualify. This supersedes M11a's "Only the author edits the story" for owners and co-owners only.
- `stories_update_author` is recreated as `stories_update_editor` with `using/with check (public.can_edit_story(stories.id))`.
- In `story_people`, the insert, update and delete policies swap their author check for `can_edit_story(story_id)`. Each keeps its name, minus the suffix change from `_author` to `_editor`.
- In `photos`, only the story-author branch (`s.author_id = auth.uid()`) of `photos_update_uploader_or_author` and `photos_delete_uploader_or_author` is replaced, by `public.can_edit_story(photos.story_id)`. Each policy keeps its existing M11a family gate (`can_contribute_to_story` / `is_family_member`). Insert is unchanged. `photos_guard_update` (M11a.2, only `sort_order` may change) is unchanged.
- Child-timeline photos on an origin story (Bill, 2026-10-11): the parent timeline's owners and co-owners may remove a photo a child-timeline member added to the parent's origin story. The child timeline's owners still can't edit that story. Every photo of a story, including a child member's upload, is stored under the story's own family folder (`storyPhotoStoragePath(familyId: story.familyId, …)`), so the parent's owners and co-owners already pass `is_family_member(folder[1])` on `story_photos_delete_member`. No storage policy change in M13 (corrected 2026-10-11 after Big Head checked main at `3158f38`).
- Client: the reader's and the edit form's photo Remove shows for the uploader or when the caller can edit the story. This replaces M11a.2's own-photos-only Remove.
- Comments and perspectives are unchanged: own-author only.
- Trigger `stories_edit_guard` (BEFORE UPDATE, security invoker, `set search_path = ''`) raises `FORBIDDEN: field is locked` on any change to `author_id`, `family_id` or `created_at`. When the caller isn't `author_id`, it also locks `status` and `published_at`, so an owner can edit content but can't unpublish or republish someone else's story.
- Policies are dropped and recreated in place. The count is 44 after M11b and stays 44 after M13, with no net new policies.
- Concurrent edits are last write wins, the same as draft saves today. No locking.
### Edit a story: client
- New route `/stories/:storyId/edit`. It reuses the New story form in edit mode: "Edit story", prefilled, with Cancel and Save changes. Save writes through the existing draft-update path (story row patch, story_people diff, photos), then returns to the reader. No new RPC.
- The reader's Edit button shows when the caller is the author, or when the story is published and the caller's membership in `story.family_id` is `owner` or `co_owner`. The server is the real gate.
### Landing and sign in (item 6)
- Route `/` stays the public page, rebuilt to Mugatu's landing screens. Magic link only: `signInWithOtp(email, emailRedirectTo: origin)`. "Send it again" repeats the same call. "Use a different email" resets the form. Bad email is client-side.
- Signed-in visitors redirect per the M10 landing rule. That's unchanged.
- No password, social or Forgot-password paths. Supabase Auth config is otherwise unchanged.
### Invite sign in (item 7, clarifications 6 and 7)
- New public route `/invite/:token`. `buildInviteUrl` changes to `${INVITE_APP_ORIGIN}/invite/<token>`.
- Links that were already sent still work: the router rewrites `/timeline?invite=X` and `/?invite=X` to `/invite/X`. After that, the `?invite=` carry-through in the router and `auth_callback` is removed.
- On load, the page calls `validate-invite-token`. That function gains:
	- `inviter_name` = `profiles.display_name` of `invited_by`, or null. When it is null, the page omits the "\{Inviter\} invited you to \{Family\}." line rather than inventing a name.
	- An `INVITE_INVALID` result when the invite's family is soft-deleted.
- Any `valid:false` result (invalid, expired, cancelled, accepted) renders the single dead-link state. The response stays limited to `{valid, code, message, family_id, family_name, inviter_name, status, expires_at}`: no emails, no ids beyond `family_id`. An invalid result is a 200 body with `valid: false`, a `code` (`INVITE_INVALID`, `INVITE_EXPIRED`, `INVITE_ACCEPTED`) and a fixed `message`, the way it's shaped today. It does not go through `mapRpcError`. (Factual fix, Gilfoyle 2026-10-11: `code` and `message` already exist on main.)
- The signed-out path calls `signInWithOtp` with `emailRedirectTo: ${origin}/invite/<token>`, so the token survives the email round trip. Auth `additional_redirect_urls` adds `${site}/invite/**` for local and prod.
- When the visitor is signed in (already, or on return from the link), the app calls `accept-invite` once. Success opens that family's timeline, using the existing family-selection path. Failure shows the dead-link state. Errors are no longer swallowed.
### Tests (mandatory)
- pgTAP, partial dates:
	- Backfill gives a decade range `decade` and sets a null end to start.
	- The CHECK rejects a bad shape for each precision and a year outside 1000–9999.
	- INSERT with `decade` is refused.
	- A legacy decade row survives an unrelated update, but can't move its dates while staying `decade`.
	- Ordering of decade, year, month and day at the same start, then `created_at`.
- pgTAP, `can_edit_story` matrix:
	- The author can edit their draft and their published story.
	- The owner and the co-owner can edit a published story but can't edit someone's draft.
	- A member, a parent-family owner, a child-family owner, a non-member and a no-uid caller are all denied.
	- Nobody can edit in a soft-deleted family.
	- A non-author editor changing `status` gets `FORBIDDEN`. Anyone changing `author_id` or `family_id` gets `FORBIDDEN`.
	- An editor can manage `story_people` and delete photos.
	- A parent owner or co-owner deletes a child member's photo on the origin story, both the row and the storage object at `<story family>/<story>/<photo>.<ext>`, the path the app writes. A child-timeline owner can't edit the origin story or delete that photo.
	- The policy count is still 44.
- Edge (Deno): `validate-invite-token` returns `inviter_name`, and returns `INVITE_INVALID` for a soft-deleted family.
- Flutter:
	- `StoryDate` round-trip and labels.
	- Picker: Day disabled until Month is filled, clearing Month clears Day, and both inline errors.
	- Legacy decade story opens with an empty picker and can't be saved.
	- Photo gating.
	- Canonical sort.
	- Search decade filter on partial dates.
	- Edit button gate.
	- `/invite/:token` live, dead and signed-in paths, plus the legacy `?invite=` rewrite.
	- `emailRedirectTo` carries the invite path.
### Open questions (Mugatu)
- `signInWithOtp` rate-limit error (429) on "Send it again": no copy is locked. Until Mugatu specifies it, the build shows the existing request-failed inline error.
