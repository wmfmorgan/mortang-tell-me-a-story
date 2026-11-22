# Family Thread (timeline rebuild): UX

**Status: APPROVED rev 1.0. Bill approved it as written on 2026-11-22 at 6:33 AM CT.** Locked by Mugatu (UXD) from the approved milestone scope rev 4, Bill's density decisions (6:14 PM CT), mockups R1–R8 and the draft PR #249 learnings. Jared stamps the copy strings FT-01 to FT-37, and the doc then goes to Gilfoyle (SAD).

- **Scope source:** PRD, section **"Family Thread — milestone scope"**, rev 4, APPROVED 2026-11-21 8:31 PM CT by Bill and stamped by Jared: https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2. It supersedes the "Timeline page concepts — scope note" rev 1.
- **Stitch:** project `13933817203770823979`, screens R1–R8. See [Stitch screens](#stitch-screens). The contact sheet is `family-thread-contact.jpg`.
- **Open UI questions:** none. Q1 is closed: on 2026-11-22 at 6:33 AM CT Bill decided the nav and the button stay "Timeline". See [§20](#20-open-ui-questions).
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

- **What it shows:** a minimap of the whole thread, oldest to newest.
  - **Decade ticks**, labelled in short form ('50s, '60s, … '00s, '10s, '20s). Each decade label appears **once**.
  - **Density bumps** per decade, sized by story count. Filled albumInkDim for matching stories. With filters on, non-matching stories show as an outline only.
  - A **viewport window**: a 2px albumTerracotta outline, radius 8, over the part of the thread on screen.
  - A **handle**: the window's grab point, with a 44×44 target.
- **Label under the handle:** the focused decade, in short form. If you're focused in the 1990s, it reads **'90s**.
- **Interaction:** drag the window or handle, or tap anywhere on the scrubber. While you drag, the thread follows live and focus settles when you let go. A tap jumps straight to the nearest matching story in that decade, with no scroll animation under reduced motion. The scrubber never changes density.
- **Position:** on ≥600pt it runs top to bottom in the right-edge column, with **Jump to year** as a 44×44 icon-plus-label button at its foot. On phone it runs left to right in the bottom strip, with **Jump to year** at its right end.
- **Jump to year** opens a small dialog: radius 16, albumParchment, 1px albumModalBorder.
  - Contents: field **Year** (numeric keypad), a helper showing the family's range ("1952–2024"), **Go** (primary, terracotta) and **Cancel**.
  - Enter submits. Go focuses the nearest *matching* story in time at the current density.
  - An out-of-range year clamps to the oldest or newest story. Non-numeric input shows the inline error "Enter a year like 1975." and the dialog stays open.
  - Focus returns to the Jump to year button when the dialog closes.

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
  - The scrubber is a slider: "Timeline scrubber, 1950s to 2020s, showing 1990s", with year values. Arrow keys step one decade and Page Up/Down step two.
  - Focus, density and filter-count changes are announced politely.
- **Keyboard and tab order:** header → toolbar (Filters, Density, Jump to year on ≥600pt) → filter sidebar when open → thread (**one tab stop**, roving focus with ↑/↓) → the focused card's Open story → scrubber.
  - The keyboard focus ring is a 2px albumTerracotta outline with a 2px offset. It's never hidden behind the sticky header (WCAG 2.4.11).
- **Dragging alternative** (WCAG 2.5.7): every scrubber drag can also be done by tapping, with the arrow keys, or with Jump to year. Pinch and ctrl + wheel always have the density control as an alternative.
- **Text resize:** layouts reflow up to 200% text. Card titles wrap to 3 lines, then truncate with an ellipsis, and the full title stays in the label.

## 14. Tokens

**No new tokens.** Only existing `album_theme` tokens are used:
- Colours: albumParchment #FBF7F2, albumInk #2C2416, albumInkDim (ink 70%), albumTerracotta #8B5E4B, albumSage #7A8B74 (non-text only), branchMoss #5B7F3A (unused here), albumBlush #F5DED6, albumPaleRose #F5ECE9, albumPillBorder, albumModalBorder.
- **sageTint**, approved by Bill: albumSage at about 18%, rendered #E1E5DD. It's used for the selected filter chips (approved 5:11 PM CT) and for the **thread band** (Bill, 6:14 PM CT).
- Type: Newsreader for headings, landmarks, card titles and initials. Literata for story body and excerpts. Source Sans 3 for labels, chips, counts and the scrubber.
- Radii: 12 for cards, 8 for chips and pills, 16 for dialogs. No glow anywhere, and no drop shadows on the thread.
- Rule: if a build step seems to need a new colour, size scale or radius, it stops and asks Bill. Don't approximate one.

## 15. Mockup corrections

The text in this doc is authoritative. These slips in R1–R8 are **not** to be built:
1. **R5 and R8, bottom scrubber:** the '50s label appears twice. Each decade label appears once, in order ('50s, '60s, '70s, '80s, '90s, '00s, …).
2. **R5 and R8, the label under the scrubber handle** reads '70s while the thread is focused in the 1990s. The handle label is the focused decade, here **'90s** ([§6](#6-time-scrubber-and-jump-to-year)).
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
| FT-27 | Scrubber tick label | '{yy}s (e.g. '90s) |
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

- **rev 1.0 (2026-11-21, approved 2026-11-22 at 6:33 AM CT):** first lock, which Bill approved as written. He also closed Q1: the nav and the button stay "Timeline". Built from scope rev 4, Bill's 6:14 PM CT decisions, R1–R8 and the #249 learnings. Renamed to Family Thread and thread band throughout.
