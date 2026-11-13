# R2 Shared header

> Gate: plan only until this plan is approved. Do not write application code before that.
>
> On approval: copy this file to `docs/superpowers/plans/2026-10-04-r2-shared-header.md` in the first commit. Worktree `.worktrees/feat-r2-shared-header`, branch `feat/r2-shared-header`, from **`origin/main` `cef8f13`**. The repo-root checkout is still `b30c697`. Do not branch from that checkout.

**Goal:** One header bar on the timeline, Drafts, and New story, matching Stitch screen `703158c2c064414883d9d1c1dff8902a` for the bar only. The family menu switches the family those screens already load. Exit is Bill local smoke. Open one PR. Do not merge. Do not claim Bill smoke.

**Architecture:** Paint and wiring only. `FamiliesGateway.listMine()` already returns this member's families. A process-memory id is consulted by `InviteApi.currentFamilyId()` when that id is one of those memberships. Timeline, Drafts, New story, and search already call `currentFamilyId()`. No new table, column, Edge function, package, or route.

**Tech stack:** Flutter 3.x, existing `albumTheme()` tokens, `go_router`, `supabase_flutter` PostgREST. Secrets stay `--dart-define` only.

## Sources (do not invent past these)

- Impl Spec §15 R2 playbook (OPEN): https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Stitch project `12192342757314667328`, screen `703158c2c064414883d9d1c1dff8902a` ("Locked Top Bar with Quiet Far-Zoom Timeline"). The `<header>` is the bar. The `<main>` (Macro Chronicle, sample decades, "Family Orchard Archive established") is a stand-in. Do not paint it.
- Code to change is the tree of `cef8f13` / M7 tip `8387401` (same tree), not the stub timeline on the stale checkout. Header today is `_TimelineHeader` in `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`. Drafts and New story use `AlbumTopBar` in `lib/core/theme/album_chrome.dart`.

## What the bar is

Left to right, one row, parchment `#FBF7F2`, bottom hairline `albumInk` at 15% opacity, height 72, horizontal padding 32 on a wide window:

1. Wordmark `Tell Me a Story`. Newsreader italic, about 24px, ink `#2C2416`, normal weight. Static text. Not a link, not a button.
2. A 1×20 hairline, ink at 15% opacity, between the wordmark and the family control.
3. Family menu. The stored `families.name` in Newsreader about 18px medium, plus `Icons.expand_more`. No sage fill, no groups icon, no "Jenkins". Empty stored name stays the existing `Family` fallback from `MemberFamily.fromJson`.
4. `Timeline`. Source Sans 3, 15px, medium. Active: full ink and a 2px ink underline. Inactive: ink at 70%. The underline is ink, not terracotta.
5. `Drafts` immediately after Timeline, same type and tap size. Not inside a More menu.
6. The existing search chip, key `timeline-search`. Pill (`StadiumBorder`), max width 224, fill ink at 4%, border ink at 10%, `Icons.search` and the label `Search archive...` in Source Sans 3 14px at ink 50%. One chip. It still pushes `/search`.

Right side, gap 16:

- `Invite` is ink text, Source Sans 3 15px medium, ink at 80%. The label is `Invite`, not `+ Invite`. It opens the existing Email/Link modal.
- `New story` is the only filled button: terracotta `#8B5E4B`, parchment label, `Icons.add`, pill, light shadow. It pushes `/stories/new`.

On `/stories/new` the right side drops `Invite` and `New story`. `Save draft` (secondary text button) and `Publish story` (filled terracotta) stay, with the same enable rules they have now. Do not rename `Publish story` to `Publish`.

The reader keeps its back control (`AlbumTopBar` leading `Timeline`). Search keeps its own bar (`SEARCH ARCHIVE`, field, filters). Add perspective keeps its current bar. Do not put this header on those three.

## Active item

| Route | Underline | Right side |
| --- | --- | --- |
| `/timeline` (far, mid, and near) | `Timeline` | `Invite`, `New story` |
| `/drafts` | `Drafts` | `Invite`, `New story` |
| `/stories/new` | neither | `Save draft`, `Publish story` |

`Timeline` goes to `/timeline` for the current family. From Drafts or New story use `context.go`. On the timeline it does not push a second timeline.

`Drafts` opens `/drafts` for the current family. If the bar is already on Drafts, the control stays and does not push another drafts route.

The family menu is on the bar at far, mid, and near. Today `_FamilyPill` is far/mid only. That split goes away.

## Family menu behavior

- The button shows the family whose id is the current `currentFamilyId()` result. Key `family-menu`.
- The menu lists `listMine()` rows. The current id is checked. One family still shows the button and one checked row. No "create family" row. No Stories, Family Members, Places, or Help rows.
- Choosing a row remembers that id in process memory (`FamilySelection`, a static field in `lib/data/family_selection.dart`). No `shared_preferences`, no new package, no migration. A cold start has nothing remembered.
- Clear `FamilySelection` when the signed-in user id changes or the session drops. `currentFamilyId()` still returns null immediately when nobody is signed in, before any membership read. When nothing valid is remembered, keep today's unordered `memberships` `limit(1)` `maybeSingle`. Do not add an order.
- `InviteApi.currentFamilyId()`:
  - No session: return null before any membership read. Clear the remembered id on the way out.
  - Nothing remembered, or the remembered id is not one of this user's memberships: keep today's query (`memberships` for this user, `limit(1)`, `maybeSingle`, no `order`). Do not add a lookup and do not add an order.
  - Something remembered: load this user's membership family ids (the same memberships read `listMine` already uses). If the remembered id is in that set, return it. If it is not, do not return it. Fall through to that same unordered `limit(1)` query.
- `Invite` calls `InviteModal.show` with the current family id read at the tap, after a switch. Do not pass an id captured when the bar first built.
- Timeline, search, New story, and Drafts keep calling `currentFamilyId()`. Do not add a second family-id source.
- On the timeline, choosing a family sets `_familyId`, restarts the existing Realtime watch for that id, reloads `listPublished`, and clears a focused story that is not in the new list (return the rail to far when the focused id is gone). Do not restyle far, mid, or near.
- On Drafts, choosing a family reloads `listMyDrafts` for that id and stays on Drafts.
- On New story, choosing a family updates the remembered id only. The form keeps the family id it loaded at open. Do not move an open draft into the other family.
- Search has no family menu. The next time search boots, `currentFamilyId()` is the remembered id. Do not change search results, chips, or its header.

## Remove from the timeline header

These are on `_TimelineHeader` today and come off. They are not destinations.

- `Stories`, `Family Members`, `Places`
- Help (`Icons.help_outline`)
- More (`timeline-more`) and the Drafts item inside it
- `Save draft` and `Publish` on the timeline bar
- The sage `_FamilyPill` and its groups icon
- The horizontal scroller that holds those links

Far, mid, and near rails, zoom cluster, pinch, fade, branch dashes, and the Realtime publication stay as shipped. Do not edit `supabase/`.

## Narrow width

One row. Do not wrap and do not add a second search control. At 320px, scale the whole bar down with `FittedBox` (`BoxFit.scaleDown`), the same idea as today's right-side cluster. The search pill gives up width before the wordmark ellipsizes. A 320×640 widget test must pump with no overflow exception and still find `timeline-search`, `Drafts`, `Invite`, and `New story`.

## Files

### Create

| Path | Responsibility |
| --- | --- |
| `apps/tell_me_a_story/lib/data/family_selection.dart` | `FamilySelection.remember` / `id` / `clear` for tests |
| `apps/tell_me_a_story/lib/core/theme/album_header.dart` | The bar. Pages pass the destination, family name, family list, and callbacks. The chip pushes `/search`. |
| `apps/tell_me_a_story/test/family_selection_test.dart` | Remembered id in the membership set is returned. A missing or non-member id falls through to the fallback. Nothing remembered does not require a membership list. |

### Edit

| Path | Change |
| --- | --- |
| `lib/data/invite_api.dart` | `currentFamilyId()` returns null with no membership read when signed out, clears `FamilySelection` on user change or a dropped session, honors a remembered membership, then the existing unordered `limit(1)`. |
| `lib/features/timeline/timeline_page.dart` | Replace `_TimelineHeader`, `_NavLink`, `_FamilyPill` with `AlbumHeader`. Keep `_SearchChip`'s label, key, and route, or move that chip into `AlbumHeader` and delete the private copy so only one exists. Family change reloads and rewatches. |
| `lib/features/drafts/drafts_page.dart` | Replace `AlbumTopBar(screenLabel: 'Drafts')` with `AlbumHeader`. Load `listMine` for the menu. Reload drafts on change. |
| `lib/features/stories/new_story_page.dart` | Same left cluster. Right side stays `Save draft` and `Publish story`. |
| `test/timeline_page_test.dart` | Header expectations below. Search-chip navigation on far, mid, and near stays. |
| `test/invite_chrome_test.dart` | The far-header test expects `Invite` and `New story`, and does not expect timeline `Save draft` or `Publish`. The Email/Link modal test stays. |

### Leave alone

- `lib/features/stories/story_reader_page.dart` and `AlbumTopBar` (reader back control, Add perspective).
- `lib/features/search/search_page.dart` and search tests, except a family-id unit case if a fake must honor `FamilySelection`.
- `lib/features/timeline/timeline_zoom.dart`, zoom widgets, photo rails.
- `supabase/**`, invite Edge functions, invite modal copy.

## Tests

From `apps/tell_me_a_story`:

- `family_selection_test.dart` (pure resolver used by `InviteApi`):
  - remembered id present in the membership ids → that id
  - remembered id absent → the unordered `limit(1)` fallback, not the remembered id
  - null remembered → fallback, and the test does not need a membership list
  - no signed-in user → null, and the membership read is not called
  - a different user id, or a dropped session, clears the remembered id before the next read
- Timeline widget tests, update the ones that expect `Save draft`, `Publish`, and More → Drafts:
  - far, mid, and near each show one `timeline-search`, `Timeline`, `Drafts`, `Invite`, `New story`, and the family name
  - `Stories`, `Family Members`, `Places`, `Help`, `Save draft`, `Publish`, and `timeline-more` find nothing on the timeline
  - `timeline-search` still pushes `/search`
  - `Drafts` pushes `/drafts`
  - `New story` pushes `/stories/new`
  - `Invite` opens the Email/Link modal with the family id read at the tap. After a switch, that id is the newly chosen family, not the id from the first build.
  - two families in a fake `listMine`: choosing the second calls `listPublished` with that id and rewatches that id
  - 320×640 pumps with zero overflow exceptions
- New story tests keep `Save draft` and `Publish story`. That page does not show a `New story` filled button or `Invite`.
- Drafts: the bar shows `Timeline`, an underlined `Drafts`, `timeline-search`, `Invite`, and `New story`. Choosing the other family calls `listMyDrafts` with that id.
- Reader test still finds the back control labeled `Timeline` and does not find `family-menu`.
- `flutter test` — paste the summary in the PR. No `supabase test db` for this PR because no SQL changes.

Reset `FamilySelection.clear()` in any test that remembers an id.

## Git and PR

- `git fetch origin`, then from the repo root: `git worktree add .worktrees/feat-r2-shared-header -b feat/r2-shared-header origin/main`
- Confirm `HEAD` is `cef8f13` before editing.
- One PR, `feat(r2): shared header`. Do not merge. Do not force-push.
- PR body: the bar is on timeline, Drafts, and New story; the Stitch main canvas was not built; search, zoom, and the reader were not reopened; Bill smoke is not claimed.
- Screenshot the Flutter web bar on far timeline, Drafts, and New story against screen `703158c2c064414883d9d1c1dff8902a`. Judge the header only.

## Out

Search behavior and the search header. Timeline zoom, rails, fade, and Realtime SQL. Reader chrome. Add perspective. Invite modal contents. SMS. Schema, RLS, Edge. Stories, Family Members, Places, and Help as destinations. A create-family row. Persisting the family id across a process restart. The Macro Chronicle stand-in under the Stitch header. Renaming the product to Jenkins.

## Conflict check

None. §15 says this screen is the bar and the timeline under it is a stand-in. The shipped far/mid/near screens stay. The wordmark, chip label, and `Invite` / `New story` / `Drafts` / `Timeline` strings match the playbook. `Publish story` on New story stays the shipped string.
