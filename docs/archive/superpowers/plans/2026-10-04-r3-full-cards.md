# R3 Full-card timeline

> **For agentic workers:** Implement only after plan approved. On approval, copy file to `docs/superpowers/plans/2026-10-04-r3-full-cards.md` in first commit. Work from new worktree. No in-place edits on `main`.

**Goal:** Replace timeline near view with full-card timeline on Stitch screen `c2c1a5e91d4a449490b92ef53b0cf72c`, for current family's published stories.

**Architecture:** Paint + list layout only. `StoriesApi.listPublished` already returns title, year, people names, place label, author display name, photo paths, comment + perspective counts. Orders `timeframe_start` oldest first. Leave query + order alone. Newest first = `dialStories` on already-loaded list. Third zoom step stays `TimelineZoom.near`, stays on `/timeline`. No new route, table, column, Edge function, package, or family-id source. R2 `AlbumHeader` not edited.

**Tech stack:** Flutter 3.x, existing `albumTheme()` tokens, `go_router`, existing `PhotosGateway` download used by `_PhotoRow`. Secrets `--dart-define` only.

## Global constraints

- Branch `feat/r3-full-cards` from `origin/main` `0795f22` (`feat(r2): shared header`). Worktree `.worktrees/feat-r3-full-cards`. One PR. No merge. No claiming Bill local smoke or Mugatu PASS.
- Impl Spec §15 R3 (OPEN): https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8. Screen project `12192342757314667328`, screen `c2c1a5e91d4a449490b92ef53b0cf72c` ("Family Timeline (Full Cards Variant) — Jenkins Family Archive"). Ignore screens `015a7a24ebd746bf96f69c4132fc1d9c`, `0ef65157329747aaba45e529d0a33947`, old near screen `b50f9265a875446abc4025d1cf84b8a3`.
- Precedence: §15 R3, then screen HTML for layout. §10 still lists near id `b50f9265` + `+/−` / Fit all cluster. R3 marks those ignore; page has no plus, minus, or Fit all. Pick R3 + user-named screen.
- No reopening M6 or M7. No restyling far or mid. No edits to `AlbumHeader`, search, reader, Drafts, New story. No edits to `supabase/`.
- Tokens: page parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74` accent only, ink `#2C2416`. Newsreader titles, Source Sans 3 labels. Card fill white `#FFFFFF` (`surface-container-lowest` on screen). Page bg stays parchment.
- "Jenkins", Aunt Clara, Graduation, stock photos, `school` / `group` icons = demo. Use stored fields. No product rename.
- Painted order newest `timeframe_start` first, via `dialStories` on rows `listPublished` already returned. No added `.order()`, no query reverse. Drafts stay off list.

## What this page is

Under existing R2 header, two regions:

1. One quiet zoom row.
2. Scrolling spine of full cards for every published story in current family.

Card whose center nearest viewport center = sharp, full opacity. Cards fade toward parchment as centers enter top/bottom of viewport. Tap still pushes `/stories/:id`.

Empty + loading unchanged: spinner while family or published list loading; `No stories yet. Capture the first one for this family.` when list empty. Zoom row hidden in those states, same as today's rail chrome.

## Zoom row

Directly under header, full width, bg `#FAF2F0`, bottom hairline ink 12% opacity, horizontal padding 32, vertical padding 10. Content max width 1280, centered.

Left: beige pill, fill `#F5ECE9`, label exactly `Zoom Level: 100% (Full Cards)`. Source Sans 3, ~12px, semibold, ink ~70%. Stadium border. Not button.

Right: one segmented switch, fill `#F5ECE9`, padding 4, radius 8, gap 4. Three labels, Source Sans 3 ~12px:

| Segment | Key | Look | Action |
| --- | --- | --- | --- |
| `Macro` | `timeline-zoom-macro` | ink 70%, no fill | `_fitAll` (far) |
| `Mid` | `timeline-zoom-mid` | ink 70%, no fill | zoom to mid, keep focused story id |
| `Full Cards` | `timeline-zoom-full` | terracotta fill, parchment label, semibold | selected. Tap no navigate. |

No plus, minus, `Fit all`, `Near · full cards`, or pinch hint on page. Hide `_ZoomCluster` when `_zoom == TimelineZoom.near`. Far + mid keep current context rows + floating cluster.

Keep existing `_onPinch` handler. No new gesture, no scale special-case. Above 1.08 still calls `_zoomIn`. On near, `zoomIn` stays on near, call still runs `_reveal`. Under 0.92 still calls `_zoomOut`, returns to mid.

`_reveal` alignment `0.3` today. Change that one call to `0.5`. Every path onto near uses it: `_openNear`, `_openFullCards`, `_zoomIn` (pinch-in from mid, pinch-in while on near). No second alignment. List = `dialStories(_published)`, not `decadeNewestFirst`. Stories from other decades on this page.

Width under 720: row stays one line. Pill ellipsizes before switch wraps. 320-wide pump must not throw overflow.

## Card list

`ListView` of `dialStories`, padding half viewport height top + bottom so first/last card can sit at center. Vertical gap ~80px wide window, 32px under 720px.

Spine = screen's solid 2px line through vertical center of list, ink 20% opacity (`outline-variant/30` on screen). Mark only. Not dashed sage rail, not second timeline. No child-family dash, `{name} Branch`, or `← {name} union joined archive` here. Those stay on far + mid. Each card has one dot on line:

- Center card dot: 20px, terracotta fill, 8px ring `#F5DED6`.
- Other dots: 14px, parchment fill, 2px border ink 40%.

Wide layout (width ≥ 800): even indexes left, odd right. Card ~half content width minus 32px. Opposite side empty. Matches screen (1991 left, 1990 right, 1989 left).

Narrow layout (under 800): one column. Spine + dot left of card, 16px gap. No squeezing two half-width cards on phone.

### Center card

White, 12px radius, 2px terracotta border, shadow (ink 8%, blur 24, offset y 8), 4px outer ring `#F5DED6` at 30% opacity. Scale 1.05. Padding 24.

Top row, space between: year (`timeframe_start.year`) Source Sans 3, ~12px, bold, uppercase tracking, terracotta. Then wrap of chips. Person chips: `Icons.person` + each `personNames` entry. One place chip: `Icons.location_on` + `placeLabel` when non-empty. Center chips filled `#F5DED6`, ink text, stadium, ~12px. No relationship-specific icons.

Title: saved title, Newsreader ~24px, bold, ink. No body.

Photos: `photoPaths.first` only. List already sorted by `sort_order`. Full card width, height 192, radius 8, cover. Download via existing `PhotosGateway`. Empty `photoPaths` = no image well, no stock photo. Failed download = well omitted. No second path on center card.

Footer, top hairline ink 12%, Source Sans 3 ~12px: `Added by {name}` ink 70%, `{name}` = trimmed `authorDisplayName` or `Member`. Right, terracotta semibold: `{photoCount} photos · {notes} notes`, `countWord` for both nouns. `photoCount` = stored count, not painted image count. `notes` = `commentCount + perspectiveCount`. Footer center card only.

Key stays `timeline-card-${story.id}`. Tap pushes `/stories/${story.id}`.

### Other cards

Same year, chips, title. Chips quiet: fill `#F5ECE9`, ink 70%, no terracotta fill. Border 1px ink 20%, white fill, 12px radius, light shadow, no scale. Opacity from scroll math below.

Photos: up to two stored paths, height 112, radius 8. Two photos = two-column row, 12px gap. One photo = full width. No footer, no "Currently Focused", no dial label, no era name.

### Fade

Reuse far rule: card opacity 1 while center outside top + bottom 45% bands (middle 10% of viewport). Dims as center enters band, to 0 at viewport edge. Apply opacity to card, not spine.

Center card = card whose center closest to viewport center. First frame, before measure: revealed card (`focusedId`) = center card at opacity 1, others start 0.4. After first measure, scroll position beats tapped id. No painting `Currently Focused`, `{year} · IN FOCUS`, or `Family Archive · Near Zoom View`.

Parchment gradient over top + bottom of list, `IgnorePointer`, so fade reads as parchment. No tap blocking.

## Files

### Edit

- `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart`
  - `_body` near branch passes `dialStories(_published)` into rail. No change to `listPublished`.
  - Hide `_ZoomCluster` when zoom near. Remove near-only `Near · full cards` label by never building cluster on page.
  - Replace `_NearRail` / `_NearCard` with layout above. Keep card key + reader push.
  - Delete near heading, archive sentence, `Currently Focused`, branch-fork sentence from this page only.
- `apps/tell_me_a_story/lib/features/timeline/timeline_zoom.dart`
  - Add `fullCardOpacity` as named wrapper around `farEdgeOpacity` so full-card test not tied to far-only name. Same `farFadeBand` 0.45. `farEdgeOpacity` results unchanged.
  - Leave `nearHeading` if a test still imports it; stop calling from page. If nothing calls it after test edit, delete.
- `apps/tell_me_a_story/test/timeline_page_test.dart`
  - Update card-tap test. After stub tap, expect `Zoom Level: 100% (Full Cards)`, saved title, no `Currently Focused`, no `Family Archive · Near Zoom View`, no body line.
  - Add cases in task below.
- `apps/tell_me_a_story/test/timeline_zoom_test.dart` if exists; else cover `fullCardOpacity` from page test's existing zoom tests. No new test file unless that file already exists.

### Leave alone

- `lib/core/theme/album_header.dart` + every `AlbumHeader(` call site.
- Far rail, mid rail, `_ZoomCluster` on far + mid, `timeline_zoom.dart` decade + dial functions except opacity wrapper and unused `nearHeading`.
- `stories_api.dart`, incl. `listPublished` + its `.order('timeframe_start')`. Published select already has fields card paints. If widget test fake builds `Story` without photo paths, pass paths in test.
- Search, reader, drafts, new story, invites, `supabase/**`.

## Tasks

### Task 1: Full-card list replaces the near rail

**Files:** `timeline_page.dart`, `timeline_zoom.dart`, `test/timeline_page_test.dart`

- [ ] Extend existing "tapping a published card pushes the story reader" test. After stub tap, page shows `Zoom Level: 100% (Full Cards)` + `Jam`, not `Currently Focused` or `Family Archive · Near Zoom View`. Card key tap still lands on reader.
- [ ] Add widget test: three published stories, years 1991, 1990, 1989, titles `Canning`, `Lawn`, `Wagon`. Open full cards. Expect 1991 title above 1989 title. Expect no `Text` with data equal to body string `secret body line`.
- [ ] Add widget test: two people + place label. Both names + place label on card. Story with no place shows no `location_on`.
- [ ] Run `flutter test test/timeline_page_test.dart` from `apps/tell_me_a_story`; confirm new expectations fail before layout change.
- [ ] Implement zoom row, alternating cards, solid spine, dot, `dialStories` on loaded list. Set single `_reveal` alignment to `0.5`. Leave `_onPinch` calling `_zoomIn` + `_zoomOut`.
- [ ] Run same test file. Expected: new cases pass; far/mid cases (`CONTINUOUS FAMILY DIAL`, `1980 · IN FOCUS`, `Fit all`, search chip) still pass.

### Task 2: Viewport center is the sharp card

**Files:** `timeline_page.dart`, `timeline_zoom.dart`, `test/timeline_page_test.dart`

- [ ] Add `fullCardOpacity`, same contract as `farEdgeOpacity`. Unit test: row center in middle 10% → 1; at viewport edge → 0; halfway through 45% band → 0.5.
- [ ] Widget test: three full cards, tall-enough surface. After pump + one scroll notification, middle card's `Opacity` > first and last. Middle card finds `Added by`. First card doesn't.
- [ ] Widget test: center story `photoCount` 4, two `photoPaths`, comment count 1. Card shows one image (first path) + footer `4 photos · 1 note`. Story with empty `photoPaths` has no image well (no `Image` descendant of card) even if `photoCount` 0.
- [ ] Implement measurement like `_MidRail`: `ScrollNotification`, post-frame measure, opacity map, center id. Footer only when id matches.
- [ ] Run `flutter test test/timeline_page_test.dart`. Expected: pass.

### Task 3: Narrow width, and the cluster stays off this page

**Files:** `timeline_page.dart`, `test/timeline_page_test.dart`

- [ ] Widget test: child family in membership list. Full-card page doesn't find `union joined archive`, `Branch`, or dashed sage painter. Spine one solid line. Far still finds branch label after `Macro`. No asserting second family's story title.
- [ ] Widget test at 320×640 on full-card page: `tester.takeException()` null; `Zoom Level: 100% (Full Cards)`, `Macro`, `Mid`, `Full Cards` present. `timeline-zoom-in` + `timeline-fit` absent. Tap `Macro` shows `CONTINUOUS FAMILY DIAL`.
- [ ] Widget test: from mid, scale `1.1` lands on full cards, focused card revealed with same `0.5` alignment as stub tap. Scale `0.9` on full cards returns to mid. Handler still `_onPinch`.
- [ ] Run `flutter test` from `apps/tell_me_a_story`. Expected: all pass. Paste summary in PR.

## Out

R2 header. Search. Reader, Drafts, New story. Far + mid layout. `listPublished` + its oldest-first order. Stories, Family Members, Places, Help. New sort column. Other family's stories on this rail. Dashed sage rail on page. Stock photos. Body excerpts. Old near heading + `Currently Focused`.

## Exit

`flutter test` from `apps/tell_me_a_story` green. PR body says R3 = full-card page only, header not edited, Bill local smoke not claimed. Bill's smoke on README path closes milestone.