# Family Thread (timeline rebuild): UX

**Status: LOCKED rev 1.3 (2026-11-25, 4:57 PM CT). Rev 1.0 was approved by Bill as written on 2026-11-22 at 6:33 AM CT. Rev 1.1 and 1.2 are lane 2 deltas to the time scrubber only ([§6.1](#61-dial-scrubber-rev-11)), from Bill's 4:50 PM CT ask via Erlich: "the scrubber should look like this, and it should move smoothly like a dial."** Locked by Mugatu (UXD) from the approved milestone scope rev 4, Bill's density decisions (6:14 PM CT), mockups R1–R8 and the draft PR #249 learnings. Jared stamps the copy strings FT-01 to FT-37, and the doc then goes to Gilfoyle (SAD).

- **Scope source:** PRD, section **"Family Thread — milestone scope"**, rev 4, APPROVED 2026-11-21 8:31 PM CT by Bill and stamped by Jared: https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2. It supersedes the "Timeline page concepts — scope note" rev 1.
- **Stitch:** project `13933817203770823979`, screens R1–R8. See [Stitch screens](#stitch-screens). The contact sheet is `family-thread-contact.jpg`.
- **Open UI questions:** none. Q2 is closed: on 2026-11-25 at 4:55 PM CT Bill approved the new token albumMossInk #4A6A2F for the scrubber's matching-decade labels only ([§20](#20-open-ui-questions)). Q1 is closed: on 2026-11-22 at 6:33 AM CT Bill decided the nav and the button stay "Timeline".
- **This doc overrides the mockups.** R1–R8 are exploration renders and contain known slips plus sample data. Where a mockup and this text differ, follow the text. [§15](#15-mockup-corrections) lists every known slip.

## Sources

Only the linked sources and named sections were read:
- PRD, **"Family Thread — milestone scope"** (rev 4), including A1, A4, A5, A6, Out of scope, Reference only, and Pipeline.
- Mugatu's concept note `/workspace/timeline-concepts/river-v2/CONCEPT.md` and the round 4 keepers R1–R8 (`MANIFEST.md`). Both use the exploration name for Concept A. That name is retired, and none of its wording carries into the product.
- Draft PR #249 (https://github.com/wmfmorgan/mortang-tell-me-a-story/pull/249), body and string literals only. It is a prototype marked "do not merge". It was built from the written note without Stitch, at the draft path `/timeline-river`.

## Scope (from rev 4, not extended)

- **Name:** the user-facing name is **Family Thread** (Bill, 8:26 PM CT: "Call it Family Thread"). The word "river" must not appear in any UI copy, screen-reader label, page title or web URL.
- **What it includes:**
  - One continuous thread screen with a three-stop density control: **Overview / Browse / Read**. It replaces the Decades/Years/Days zoom and the zoom switch.
  - The **thread band** in sageTint.
  - A time scrubber with **Jump to year**.
  - Photo story cards: a 4:3 cover, a fan of three plus "+n", or a quote card.
  - Non-matching stories collapse to hollow dots.
  - The #190 filters and the #248 filter panel.
  - Focus centering with fade by distance.
- **Phases:**
  1. **Build alongside.** The current `/timeline` doesn't change, and no link to the new screen is added on it.
  2. **Cut over.** `/timeline` becomes Family Thread after Bill's smoke test on main. Gilfoyle picks the mechanism.
  3. **Decommission.** A separate PR removes the old rails, the zoom switch and their tests.
- **Route:** the final route is `/timeline`. Gilfoyle picks the route used during the build. `/timeline-river` from #249 is a draft path only. UX requirement: the build-phase path must not contain "river", because web users see the URL.
- **A1:** the primary user is any family member who is browsing and rediscovering stories.
- **A4:** the lead photo is the first one attached. Alt text is the caption, or the title when there is no caption. Existing photos only.
- **A5:** the open state is saved on the device and must work on iOS and web.
- **A6:** decades are the only grouping above years.
- **Out of scope:** the tree/treemap page, schema changes, new data, syncing the open state across devices, and any new token.

### Conflicts between the concept and the scope (scope wins)

No blocking conflicts. Where the two differ, this doc follows the scope:
1. **Naming.** The concept said "river" and "river band". These are now **Family Thread** and **thread band**. The water-themed "ripple" delight is replaced by a stitch ring ([§18](#18-delight-pass)).
2. **Alt text.** The concept and A4 both say "caption, else title". The client story payload has no caption field (#249), and new data is out of scope. In practice, **alt = story title** for now. If a caption field ever ships, the rule switches to "caption, else title" automatically, with no UX change.
3. **Open state.** The concept didn't say where state is saved. Scope A5 makes it **device-local** (saved on each device, never synced) on both iOS and web. #249 saved it on web only, which doesn't meet A5.
4. **Years filter.** Scope rev 1 said "decade/year range". Rev 4 and #248 use **decade ranges** only. This doc uses decade ranges.

---

## 1. Terms

| Term (doc and code reviews) | Meaning |
|---|---|
| **Family Thread** | the screen, and its user-facing name |
| **thread band** | the sageTint band the stories hang from. A 2px terracotta **spine** runs down its middle. |
| **beat** | one stop along the thread. Overview: one beat per decade. Browse: one per year. Read: one per story. |
| **focus line** | the vertical centre of the thread area. The beat on it is *focused*. |
| **focus story** | the story the screen is anchored to. Focus is always a story id, even in Overview and Browse. |
| **density** | Overview / Browse / Read |

"Beat", "focus line" and "focus story" are internal terms and never appear in the UI.

## 2. Layout

Stories run **oldest at the top, newest at the bottom**. Within a year they're ordered by the recorded event date at whatever precision was entered, then by publish time.

| Width | Filters | Thread | Scrubber |
|---|---|---|---|
| **≥900pt** | #248 **sidebar**, 280pt on the left, open by default. The toolbar's **Filters** button toggles it. | Centered. Beats alternate left and right of the band. | **Right-edge column**, 56pt wide |
| **600–899pt** | #248 **drawer** (bottom sheet) | Centered. Beats alternate. | Right-edge column |
| **<600pt (phone)** | Drawer | Band 32pt from the left edge, content to the right | **Bottom strip**, 56pt tall, above the safe area |

- **Header:** the existing app header (#130), unchanged.
- **Toolbar:** a row under the header with **Filters** (left), the **density control** (centre on ≥600pt, right on phone), and the **"n of N" count**. On ≥600pt the count sits in the toolbar. On phone it sits in the drawer header and in the Filters button label.
- **Active filter pills** appear in a row under the toolbar whenever a filter is on. Each pill has a 44×44 remove ×.
- **Thread band:** sageTint (#E1E5DD), 24pt wide (16pt on phone), radius 12 at both ends, with a 2px albumTerracotta spine down the middle. It has a small terracotta knot (an 8pt filled dot) at the oldest story ([§18](#18-delight-pass)). No gradient, shadow or glow.
- **Decade landmarks** (Browse and Read only): Newsreader 40pt in albumInkDim, floating beside the band at the first beat of each decade, on the side opposite that beat's card. They're decorative and hidden from screen readers, because each beat's label already carries its year.

## 3. Density model

The scope sets three fixed stops with nothing in between. The page is one screen and one thread. Changing density never navigates.

| Stop | One beat is | Beat visual | Focused beat |
|---|---|---|---|
| **Overview** | a decade (only decades that have stories) | 112pt **decade mosaic** medallion. Label: "1970s · 6 stories" | Medallion with the stitch ring. The label is Newsreader semibold. |
| **Browse** (default) | a year (only years that have stories) | 64pt **year medallion** with the year label | Opens a **story card** beside it: 4:3 photo, title, date line, place and people chips, **Open story**, and "{k} more in {year}" when the year has more stories |
| **Read** | a story | compact card: thumbnail, title, date line | **Expanded card**: photo area per [§7](#7-photo-cards-and-medallions), title, date line, first 3 lines of the story, chips, **Open story** |

- **Anchoring rule:** the focus story stays on the focus line through every density change.
  - Read → Browse shows the focus story's year. Browse → Overview shows its decade.
  - Going back down returns to *the same story*. For example, focus the 1996 story, switch to Overview, and the 1990s cluster is centred. Switch back to Read and the 1996 story is centred.
- **When you move focus at a coarser stop**, for example by scrolling to the 1970s in Overview, the focus story becomes that beat's **representative**: the oldest story in that decade or year, so reading starts at the beginning. One exception: if the previous focus story is inside that beat, it stays the focus story.
- **Browse card content:** if the focus story is in the focused year, the card shows it. Otherwise it shows the year's oldest story.
- **Days:** day precision appears only on the date line, at whatever precision the author entered (existing `storyDateLabel` behaviour). There is no Days stop.
- **Rebuild, not morph** (#249 learning): a density change **rebuilds the beats** at the new stop, with the focus story's beat placed on the focus line.
  - The new beats fade in with a 150ms opacity change. There's no cross-fade, scale morph or scroll animation between stops.
  - With reduced motion on, the swap is instant.
  - Screen readers announce "Showing Overview", "Showing Browse" or "Showing Read".

## 4. Focus, scroll and fade

- Scrolling or swiping moves along the thread. When scrolling stops, the nearest *matching* beat **snaps** to the focus line (200ms ease-out, instant with reduced motion) and becomes focused. Snap never fights a drag that's still in progress.
- Screen readers hear a polite announcement when focus settles: "Focused 1996, The new tractor". In Overview it's "Focused 1990s, 3 stories".
- **Fade by distance** applies to **images only**: photos, medallion art and mosaics. Opacity is 100% at the focused beat, 60% one beat away, and 30% two or more away.
  - **Text never fades below albumInkDim.** Titles and labels of the focused beat and its neighbours use albumInk. Beats two or more away use albumInkDim (5.6:1 on parchment). This replaces the concept's fade-everything, which failed contrast.
  - With reduced motion on, there's no fade at all: every image shows at 100%.

## 5. Anchored drill-down and Back

| You tap | At | Result |
|---|---|---|
| a decade mosaic | Overview | Browse, anchored on that decade. The focus story is unchanged if it's in that decade, otherwise the decade's oldest story. |
| an unfocused year medallion | Browse | It snaps to focus and its card opens. Density doesn't change. |
| the **focused** year medallion | Browse | Read, anchored on the card's story |
| the year card's "{k} more in {year}" | Browse | Read, anchored on that year's first story after the card's story |
| a story card or **Open story** | Browse / Read | the full story at `/stories/:id`, as today |
| an unfocused compact card | Read | It snaps to focus and expands. |
| the focused, expanded card | Read | the full story |

- **Back** from the full story returns to Family Thread at **the same density and focus story, with the same filters, search text and scroll position**. The card you left gets the stitch ring again ([§18](#18-delight-pass)). Back is session navigation, so filters survive it. Filters are *not* restored when you open the screen fresh ([§9](#9-open-state-a5)).
- System Back, edge swipe on iOS and the browser Back button all behave the same way. A density change is not a history entry. Back never steps through densities.

## 6. Time scrubber and Jump to year

- **Rev 1.1:** what the scrubber shows, how it looks and how it moves are now defined in [§6.1](#61-dial-scrubber-rev-11). The rev 1.0 density bumps, viewport window, separate handle and short '90s labels are retired. Position and Jump to year below are unchanged.
- **Position:** on ≥600pt it runs top to bottom in the right-edge column, with **Jump to year** as a 44×44 icon-plus-label button at its foot. On phone it runs left to right in the bottom strip, with **Jump to year** at its right end.
- **Jump to year** opens a small dialog: radius 16, albumParchment, 1px albumModalBorder.
  - Contents: field **Year** (numeric keypad), a helper showing the family's range ("1952–2024"), **Go** (primary, terracotta) and **Cancel**.
  - Enter submits. Go focuses the nearest *matching* story in time at the current density.
  - An out-of-range year clamps to the oldest or newest story. Non-numeric input shows the inline error "Enter a year like 1975." and the dialog stays open.
  - Focus returns to the Jump to year button when the dialog closes.

## 6.1 Dial scrubber (rev 1.1)

Built from Bill's reference screenshot (`/workspace/family-thread/refs/bill-scrubber-reference.png`; rev 1.2 matched against the image itself): a vertical cream pill with full decade labels, small dots between decades, the focused decade in a filled brown chip with white text, matching decades in green and the rest in grey. This section replaces the look and motion in [§6](#6-time-scrubber-and-jump-to-year). Scope is the scrubber only. The thread, density, filters, Jump to year and every other section are unchanged. No schema change and no new data. Code today: `lib/features/family_thread/time_scrubber.dart` (S1a, PR #275 at `9e22776`).

### 6.1a Decades on the dial

- **Every decade from the oldest story's decade to the newest story's decade gets one slot**, evenly spaced, including decades with no stories. Slots are no longer sized by story count.
- A decade is **eligible** when it has at least one story that matches the current filters. With no filters, any decade with a story is eligible.
- Ineligible decades (empty, or no matches) are shown in grey and are skipped by snapping, taps, keys and wheel, the same way non-matching beats are skipped in [§8](#8-filters-190-rules-248-panel).
- Story counts are no longer drawn on the scrubber. They stay on decade beats and mosaic labels (FT-23, FT-32).

### 6.1b Labels: full years

- Every label is the **full decade**: **1950s, 1960s, … 2000s, 2010s, 2020s**. There is no short form anywhere on the scrubber, so '20s can never be read as the 1920s or the 2020s. A family spanning 1920s to 2020s reads 1920s … 2020s.
- FT-27 changes from '{yy}s to **{yyyy}s** (copy delta for Jared's stamp, [§19](#19-copy-strings)). The rev 1.0 "label under the handle" is gone: the focused chip is the label.
- Labels never truncate, wrap or scale down. At 200% text the pitch rule in 6.1c switches the scrubber to the centred dial.

### 6.1c Visual, ≥600pt (right-edge column)

All existing tokens. Measurements in pt.

| Part | Spec |
|---|---|
| Column | 56 wide (unchanged, [§2](#2-layout)) |
| Pill | 48 wide, centred in the column; 12 from the column top; 12 above the Jump to year button. Fill **albumPillFill** #F6F1EB, 1px **albumPillBorder**, **fully round ends** (stadium: radius = half the width, the same shape rule as the thread band's round ends in [§2](#2-layout); no new radius value). No shadow, gradient or glow. |
| Inner padding | 8 at each end of the pill |
| Slot pitch | inner length ÷ number of decades, **minimum 44**. Each label is centred in its slot. |
| Label, eligible | Source Sans 3, 12pt, weight 600, **albumMossInk #4A6A2F** (new token, Bill approved 2026-11-25 4:55 PM CT; ≈5.5:1 on the pill) |
| Label, ineligible | Source Sans 3, 12pt, weight 400, **albumInkDim** (≈5.4:1 on the pill) |
| Dots | between each pair of adjacent labels, **one** 4pt filled circle, **albumInkFaint**, centred in the gap. Decorative, hidden from screen readers. |
| Focused chip | 44 wide × 28 tall, **fully round ends** (stadium), fill **albumTerracotta**, label Source Sans 3 **13pt weight 700** in **albumWhite** (5.5:1). The chip label is one step larger and bolder than the other labels. It sits on top of the pill and fully covers the label of the decade it's on. |
| Keyboard focus | the 2px albumTerracotta ring with 2px offset goes around the **whole pill** ([§13](#13-accessibility)) |
| Pointer (web) | `grab` cursor over the pill, `grabbing` while dragging |

**Fallback, too many decades:** if the pitch would drop below 44 (many decades, a short window, or large text), the ≥600pt pill uses the **centred dial** from 6.1e turned vertical: the chip stays fixed at the pill's vertical centre and the labels slide under it at a 44 pitch, clipped by the pill shape.

**Contrast check:** albumInk on albumPillFill ≈13.5:1, albumInkDim ≈5.4:1, albumWhite on albumTerracotta ≈5.5:1. albumMossInk ≈5.5:1. branchMoss text on the pill is only ≈4.1:1 and fails AA for 12pt text, so it is **not** used for labels (Q2).

### 6.1d Motion: "move smoothly like a dial" (≥600pt)

The chip is the thing you hold. Oldest is at the top, as in the thread.

1. **Press and drag** anywhere on the pill. The chip jumps under the pointer and then follows it **continuously, 1:1**, with no stepping. It's clamped between the first and last eligible decade centres. The chip's label always shows the nearest eligible decade.
2. **Detents while dragging:** each time the nearest eligible decade changes, the thread previews that decade's nearest matching story (the existing `onPreview` path) and iOS plays `HapticFeedback.selectionClick()`. Web has no haptic. Previews fire per detent, not per pixel.
3. **Release with momentum:** take the release velocity *v* (pt/s).
   - If |v| < 50: snap to the nearest eligible decade.
   - Otherwise: projected point = release position + v × 0.25s, clamped to the ends. Snap to the nearest eligible decade to that point.
   - The glide uses `Curves.easeOutCubic`. Duration = 250ms + 25ms per decade travelled, at most 450ms. No overshoot and no bounce at either end.
   - Detent previews and haptics keep firing as the chip passes decades during the glide.
4. **Commit:** when the chip comes to rest, focus settles on that decade's nearest matching story (the existing `onCommit`). That's one commit per gesture.
5. **Catch:** a new press during a glide stops the chip where it is and starts a new drag from there. No commit happens for the interrupted glide.
6. **Pointer cancel** (existing S1a behaviour): the chip returns to the committed decade in 200ms easeOutCubic, the preview is cleared, nothing commits.
7. **Tap** on a slot: the chip slides to the tapped decade over **250ms easeInOutCubic**, and the thread runs its 250ms scroll in sync ([§12](#12-motion-and-reduced-motion)). This is the 250ms that S1a deferred. Tapping an ineligible decade goes to the nearest eligible decade in time, matching today's `tapPick`.
8. **Keys** (focus on the scrubber): ↑/↓ and ←/→ step one eligible decade; Page Up/Page Down step two; **Home/End** go to the oldest/newest eligible decade. Each step animates like a tap (250ms). A step that arrives mid-animation retargets from the chip's current position. Steps don't queue, so a held arrow never runs ahead of the chip.
9. **Wheel and trackpad over the pill** (web, no modifier): scrolling moves the chip continuously, 1pt of chip per 1pt of scroll delta. 150ms after the last wheel event it snaps as in step 3 with v = 0, then commits. The event is consumed, so the thread doesn't also scroll. Ctrl/⌘ + wheel over the scrubber still goes to the browser for page zoom ([§10](#10-input-gestures-keys-pointer)).
10. Nothing loops and nothing moves on its own.

**Reduced motion:**
- Drag still follows the pointer 1:1, because that's direct manipulation, not animation.
- No momentum: release snaps **instantly** to the nearest eligible decade to the release point, with no projection.
- Tap, keys, wheel snap and pointer cancel cut straight to the target, and so does the thread (existing §12 row).
- Haptics stay. They aren't motion, and iOS has its own system haptics switch.

### 6.1e Phone bottom strip (<600pt): the centred dial

Labels at full width don't fit side by side on a phone (8 decades × 44 > ~280pt), so on phone the **dial turns and the chip stays put**.

| Part | Spec |
|---|---|
| Strip | 56 tall, above the safe area (unchanged) |
| Pill | 44 tall, horizontal, from 16 off the left edge to 8 before the Jump to year button (44×44, right end, 16 from the right edge). Same fill, border and fully round ends as 6.1c. |
| Chip | fixed at the pill's horizontal centre, 56 wide × 28 tall, fully round ends, terracotta with albumWhite 13pt weight 700 label |
| Labels | the same full labels and colours as 6.1c, laid out at a fixed **64 pitch**, one 4pt albumInkFaint dot in each gap. The row is padded by half the pill width at each end so the oldest and the newest decade can both sit under the chip. Hard clip at the pill shape, with no fade gradient. |

Motion is the same as 6.1d, except that **the row is the thing you hold**:
- Dragging left brings newer decades to the chip and dragging right brings older ones. The row follows the finger 1:1.
- Release uses the same momentum, snap, durations, detent previews, haptics, catch, commit and reduced-motion rules.
- A tap on a visible label slides that label to the chip over 250ms, with the thread in sync.
- A horizontal swipe on the strip never scrolls the thread or the page.

### 6.1f States

- **Loading:** the pill renders empty (fill and border only, no labels, no chip), per [§11](#11-loading-empty-error).
- **Empty family:** hidden, as before.
- **One decade:** one label with the chip on it. Drag and keys do nothing, and it's still exposed as a slider.
- **Filters change:** labels recolour to the new eligibility. If the focused decade becomes ineligible, the chip follows the thread's new focus (250ms, or a cut under reduced motion). It never picks a decade by itself.
- **Focus moves in the thread** (scroll, ↑/↓, drill-down, Back): the chip follows to the focused decade with the 200ms snap, and there's no commit loop back into the thread.

### 6.1g Screen readers

Unchanged from [§13](#13-accessibility): one slider, FT-34 "Timeline scrubber, 1950s to 2020s, showing 1990s", value text "1990s". Increase/decrease step one eligible decade. Labels, dots and chip are excluded from semantics, as today. The focused decade is announced politely when it settles, not on each detent during a drag.

### 6.1h Acceptance checks for the build

1. Full labels 1950s…2020s, each once, in order, evenly spaced; no '90s form anywhere on the scrubber.
2. Pill albumPillFill + 1px albumPillBorder, fully round ends; chip albumTerracotta, fully round ends, albumWhite 13pt w700 text; eligible labels albumMossInk #4A6A2F w600 12pt; ineligible albumInkDim w400 12pt; one 4pt albumInkFaint dot per gap. No colour outside `album_theme.dart`; albumMossInk is added there as `Color(0xFF4A6A2F)` and used only for eligible scrubber labels.
3. Drag moves the chip continuously (golden or widget test at a mid-slot position shows the chip between two slots).
4. A fling ends on an eligible decade with one `onCommit`; previews fire once per detent.
5. A tap animates 250ms; under reduced motion, a tap and a fling end with no animation frames.
6. Home/End/Page keys work; ineligible decades are skipped by every input.
7. Phone: fixed centre chip, row drags, oldest and newest can both reach the chip.
8. ≥600pt with a pitch below 44 switches to the vertical centred dial.
9. Tab from the focused card's Open story reaches the scrubber, and Shift+Tab goes back ([§13](#13-accessibility), the open note from #268).

## 7. Photo cards and medallions

From R7. The lead photo is the **first attached** photo (A4).

- **a. One photo:** 4:3 cover crop, radius 12 on the top corners, centred.
- **b. Two or more photos: a fan of three** (R6 fix: the fan must be clearly readable as a stack).
  - The front print is upright. Two prints sit behind it at **−6°** and **+5°**, offset **12pt** sideways and **6pt** up.
  - At least **8pt** of each back print shows on two edges.
  - Each print has a 4pt albumParchment mat and a 1px albumPillBorder outline. No shadow and no glow.
  - A **"+n" chip** shows when there are more than 3 photos: albumParchment fill, albumInk Source Sans 3 semibold 13pt, radius 8, bottom-right of the front print. With exactly 2 photos, the fan shows 2 prints and no chip.
- **c. No photo:** an albumParchment card with a terracotta Newsreader quote mark (48pt) and the **first line of the story**.
  - It never shows a broken image, an empty frame or a grey placeholder.
  - If the story text is a single line, it isn't repeated under the quote (#249).
  - A photo that fails to download uses this card.
- **d. Medallions:**
  - **Year medallion:** a circle crop of the lead photo of the year's first story that has a photo, with a 2px terracotta ring. If no story that year has a photo, it shows the oldest story's **initial**: Newsreader semibold 28pt, terracotta on albumBlush. That counts as large text, so 4.3:1 passes.
  - **Decade mosaic:** 1 story fills the whole circle. 2–3 stories split it into 2–3 tiles. 4 or more make a 2×2 grid. When there are more than 4, the 4th tile becomes **"+k"** (albumInk on albumPaleRose). Tiles use each story's lead photo, or its initial tile.
- **Alt text:** the caption, otherwise the story **title**. Today that's always the title (§Conflicts 2).
  - A fan reads "{title}, {n} photos".
  - A no-photo card has no image, so it needs no alt. The quote reads as text.
  - Medallions use the combined beat label in [§13](#13-accessibility).
- **Sample data:** place names, people names and repeated photos in R1–R8 are sample data only. Real cards show the family's own stories and photos.

## 8. Filters (#190 rules, #248 panel)

- **Panel:** #248's filter panel as it is. A sidebar on ≥900pt, a drawer below that.
  - **Search:** "Search titles, stories and people".
  - **People** and **Places** chips. Selected chips use a sageTint fill, an albumInk label and a ✓.
  - **Years:** a decade range slider showing "1950s – 2000s".
  - **Clear filters**.
  - The drawer footer adds **Show {n} stories**, which closes the drawer.
- **Logic:** OR within a category, AND across categories. Search is ANDed with the others.
- **Results stay in place.** Matching stories keep their photos. Non-matching beats **collapse in place** to a **hollow 12pt dot**: a 1.5px albumInkDim outline, which is 3:1 or better as a non-text indicator. The title sits beside it in albumInkDim.
  - At Overview, a decade with no matches becomes a hollow dot with its label. A decade with some matches builds its mosaic from the matching stories and is labelled "{decade}s · {m} of {n} stories".
  - Non-matching beats are skipped by snapping, by ↑/↓ and by scrubber jumps. They can't be tapped, but screen readers still read them.
- **Focus under filters:** if the focus story stops matching, focus moves to the nearest matching story in time. **Clear filters** keeps the current focus.
- **Count:** "{n} of {N} stories", always visible (toolbar on ≥600pt, drawer header on phone). The **Filters** button shows "Filters · {k}" when k filters are active.
- **No match:** the thread keeps its hollow dots, and a centred card sits on the focus line: "No stories match these filters." + **Clear filters**. The card is radius 12, albumPaleRose, with a 1px albumModalBorder.
- **Removable pills:** one per active value. A decade range shows as one pill, "1950s – 2000s".

## 9. Open state (A5)

This section describes behaviour only. The storage mechanism is Gilfoyle's call.

- **What's remembered**, **per family, on this device:** the last **density** and the **focus story**. It's saved whenever focus settles or density changes, so a crash or kill loses at most the last settle.
- **On open:** restore the density, then centre the focus story.
  - **The story is gone** (unpublished, deleted or no longer visible): open at the same density on the **nearest story in time**. When two are equally near, the newer one wins.
  - **Nothing saved** (first visit, new device, a family never opened here, or storage unavailable such as private browsing): open at **Browse**, centred on the **newest published story**.
  - **Filters are never restored** on open. The screen opens unfiltered, showing "N of N stories".
- **Platforms:** this must work on **iOS** (across app relaunch and after the app is killed) and on **web** (across reload and new tabs in the same browser). The #249 prototype only persisted on web, which doesn't meet this.
- **Not synced across devices** (out of scope). Each device has its own last place. No UI mentions syncing.
- **Switching family** while on Family Thread (#82 family switch) opens the new family's own saved place.
- Restoring happens before the first frame of the thread draws. There's no visible jump from the newest story to the saved spot. Show the loading skeleton until the thread is ready.

## 10. Input: gestures, keys, pointer

| Input | Effect |
|---|---|
| Scroll wheel, trackpad two-finger scroll, touch swipe | moves along the thread, then snaps |
| **Density control** (segmented radio group) | sets the stop |
| **Pinch** (iOS touch, web touch, trackpad pinch) | one stop per gesture: pinch in → coarser, pinch out → finer |
| **Ctrl/⌘ + wheel** (web) | **One density step per gesture, and it does NOT scroll** (see below) |
| `+` / `=` and `−` / `-` with no modifier, while focus is in the thread | finer / coarser |
| ↑ / ↓ | previous / next matching beat |
| Home / End | oldest / newest matching story |
| Enter / Space on the focused beat | same as tapping it (drill down per [§5](#5-anchored-drill-down-and-back)) |
| Esc | closes the Jump to year dialog or the drawer |

**Decision on ctrl/⌘ + scroll (#249 learning):** keep it as a density control, and consume the event.
- In #249, ctrl/⌘ + scroll both changed density *and* scrolled. That's two effects from one gesture and it loses your place.
- Locked behaviour: when the pointer is **over the thread area**, ctrl/⌘ + wheel **only** changes density. The event's default handling and the scroll are both cancelled (preventDefault on web), so neither the thread nor browser page zoom moves.
- Wheel deltas add up until they cross one threshold, then step one stop. There's a 300ms cooldown, so one flick equals one step.
- **Why keep it:** browsers report a trackpad pinch as ctrl + wheel. Dropping ctrl + wheel would quietly break trackpad pinch on web, and pinch is a locked input.
- **Guardrails:**
  - Outside the thread area (header, toolbar, sidebar, scrubber), ctrl/⌘ + wheel keeps the browser's own page zoom.
  - Ctrl/⌘ + `+` / `−` / `0` on the keyboard are **never** intercepted, so browser zoom (WCAG 1.4.4 Resize Text) always works.
  - Plain `+` / `−` are ignored while a text field has focus.

## 11. Loading, empty, error

- **Loading:** the toolbar and scrubber frame render. The thread band shows 5 skeleton beats: albumPaleRose circles and lines, with no shimmer when reduced motion is on. Screen readers hear "Loading stories". The density control is disabled until the thread is ready.
- **Empty family** (0 published stories): reuse the current `/timeline` empty state, copy and action **verbatim**. No new copy. The scrubber, density control and Filters are hidden.
- **Load error:** the existing sentence **"Couldn't load stories."** + **Retry**, centred where the thread would be. There's no automatic retry.
- **A photo fails to load:** that card falls back to the no-photo quote card ([§7c](#7-photo-cards-and-medallions)), and a medallion falls back to the initial. No error toast.

## 12. Motion (and reduced motion)

| Motion | Default | Reduced motion |
|---|---|---|
| Snap to focus line | 200ms ease-out | instant |
| Density rebuild | new beats fade in over 150ms (opacity only) | instant swap |
| Fade by distance | 100 / 60 / 30% on images | none, all at 100% |
| Stitch ring on focus | draws once over 400ms, then stays still | static ring, no animation |
| Scrubber tap jump | 250ms scroll | cut, no animation |
| Scrubber chip on tap / key step (rev 1.1) | 250ms easeInOutCubic, in sync with the thread | cut |
| Scrubber release glide (rev 1.1) | easeOutCubic, 250ms + 25ms per decade, max 450ms, no overshoot | none: instant snap to nearest decade |
| Drawer | platform sheet motion | no slide; appears in place |
| Skeleton | gentle opacity pulse | static |

- Nothing loops. #249's repeating ripple is removed: a looping animation that runs until focus moves goes against WCAG 2.2.2 (Pause, Stop, Hide) and is a distraction.
- There's no parallax at any setting.

## 13. Accessibility

WCAG 2.2 AA throughout.
- **Contrast:**
  - Body text and labels are albumInk (14.4:1 on parchment, 12.0:1 on sageTint).
  - Secondary or dimmed text is albumInkDim (5.6:1 on parchment, 5.1:1 on sageTint).
  - albumTerracotta text is allowed on albumParchment (5.2:1) and albumPaleRose (4.75:1). It's **not** allowed as small text on sageTint (4.3:1) or albumBlush (4.3:1). There it's only for large text such as the initials, or for non-text marks.
  - albumSage and branchMoss are never used for text here.
  - Parchment text on a terracotta button is 5.2:1.
- **Targets:** at least 44×44 for every control. That covers medallions (the 64pt and 112pt visuals already meet it), compact cards, density stops, Filters, filter chips, pill ×, the scrubber handle, Jump to year, Go/Cancel and Open story. The hollow dots aren't interactive, so they need no target.
- **Screen-reader labels** (the exact strings are in [§19](#19-copy-strings)):
  - The density control is a radio group, "Density", with each stop as a radio. Selected state is exposed.
  - The thread is one list, "Family Thread, {N} stories". Each beat is a list item with a combined label:
    - Year: "1996, The new tractor, The farm, Tom, 3 photos".
    - Decade: "1990s, 3 stories".
    - Non-match: "{title}, {year}, doesn't match filters".
  - The scrubber is a slider: "Timeline scrubber, 1950s to 2020s, showing 1990s", with year values. Arrow keys step one eligible decade, Page Up/Down step two and Home/End go to the oldest/newest (rev 1.1, [§6.1](#61-dial-scrubber-rev-11)).
  - Focus, density and filter-count changes are announced politely.
- **Keyboard and tab order:** header → toolbar (Filters, Density, Jump to year on ≥600pt) → filter sidebar when open → thread (**one tab stop**, roving focus with ↑/↓) → the focused card's Open story → scrubber.
  - The keyboard focus ring is a 2px albumTerracotta outline with a 2px offset. It's never hidden behind the sticky header (WCAG 2.4.11).
- **Dragging alternative** (WCAG 2.5.7): every scrubber drag can also be done by tapping, with the arrow keys, or with Jump to year. Pinch and ctrl + wheel always have the density control as an alternative.
- **Text resize:** layouts reflow up to 200% text. Card titles wrap to 3 lines, then truncate with an ellipsis, and the full title stays in the label.

## 14. Tokens

**One new token (rev 1.3):** **albumMossInk #4A6A2F**, approved by Bill on 2026-11-25 at 4:55 PM CT, for the scrubber's matching-decade labels only ([§6.1c](#61-dial-scrubber-rev-11)). It isn't used anywhere else. Every other colour is an existing `album_theme` token:
- Colours: albumParchment #FBF7F2, albumInk #2C2416, albumInkDim (ink 70%), albumTerracotta #8B5E4B, albumSage #7A8B74 (non-text only), branchMoss #5B7F3A (unused here), albumBlush #F5DED6, albumPaleRose #F5ECE9, albumPillFill #F6F1EB, albumPillBorder, albumModalBorder, albumInkFaint (ink 20%), albumWhite #FFFFFF.
- **sageTint**, approved by Bill: albumSage at about 18%, rendered #E1E5DD. It's used for the selected filter chips (approved 5:11 PM CT) and for the **thread band** (Bill, 6:14 PM CT).
- Type: Newsreader for headings, landmarks, card titles and initials. Literata for story body and excerpts. Source Sans 3 for labels, chips, counts and the scrubber.
- Radii: 12 for cards, 8 for chips and pills, 16 for dialogs. No glow anywhere, and no drop shadows on the thread.
- Rule: if a build step seems to need a new colour, size scale or radius, it stops and asks Bill. Don't approximate one.

## 15. Mockup corrections

The text in this doc is authoritative. These slips in R1–R8 are **not** to be built:
1. **R2, R5 and R8, scrubber:** superseded by rev 1.1. Build the scrubber from [§6.1](#61-dial-scrubber-rev-11), not from any R screen. (Rev 1.0 note: each decade label appears once, in order.)
2. **R5 and R8, the label under the scrubber handle:** superseded by rev 1.1. The focused chip shows the focused decade, for example **1990s**.
3. **R3, Read:** a 1995 marker sits out of chronological order, and the 1988 landmark doesn't match the 1989 date on its card. Beats are strictly chronological ([§2](#2-layout)). A landmark is the decade label at the first beat of its decade. Cards show their own date line, and nothing contradicts it.
4. **R6, phone Read:** the photo fan is too subtle to read as several photos. Build the fan per [§7b](#7-photo-cards-and-medallions) (−6° / +5°, 12pt offset, at least 8pt visible).
5. **R1** shows a 40-story sample while the other screens show about 12. Every count is live data. Neither number is a design target.
6. **R1–R8:** invented place and people names and repeated photos are sample data only.
7. **Exploration titles:** Stitch screen titles and R7's heading use the retired exploration name. They are not UI copy. The screen is "Family Thread".
8. **R1** caption "The Morgan Family · …": the family name comes from data, written as the header shows it, with no doubled "Family" ([§19](#19-copy-strings), FT-26).

## 16. Draft PR #249: what it taught and how it's resolved

| # | #249 behaviour or finding | Locked resolution |
|---|---|---|
| L1 | No caption field on the client story payload, so alt = title | Alt = title today. The rule stays "caption, else title" (A4) with no new data ([§7](#7-photo-cards-and-medallions)). |
| L2 | A density change rebuilds the beats rather than cross-fading | Rebuild, focus anchored on the focus story, new beats fade in over 150ms, **instant with reduced motion** ([§3](#3-density-model)) |
| L3 | The Years filter is the #248 decade range | Locked as **decade ranges**: "1950s – 2000s" ([§8](#8-filters-190-rules-248-panel)) |
| L4 | Ctrl/⌘ + scroll changed density *and* scrolled | **Kept as density, with preventDefault, no scroll**, only over the thread. Browser zoom keys are never intercepted ([§10](#10-input-gestures-keys-pointer)). |
| L5 | Open state persisted on web only | Must persist on **iOS and web** (A5), per family, device-local ([§9](#9-open-state-a5)) |
| L6 | The ripple repeats until focus moves | A **stitch ring** that draws once and stays still. Nothing loops ([§12](#12-motion-and-reduced-motion), [§18](#18-delight-pass)). |
| L7 | Enter opened `/stories/:id` from any density | Enter = tap on the focused beat, so it drills one level ([§5](#5-anchored-drill-down-and-back)) |
| L8 | Count read "n of N stories match" | Unified as "{n} of {N} stories" (FT-14) |
| L9 | Overview caption "The {name} Family · …" | Uses the family's display name, with no doubled "Family" (FT-26) |
| L10 | Every beat built up front, so a large family builds every medallion | Not a UX rule, but a UX requirement: scrolling and snapping stay smooth for a family with hundreds of stories. Gilfoyle owns how. |
| L11 | Scrubber column from 600px wide | Kept: right column at ≥600pt, bottom strip below ([§2](#2-layout)) |
| L12 | The route `/timeline-river` | A draft path only. The build-phase path is Gilfoyle's call, without "river". The final route is `/timeline`. |
| L13 | One 3,275-line PR | Process lesson from the scope. The UX sections here are numbered so Big Head can slice small PRs, for example: thread + density → photos → filters → scrubber/jump → open state → cutover. |

## 17. Heuristics check (Nielsen)

1. **Visibility of status:** the density control shows the current stop. The scrubber window and '90s label show where you are. "n of N" and the Filters count show filter state. Screen readers hear focus announcements.
2. **Match with the real world:** decades and years as people remember them, a thread of family stories, photo prints in a fan.
3. **User control and freedom:** Back returns to the exact spot. Clear filters is one tap. Density changes are always reversible with no data loss.
4. **Consistency and standards:** the #248 filter panel, #190 logic, existing radii and tokens, and the existing story date line and `/stories/:id` reader.
5. **Error prevention:** Jump to year clamps out-of-range input. Gestures snap to 3 stops with no in-between states. Ctrl + wheel can't double-fire.
6. **Recognition over recall:** photos and titles appear on the thread. Decade landmarks act as signposts. Active filter pills stay visible.
7. **Flexibility and efficiency:** pinch, ctrl + wheel, +/−, arrow keys, the scrubber and Jump to year are all shortcuts over one model.
8. **Aesthetic and minimalist design:** one thread and one accent (terracotta), with fades on images only. No in-between zoom states.
9. **Recognising and recovering from errors:** "Couldn't load stories." + Retry. Failed photos degrade to the quote card. A missing saved story falls back to the nearest one.
10. **Help:** labels are self-explanatory, and the density stops have plain names. No tutorial is needed.

**One design system:** every component comes from the existing album theme, the #248 panel and the existing reader. No one-off styles.

## 18. Delight pass

Small and quiet, with no glow and nothing that loops:
- **Stitch ring:** when a beat takes focus, a thin dashed albumTerracotta ring is drawn around its medallion or card once, like a stitch pulled through, and then stays. It replaces the concept's water ripple. With reduced motion on, it's simply there.
- **Knot at the beginning:** the thread band starts with a small terracotta knot at the oldest story. It's a quiet sign of "where the family's stories begin".
- **"You were here":** coming Back from a story lands you on that same card with its stitch ring. Opening the app lands you where you left off.
- **Overview caption:** "{Family name} · stories carried down the years", in Literata italic albumInkDim beneath the thread.
- **Photo fan:** prints with parchment mats, like real photos in an album.

## 19. Copy strings

These are for **Jared's stamp** after Bill's review. {braces} are values. Strings marked *existing* are carried over verbatim from #190, #248 or today's `/timeline` and need no restamp. They're listed so the stamp covers the whole screen.

| # | Where | String |
|---|---|---|
| FT-01 | Screen title (app bar semantics and browser tab) | Family Thread |
| FT-02 | Density radio group label (screen reader) | Density |
| FT-03 | Density stop | Overview |
| FT-04 | Density stop | Browse |
| FT-05 | Density stop | Read |
| FT-06 | Density change announcement | Showing {Overview \| Browse \| Read} |
| FT-07 | Toolbar button | Filters *(existing)* |
| FT-08 | Toolbar button with active filters | Filters · {k} |
| FT-09 | Panel heading | Filters *(existing)* |
| FT-10 | Search placeholder | Search titles, stories and people *(existing)* |
| FT-11 | Filter section labels | People · Places · Years *(existing)* |
| FT-12 | Decade range value and pill | {from}s – {to}s *(existing)* |
| FT-13 | Pill remove (screen reader) | Remove filter: {value} |
| FT-14 | Count | {n} of {N} stories (singular: 1 of 1 story) |
| FT-15 | Clear action | Clear filters *(existing)* |
| FT-16 | Drawer footer button | Show {n} stories (singular: Show 1 story) |
| FT-17 | Drawer close (screen reader) | Close filters |
| FT-18 | No-match card | No stories match these filters. *(existing)* |
| FT-19 | Scrubber button and dialog title | Jump to year *(existing)* |
| FT-20 | Jump dialog field label / helper | Year / {oldest}–{newest} |
| FT-21 | Jump dialog actions | Go · Cancel |
| FT-22 | Jump dialog error | Enter a year like 1975. |
| FT-23 | Decade mosaic label | {decade}s · {n} stories (singular: 1 story); filtered: {decade}s · {m} of {n} stories |
| FT-24 | Year card link to Read | {k} more in {year} |
| FT-25 | Card action | Open story |
| FT-26 | Overview caption | {Family name} · stories carried down the years |
| FT-27 | Scrubber decade label | {yyyy}s (e.g. 1990s) *(changed in rev 1.1 from '{yy}s; needs Jared's stamp)* |
| FT-28 | Load error + action | Couldn't load stories. · Retry *(existing)* |
| FT-29 | Loading (screen reader) | Loading stories |
| FT-30 | Thread list (screen reader) | Family Thread, {N} stories |
| FT-31 | Year / story beat (screen reader) | {year}, {title}, {place}, {people}, {n} photos *(missing parts are left out; "1 photo"; no photo part when there are none)* |
| FT-32 | Decade beat (screen reader) | {decade}s, {n} stories |
| FT-33 | Non-match beat (screen reader) | {title}, {year}, doesn't match filters |
| FT-34 | Scrubber (screen reader slider) | Timeline scrubber, {oldest}s to {newest}s, showing {decade}s |
| FT-35 | Focus announcement | Focused {year}, {title} / Focused {decade}s, {n} stories |
| FT-36 | Photo alt / fan alt | {title} / {title}, {n} photos |
| FT-37 | Empty family | the current `/timeline` empty-state copy and action, verbatim *(existing)* |

**37 strings** (FT-01 to FT-37). 10 are existing or verbatim carries (FT-07, 09, 10, 11, 12, 15, 18, 19, 28, 37), and 27 are new or changed.

## 20. Open UI questions

**None blocking.**
- **Q1 (CLOSED 2026-11-22, 6:33 AM CT). Bill: "Keep the nav and button as 'Timeline'". Both keep their current locked copy, and the route stays `/timeline`.** The original question: at cutover, should the header nav item "Timeline" and the Family Landing CTA be renamed to "Family Thread"? **Default if unanswered:** both keep their current locked copy, the route stays `/timeline`, and the screen itself is titled **Family Thread** (FT-01). A rename would be a small copy delta for Jared to stamp, not a UX change.

- **Q2 (CLOSED 2026-11-25, 4:55 PM CT). Bill: "Approve the new albumMossInk green for the scrubber labels". Answer (a): albumMossInk #4A6A2F, scrubber matching-decade labels only.** The original question, green labels for matching decades: Bill's reference shows matching decades in green. The existing greens fail AA as 12pt text on the pill (branchMoss ≈4.1:1; albumSage is non-text only). **Options:** (a) approve one new token, **albumMossInk #4A6A2F** (≈5.5:1 on albumPillFill, ≈5.8:1 on parchment), used only for eligible scrubber labels; (b) keep albumInk. **Mugatu's pick: (a).** **Default until answered: (b) albumInk.** Either way it's a one-constant swap in the scrubber and changes nothing else.

## Handoff notes for Gilfoyle (SAD)

These are not UX decisions. Each one is a UX requirement whose mechanism Gilfoyle picks:
- **Build-phase route:** no "river" in it. Cutover mechanism. A separate decommission PR.
- **Device-local open-state storage** that survives relaunch on iOS and reload on web ([§9](#9-open-state-a5)). Not synced.
- **Web:** ctrl/⌘ + wheel needs a non-passive listener scoped to the thread area so preventDefault works ([§10](#10-input-gestures-keys-pointer)).
- **Performance:** smooth snapping and centring for large families (L10).
- **Live updates:** keep the same live-update behaviour as the current `/timeline`. No new UX is required either way.
- **Stories with no recorded year:** not expected for published stories. Confirm against the data model rather than designing for it.

## Stitch screens

Project `13933817203770823979`. These are reference renders only. **This doc is authoritative** ([§15](#15-mockup-corrections)). Screen titles in Stitch still use the exploration name.

| Screen | What it shows | Link |
|---|---|---|
| R1 | Overview, desktop with sidebar | https://stitch.withgoogle.com/projects/13933817203770823979/screens/9cbf77de78b54bb19d8344c7323c51ab |
| R2 | Browse + scrubber, desktop | https://stitch.withgoogle.com/projects/13933817203770823979/screens/b35ae83d265941b0a66ff1799031d36e |
| R3 | Read, focused card expanded | https://stitch.withgoogle.com/projects/13933817203770823979/screens/e774e6c00c084517a9bd756fd3c09c50 |
| R4 | Browse, filtered (hollow dots) | https://stitch.withgoogle.com/projects/13933817203770823979/screens/f43d60a4ac1a44de9fef5d5cd5301434 |
| R5 | Phone Browse, bottom scrubber | https://stitch.withgoogle.com/projects/13933817203770823979/screens/08985a95a2804ee6ada1b9462275bfed |
| R6 | Phone Read | https://stitch.withgoogle.com/projects/13933817203770823979/screens/8b1a1be70d5141b89928a5ff94c95598 |
| R7 | Photo card variants (one, fan, none, medallions) | https://stitch.withgoogle.com/projects/13933817203770823979/screens/ebdb6d71a4de489eb01f9bac920e1209 |
| R8 | Phone filter drawer | https://stitch.withgoogle.com/projects/13933817203770823979/screens/58a794a0d1904f0d89855daa56de8962 |

Contact sheet: `family-thread-contact.jpg` (R1–R8, reference only).

## Changelog

- **rev 1.3 (2026-11-25, 4:57 PM CT):** closed Q2 as (a). Bill approved albumMossInk #4A6A2F at 4:55 PM CT for the scrubber's matching-decade labels only. Updated §6.1c, §6.1h check 2, §14 and §20.
- **rev 1.2 (2026-11-25, 4:55 PM CT):** matched §6.1 against Bill's actual screenshot. Pill and chip now have fully round ends, there is one 4pt albumInkFaint dot per gap instead of three, and the chip label is 13pt weight 700. Nothing else changed.
- **rev 1.1 (2026-11-25, 4:52 PM CT):** lane 2 delta from Bill's 4:50 PM CT ask via Erlich. Added [§6.1](#61-dial-scrubber-rev-11), the dial scrubber: cream pill, full decade labels, dots, terracotta focus chip, continuous drag with momentum and snap, the 250ms tap animation, reduced motion, and the phone centred dial. §6 bullets were retired in place, §12 gained two rows, §13 gained Home/End, FT-27 changed to {yyyy}s, §15 items 1–2 were superseded, and Q2 was opened. No new tokens are used; Q2 proposes one.
- **rev 1.0 (2026-11-21, approved 2026-11-22 at 6:33 AM CT):** first lock, which Bill approved as written. He also closed Q1: the nav and the button stay "Timeline". Built from scope rev 4, Bill's 6:14 PM CT decisions, R1–R8 and the #249 learnings. Renamed to Family Thread and thread band throughout.
