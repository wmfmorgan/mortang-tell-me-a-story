# Family Thread (timeline rebuild): UX

**Status: LOCKED rev 1.4. Bill approved it as written, including Mugatu's picks on Q3 to Q8, on 2026-11-25 at 5:29 PM CT (relayed by Erlich).** The previous lock was rev 1.3 (2026-11-25, 4:57 PM CT). Rev 1.4 is a full-page Stitch-match revision from Bill's 4:59 PM CT approval of the Stitch-match plan (relayed by Erlich): the shipped page is to match R1–R8. [§6.1](#61-dial-scrubber-rev-11) (the dial scrubber) is unchanged from rev 1.3 except for cross-links. The copy strings it adds (FT-38 to FT-40) go to Jared for his stamp. History: rev 1.0 was approved by Bill as written on 2026-11-22 at 6:33 AM CT. Rev 1.1 to 1.3 are lane 2 deltas to the time scrubber only, from Bill's 4:50 PM CT ask via Erlich: "the scrubber should look like this, and it should move smoothly like a dial." Written by Mugatu (UXD) from the approved milestone scope rev 4, Bill's density decisions (6:14 PM CT), mockups R1–R8 and the draft PR #249 learnings. The doc then goes to Gilfoyle (SAD) and Big Head (impl spec).

- **Scope source:** PRD, section **"Family Thread — milestone scope"**, rev 4, APPROVED 2026-11-21 8:31 PM CT by Bill and stamped by Jared: https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2. It supersedes the "Timeline page concepts — scope note" rev 1.
- **Stitch:** project `13933817203770823979`, screens R1–R8. See [Stitch screens](#stitch-screens) and [Stitch cleanup](#stitch-cleanup-rev-14). The contact sheet is committed at `docs/ux/assets/family-thread/R1-R8-contact.jpg`.
- **Open UI questions:** none. Q3 to Q8 are closed: on 2026-11-25 at 5:29 PM CT Bill approved rev 1.4 as written, which takes option (a) on each ([§20](#20-open-ui-questions)). Q2 is closed: on 2026-11-25 at 4:55 PM CT Bill approved the new token albumMossInk #4A6A2F for the scrubber's matching-decade labels only ([§20](#20-open-ui-questions)). Q1 is closed: on 2026-11-22 at 6:33 AM CT Bill decided the nav and the button stay "Timeline".
- **This doc overrides the mockups.** R1–R8 are exploration renders and contain known slips plus sample data. Where a mockup and this text differ, follow the text. [§15](#15-mockup-corrections) lists every known slip. Rev 1.4 adopts the R1–R8 look for the band, chips, cards, photos, toolbar, Overview and phone, with measured numbers written here ([§2.1–2.6](#21-toolbar-filters-pill-and-density-pill-rev-14), [§7.1](#71-full-size-photos-rev-14)). Each section has a visual check against its R screen ([§21](#21-visual-acceptance-checks-rev-14)).

## Sources

Only the linked sources and named sections were read:
- PRD, **"Family Thread — milestone scope"** (rev 4), including A1, A4, A5, A6, Out of scope, Reference only, and Pipeline.
- Mugatu's concept note `/workspace/timeline-concepts/river-v2/CONCEPT.md` and the round 4 keepers R1–R8 (`MANIFEST.md`). Both use the exploration name for Concept A. That name is retired, and none of its wording carries into the product.
- Rev 1.4: the R1–R8 PNGs and contact sheet in `/workspace/stitch-audit/`, measured at 2× (1280pt desktop, 390pt phone). Erlich's gap list (Stitch vs the live preview at `/family-thread`). These files on `client/ft-family-thread` at `9e22776`: `thread_band.dart`, `thread_view.dart`, `story_card.dart`, `photo_fan.dart`, `density_control.dart`, `filter_button.dart`, and the tokens in `album_theme.dart`. The live preview sits behind sign-in and couldn't be rendered for this rev.
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
| **thread band** | the sageTint band the stories hang from. Rev 1.4: it's a gentle **wave**, and a 2px dashed terracotta **spine** runs along its centre line ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)). |
| **beat** | one stop along the thread. Overview: one beat per decade. Browse: one per year. Read: one per story. |
| **focus line** | the vertical centre of the thread area. The beat on it is *focused*. |
| **focus story** | the story the screen is anchored to. Focus is always a story id, even in Overview and Browse. |
| **density** | Overview / Browse / Read |
| **year chip** | rev 1.4: the small year label that sits on the spine at each Browse and Read beat ([§2.3](#23-year-chips-and-beat-nodes-rev-14)) |
| **row** | rev 1.4: the vertical space one beat takes. Rows have different heights ([§2.4](#24-rows-cards-and-variable-heights-rev-14)). |
| **alternating / single-side mode** | rev 1.4: the two thread layouts, picked by the thread area's width ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)) |

"Beat", "focus line", "focus story", "row" and the mode names are internal terms and never appear in the UI.

## 2. Layout

Stories run **oldest at the top, newest at the bottom**. Within a year they're ordered by the recorded event date at whatever precision was entered, then by publish time.

| Width | Filters | Thread | Scrubber |
|---|---|---|---|
| **≥900pt** | #248 **sidebar**, 280pt on the left, open by default. The toolbar's **Filters** button toggles it. | Alternating mode (beats alternate left and right of the band) when the thread area is 720pt or wider, otherwise single-side mode (rev 1.4, [§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)) | **Right-edge column**, 56pt wide |
| **600–899pt** | #248 **drawer** (bottom sheet) | The same 720pt rule | Right-edge column |
| **<600pt (phone)** | Drawer | Single-side mode: band 32pt from the left edge, content to the right | **Bottom strip**, 56pt tall, above the safe area |

- **Header:** the existing app header (#130), unchanged.
- **Toolbar:** a row under the header with the **Filters** pill, the **density** pill and the **"n of N" count**. Rev 1.4 moves the pills together and defines their look in [§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14): on ≥600pt the count is on the left and both pills are on the right; on phone, Filters is on the left and density on the right, and the count sits in the drawer header.
- **Active filter pills** appear in a row under the toolbar whenever a filter is on. Each pill has a 44×44 remove ×.
- **Thread band:** sageTint (#E1E5DD), with a terracotta spine and a small terracotta knot (an 8pt filled dot) at the oldest story ([§18](#18-delight-pass)). No gradient, shadow or glow. Rev 1.4: its wave, width, dashed spine and ends are in [§2.2](#22-thread-band-wave-and-dashed-spine-rev-14). That replaces rev 1.0's straight 24pt (phone 16pt) bar with radius 12 ends and a solid spine.
- **Decade landmarks** (Browse and Read only): decade labels at the first beat of each decade, on the side opposite that beat's card. They're decorative and hidden from screen readers, because each beat's label already carries its year. Rev 1.4: Newsreader italic 28pt in albumInkDim, in a 56pt spacer row of their own ([§2.4](#24-rows-cards-and-variable-heights-rev-14)). This replaces rev 1.0's 40pt.

### 2.1 Toolbar: Filters pill and density pill (rev 1.4)

Adopts the R1, R2 and R5 toolbar. Replaces the rev 1.0 toolbar placement above where they differ. Measurements in pt.

**Placement**

| Width | Row | Left | Right |
|---|---|---|---|
| ≥600pt | 64 tall, controls vertically centred, 24 in from the thread area's left and right edges | the **"n of N" count** (FT-14), Source Sans 3 13pt weight 400, albumInkDim. When the ≥900pt sidebar is open, the count moves into the sidebar header under the "Filters" heading (R1, R2) and this slot is empty, so the count is never shown twice. | **Filters pill**, 8 gap, **density pill** |
| <600pt (phone) | 56 tall, 16 in from both screen edges | **Filters pill** | **density pill** |

- On phone, if the two pills don't fit on one row with at least 8 between them (narrow screens or large text), the density pill moves to its own row under the Filters pill. It then spans the width minus 16 at each side, and its three segments are equal width.
- Active filter pills stay in their own row under the toolbar (unchanged, R4).

**Density pill** (segmented look, radio semantics)

| Part | Spec |
|---|---|
| Container | 44 tall, fill **albumPillFill**, 1px **albumPillBorder**, **stadium** ends (radius = half the height, the rev 1.2 shape rule; [Q3](#20-open-ui-questions)). Hugs its segments. No shadow, gradient or glow. |
| Segment | 36 tall, inset 4 from the container on every side, 16 left and right padding, minimum 72 wide. Label Source Sans 3 14pt weight 600 in **albumInk** (≈13.5:1 on the pill). The whole 44-tall column of a segment is its tap target, so each stop is at least 72×44. |
| Selected segment | fill **albumTerracotta**, stadium ends, label **albumWhite** (5.5:1). No check mark, no icon, no Material grey fill or tonal tint. |
| Hover (web, unselected) | fill **albumPaleRose** behind the segment, label unchanged |
| Pressed | same as hover |
| Disabled (loading, [§11](#11-loading-empty-error)) | all labels **albumInkDim**, selected segment fill **albumPillBorder**. Not focusable. |
| Keyboard focus | the 2px albumTerracotta ring with a 2px offset around the focused segment, following its stadium shape ([§13](#13-accessibility)) |
| Change | the selected fill slides to the new segment over 150ms ease-out. Reduced motion: it cuts. |

The look is a segmented pill. The semantics stay exactly as [§13](#13-accessibility): one radio group "Density" (FT-02) with three radios. ←/→ (and ↑/↓) move between stops and select them, the way a radio group does. Tab enters the group on the selected stop and leaves it in one step.

**Filters pill**

| Part | Spec |
|---|---|
| Shape | 44 tall, stadium ends, padding 16 left and right. Same fill and border as the density container: **albumPillFill**, 1px **albumPillBorder**. |
| Content | the **tune** icon (Material Symbols "tune", 20pt, **albumInk**), 8 gap, label "Filters" (FT-07) Source Sans 3 14pt weight 600, **albumInk** |
| Active (k ≥ 1 filters) | label becomes "Filters · {k}" (FT-08). Fill **sageTint**, 1px **albumSage** border (non-text, ≈3.4:1 against parchment), label and icon **albumInk** (12.0:1). The same sageTint "selected" meaning as the filter chips in [§8](#8-filters-190-rules-248-panel). |
| Hover / pressed (web) | fill **albumPaleRose** when inactive. When active it stays sageTint. |
| Keyboard focus | 2px albumTerracotta ring with 2px offset, stadium shape |
| Sidebar or drawer open | no extra visual. The open panel is the visible state. Screen readers hear the expanded state ([§13](#13-accessibility)). |

**Visual check (§2.1):** build at 1280×1024, Overview, sidebar open, next to **R1**; build at 390×844, Browse, next to **R5**. Must match: both pills stadium and 44 tall; Filters pill shows the tune icon left of the label; selected segment is a terracotta stadium with white label inside a cream container; no radio circles anywhere; on 1280 the pills sit together at the right; on 390 Filters is left and density right. Tokens: albumPillFill, albumPillBorder, albumTerracotta, albumWhite, albumInk. A second build screenshot with two filters on must show "Filters · 2" on a sageTint pill.

### 2.2 Thread band: wave and dashed spine (rev 1.4)

Adopts the wavy band and dashed spine from R1, R2 and R6. Replaces the rev 1.0 straight bar.

**Two layout modes** (also used by [§2.4](#24-rows-cards-and-variable-heights-rev-14)):
- **Alternating mode:** the thread area (the space between the sidebar or screen edge and the scrubber column) is **720pt or wider**. The band's centre line runs down the middle of the thread area and beats alternate sides.
- **Single-side mode:** the thread area is **narrower than 720pt**. That's every phone, and on wider screens it's 600–775pt windows, or 900–1055pt windows with the sidebar open ([Q6](#20-open-ui-questions)). The band's centre line runs 32pt from the thread area's left edge and all content sits to its right.

| Part | Alternating mode | Single-side mode |
|---|---|---|
| Band fill | **sageTint** #E1E5DD | same |
| Band width (measured across the band) | **28** ([Q5](#20-open-ui-questions)) | **16** |
| Wave | a smooth sine wave. Amplitude **24** (the centre line swings 24 left and 24 right of the base line). Wavelength **360**. | amplitude **6**, wavelength **280** |
| Space the band can use | 76 wide (28 + 2 × 24), centred on the base line | 28 wide (16 + 2 × 6), centred 32 from the left edge |
| Ends | round (stadium) at both ends. The band starts 24 above the oldest beat's centre and ends 24 below the newest beat's centre. | same |
| Spine | **dashed** line along the band's centre line: **2** wide, **5 on, 5 off**, square-cut (butt) dash ends, **albumTerracotta**. Dashes follow the curve, measured along the path, and the pattern starts at the knot. | same |
| Knot | the 8pt filled albumTerracotta dot ([§18](#18-delight-pass)) sits on the spine 8 below the band's top end | same |
| Effects | none: no glow, shadow, gradient, blur, texture or transparency | same |

- **Where the wave is:** the wave's sideways offset depends only on the distance down the thread from the oldest beat's centre. At the oldest beat the band is on its base line. So the band scrolls with the content as one rigid shape. It never moves on its own, never changes shape while you scroll, and looks the same each time the same density is opened with the same stories and filters.
- **How it meets beats:** each beat's marker (a year chip in Browse and Read, a node in Overview, [§2.3](#23-year-chips-and-beat-nodes-rev-14)) sits **on the spine** at that beat's height, so markers ride the wave. Medallions and cards don't follow the wave. They sit in fixed columns ([§2.4](#24-rows-cards-and-variable-heights-rev-14)), and a 1px connector line joins each marker to its medallion or card, so the connector length changes from beat to beat.
- **Density change, filters, live updates:** the band is redrawn for the new rows at the same moment the beats rebuild. It doesn't animate, morph or slide between shapes.
- **Under a Read expanded card** in alternating mode the band passes behind the card ([§2.4](#24-rows-cards-and-variable-heights-rev-14)).
- **Reduced motion:** nothing to change. The band and spine never animate, and the dashes don't march.
- **Screen readers:** decorative and hidden, as before.
- **Performance requirement:** scrolling with the wave stays as smooth as with the straight band, including for a family with hundreds of stories (L10). The band's shape is not rebuilt each frame. Mechanism notes are in the [handoff](#handoff-notes-for-gilfoyle-sad).

**Visual check (§2.2):** build at 1280, Overview, next to **R1**; build at 390, Read, next to **R6**. Must match: the band is a sageTint wave, not a straight bar; a dashed terracotta spine follows the band's centre line; the dashes are evenly spaced and don't bunch on curves; the ends are round; the knot sits on the spine at the top; the phone wave is gentle (it stays near the left edge, as in R6, not the wide sweep of R5). Measure on the 1280 screenshot: band about 28 across, the centre line swinging about 24 each side, about 360 from one left-most swing to the next. No shadow or glow anywhere on the band.

### 2.3 Year chips and beat nodes (rev 1.4)

Adopts the year chips on the band from R2, R3 and R6. New in rev 1.4.

**Which beats get a chip:** every **year beat in Browse** and every **story beat in Read** (showing that story's year), including non-matching beats. **Overview** has no chips: each decade beat gets a **node** instead, because its decade label is already large beside the mosaic.

| Part | Spec |
|---|---|
| Position | centred on the spine at the beat's height (it rides the wave). It sits on top of the band. In Read alternating mode the focused beat's chip sits on the spine 16 above the top edge of the expanded card, where the band is still visible (R3). |
| Unfocused chip | 24 tall, padding 8 left and right, stadium ends ([Q3](#20-open-ui-questions)), fill **albumParchment**, 1px **albumPillBorder**. Label: full year ("1996", never "'96"), Source Sans 3 12pt weight 600, **albumInkDim** (5.6:1 on parchment). About 48 wide. |
| Focused chip | 28 tall, padding 10 left and right, stadium ends, fill **albumTerracotta**, no border. Label Source Sans 3 **13pt weight 700**, **albumWhite** (5.5:1). The same chip style as the scrubber's focused chip ([§6.1c](#61c-visual-600pt-right-edge-column)). |
| Non-matching beat | unfocused chip style. Non-matching beats can't take focus ([§8](#8-filters-190-rules-248-panel)). |
| Connector | a 1px horizontal line from the chip's edge to the medallion or card edge at the chip's height. **albumPillBorder** for unfocused beats, **albumTerracotta** for the focused beat. Not drawn for the Read alternating expanded card (the chip sits above it). |
| Overview node | 12 circle on the spine: fill **albumPillFill**, 1.5px **albumInkFaint** outline. Focused: 12 filled **albumTerracotta**, no outline. Non-matching decade: the rev 1.0 hollow dot ([§8](#8-filters-190-rules-248-panel)). |
| Text size | at 200% text the chip grows with its label. It never truncates or wraps. |
| Change of focus | the chip colours swap when focus settles ([§4.1](#41-snap-and-focus-with-variable-row-heights-rev-14)). With reduced motion it's a cut; otherwise a 150ms colour cross-fade. |

- **Not a separate control.** A chip is part of its beat's tap area. Tapping it does what tapping the beat does ([§5](#5-anchored-drill-down-and-back)). It adds no tab stop and needs no target of its own.
- **Screen readers don't hear the chip.** It's excluded from semantics because every beat label already starts with the year (FT-31, FT-33). The year is read once.
- **Same year twice in Read:** two stories from 1996 each show a "1996" chip. That's intended: each chip marks its own story.

**Visual check (§2.3):** build at 1280, Browse, next to **R2**; build at 390, Read, next to **R6**. Must match: a chip on the band at every row; full four-digit years; unfocused chips are cream with a thin border and dim text; the focused chip is a terracotta stadium with white bold text; a thin line joins each chip to its medallion or card; Overview (vs **R1**) shows round nodes, not chips, with the focused node filled terracotta.

### 2.4 Rows, cards and variable heights (rev 1.4)

Adopts the Stitch card sizes from R2, R3, R5 and R6. **Rows no longer share one fixed height.** Each row is as tall as its content, and the focused row is much taller than the others. This replaces impl spec P1c's fixed row heights (64 / 112 / 124pt), which forced the focused card into a sideways layout. **Big Head will restamp the impl spec to drop the fixed item extent after Bill approves this rev.** Snapping and centring with variable heights are defined in [§4.1](#41-snap-and-focus-with-variable-row-heights-rev-14).

**Columns** (cards and medallions don't follow the wave):
- **Alternating mode:** content sits beside the band's 76-wide space with a 24 gap, so each side's content starts 62 from the thread area's centre line. The **side column** is (thread area width − 76) ÷ 2 − 24 − 16 (the 16 is the outer margin). At 1280 with the sidebar open, the thread area is 944 and the side column is 394. At the 720 minimum it's 282. Beats alternate sides, oldest on the left.
- **Single-side mode:** content starts **72** from the thread area's left edge (spine 32 + wave 6 + half a chip 24 + a 10 gap) and ends 16 from the right edge on phone, or 24 on wider screens. At 390 that's a 302 column.

**Row anatomy and sizes**

| Density | Row | Width | Height (at 100% text) | Content |
|---|---|---|---|---|
| Overview | unfocused decade | mosaic **96** (single-side: **80**) | **104** | mosaic + label block ([§2.5](#25-overview-mosaic-rev-14)) |
| Overview | focused decade | mosaic **112** (single-side: **96**) | **148** | mosaic, stitch ring, label block with the Browse link |
| Browse | unfocused year | medallion 64 + 12 gap + title block, up to the side column | **88** with a one-line title, **96** with two lines; never less than 88 | 64 year medallion ([§7d](#7-photo-cards-and-medallions)) next to the band; title Newsreader 18pt weight 400 albumInk, up to 2 lines; meta line Source Sans 3 12pt albumInkDim, "{place} · {people}", 1 line with ellipsis. Text sits on the side away from the band and aligns toward the medallion. |
| Browse | non-matching year | hollow dot + title | **44** | the rev 1.0 hollow 12pt dot and the title in albumInkDim ([§8](#8-filters-190-rules-248-panel)) |
| Browse | focused year: **story card** | side column, clamped to **280–360** (single-side: the full column) | card height + 16 above and below. A 360 card with one chip row is about 460 tall. | see "Browse story card" below |
| Read | unfocused story: **compact card** | side column, clamped to **280–400** (single-side: the full column) | card height + 12 above and below. A 400 card is about 320 tall. | see "Read compact card" below |
| Read | non-matching story | hollow dot + title | **44** | as Browse |
| Read | focused story: **expanded card** | alternating mode: **centred on the thread area, over the band**, thread area − 48, clamped to **320–560** ([Q7](#20-open-ui-questions)). Single-side: the full column. | card height + 32 above (room for the chip in alternating mode) and 32 below | see "Read expanded card" below |
| Browse, Read | decade landmark | — | **56** | its own spacer row before the first beat of each decade. Newsreader **italic 28pt**, **albumInkDim** (R2, R4). Alternating: on the side opposite the next beat's content; single-side: in the content column. Never takes focus, skipped by snapping, ↑/↓ and the scrubber. Decorative and hidden from screen readers, as before. |

**Browse story card** (R2; phone R5)
- Container: fill **albumPaleRose**, 1px **albumTerracotta** border, radius 12, no shadow.
- Photo: the lead photo as a full-bleed **4:3** cover across the card's full width, radius 12 on the top corners ([§7a](#7-photo-cards-and-medallions)). A 360 card has a 360×270 photo. Browse shows the lead photo only, even when the story has several. The fan is for Read ([§7.1](#71-full-size-photos-rev-14)). No photo: the quote treatment from §7c fills the same 4:3 area.
- Body, padding 16: the **date line** (existing `storyDateLabel`, at the precision entered) in Source Sans 3 12pt weight 700, letter spacing 0.5, albumInkDim. Then 4 gap and the **title** in Newsreader 24pt weight 400, line height 1.2, albumInk, up to 3 lines. Then 12 gap and the **chips**. Then "{k} more in {year}" (FT-24) when the year has more stories: Source Sans 3 13pt weight 600, albumTerracotta, 44-tall target. Then 12 gap, a 1px albumPillBorder divider, and a 44-tall **footer**: the photo count (FT-39) on the left in Source Sans 3 13pt albumInkDim, and **Open story →** on the right in Source Sans 3 14pt weight 600 albumTerracotta with a 16pt arrow icon, 44×44 minimum target.
- **Chips** (people and place, in this card and both Read cards): Source Sans 3 13pt albumInk with a 16pt icon (person, or location pin), fill albumPillFill, 1px albumPillBorder, radius 8, 28 tall, padding 8. People first, then place. They wrap to at most **2 rows**. Anything left over becomes one "+{n}" chip (FT-40). **They aren't buttons**: no hover, no target, no tab stop. The beat's screen-reader label already names every person and place.

**Read compact card** (R3, R6, unfocused)
- Container: fill **albumParchment**, 1px **albumPillBorder**, radius 12.
- Photo: the lead photo as a full-bleed **2:1** strip, radius 12 on the top corners ([Q4](#20-open-ui-questions)). A 400 card has a 400×200 strip. No photo: the compact quote (a 32pt terracotta quote mark and the first line in Literata italic 14pt, up to 2 lines, albumInk), padding 16, no image area.
- Body, padding 16: the date line (12pt, albumInkDim), the title in Newsreader 20pt weight 400, up to 2 lines, one row of chips ("+{n}" for the rest), a divider, and a footer with the photo count only. **No Open story link**: tapping a compact card focuses and expands it ([§5](#5-anchored-drill-down-and-back)).
- Fade by distance applies to its photo only ([§4](#4-focus-scroll-and-fade)).

**Read expanded card** (R3; phone R6, focused)
- Container: fill **albumPaleRose**, 1px **albumTerracotta**, radius 12, padding **24** (single-side: 16). The stitch ring goes around it ([§18](#18-delight-pass)).
- Photo area at the top: one photo, the fan, or the quote, at full size ([§7.1](#71-full-size-photos-rev-14)).
- Then 16 gap and the date line: Source Sans 3 12pt weight 600, letter spacing 1, uppercase, albumInkDim. The uppercase is visual only, and screen readers get the normal date text. Then the **title** in Newsreader **28pt weight 600**, up to 3 lines (single-side: 24pt). Then the **first 3 lines of the story** in Literata italic 15pt, line height 1.5, albumInk, ending in an ellipsis. Then chips (up to 2 rows), a divider, and a footer: the photo count on the left and **Open story →** on the right as a **filled stadium button**, 44 tall, padding 20, fill albumTerracotta, label Source Sans 3 14pt weight 600 **albumParchment** (5.2:1) with a 16pt arrow icon.
- **Height cap:** the card is never taller than the thread area minus 48. If it would be, the photo area shrinks first (down to a 160-tall front print or cover), then the excerpt drops to 2 lines. If it's still too tall (very short windows or large text), the card's top sits 24 below the top of the thread area instead of being centred, so the title and Open story stay reachable.

**Text reflow rules (all rows):**
- Line limits are counted in lines, so at 200% text rows grow taller and keep the same number of lines. Rows have minimum heights (above) and no maximum.
- A title that hits its line limit ends in an ellipsis, and the full title stays in the screen-reader label (§13).
- The meta line and the photo count are one line with an ellipsis.
- Chips wrap and never shrink their text. A long name ends in an ellipsis at the column width.
- Card widths come from the column, not from the text. Text never makes a card wider.
- Nothing is laid out sideways (photo beside text) at any density or width. That was the P1c fixed-height symptom.

**Visual checks (§2.4):**
- Browse at 1280 next to **R2**: the focused card is upright (photo on top, text below), about 360 wide with a 4:3 photo across the full card, a pale rose fill and a terracotta border; unfocused rows are 64 medallions with titles; rows are not all the same height.
- Read at 1280 next to **R3**: the expanded card is about 560 wide, centred over the band, with the chip above it; compact cards are about 400 wide with a 2:1 photo strip and no Open story link.
- Browse at 390 next to **R5** and Read at 390 next to **R6**: cards fill the column from 72 to 16 short of the right edge; the expanded card is fully visible with Open story reachable.
- Large-text check: 200% text at 390 Read, with the focused card still showing its title and Open story.

### 2.5 Overview mosaic (rev 1.4)

Adopts R1. Tiles follow [§7d](#7-photo-cards-and-medallions), unchanged.

| Part | Alternating mode | Single-side mode |
|---|---|---|
| Mosaic, unfocused | **96** circle, 2px **albumTerracotta** ring, tiles split by a 2px **albumParchment** gutter | **80** |
| Mosaic, focused | **112** circle, same ring, plus the stitch ring 6 outside it ([§18](#18-delight-pass)) | **96** |
| Placement | inner edge 62 from the centre line, alternating sides, oldest decade on the left | 72 from the left edge |
| Decade label, unfocused | Newsreader **32pt** weight 400, 16 from the mosaic on its outer side, aligned toward the mosaic. **albumInk** within one beat of focus, **albumInkDim** two or more beats away ([§4](#4-focus-scroll-and-fade)). | Newsreader 28pt, to the right of the mosaic |
| Decade label, focused | Newsreader **36pt** weight 700, albumInk | 32pt weight 700 |
| Count line | "{n} stories" (FT-23 parts) in Source Sans 3 13pt, albumInkDim, under the decade | same |
| Browse link, focused decade only | "Browse the {decade}s →" (FT-38), Source Sans 3 13pt weight 600, albumTerracotta, 44-tall target, under the count ([Q8](#20-open-ui-questions)). It does exactly what tapping the focused mosaic does ([§5](#5-anchored-drill-down-and-back)). | same |
| Caption | "{Family name} · stories carried down the years" (FT-26), Literata italic 13pt, albumInkDim, centred under the last beat ([§18](#18-delight-pass)) | same, left-aligned to the content column |

- Under filters a partly matching decade builds its mosaic from matching stories and keeps the FT-23 filtered label. A decade with no matches is a hollow dot and its label, as in [§8](#8-filters-190-rules-248-panel).
- The Browse link is the focused beat's action in the tab order, in the slot that Open story takes in Browse and Read ([§13](#13-accessibility)).

**Visual check (§2.5):** build at 1280, Overview, next to **R1**. Must match: mosaics alternate sides of the wave; the focused decade's mosaic is visibly larger with a ring around it and a bold decade label, its count, and a terracotta "Browse the 1990s →"; other decades show a large decade label and a dim count; nodes sit on the spine; the caption is centred at the bottom. Mosaic about 96 across (focused about 112). There's no Stitch screen for phone Overview, so check phone Overview at 390 against this table and the R1 shapes.

### 2.6 Phone layout (rev 1.4)

Adopts R5, R6 and R8 as one consistent phone layout. Where they disagree, R6 wins for the band and R2's card anatomy wins for the Browse card ([§15](#15-mockup-corrections)).

- **Header:** the existing #130 phone header, unchanged.
- **Toolbar:** [§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14), with Filters left and density right.
- **Thread:** single-side mode ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)): the gentle wave 32 from the left edge, chips on the spine, and content from 72 to 16 short of the right edge ([§2.4](#24-rows-cards-and-variable-heights-rev-14)).
- **Bottom strip:** the [§6.1e](#61e-phone-bottom-strip-600pt-the-centred-dial) centred dial, unchanged. The thread area ends above the strip, so no card hides behind it. The first and last beats can both reach the focus line.
- **Filter drawer** (R8): the #248 drawer as it is ([§8](#8-filters-190-rules-248-panel)), with the existing parchment sheet and albumModalScrim. Header "Filters" with the "{n} of {N} stories" count beneath it and a 44×44 close ×. Then search, People and Places chips (selected chips are sageTint with ✓), the Years range, and a footer with **Clear filters** on the left and **Show {n} stories** on the right as a terracotta stadium button.

**Visual check (§2.6):** build at 390×844 next to **R5** (Browse), **R6** (Read) and **R8** (drawer open). Must match the pills, the band and chip position, card widths and anatomy, the bottom strip, and the drawer's order of parts and footer buttons. Known differences that are correct: the R5 band sweep, the R5 round year chip, the R5 card header row and the R5–R8 short-year scrubber ([§15](#15-mockup-corrections)).

## 3. Density model

The scope sets three fixed stops with nothing in between. The page is one screen and one thread. Changing density never navigates.

| Stop | One beat is | Beat visual | Focused beat |
|---|---|---|---|
| **Overview** | a decade (only decades that have stories) | **decade mosaic**, 96pt (rev 1.4; 80pt single-side). Label: "1970s · 6 stories" | 112pt mosaic (96pt single-side) with the stitch ring, a bold label and "Browse the {decade}s →" ([§2.5](#25-overview-mosaic-rev-14)) |
| **Browse** (default) | a year (only years that have stories) | 64pt **year medallion** with the title; the year is on its chip ([§2.3](#23-year-chips-and-beat-nodes-rev-14)) | Opens an upright **story card** in its row, at Stitch size ([§2.4](#24-rows-cards-and-variable-heights-rev-14)): 4:3 photo, title, date line, place and people chips, **Open story**, and "{k} more in {year}" when the year has more stories |
| **Read** | a story | compact card: 2:1 photo strip, date line, title, chips (rev 1.4, [§2.4](#24-rows-cards-and-variable-heights-rev-14)) | **Expanded card**, up to 560pt wide and centred over the band on wide screens: full-size photo area per [§7.1](#71-full-size-photos-rev-14), date line, title, first 3 lines of the story, chips, **Open story** |

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

### 4.1 Snap and focus with variable row heights (rev 1.4)

Rows now have different heights, and the focused row is the tallest ([§2.4](#24-rows-cards-and-variable-heights-rev-14)). These rules keep snapping, centring and the anchoring rule in [§3](#3-density-model) working.

1. **Focus line:** unchanged. It's the vertical centre of the thread area. A settled focused row has its centre on the focus line, except an expanded card that is taller than the thread area minus 48, which top-aligns 24 below the thread area's top ([§2.4](#24-rows-cards-and-variable-heights-rev-14)).
2. **Sizes freeze while the thread moves.** During a drag, a fling, a scrubber drag or glide, or a keyboard or jump scroll, no row changes height. The row that was focused stays expanded as you scroll past it. That way the content under your finger never jumps.
3. **Picking the beat when scrolling stops:** if the focus line is inside the expanded row, that beat stays focused and re-centres. Otherwise the matching beat whose row centre is nearest the focus line is picked, using the row positions on screen at that moment.
4. **Settle:** the picked row snaps to the focus line. If focus changed, the old row collapses and the new row expands **in the same 200ms ease-out**. The new focused row is **pinned**: its centre ends exactly on the focus line, rows above it move up and rows below it move down. Nothing moves after that. Reduced motion: one cut to the final layout.
5. **Jumps to a known beat** (↑/↓, Home/End, scrubber commit, Jump to year, drill-down, density change, Back, and restoring the open state): the layout is worked out with the target row already expanded, and the scroll lands with it centred. There is no visible step where the target is small and then grows. ↑/↓ runs the same 200ms snap, or a cut with reduced motion.
6. **Heights are known before they're drawn.** Photo areas reserve their size from the card width and aspect ratio before the image arrives. A photo loading, failing (the quote fills the same area, [§11](#11-loading-empty-error)) or fading never changes a row's height.
7. **Live updates and corrections:** when a story is added or removed, or the height of an off-screen row turns out different from what was assumed, the focused row stays pinned on the focus line and the change happens off screen or below it.
8. **Fade by distance** still counts beats, not points ([§4](#4-focus-scroll-and-fade)).
9. **Snap never fights a drag** (unchanged), and no row grows or shrinks under a finger that's still down.

**Visual check (§4.1):** a screen recording at 1280 Browse, next to **R2** as the end state. Scroll from 1989 to 1996 and let go. The 1996 card must end centred and upright like R2, and the 1989 row must collapse back to a medallion row. There's no jump while dragging. With reduced motion on, the change must be a single cut. Run the same check at 390 Read against **R6**.

## 5. Anchored drill-down and Back

| You tap | At | Result |
|---|---|---|
| a decade mosaic, or the focused decade's "Browse the {decade}s →" link (rev 1.4) | Overview | Browse, anchored on that decade. The focus story is unchanged if it's in that decade, otherwise the decade's oldest story. |
| an unfocused year medallion | Browse | It snaps to focus and its card opens. Density doesn't change. |
| the **focused** year medallion | Browse | Read, anchored on the card's story |
| the year card's "{k} more in {year}" | Browse | Read, anchored on that year's first story after the card's story |
| a story card or **Open story** | Browse / Read | the full story at `/stories/:id`, as today |
| an unfocused compact card | Read | It snaps to focus and expands ([§4.1](#41-snap-and-focus-with-variable-row-heights-rev-14)). |
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
- Labels never truncate, wrap or scale down. At 200% text the pitch rule in [6.1c](#61c-visual-600pt-right-edge-column) switches the scrubber to the centred dial.

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
| Pill | 44 tall, horizontal, from 16 off the left edge to 8 before the Jump to year button (44×44, right end, 16 from the right edge). Same fill, border and fully round ends as [6.1c](#61c-visual-600pt-right-edge-column). |
| Chip | fixed at the pill's horizontal centre, 56 wide × 28 tall, fully round ends, terracotta with albumWhite 13pt weight 700 label |
| Labels | the same full labels and colours as [6.1c](#61c-visual-600pt-right-edge-column), laid out at a fixed **64 pitch**, one 4pt albumInkFaint dot in each gap. The row is padded by half the pill width at each end so the oldest and the newest decade can both sit under the chip. Hard clip at the pill shape, with no fade gradient. |

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
- **b. Two or more photos: a fan of three** (R6 fix: the fan must be clearly readable as a stack). Rev 1.4: full-size prints in [§7.1](#71-full-size-photos-rev-14); the offsets and mat below scale as stated there.
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

### 7.1 Full-size photos (rev 1.4)

Adopts the print sizes from R3, R6 and R7. The rev 1.0 rules in 7a–7d (crop, rotation, mats, the "+n" chip, the fallbacks and alt text) still apply. Only the sizes change, from the 96×72 prints in today's build to these.

| Where | Photo treatment | Size |
|---|---|---|
| Browse story card | lead photo only, full-bleed 4:3 cover (7a) | card width × ¾ (360 card → 360×270) |
| Read compact card | lead photo only, full-bleed **2:1** strip ([Q4](#20-open-ui-questions)) | card width × ½ (400 card → 400×200) |
| Read expanded card, 1 photo | 4:3 cover inside the card padding, centred, radius 8 | width = the content width (card − 2 × padding), but no taller than 45% of the thread area's height. When the height limit applies, the width shrinks to keep 4:3. |
| Read expanded card, 2+ photos | **the fan** (7b) | front print width **W** = the smallest of: content width − 48, **400**, and (45% of the thread area height) × 4⁄3. Height = ¾ W. Minimum W is 200. At 1280 Read: W = 400 (400×300). At 390: W = 222 (222×167), matching R6. |
| Unfocused Browse rows, Overview | medallions and mosaics (7d, [§2.5](#25-overview-mosaic-rev-14)) | 64 / 96 / 112 (single-side 80 / 96) |

**Fan at full size** (7b, scaled):
- All three prints are the same size, W × ¾W. The back prints are at −6° and +5°, offset sideways by **12 or 4% of W, whichever is larger**, and up by **6 or 2% of W, whichever is larger** (at W = 400: 16 and 8).
- At least 8 of each back print shows on two edges at every size (unchanged rule).
- Mats are **6** albumParchment (it was 4 at the old 96pt size) plus a 1px albumPillBorder outline. No shadow and no glow.
- The fan's box is W + 48 wide and ¾W + 48 tall, centred in the card's content width. The back prints may reach into that 24 margin but never cross the card's border. Nothing is clipped.
- The "+n" chip (7b, unchanged style: albumParchment, albumInk 13pt semibold, radius 8) sits 8 in from the front print's inner bottom-right corner. Text only, with no photo icon and no "photos" word (R3 and R6 slips, [§15](#15-mockup-corrections)).
- Fade by distance doesn't apply to the focused card, which is always at 100%.

**Image quality requirement:** photos are shown sharp at these sizes on high-density screens, not upscaled from a thumbnail. Off-screen photos still don't download early (R-02). The mechanism is Gilfoyle's.

**Visual check (§7.1):** build at 1280, Read, focused on a story with 5 photos, next to **R3** and **R7 (b)**; build at 390 next to **R6**; build at 1280 Browse next to **R2** and **R7 (a)**; a no-photo story next to **R7 (c)**. Must match: the fan fills most of the card's width (about 400×300 at 1280, about 222 wide at 390); three prints of equal size with cream mats and visible back edges; "+2" chip at the bottom-right; Browse shows one full-width 4:3 cover; compact cards show a 2:1 strip; the no-photo card shows the terracotta quote mark and never an empty frame.

## 8. Filters (#190 rules, #248 panel)

- **Panel:** #248's filter panel as it is. A sidebar on ≥900pt, a drawer below that.
  - **Search:** "Search titles, stories and people".
  - **People** and **Places** chips. Selected chips use a sageTint fill, an albumInk label and a ✓.
  - **Years:** a decade range slider showing "1950s – 2000s".
  - **Clear filters**.
  - The drawer footer adds **Show {n} stories**, which closes the drawer.
- **Logic:** OR within a category, AND across categories. Search is ANDed with the others.
- **Results stay in place.** Matching stories keep their photos. Non-matching beats **collapse in place** to a **hollow 12pt dot**: a 1.5px albumInkDim outline, which is 3:1 or better as a non-text indicator. The title sits beside it in albumInkDim. Rev 1.4: the row is 44pt tall, and its year chip stays on the band ([§2.3](#23-year-chips-and-beat-nodes-rev-14)).
  - At Overview, a decade with no matches becomes a hollow dot with its label. A decade with some matches builds its mosaic from the matching stories and is labelled "{decade}s · {m} of {n} stories".
  - Non-matching beats are skipped by snapping, by ↑/↓ and by scrubber jumps. They can't be tapped, but screen readers still read them.
- **Focus under filters:** if the focus story stops matching, focus moves to the nearest matching story in time. **Clear filters** keeps the current focus.
- **Count:** "{n} of {N} stories", always visible: in the toolbar on ≥600pt, or the sidebar header while the ≥900pt sidebar is open (rev 1.4), and in the drawer header on phone. The **Filters** pill shows "Filters · {k}" on sageTint when k filters are active ([§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14)).
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

- **Loading:** the toolbar and scrubber frame render, with the density pill in its disabled look ([§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14)). The thread band (the wave and dashed spine) shows 5 skeleton beats: albumPaleRose circles and lines, with no shimmer when reduced motion is on. Screen readers hear "Loading stories". The density control is disabled until the thread is ready.
- **Empty family** (0 published stories): reuse the current `/timeline` empty state, copy and action **verbatim**. No new copy. The scrubber, density control and Filters are hidden.
- **Load error:** the existing sentence **"Couldn't load stories."** + **Retry**, centred where the thread would be. There's no automatic retry.
- **A photo fails to load:** that card falls back to the no-photo quote card ([§7c](#7-photo-cards-and-medallions)), and a medallion falls back to the initial. No error toast. Rev 1.4: the quote fills the photo's reserved area, so the row's height doesn't change ([§4.1](#41-snap-and-focus-with-variable-row-heights-rev-14)).

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
| Row expand / collapse on settle (rev 1.4) | 200ms ease-out, in the same motion as the snap, with the focused row pinned | cut |
| Density pill selected fill (rev 1.4) | slides 150ms ease-out | cut |
| Year chip focus colours (rev 1.4) | 150ms cross-fade | cut |
| Drawer | platform sheet motion | no slide; appears in place |
| Skeleton | gentle opacity pulse | static |

- Nothing loops. #249's repeating ripple is removed: a looping animation that runs until focus moves goes against WCAG 2.2.2 (Pause, Stop, Hide) and is a distraction.
- There's no parallax at any setting.
- Rev 1.4: the wave band never animates, and its dashes never march ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)).

## 13. Accessibility

WCAG 2.2 AA throughout.
- **Contrast:**
  - Body text and labels are albumInk (14.4:1 on parchment, 12.0:1 on sageTint).
  - Secondary or dimmed text is albumInkDim (5.6:1 on parchment, 5.1:1 on sageTint).
  - albumTerracotta text is allowed on albumParchment (5.2:1) and albumPaleRose (4.75:1). It's **not** allowed as small text on sageTint (4.3:1) or albumBlush (4.3:1). There it's only for large text such as the initials, or for non-text marks.
  - albumSage and branchMoss are never used for text here. albumSage is used as a non-text border on the active Filters pill (rev 1.4).
  - Rev 1.4: albumWhite on albumTerracotta (the selected density segment and the focused year chip) is 5.5:1. albumInkDim on albumParchment (unfocused year chips) is 5.6:1. albumInk on sageTint (the active Filters pill) is 12.0:1.
  - Parchment text on a terracotta button is 5.2:1.
- **Targets:** at least 44×44 for every control. That covers medallions (the 64pt, 80pt, 96pt and 112pt visuals already meet it), compact cards, density stops (each segment at least 72×44), the Filters pill (44 tall), filter chips, pill ×, the scrubber handle, Jump to year, Go/Cancel, Open story and the Overview "Browse the {decade}s →" link (44 tall). The hollow dots, year chips and card chips aren't separate controls, so they need no target of their own.
- **Screen-reader labels** (the exact strings are in [§19](#19-copy-strings)):
  - The density control is a radio group, "Density", with each stop as a radio. Selected state is exposed. Rev 1.4 changes only its look (a segmented pill, [§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14)). Its semantics are unchanged.
  - The Filters pill is a button named by its visible text ("Filters" or "Filters · 2") with an expanded or collapsed state for the sidebar or drawer.
  - Year chips, Overview nodes, connectors, the band and landmarks are hidden. Each beat's label already starts with its year, so the year is read once.
  - The thread is one list, "Family Thread, {N} stories". Each beat is a list item with a combined label:
    - Year: "1996, The new tractor, The farm, Tom, 3 photos".
    - Decade: "1990s, 3 stories".
    - Non-match: "{title}, {year}, doesn't match filters".
  - The scrubber is a slider: "Timeline scrubber, 1950s to 2020s, showing 1990s", with year values. Arrow keys step one eligible decade, Page Up/Down step two and Home/End go to the oldest/newest (rev 1.1, [§6.1](#61-dial-scrubber-rev-11)).
  - Focus, density and filter-count changes are announced politely.
- **Keyboard and tab order:** header → toolbar (Filters, Density, Jump to year on ≥600pt) → filter sidebar when open → thread (**one tab stop**, roving focus with ↑/↓) → the focused card's Open story (in Overview: the focused decade's "Browse the {decade}s →" link, rev 1.4) → scrubber.
  - The keyboard focus ring is a 2px albumTerracotta outline with a 2px offset. It's never hidden behind the sticky header (WCAG 2.4.11).
- **Dragging alternative** (WCAG 2.5.7): every scrubber drag can also be done by tapping, with the arrow keys, or with Jump to year. Pinch and ctrl + wheel always have the density control as an alternative.
- **Text resize:** layouts reflow up to 200% text. Card titles wrap to their line limit (3 lines on focused cards, 2 on compact cards and Browse rows), then truncate with an ellipsis, and the full title stays in the label. Rows grow taller and never clip ([§2.4](#24-rows-cards-and-variable-heights-rev-14)).

## 14. Tokens

**One new token (rev 1.3):** **albumMossInk #4A6A2F**, approved by Bill on 2026-11-25 at 4:55 PM CT, for the scrubber's matching-decade labels only ([§6.1c](#61c-visual-600pt-right-edge-column)). It isn't used anywhere else. Every other colour is an existing `album_theme` token:
- Colours: albumParchment #FBF7F2, albumInk #2C2416, albumInkDim (ink 70%), albumTerracotta #8B5E4B, albumSage #7A8B74 (non-text only), branchMoss #5B7F3A (unused here), albumBlush #F5DED6, albumPaleRose #F5ECE9, albumPillFill #F6F1EB, albumPillBorder, albumModalBorder, albumInkFaint (ink 20%), albumWhite #FFFFFF.
- **sageTint**, approved by Bill: albumSage at about 18%, rendered #E1E5DD. It's used for the selected filter chips (approved 5:11 PM CT) and for the **thread band** (Bill, 6:14 PM CT).
- Type: Newsreader for headings, landmarks, card titles and initials. Literata for story body and excerpts. Source Sans 3 for labels, chips, counts and the scrubber.
- Radii: 12 for cards, 8 for chips and pills, 16 for dialogs. No glow anywhere, and no drop shadows on the thread.
- **Rev 1.4 adds no colour token and no radius value.** Its new parts use existing tokens only: albumPillFill, albumPillBorder, albumTerracotta, albumWhite, albumInk, albumInkDim, albumInkFaint, albumParchment, albumPaleRose, albumSage (non-text border), and sageTint (the band and the active Filters pill). The **stadium** shape (radius = half the height) that rev 1.2 set for the scrubber is extended to the toolbar pills, year chips and the Read Open story button ([Q3](#20-open-ui-questions)). Filter chips and card chips keep radius 8. Type sizes are set per element in this doc, as in rev 1.0. `album_theme` has no type-size scale token, and none is added.
- Rule: if a build step seems to need a new colour, size scale or radius, it stops and asks Bill. Don't approximate one.

## 15. Mockup corrections

The text in this doc is authoritative. These slips in R1–R8 are **not** to be built:
1. **R2, R5 and R8, scrubber:** superseded by rev 1.1. Build the scrubber from [§6.1](#61-dial-scrubber-rev-11), not from any R screen. (Rev 1.0 note: each decade label appears once, in order.)
2. **R5 and R8, the label under the scrubber handle:** superseded by rev 1.1. The focused chip shows the focused decade, for example **1990s**.
3. **R3, Read:** a 1995 marker sits out of chronological order, and the 1988 landmark doesn't match the 1989 date on its card. Beats are strictly chronological ([§2](#2-layout)). A landmark is the decade label at the first beat of its decade. Cards show their own date line, and nothing contradicts it.
4. **R6, phone Read:** the photo fan is too subtle to read as several photos. Build the fan per [§7b](#7-photo-cards-and-medallions) (−6° / +5°, 12pt offset, at least 8pt visible), at the rev 1.4 full size in [§7.1](#71-full-size-photos-rev-14).
5. **R1** shows a 40-story sample while the other screens show about 12. Every count is live data. Neither number is a design target.
6. **R1–R8:** invented place and people names and repeated photos are sample data only.
7. **Exploration titles:** Stitch screen titles and R7's heading use the retired exploration name. They are not UI copy. The screen is "Family Thread".
8. **R1** caption "The Morgan Family · …": the family name comes from data, written as the header shows it, with no doubled "Family" ([§19](#19-copy-strings), FT-26).

**Rev 1.4: Stitch visuals now adopted.** Rev 1.4 builds these from the R screens, with the measurements written into this doc: the wavy band and dashed spine (R1, R2, R6, [§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)), year chips (R2, R6, [§2.3](#23-year-chips-and-beat-nodes-rev-14)), Stitch-size cards with variable row heights (R2, R3, R5, R6, [§2.4](#24-rows-cards-and-variable-heights-rev-14)), the full-size fan (R3, R6, R7, [§7.1](#71-full-size-photos-rev-14)), the segmented density pill and the Filters pill (R1, R5, [§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14)), the Overview mosaic layout (R1, [§2.5](#25-overview-mosaic-rev-14)) and the phone layout (R5, R6, R8, [§2.6](#26-phone-layout-rev-14)). **The text is still authoritative.** Build from the numbers here, not by measuring a screen, and items 1–8 above still hold. These further slips are not to be built:

9. **R4 and R5, short years on the band** ('74, '89, '95): chips always show the full year ([§2.3](#23-year-chips-and-beat-nodes-rev-14)).
10. **R3's focused chip** (calendar icon with dots either side) **and R5's round "1996" badge:** use the one chip style in §2.3.
11. **"1 note" / "3 notes"** (R2–R7): there's no notes data, and new data is out of scope. Footers show the photo count only (FT-39).
12. **"+5 photos" with an icon** (R3, R6): the chip is text-only "+n" ([§7.1](#71-full-size-photos-rev-14)).
13. **R5's wide sweeping band on phone:** phone uses the gentle single-side wave from R6 ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)).
14. **R1's nodes sit on a straight line, off the wave:** nodes and chips ride the spine ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)).
15. **Band width and wavelength vary across R1, R2 and R5** (about 28–32 wide, waves of 320–700): use the §2.2 numbers.
16. **R3 compact cards show "Open story":** compact cards have no Open story link. Tapping one expands it ([§5](#5-anchored-drill-down-and-back)).
17. **R5's Browse card header row** (year and counts above the photo): use the R2 anatomy, photo first ([§2.4](#24-rows-cards-and-variable-heights-rev-14)).
18. **R1's toolbar pills are about 30 tall:** they're 44 ([§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14)).
19. **R2's Browse card shows only "1996":** the card shows the date line at the precision entered.
20. **R3's front print is cropped about 2:1 inside the fan:** fan prints are 4:3 ([§7.1](#71-full-size-photos-rev-14)).
21. **R4's "4 of 12 stories match":** the count reads "{n} of {N} stories" (FT-14, L8).
22. **R4's "1974 · Moving day" on non-matching rows:** the chip carries the year. The row shows the title only.

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

1. **Visibility of status:** the density control shows the current stop. The scrubber's focused chip and the focused year chip on the band show where you are (rev 1.4). "n of N" and the Filters count show filter state. Screen readers hear focus announcements.
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
- **Knot at the beginning:** the thread band starts with a small terracotta knot at the oldest story, where the dashed spine begins (rev 1.4). It's a quiet sign of "where the family's stories begin".
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
| FT-27 | Scrubber decade label | {yyyy}s (e.g. 1990s) *(changed in rev 1.1 from '{yy}s; stamped by Jared 2026-11-25, 4:56 PM CT)* |
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
| FT-38 | Overview focused decade link (rev 1.4, [§2.5](#25-overview-mosaic-rev-14)) | Browse the {decade}s *(the → is an icon and isn't read; new, needs Jared's stamp)* |
| FT-39 | Card footer photo count (rev 1.4, [§2.4](#24-rows-cards-and-variable-heights-rev-14)) | {n} photos (singular: 1 photo; left out when there are none) *(same wording as the photo part of FT-31; new as visible text, needs Jared's stamp)* |
| FT-40 | Card chip overflow (rev 1.4, [§2.4](#24-rows-cards-and-variable-heights-rev-14)) | +{n} *(visual only; the beat label already names everyone; new, needs Jared's stamp)* |

**40 strings** (FT-01 to FT-40). 10 are existing or verbatim carries (FT-07, 09, 10, 11, 12, 15, 18, 19, 28, 37), and 30 are new or changed. FT-38 to FT-40 are new in rev 1.4 and need Jared's stamp after Bill approves. No rev 1.4 string contains "river".

## 20. Open UI questions

**Rev 1.4: Q3 to Q8 are open for Bill.** Bill approves rev 1.4 as a whole. Rev 1.4 is written to Mugatu's picks, and any other answer is a small, local change to the section named. Nothing is built before his approval.
- **Q1 (CLOSED 2026-11-22, 6:33 AM CT). Bill: "Keep the nav and button as 'Timeline'". Both keep their current locked copy, and the route stays `/timeline`.** The original question: at cutover, should the header nav item "Timeline" and the Family Landing CTA be renamed to "Family Thread"? **Default if unanswered:** both keep their current locked copy, the route stays `/timeline`, and the screen itself is titled **Family Thread** (FT-01). A rename would be a small copy delta for Jared to stamp, not a UX change.
- **Q2 (CLOSED 2026-11-25, 4:55 PM CT). Bill: "Approve the new albumMossInk green for the scrubber labels". Answer (a): albumMossInk #4A6A2F, scrubber matching-decade labels only.** The original question, green labels for matching decades: Bill's reference shows matching decades in green. The existing greens fail AA as 12pt text on the pill (branchMoss ≈4.1:1; albumSage is non-text only). **Options:** (a) approve one new token, **albumMossInk #4A6A2F** (≈5.5:1 on albumPillFill, ≈5.8:1 on parchment), used only for eligible scrubber labels; (b) keep albumInk. **Mugatu's pick: (a).** **Default until answered: (b) albumInk.** Either way it's a one-constant swap in the scrubber and changes nothing else.
- **Q3 (CLOSED 2026-11-25, 5:29 PM CT: Bill approved rev 1.4 as written, so the answer is (a)). Stadium shape for more pills.** Stitch draws the toolbar pills, the year chips and the Read Open story button with fully round ends. **Options:** (a) use the rev 1.2 stadium rule (radius = half the height, no new radius value) for the Filters pill, the density pill, the year chips and the Read Open story button, while filter chips and card chips keep radius 8; (b) keep radius 8 everywhere except the scrubber. **Mugatu's pick: (a)**, because it matches R1–R6 and the scrubber Bill already approved. Rev 1.4 is written to (a).
- **Q4 (CLOSED 2026-11-25, 5:29 PM CT: Bill approved rev 1.4 as written, so the answer is (a)). Photo crop on Read compact cards.** **Options:** (a) a 2:1 strip, as in R3 and R6 (a 400 card is about 320 tall, so about two and a half fit on screen); (b) 4:3, the same as §7a (about 420 tall, under two on screen). **Mugatu's pick: (a)**, because Read stays scannable and the focused card still shows the full 4:3 photo or fan. Rev 1.4 is written to (a).
- **Q5 (CLOSED 2026-11-25, 5:29 PM CT: Bill approved rev 1.4 as written, so the answer is (a)). Band width on wide screens.** **Options:** (a) 28pt, measured in R1 and R2; (b) keep the rev 1.0 24pt. Phone stays 16pt either way. **Mugatu's pick: (a).** Rev 1.4 is written to (a). It's a one-number change.
- **Q6 (CLOSED 2026-11-25, 5:29 PM CT: Bill approved rev 1.4 as written, so the answer is (a)). Narrow wide-screen windows.** Stitch-size cards don't fit on both sides of the band when the thread area is under 720pt (600–775pt windows, or 900–1055pt with the sidebar open). **Options:** (a) switch to the phone's single-side layout there, keeping the wide toolbar and scrubber; (b) keep alternating with cards squeezed down to 240pt; (c) auto-close the sidebar below 1056pt. **Mugatu's pick: (a)**, because cards keep their Stitch size and nothing is squeezed or hidden. Rev 1.4 is written to (a).
- **Q7 (CLOSED 2026-11-25, 5:29 PM CT: Bill approved rev 1.4 as written, so the answer is (a)). Where the Read focused card sits on wide screens.** **Options:** (a) centred over the band, up to 560pt wide, with its year chip above it, as in R3; (b) on its alternating side, up to about 394pt wide. **Mugatu's pick: (a)**, because it's the roomy card in R3 and fixes the cramped card. Rev 1.4 is written to (a).
- **Q8 (CLOSED 2026-11-25, 5:29 PM CT: Bill approved rev 1.4 as written, so the answer is (a)). "Browse the {decade}s →" link in Overview** (R1). **Options:** (a) add it under the focused decade (FT-38), doing the same as tapping the mosaic; (b) leave it out, so tapping the mosaic is the only way. **Mugatu's pick: (a)**, because it makes the drill-down visible (recognition over recall) and adds one tab stop in the slot Open story uses. Rev 1.4 is written to (a).

## 21. Visual acceptance checks (rev 1.4)

These checks are in addition to the behaviour checks. A build PR that touches a section attaches, for each row below, **a screenshot of the build placed next to the cited R screen** (or Bill's scrubber reference), taken at the same width: **1280** wide for desktop screens and **390** wide for phone screens. Use a test family with at least 6 decades, a story with 5 photos, a story with 1 photo and a story with no photo. Mugatu reviews the pairs before merge.
- Sizes and positions must be within **±2pt** of this doc's numbers. The Stitch screens are only the look to compare against, and the numbers here win.
- Colours must be the named `album_theme` token, exactly.
- Shapes must match: stadium, radius 12 or radius 8, circle.
- Sample data (names, places, photos, counts) differs and isn't checked.

| § | Build screenshot | Next to | Must match |
|---|---|---|---|
| 2, 2.1 | 1280 Overview, sidebar open; 390 Browse; 1280 with 2 filters on | R1, R5, R4 | Toolbar placement, both pills 44 tall and stadium, tune icon, terracotta selected segment with white label, no radio circles, count position (sidebar header when open), "Filters · 2" on sageTint |
| 2.2 | 1280 Overview; 390 Read | R1, R6 | sageTint wave about 28 wide, swinging about ±24 with a wavelength of about 360; dashed terracotta spine 2 wide, 5 on, 5 off, following the curve; round ends; knot on the spine; gentle phone wave near the left edge; no shadow or glow |
| 2.3 | 1280 Browse; 390 Read; 1280 Overview | R2, R6, R1 | A chip on every row, centred on the spine, full years; unfocused cream with a border and dim text; focused terracotta with white bold text; 1px connectors; Overview nodes instead of chips |
| 2.4 | 1280 Browse; 1280 Read; 390 Browse; 390 Read; 390 Read at 200% text | R2, R3, R5, R6 | Upright cards (never photo beside text), card widths 360 / 400 / 560, the 302 phone column, pale rose and terracotta focused cards, parchment compact cards, a 2:1 compact strip, no Open story on compact cards, uneven row heights, landmarks in italic 28pt |
| 2.5 | 1280 Overview | R1 | Mosaics 96 and focused 112 with the stitch ring, alternating; 32pt and 36pt bold labels; "Browse the 1990s →"; caption at the bottom |
| 2.6 | 390 Browse; 390 Read; 390 drawer open | R5, R6, R8 | Pills, band position, card column, bottom strip, drawer parts and footer |
| 3 | 1280 at each stop, focused on the same story | R1, R2, R3 | The same story is centred at every stop (its decade, its year, the story itself) |
| 4, 4.1 | 1280 Browse, settled after a scroll; recording of the settle | R2 | Focused card centred; images two or more beats away visibly faded (30%); text never lighter than albumInkDim; no jump during the drag |
| 5 | 1280 Read after Back from a story | R3 | The same card focused and centred with its stitch ring, the same filters |
| 6, 6.1 | 1280 scrubber column; 390 bottom strip | Bill's reference `refs/bill-scrubber-reference.png` (the R scrubbers are superseded) | Everything in [§6.1h](#61h-acceptance-checks-for-the-build), unchanged |
| 7, 7.1 | 1280 Read with 5 photos; 1280 Browse with 1 photo; 1280 Read with no photo; 390 Read with 5 photos | R3, R7 (a, b, c, d), R2, R6 | Fan about 400×300 (390: about 222 wide), equal prints, 6 mats, back edges showing, "+2"; 4:3 Browse cover; quote card with no empty frame; 64 medallions with a 2px ring |
| 8 | 1280 Browse with filters; 390 drawer | R4, R8 | Hollow 12 dots with dim titles and chips still on the band; active pills row; "{n} of {N} stories"; drawer as R8 |
| 9 | none (behaviour) | — | No visual step. Restoring shows no jump from the newest story, per the §9 behaviour checks. |
| 10 | 1280 with keyboard focus on the thread | R2 | The roving focus ring on the focused beat's card or medallion, not on the chip |
| 11 | 1280 loading; load error | none (text only) | 5 skeleton beats on a band (the wave and dashed spine already drawn), density pill in the disabled look, "Couldn't load stories." + Retry |
| 12 | Recordings with reduced motion on and off | none | Nothing loops; with reduced motion on, snaps, expands, segment and chip changes are single cuts |
| 13 | 1280 keyboard focus on each of: Filters pill, density segment, the focused card's Open story or Browse link, scrubber | R1, R2 | 2px albumTerracotta ring with a 2px offset following each control's shape, never hidden under the sticky header |
| 18 | 1280 Overview and Read | R1, R3 | The stitch ring around the focused mosaic or card; the knot at the top of the spine |

## Handoff notes for Gilfoyle (SAD)

These are not UX decisions. Each one is a UX requirement whose mechanism Gilfoyle picks:
- **Build-phase route:** no "river" in it. Cutover mechanism. A separate decommission PR.
- **Device-local open-state storage** that survives relaunch on iOS and reload on web ([§9](#9-open-state-a5)). Not synced.
- **Web:** ctrl/⌘ + wheel needs a non-passive listener scoped to the thread area so preventDefault works ([§10](#10-input-gestures-keys-pointer)).
- **Performance:** smooth snapping and centring for large families (L10).
- **Live updates:** keep the same live-update behaviour as the current `/timeline`. No new UX is required either way.
- **Stories with no recorded year:** not expected for published stories. Confirm against the data model rather than designing for it.
- **Rev 1.4, variable row heights (Big Head, then Gilfoyle):** after Bill approves rev 1.4, Big Head restamps impl spec P1c to drop the fixed item extent (64 / 112 / 124pt) and its sideways card layout. The UX requirements are in [§2.4](#24-rows-cards-and-variable-heights-rev-14) and [§4.1](#41-snap-and-focus-with-variable-row-heights-rev-14): sizes frozen while the thread moves, the pinned focused row on settle, the target already expanded on jumps, photo areas reserving their size before the image arrives, and no jump when an off-screen height estimate is corrected. How heights are measured, estimated and cached, and how the list keeps its anchor, is Gilfoyle's call. The L10 smoothness bar for families with hundreds of stories still applies.
- **Rev 1.4, wave band painting:** the band and dashed spine should be drawn as one shape for the visible range (plus a margin), with dashes laid out along the path length. Don't rebuild them on every scroll frame, and don't draw one band piece per row. The wave's offset must be a pure function of distance from the oldest beat ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)), so a row inserted far away doesn't reshape the band on screen. There are no shadows, blurs or transparency layers, so no offscreen compositing is needed.
- **Rev 1.4, density pill:** the build can use a custom widget or a themed platform segmented control, but it must have no check mark, no Material grey or tonal fill and no ripple that leaves a grey wash. Semantics stay one radio group with three radios (FT-02 to FT-05).
- **Rev 1.4, Filters pill:** exposes button semantics with an expanded or collapsed state tied to the sidebar or drawer. Its accessible name contains the visible text "Filters" or "Filters · {k}" (WCAG 2.5.3).
- **Rev 1.4, photo decode size:** photos decode at their displayed size × device pixel ratio for the §7.1 sizes. Today's fan decodes at 96. Off-screen photos still don't download early (R-02).
- **Rev 1.4, visual checks:** golden or screenshot tests at 1280 and 390 make the [§21](#21-visual-acceptance-checks-rev-14) pairs cheap to produce. The test seam is Big Head's choice.

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

Contact sheet: `docs/ux/assets/family-thread/R1-R8-contact.jpg` (R1–R8, reference only). Its source is `/workspace/stitch-audit/R1-R8-contact.jpg`.

### Stitch cleanup (rev 1.4)

**Done on 2026-11-25, about 5:15 PM CT, with the Stitch CLI's `update_project`. Canvas layout and labels only, nothing generated or deleted:**
- R1–R8 weren't on the project canvas before. The project's screen list showed 36 exploration screens and no R screens, although each R screen could be opened by its id. All eight are now placed on the canvas in one row above the exploration screens, in order R1 to R8, at y = −2400 (x = 0, 1400, 2800, 4200, 5600, 6110, 6620, 8020). Desktop screens are 1280 wide, phone screens 390. They're labelled "Family Thread R{n} — {what it shows} (reference; UX doc rev 1.4 is authoritative)". The project's screen list now returns 44 screens, including all eight R screens.
- All 36 exploration screens (concepts A–E) keep their places and are relabelled "RETIRED (exploration, not built) — {original title}".
- A backup of the canvas from before the change is kept at `/workspace/family-thread/stitch-cleanup/backup-get_project-before.json`, so it can be restored exactly.

**Not done, and what's needed:**
- **The R screens' own titles** still use the exploration name ("Timeline — Concept A: … (…)"). The Stitch tools can change a canvas label but not a screen's title. Renaming them needs a person in the Stitch web app, or leaving them as they are. They aren't UI copy ([§15](#15-mockup-corrections) item 7).
- **Nobody has looked at the canvas in the Stitch web app yet.** The new placements were confirmed through the API only. If the web app doesn't show the eight R screens in a row above the retired concepts, someone needs to place them by hand in Stitch.
- **Committing the contact sheet** at `docs/ux/assets/family-thread/R1-R8-contact.jpg` is for the docs PR, because Mugatu doesn't push. **Why this path:** it sits next to this doc under `docs/ux/`, so the relative link `assets/family-thread/R1-R8-contact.jpg` renders on GitHub. The per-feature folder keeps later feature assets from colliding in one flat folder. It stays in the docs lane, outside `apps/`, so it never ships in the app bundle. The rev 1.0 name `family-thread-contact.jpg` was never committed, and this path replaces it.

## Changelog

- **rev 1.4 LOCKED (2026-11-25, 5:31 PM CT):** Bill approved rev 1.4 as written at 5:29 PM CT, via Erlich. Q3 to Q8 are closed as (a). Only the status lines and §20 changed.
- **rev 1.4 DRAFT (2026-11-25, 5:30 PM CT), awaiting Bill's approval. Baseline: locked rev 1.3.** A full-page Stitch-match revision from Bill's 4:59 PM CT approval of the Stitch-match plan, relayed by Erlich, so the shipped page matches R1–R8. It closes Erlich's seven gaps:
  1. The wavy band with a dashed spine ([§2.2](#22-thread-band-wave-and-dashed-spine-rev-14)).
  2. Stitch-size cards with variable row heights, and the snap and centring rules for them ([§2.4](#24-rows-cards-and-variable-heights-rev-14), [§4.1](#41-snap-and-focus-with-variable-row-heights-rev-14)). Big Head restamps P1c after approval.
  3. The full-size photo fan ([§7.1](#71-full-size-photos-rev-14)).
  4. The segmented density pill with radio semantics, and 5. the Filters pill with the tune icon and an active state ([§2.1](#21-toolbar-filters-pill-and-density-pill-rev-14)).
  6. Year chips on the band ([§2.3](#23-year-chips-and-beat-nodes-rev-14)).
  7. The Overview mosaic and the phone layout ([§2.5](#25-overview-mosaic-rev-14), [§2.6](#26-phone-layout-rev-14)).

  Also added: [§21](#21-visual-acceptance-checks-rev-14), visual acceptance checks per section against the R screens, and the [Stitch cleanup](#stitch-cleanup-rev-14) record (R1–R8 placed on the canvas and concepts A–E labelled retired) with the contact sheet path `docs/ux/assets/family-thread/R1-R8-contact.jpg`.

  Sections touched: status block, Sources, §1, §2 (table and bullets), new §2.1–2.6, §3 table, new §4.1, §5 table, §7b, new §7.1, §8, §11, §12, §13, §14, §15 (adopted visuals and items 9–22; item 4 updated), §17 item 1 (stale '90s wording), §18, §19 (FT-38 to FT-40), §20 (Q3 to Q8 opened), new §21, handoff notes, Stitch screens.

  §6.1 content is unchanged. Only cross-links were added in 6.1b and 6.1e.

  Doc nits from PR #276 folded in:
  - (1) FT-27 is marked stamped (Jared locked {yyyy}s on 2026-11-25 at 4:56 PM CT).
  - (2) Every §6.1c reference now links to `#61c-visual-600pt-right-edge-column`: §14's albumMossInk link, and the plain "6.1c" mentions in 6.1b and 6.1e. The eligible-label row in 6.1c has no link, in this file or in PR #276, so it was left as is.
  - (3) §20's Q1 and Q2 are now one list, with no blank line between them.

  No new colour token and no new radius value. Q3 extends the existing stadium rule.
- **rev 1.3 (2026-11-25, 4:57 PM CT):** closed Q2 as (a). Bill approved albumMossInk #4A6A2F at 4:55 PM CT for the scrubber's matching-decade labels only. Updated §6.1c, §6.1h check 2, §14 and §20.
- **rev 1.2 (2026-11-25, 4:55 PM CT):** matched §6.1 against Bill's actual screenshot. Pill and chip now have fully round ends, there is one 4pt albumInkFaint dot per gap instead of three, and the chip label is 13pt weight 700. Nothing else changed.
- **rev 1.1 (2026-11-25, 4:52 PM CT):** lane 2 delta from Bill's 4:50 PM CT ask via Erlich. Added [§6.1](#61-dial-scrubber-rev-11), the dial scrubber: cream pill, full decade labels, dots, terracotta focus chip, continuous drag with momentum and snap, the 250ms tap animation, reduced motion, and the phone centred dial. §6 bullets were retired in place, §12 gained two rows, §13 gained Home/End, FT-27 changed to {yyyy}s, §15 items 1–2 were superseded, and Q2 was opened. No new tokens are used; Q2 proposes one.
- **rev 1.0 (2026-11-21, approved 2026-11-22 at 6:33 AM CT):** first lock, which Bill approved as written. He also closed Q1: the nav and the button stay "Timeline". Built from scope rev 4, Bill's 6:14 PM CT decisions, R1–R8 and the #249 learnings. Renamed to Family Thread and thread band throughout.
