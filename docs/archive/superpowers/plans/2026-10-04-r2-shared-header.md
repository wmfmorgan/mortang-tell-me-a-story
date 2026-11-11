# R2 Shared header

> Gate: plan only until approved. No application code before.
>
> On approval: copy file to `docs/superpowers/plans/2026-10-04-r2-shared-header.md` in first commit. Worktree `.worktrees/feat-r2-shared-header`, branch `feat/r2-shared-header`, from **`origin/main` `cef8f13`**. Repo-root checkout still `b30c697`. Don't branch from it.

**Goal:** One header bar on timeline, Drafts, New story, matching Stitch screen `703158c2c064414883d9d1c1dff8902a` (bar only). Family menu switches family those screens already load. Exit = Bill local smoke. Open one PR. No merge. Don't claim Bill smoke.

**Architecture:** Paint + wiring only. `FamiliesGateway.listMine()` already returns member's families. Process-memory id consulted by `InviteApi.currentFamilyId()` when id is one of those memberships. Timeline, Drafts, New story, search already call `currentFamilyId()`. No new table, column, Edge function, package, route.

**Tech stack:** Flutter 3.x, existing `albumTheme()` tokens, `go_router`, `supabase_flutter` PostgREST. Secrets `--dart-define` only.

## Sources (do not invent past these)

- Impl Spec §15 R2 playbook (OPEN): https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- Stitch project `12192342757314667328`, screen `703158c2c064414883d9d1c1dff8902a` ("Locked Top Bar with Quiet Far-Zoom Timeline"). `<header>` = bar. `<main>` (Macro Chronicle, sample decades, "Family Orchard Archive established") = stand-in. Don't paint.
- Code to change = tree of `cef8f13` / M7 tip `8387401` (same tree), not stub timeline on stale checkout. Header today = `_TimelineHeader` in `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`. Drafts + New story use `AlbumTopBar` in `lib/core/theme/album_chrome.dart`.

## What the bar is

Left→right, one row, parchment `#FBF7F2`, bottom hairline `albumInk` 15% opacity, height 72, horizontal padding 32 on wide window:

1. Wordmark `Tell Me a Story`. Newsreader italic, ~24px, ink `#2C2416`, normal weight. Static text. Not link/button.
2. 1×20 hairline, ink 15%, between wordmark and family control.
3. Family menu. Stored `families.name` in Newsreader ~18px medium, plus `Icons.expand_more`. No sage fill, no groups icon, no "Jenkins". Empty stored name keeps existing `Family` fallback from `MemberFamily.fromJson`.
4. `Timeline`. Source Sans 3, 15px, medium. Active: full ink + 2px ink underline. Inactive: ink 70%. Underline ink, not terracotta.
5. `Drafts` right after Timeline, same type + tap size. Not in More menu.
6. Existing search chip, key `timeline-search`. Pill (`StadiumBorder`), max width 224, fill ink 4%, border ink 10%, `Icons.search` + label `Search archive...` Source Sans 3 14px ink 50%. One chip. Still pushes `/search`.

Right side, gap 16:

- `Invite`: ink text, Source Sans 3 15px medium, ink 80%. Label `Invite`, not `+ Invite`. Opens existing Email/Link modal.
- `New story`: only filled button. Terracotta `#8B5E4B`, parchment label, `Icons.add`, pill, light shadow. Pushes `/stories/new`.

On `/stories/new` right side drops `Invite` + `New story`. `Save draft` (secondary text button) + `Publish story` (filled terracotta) stay, same enable rules as now. Don't rename `Publish story` to `Publish`.

Reader keeps back control (`AlbumTopBar` leading `Timeline`). Search keeps own bar (`SEARCH ARCHIVE`, field, filters). Add perspective keeps current bar. No header on those three.

## Active item

| Route | Underline | Right side |
| --- | --- | --- |
| `/timeline` (far, mid, and near) | `Timeline` | `Invite`, `New story` |
| `/drafts` | `Drafts` | `Invite`, `New story` |
| `/stories/new` | neither | `Save draft`, `Publish story` |

`Timeline` → `/timeline` for current family. From Drafts or New story use `context.go`. On timeline, no second timeline push.

`Drafts` opens `/drafts` for current family. Already on Drafts: control stays, no extra drafts push.

Family menu on bar at far, mid, near. Today `_FamilyPill` far/mid only. Split goes away.

## Family menu behavior

- Button shows family whose id = current `currentFamilyId()` result. Key `family-menu`.
- Menu lists `listMine()` rows. Current id checked. One family → still button + one checked row. No "create family" row. No Stories, Family Members, Places, Help rows.
- Choosing row remembers id in process memory (`FamilySelection`, static field in `lib/data/family_selection.dart`). No `shared_preferences`, no new package, no migration. Cold start = nothing remembered.
- Clear `FamilySelection` when signed-in user id changes or session drops. `currentFamilyId()` still returns null immediately when nobody signed in, before any membership read. Nothing valid remembered → keep today's unordered `memberships` `limit(1)` `maybeSingle`. No order.
- `InviteApi.currentFamilyId()`:
  - No session: return null before membership read. Clear remembered id on way out.
  - Nothing remembered, or remembered id not in user's memberships: keep today's query (`memberships` for user, `limit(1)`, `maybeSingle`, no `order`). No extra lookup, no order.
  - Something remembered: load user's membership family ids (same memberships read `listMine` uses). In set → return it. Not in set → don't return; fall through to same unordered `limit(1)` query.
- `Invite` calls `InviteModal.show` with current family id read at tap, after switch. Not id captured at first build.
- Timeline, search, New story, Drafts keep calling `currentFamilyId()`. No second family-id source.
- Timeline: choosing family sets `_familyId`, restarts existing Realtime watch for that id, reloads `listPublished`, clears focused story not in new list (rail back to far when focused id gone). No restyle of far, mid, near.
- Drafts: choosing family reloads `listMyDrafts` for that id, stays on Drafts.
- New story: choosing family updates remembered id only. Form keeps family id loaded at open. Don't move open draft to other family.
- Search has no family menu. Next search boot, `currentFamilyId()` = remembered id. Don't change search results, chips, header.

## Remove from the timeline header

On `_TimelineHeader` today, come off. Not destinations.

- `Stories`, `Family Members`, `Places`
- Help (`Icons.help_outline`)
- More (`timeline-more`) + Drafts item inside
- `Save draft` and `Publish` on timeline bar
- Sage `_FamilyPill` + groups icon
- Horizontal scroller holding those links

Far, mid, near rails, zoom cluster, pinch, fade, branch dashes, Realtime publication stay as shipped. Don't edit `supabase/`.

## Narrow width

One row. No wrap, no second search control. At 320px, scale whole bar down with `FittedBox` (`BoxFit.scaleDown`), same idea as today's right-side cluster. Search pill gives up width before wordmark ellipsizes. 320×640 widget test must pump with no overflow exception and still find `timeline-search`, `Drafts`, `Invite`, `New story`.

## Files

### Create

| Path | Responsibility |
| --- | --- |
| `apps/tell_me_a_story/lib/data/family_selection.dart` | `FamilySelection.remember` / `id` / `clear` for tests |
| `apps/tell_me_a_story/lib/core/theme/album_header.dart` | The bar. Pages pass destination, family name, family list, callbacks. Chip pushes `/search`. |
| `apps/tell_me_a_story/test/family_selection_test.dart` | Remembered id in membership set returned. Missing or non-member id falls through to fallback. Nothing remembered needs no membership list. |

### Edit

| Path | Change |
| --- | --- |
| `lib/data/invite_api.dart` | `currentFamilyId()` returns null, no membership read, when signed out; clears `FamilySelection` on user change or dropped session; honors remembered membership; then existing unordered `limit(1)`. |
| `lib/features/timeline/timeline_page.dart` | Replace `_TimelineHeader`, `_NavLink`, `_FamilyPill` with `AlbumHeader`. Keep `_SearchChip` label, key, route, or move chip into `AlbumHeader` and delete private copy so only one exists. Family change reloads + rewatches. |
| `lib/features/drafts/drafts_page.dart` | Replace `AlbumTopBar(screenLabel: 'Drafts')` with `AlbumHeader`. Load `listMine` for menu. Reload drafts on change. |
| `lib/features/stories/new_story_page.dart` | Same left cluster. Right side stays `Save draft` + `Publish story`. |
| `test/timeline_page_test.dart` | Header expectations below. Search-chip nav on far, mid, near stays. |
| `test/invite_chrome_test.dart` | Far-header test expects `Invite` + `New story`, not timeline `Save draft` or `Publish`. Email/Link modal test stays. |

### Leave alone

- `lib/features/stories/story_reader_page.dart` and `AlbumTopBar` (reader back control, Add perspective).
- `lib/features/search/search_page.dart` + search tests, except family-id unit case if fake must honor `FamilySelection`.
- `lib/features/timeline/timeline_zoom.dart`, zoom widgets, photo rails.
- `supabase/**`, invite Edge functions, invite modal copy.

## Tests

From `apps/tell_me_a_story`:

- `family_selection_test.dart` (pure resolver used by `InviteApi`):
  - remembered id in membership ids → that id
  - remembered id absent → unordered `limit(1)` fallback, not remembered id
  - null remembered → fallback, test needs no membership list
  - no signed-in user → null, membership read not called
  - different user id or dropped session clears remembered id before next read
- Timeline widget tests, update ones expecting `Save draft`, `Publish`, More → Drafts:
  - far, mid, near each show one `timeline-search`, `Timeline`, `Drafts`, `Invite`, `New story`, family name
  - `Stories`, `Family Members`, `Places`, `Help`, `Save draft`, `Publish`, `timeline-more` find nothing on timeline
  - `timeline-search` still pushes `/search`
  - `Drafts` pushes `/drafts`
  - `New story` pushes `/stories/new`
  - `Invite` opens Email/Link modal with family id read at tap. After switch, id = newly chosen family, not first-build id.
  - two families in fake `listMine`: choosing second calls `listPublished` with that id + rewatches that id
  - 320×640 pumps with zero overflow exceptions
- New story tests keep `Save draft` + `Publish story`. Page shows no `New story` filled button, no `Invite`.
- Drafts: bar shows `Timeline`, underlined `Drafts`, `timeline-search`, `Invite`, `New story`. Choosing other family calls `listMyDrafts` with that id.
- Reader test still finds back control labeled `Timeline`, no `family-menu`.
- `flutter test` — paste summary in PR. No `supabase test db` (no SQL changes).

Reset `FamilySelection.clear()` in any test that remembers an id.

## Git and PR

- `git fetch origin`, then from repo root: `git worktree add .worktrees/feat-r2-shared-header -b feat/r2-shared-header origin/main`
- Confirm `HEAD` is `cef8f13` before editing.
- One PR, `feat(r2): shared header`. No merge. No force-push.
- PR body: bar on timeline, Drafts, New story; Stitch main canvas not built; search, zoom, reader not reopened; Bill smoke not claimed.
- Screenshot Flutter web bar on far timeline, Drafts, New story vs screen `703158c2c064414883d9d1c1dff8902a`. Judge header only.

## Out

Search behavior + search header. Timeline zoom, rails, fade, Realtime SQL. Reader chrome. Add perspective. Invite modal contents. SMS. Schema, RLS, Edge. Stories, Family Members, Places, Help as destinations. Create-family row. Persisting family id across process restart. Macro Chronicle stand-in under Stitch header. Renaming product to Jenkins.

## Conflict check

None. §15 says screen = bar, timeline under it = stand-in. Shipped far/mid/near screens stay. Wordmark, chip label, `Invite` / `New story` / `Drafts` / `Timeline` strings match playbook. `Publish story` on New story stays shipped string.