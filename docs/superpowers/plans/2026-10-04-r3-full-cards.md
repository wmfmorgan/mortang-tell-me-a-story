# R3 Full-card timeline

> **For agentic workers:** Implement only after this plan is approved. On approval, copy this file to `docs/superpowers/plans/2026-10-04-r3-full-cards.md` in the first commit. Work from a new worktree. Do not edit `main` in place.

**Goal:** Replace the timeline's near view with the full-card timeline on Stitch screen `c2c1a5e91d4a449490b92ef53b0cf72c`, for the current family's published stories.

**Architecture:** Paint and list layout only. `StoriesApi.listPublished` already returns title, year, people names, place label, author display name, photo paths, and comment and perspective counts. It orders `timeframe_start` oldest first. Leave that query and that order alone. Newest first is `dialStories` on the list already loaded. The third zoom step stays `TimelineZoom.near` and stays on `/timeline`. No new route, table, column, Edge function, package, or family-id source. The R2 `AlbumHeader` is not edited.

**Tech stack:** Flutter 3.x, existing `albumTheme()` tokens, `go_router`, the existing `PhotosGateway` download used by `_PhotoRow`. Secrets stay `--dart-define` only.

## Global constraints

- Branch `feat/r3-full-cards` from `origin/main` `0795f22` (`feat(r2): shared header`). Worktree `.worktrees/feat-r3-full-cards`. One PR. Do not merge. Do not claim Bill local smoke or Mugatu PASS.
- Impl Spec §15 R3 (OPEN): https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8. Screen project `12192342757314667328`, screen `c2c1a5e91d4a449490b92ef53b0cf72c` ("Family Timeline (Full Cards Variant) — Jenkins Family Archive"). Ignore screens `015a7a24ebd746bf96f69c4132fc1d9c`, `0ef65157329747aaba45e529d0a33947`, and the old near screen `b50f9265a875446abc4025d1cf84b8a3`.
- Precedence for this PR: §15 R3, then that screen's HTML for layout. §10 still lists near id `b50f9265` and a `+/−` / Fit all cluster. R3 names those as ignore and says this page has no plus, no minus, and no Fit all. Pick R3 and the screen the user named.
- Do not reopen M6 or M7. Do not restyle far or mid. Do not edit `AlbumHeader`, search, the reader, Drafts, or New story. Do not edit `supabase/`.
- Tokens: page parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74` accent only, ink `#2C2416`. Newsreader titles, Source Sans 3 labels. Card fill on this page is white `#FFFFFF` (`surface-container-lowest` on the screen). The page background stays parchment.
- "Jenkins", Aunt Clara, Graduation, stock photos, and `school` / `group` icons are demo. Use stored fields. Do not rename the product.
- The painted order is newest `timeframe_start` first, via `dialStories` on the rows `listPublished` already returned. Do not add an `.order()` and do not reverse the query. Drafts stay off the list.

## What this page is

Under the existing R2 header, two regions:

1. One quiet zoom row.
2. A scrolling spine of full cards for every published story in the current family.

The card whose center is nearest the viewport center is sharp and full opacity. Cards fade toward parchment as their centers enter the top or bottom of the viewport. Tapping a card still pushes `/stories/:id`.

Empty and loading stay as they are: spinner while the family or the published list is loading, and `No stories yet. Capture the first one for this family.` when that list is empty. The zoom row is hidden in those states, same as today's rail chrome.

## Zoom row

Directly under the header, full width, background `#FAF2F0`, bottom hairline ink at 12% opacity, horizontal padding 32, vertical padding 10. Content max width 1280, centered.

Left: a beige pill, fill `#F5ECE9`, label exactly `Zoom Level: 100% (Full Cards)`. Source Sans 3, about 12px, semibold, ink at about 70%. Stadium border. Not a button.

Right: one segmented switch, fill `#F5ECE9`, padding 4, corner radius 8, gap 4. Three labels, Source Sans 3 about 12px:

| Segment | Key | Look | Action |
| --- | --- | --- | --- |
| `Macro` | `timeline-zoom-macro` | ink at 70%, no fill | `_fitAll` (far) |
| `Mid` | `timeline-zoom-mid` | ink at 70%, no fill | set zoom to mid, keep the focused story id |
| `Full Cards` | `timeline-zoom-full` | terracotta fill, parchment label, semibold | selected. Tapping it does not navigate. |

No plus, no minus, no `Fit all`, no `Near · full cards`, and no pinch hint on this page. Hide `_ZoomCluster` when `_zoom == TimelineZoom.near`. Far and mid keep their current context rows and the floating cluster.

Keep the existing `_onPinch` handler. Do not add a gesture and do not special-case the scale. Above 1.08 still calls `_zoomIn`. On near, `zoomIn` already stays on near, and that call still runs `_reveal`. Under 0.92 still calls `_zoomOut` and returns to mid.

`_reveal` is alignment `0.3` today. Change that one call to `0.5`. Every path onto near uses it: `_openNear`, `_openFullCards`, and `_zoomIn` (pinch-in from mid, and pinch-in while already on near). Do not pass a second alignment. The list is `dialStories(_published)`, not `decadeNewestFirst`. A story from another decade is on this page.

At width under 720, the row stays one line. The pill ellipsizes before the switch wraps. A 320-wide pump must not throw an overflow.

## Card list

`ListView` of `dialStories`, padding half the viewport height on top and bottom so the first and last card can sit at the center. Vertical gap about 80px on a wide window, 32px under 720px.

The spine is the screen's solid 2px line through the vertical center of the list, ink at 20% opacity (`outline-variant/30` on the screen). It is a mark on this page. It is not a dashed sage rail and it is not a second timeline. Do not paint the child-family dash, `{name} Branch`, or `← {name} union joined archive` here. Those stay on far and mid. Each card has one dot on that line:

- The center card's dot is 20px, fill terracotta, with an 8px ring of `#F5DED6`.
- Every other dot is 14px, fill parchment, 2px border ink at 40%.

Wide layout (width at least 800): even indexes sit on the left, odd indexes on the right. Each card is about half the content width minus 32px. The opposite side is empty. This matches the screen (1991 left, 1990 right, 1989 left).

Narrow layout (under 800): one column. The spine and dot sit on the left of the card with 16px of gap. Do not squeeze two half-width cards onto a phone.

### Center card

White, 12px radius, 2px terracotta border, shadow (ink at 8%, blur 24, offset y 8), and a 4px outer ring of `#F5DED6` at 30% opacity. Scale 1.05. Padding 24.

Top row, space between: the year (`timeframe_start.year`) in Source Sans 3, about 12px, bold, uppercase tracking, terracotta. Then a wrap of chips. Person chips use `Icons.person` and each `personNames` entry. One place chip uses `Icons.location_on` and `placeLabel` when that label is non-empty. Center chips are filled `#F5DED6` with ink text, stadium, about 12px. No relationship-specific icons.

Title: the saved title, Newsreader about 24px, bold, ink. No body.

Photos: `photoPaths.first` only. That list is already sorted by `sort_order`. Full width of the card, height 192, radius 8, cover. Download through the existing `PhotosGateway`. An empty `photoPaths` means no image well and no stock photo. A failed download leaves that well out. Do not paint the second path on the center card.

Footer, top hairline ink at 12%, Source Sans 3 about 12px: `Added by {name}` in ink at 70%, where `{name}` is the trimmed `authorDisplayName` or `Member`. On the right, terracotta semibold: `{photoCount} photos · {notes} notes`, using `countWord` for both nouns. `photoCount` is the stored count, not how many images this card paints. `notes` is `commentCount + perspectiveCount`. This footer is only on the center card.

Key stays `timeline-card-${story.id}`. Tap pushes `/stories/${story.id}`.

### Other cards

Same year, chips, and title. Chips are quiet: fill `#F5ECE9`, ink at 70%, no terracotta fill. Border is 1px ink at 20%, white fill, 12px radius, light shadow, no scale. Opacity comes from the scroll math below.

Photos: up to two stored paths, height 112, radius 8. Two photos use a two-column row with 12px gap. One photo is full width. No footer, no "Currently Focused", no dial label, no era name.

### Fade

Reuse the far rule: a card stays at opacity 1 while its center is outside the top and bottom 45% bands (the middle 10% of the viewport). It dims as that center enters a band, down to 0 at the viewport edge. Apply that opacity to the card, not to the spine.

The center card is the one whose center is closest to the viewport center. On the first frame, before measurement, the card that was revealed (`focusedId`) is the center card at opacity 1 and the others start at 0.4. After the first measure, scroll position wins over the tapped id. Do not paint `Currently Focused`, `{year} · IN FOCUS`, or `Family Archive · Near Zoom View`.

A parchment gradient sits over the top and bottom of the list, `IgnorePointer`, so the fade reads as parchment. It does not block taps.

## Files

### Edit

- `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`
  - `_body` near branch passes `dialStories(_published)` into the rail. Do not change `listPublished`.
  - Hide `_ZoomCluster` when zoom is near. Remove the near-only `Near · full cards` label from the cluster by never building the cluster on this page.
  - Replace `_NearRail` / `_NearCard` with the layout above. Keep the card key and the reader push.
  - Delete the near heading, the archive sentence, `Currently Focused`, and the branch-fork sentence from this page only.
- `apps/tell_me_a_story/lib/features/timeline/timeline_zoom.dart`
  - Add `fullCardOpacity` as a named wrapper around `farEdgeOpacity` so the full-card test does not depend on a far-only name. Same `farFadeBand` of 0.45. Do not change `farEdgeOpacity` results.
  - Leave `nearHeading` in the file if a test still imports it; stop calling it from the page. If nothing calls it after the test edit, delete it.
- `apps/tell_me_a_story/test/timeline_page_test.dart`
  - Update the card-tap test. After the stub tap, expect `Zoom Level: 100% (Full Cards)`, the saved title, and no `Currently Focused`, no `Family Archive · Near Zoom View`, and no body line.
  - Add the cases in the task below.
- `apps/tell_me_a_story/test/timeline_zoom_test.dart` if it exists; otherwise cover `fullCardOpacity` from the page test's existing zoom tests. Do not add a new test file unless that file already exists.

### Leave alone

- `lib/core/theme/album_header.dart` and every `AlbumHeader(` call site.
- Far rail, mid rail, `_ZoomCluster` on far and mid, `timeline_zoom.dart` decade and dial functions other than the opacity wrapper and an unused `nearHeading`.
- `stories_api.dart`, including `listPublished` and its `.order('timeframe_start')`. The published select already has the fields this card paints. If a widget test fake constructs `Story` without photo paths, pass paths in the test.
- Search, reader, drafts, new story, invites, `supabase/**`.

## Tasks

### Task 1: Full-card list replaces the near rail

**Files:** `timeline_page.dart`, `timeline_zoom.dart`, `test/timeline_page_test.dart`

- [ ] Extend the existing "tapping a published card pushes the story reader" test. After the stub tap, the page shows `Zoom Level: 100% (Full Cards)` and `Jam`, and does not show `Currently Focused` or `Family Archive · Near Zoom View`. The card key tap still lands on the reader.
- [ ] Add a widget test with three published stories, years 1991, 1990, and 1989, titles `Canning`, `Lawn`, and `Wagon`. Open full cards. Expect the 1991 title above the 1989 title. Expect no `Text` whose data equals the body string `secret body line`.
- [ ] Add a widget test with two people and a place label. Both names and the place label are on the card. A story with no place does not show `location_on`.
- [ ] Run `flutter test test/timeline_page_test.dart` from `apps/tell_me_a_story` and confirm the new expectations fail before the layout change.
- [ ] Implement the zoom row, the alternating cards, the solid spine, the dot, and `dialStories` on the list already loaded. Set the single `_reveal` alignment to `0.5`. Leave `_onPinch` calling `_zoomIn` and `_zoomOut`.
- [ ] Run the same test file. Expected: the new cases pass, and the far/mid cases (`CONTINUOUS FAMILY DIAL`, `1980 · IN FOCUS`, `Fit all`, search chip) still pass.

### Task 2: Viewport center is the sharp card

**Files:** `timeline_page.dart`, `timeline_zoom.dart`, `test/timeline_page_test.dart`

- [ ] Add `fullCardOpacity` with the same contract as `farEdgeOpacity`. A unit test: row center in the middle 10% returns 1; a row center at the viewport edge returns 0; a row center halfway through the 45% band returns 0.5.
- [ ] Widget test: three full cards in a tall-enough surface. After pump and one scroll notification, the middle card's `Opacity` is greater than the first and last. The middle card finds `Added by`. The first card does not find `Added by`.
- [ ] Widget test: the center story has `photoCount` 4, two `photoPaths`, and comment count 1. The card shows one image (the first path) and the footer `4 photos · 1 note`. A story with an empty `photoPaths` has no image well (no `Image` descendant of that card) even if `photoCount` were 0.
- [ ] Implement measurement the same way `_MidRail` already does: `ScrollNotification`, post-frame measure, opacity map, center id. Footer only when that id matches.
- [ ] Run `flutter test test/timeline_page_test.dart`. Expected: pass.

### Task 3: Narrow width, and the cluster stays off this page

**Files:** `timeline_page.dart`, `test/timeline_page_test.dart`

- [ ] Widget test: a child family is in the membership list. The full-card page does not find `union joined archive`, `Branch`, or a dashed sage painter. The spine is one solid line. Far still finds the branch label after `Macro`. Do not assert a second family's story title.
- [ ] Widget test at 320×640 on the full-card page: `tester.takeException()` is null, and `Zoom Level: 100% (Full Cards)`, `Macro`, `Mid`, and `Full Cards` are present. `timeline-zoom-in` and `timeline-fit` are absent. Tapping `Macro` shows `CONTINUOUS FAMILY DIAL`.
- [ ] Widget test: from mid, a scale of `1.1` lands on full cards and the focused card is revealed with the same `0.5` alignment as a stub tap. A scale of `0.9` on full cards returns to mid. The handler is still `_onPinch`.
- [ ] Run `flutter test` from `apps/tell_me_a_story`. Expected: all tests pass. Paste the summary in the PR.

## Out

The R2 header. Search. Reader, Drafts, New story. Far and mid layout. `listPublished` and its oldest-first order. Stories, Family Members, Places, Help. A new sort column. Another family's stories on this rail. A dashed sage rail on this page. Stock photos. Body excerpts. The old near heading and `Currently Focused`.

## Exit

`flutter test` from `apps/tell_me_a_story` is green. PR body says R3 is the full-card page only, the header was not edited, and Bill local smoke is not claimed. Bill's smoke on the README path is what closes the milestone.
