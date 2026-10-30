# #80 All Stories view + Stories nav rework (UX LOCKED)

Status: **LOCKED** rev **1.1** (2026-10-30 ~6:18 PM CT: open Qs closed, see Change log); rev 1.0 Bill 2026-10-30 6:10 PM CT America/Chicago ("Lock #80 UI as drafted, page opens grouped by Date"), Mugatu. Rev 1.0 locks rev 0.2 as drafted and confirms Default grouping = Date. Copy stamped by Bill 6:16 PM CT (Decisions "### #80 copy stamps"). Rev 0.2 was ~6:05 PM CT; rev 0.1 ~5:45 PM CT. Written rules win over mock quirks.
Source: PRD "#80 All Stories view + Stories nav rework", APPROVED by Bill 2026-10-30 5:28 PM CT, rev 1: https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2
Decisions: 2026-10-30 entry, Issue #80 (Q1–Q6 locked): https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166 · Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/80
Delta baseline (main @ `7432ff4`): `docs/ux/79-family-landing.md` Rev 2.2, `docs/ux/130-header-cleanup.md` rev 1.3, `docs/ux/uxd-handoff.md` (DESIGN.md, R2, R3, M9, M12, M11a, #153 amend).
Lane: 3. UX delta only. Does **not** reopen the #130 chrome look, the timeline (R3/M12/M13 zoom levels), the reader (M9/#153), the Search screen (M7), the Landing hero or Latest shelf, or #79 Rule 9 (return to Landing).

Tokens (album_theme only, no new colors, fonts or icons): parchment `#FBF7F2`, ink `#2C2416`, terracotta `#8B5E4B`, sage `#7A8B74`, albumDialogSurface `#FFF8F6`. Story pills (#153): fill `#F6F1EB`, border `#E7DECE`, 20px radius. Branch ring (M12/M11a): 16px dashed sage hollow ring on a parchment disc. Fonts: Newsreader (headings), Source Sans 3 (UI). Material icons only.

## Primary user / JTBD (PRD Q1)

Any family member browsing and rediscovering the family's stories: one place to see, group and search all of them, with timelines one step away.

## Product locks this doc builds on (do not invent)

1. **Q2:** All Stories is its own page (not an expanded Landing). The Landing button goes there.
2. **Q3:** Header **Stories** and the Landing CTA both go to All Stories. Timelines open from All Stories. Supersedes the #79 Q1/Q6 header-Stories-to-timeline locks.
3. **Q3b:** Landing CTA copy is `View all stories for {Family}`. Pill styling stays Mugatu's.
4. **Q4 (all must-have):** group/sort by date, by member, by place; search that **dims** non-matches; highlight stories that spawn a timeline.
5. **Q5 (out):** saved filters/searches; editing/curating from All Stories; cross-family search.
6. **Q6:** search matches title, story text, and people on the story. Place is **not** a search field.

## Screen map

| Id | Screen | Who |
|----|--------|-----|
| A | All Stories, default, grouped by Date (decades) | Any member |
| B | All Stories, grouped by Member | Any member |
| C | All Stories, grouped by Place (with "No place yet" last) | Any member |
| D | All Stories, search active, non-matches dimmed | Any member |
| E | All Stories by Date, `Started a timeline` toggle ON in the pinned row, only spawn stories undimmed | Any member |
| — | Family Landing with the new CTA label | No new screen: written-rule only (Rule 3) |

Route: new All Stories route for the current header family (route name is Gilfoyle's). Timeline route unchanged.

## Rules

### Rule 1: Page layout
- Shared #130 header on top (Rule 2). Below it, one centered content column on parchment, same max width as Landing.
- **Heading row:** Newsreader page title `All Stories` (copy needs Jared stamp) on the left; the timeline button (Rule 9) on the right.
- **Control row** (one quiet row, same spirit as the R3 zoom row): in-page search field on the left (Rule 5), then the `Started a timeline` toggle (Rule 6), then the `Group by` segmented switch on the right (Rule 4). The status line (Rule 5/6) sits directly under it.
- **Groups:** a section heading per group, then that group's story cards in a grid: 3 columns at desktop / iPad landscape, 2 at iPad portrait, 1 on phone. 24px gaps.
- **Story card** extends #79 Rule 4: cover thumb (first story photo by sort order per #153, or parchment blank) · recorded-event line exactly as entered (M13: `1987` / `March 1987` / `March 4, 1987`) · saved title (Newsreader, 2 lines then ellipsis, no invented "Untitled") · people pills (#153 pill style) · place line (sage `location_on` + place name). No body text, no counts, no author line, no edit/delete/select controls (Q5).
- The page shows the current family's published stories only. Drafts stay in Draft Stories.
- **Pinned controls (UI decision 5):** the header stays, and the control row plus its status line pin directly under it while the groups scroll. Pinned row: parchment fill, thin ink 10% bottom border once content scrolls under it. The heading row (title + timeline button) scrolls away. Focus moving to a card scrolls it clear of the pinned row.

### Rule 2: Header Stories entry
- Header nav label stays **Stories** (#130 Rule 3); its **target** changes from the timeline to **All Stories** (PRD Q3).
- Active underline: **underlined on All Stories** and still underlined on the timeline (timeline is reached through Stories). Still **not** underlined on Landing (#79 locked UI decision 1 stands for Landing).
- Draft Stories, search icon, New story, avatar, family switcher: unchanged (#130).
- Family switch while on All Stories follows #82/M22: a different family → that family's Landing. Same-family pick → Landing (#79 Rule 9, unchanged).
- The header search icon keeps opening the existing Search screen (#130 Rule 5 unchanged; UI decision 4). It does not open All Stories, and All Stories' in-page search does not replace it.

### Rule 3: Landing CTA change (supersedes #79 Rule 7′ copy + target)
- Copy: `View all stories for {Family}` (PRD Q3b; `{Family}` = header family display name).
- Target: **All Stories** (PRD Q2/Q3), not the timeline.
- Look **unchanged** from #79 Rule 7′: centered terracotta stadium FilledButton, parchment label, Source Sans 3 18/w600, no icon, ~16×10 padding, soft elevation 1; single line with end ellipsis and full string in tooltip/semantics; still shown on the empty week. Key may stay `family-landing-view-all`.
- No Stitch regen: only the label string changes. Build from #79 Rev 2.1 keepers A/B/C with the new label.

### Rule 4: Group / sort control
- One segmented switch, label `Group by`, three segments `Date` · `Member` · `Place` (copy needs Jared stamp). Selected = filled terracotta pill with parchment label, sliding 240ms like the R3/M13 zoom switch; others ink on the soft beige track.
- **Default = Date** (LOCKED Bill 2026-10-30 6:10 PM CT).
- **Within every group, stories sort by recorded event date, newest first** (matches the Landing shelf and timeline direction). Ties: newest published first.
- **Date:** sections by **decade**, newest decade first, heading `1980s` + quiet count `3 stories`. Each card shows its own year/month/day line, so year and exact date read inside the decade (issue: "decade, date, year"). Any published story without a date groups last under `No date yet` (existing Bill-approved Drafts copy).
- **Member:** one section per person tagged on a story, A–Z by display name. Heading: 32px M8 avatar circle (photo or initials) + name + count. A story with several people **repeats under each person tagged** (UI decision 3). Stories with no people group last under `No one tagged` (copy needs Jared stamp).
- **Place:** one section per story place, A–Z by place name. Heading: sage `location_on` + place name + quiet short address + count. No maps on this page. Stories without a place group last under `No place yet` (copy needs Jared stamp). Depends on PRD Assumption 1 (Gilfoyle confirms stories carry a usable place).
- Switching grouping keeps the search text, the toggle and their dimming (Rules 5–6), and scrolls to the top.
- The choice lasts while the user stays in the session (back from the reader or the timeline restores it). It is **not** a saved filter and is not stored per user (Q5).

### Rule 5: Search dims, never hides
- In-page field in the control row: leading `search` icon, placeholder `Search titles, story text, and people` (copy needs Jared stamp), clear `close` button when the field has text. Focused: 2px terracotta border.
- Matches **title, story text, and people on the story** (Q6). Place is not searched. Current family only (Q5: no cross-family).
- Results update as you type (after a short pause); Enter does nothing extra.
- **Nothing is hidden, removed or reordered.** Groups, order and card sizes stay exactly as without search.
- **Match:** full color, plus a 2px terracotta card border; a matching person pill gets a terracotta outline.
- **Non-match (dimmed):** photo grayscale with a soft parchment veil; all card text (title, date, pills, place) drawn no lighter than **#6A6358** (ink at ~70% on parchment, **5.56:1**, passes 4.5:1). Never use plain opacity below that. Dimmed cards stay tappable and open the reader.
- A section with zero matches dims its heading the same way.
- Status line under the control row: `{n} of {total} stories match "{query}"` (copy needs Jared stamp). With the toggle also on, see Rule 6.
- Clearing (X, or emptying the field) restores everything at full color. The search text is kept while in session (same as Rule 4) and is not saved (Q5).

### Rule 6: Timeline-spawn highlight (UI decision 1: BOTH marks and toggle)
- A story **spawns a timeline** when at least one other family's timeline was started from it (it is that family's origin story, M11a/M11b).
- **6a. Always-on marks**, in every grouping and every state: the card's pill row starts with the #153 **Origin** pill (sage icon and text), then one family pill per branch started from it (tree icon, A–Z), then people pills. Plus the M12 **16px dashed sage hollow ring** on a parchment disc at the top-right corner of the cover photo. Not color alone: ring plus worded pills. Under any dimming, a dimmed spawn story keeps its ring and pills in the dimmed style.
- **6b. Child family's origin story (UI decision 6):** a child family's All Stories includes its origin story from the parent, with the #153/M11a `Origin · from {Parent}` tag as its Origin mark (plus the ring). It groups, searches, and counts like any other story in that family. It counts as a spawn story for the toggle (it started this timeline).
- **6c. `Started a timeline` toggle** (copy needs Jared stamp) in the pinned control row, between search and `Group by`. Stadium chip, ≥ 44px tall.
  - **Off (default):** outlined chip, ink 15% border, ink label, leading sage dashed-ring glyph (same mark as 6a, drawn small). Nothing dims because of it.
  - **On:** filled terracotta, parchment label, leading `check` icon replaces the ring glyph. Every story that does not spawn a timeline dims with **exactly the Rule 5 dim treatment** (grayscale photo + parchment veil, text no lighter than #6A6358, still tappable). Spawn stories stay full color with the 2px terracotta border. Sections with no spawn story dim their heading. Nothing is hidden or reordered.
  - Tap or Space/Enter flips it. It lasts for the session like Rule 4; it is not saved (Q5).
  - **Accessible name/state:** a toggle button named `Started a timeline`, exposing pressed = false/true (`aria-pressed` / Flutter `toggled`). On change the status line announces (polite live region).
- **6d. Toggle + search combine with AND:** a story is undimmed only if it matches **every active filter**: the search query (when text is entered) **and** spawn status (when the toggle is on). Otherwise it dims. Either alone behaves as its own rule.
- **6e. Status line** (copy needs Jared stamp): toggle only → `{n} of {total} stories started a timeline`; search only → Rule 5; both → `{n} of {total} stories started a timeline and match "{query}"`. Zero → `0 of {total} …`, every card dimmed, nothing hidden. Clearing search keeps the toggle state and vice versa.
- **6f. Empty family:** toggle disabled with the search field and switch (Rule 7). A family with stories but no spawn story: toggle still works; on, every card dims and the status line reads `0 of {total} stories started a timeline`.

### Rule 7: Empty, no-results and loading states
- **Loading:** heading row and control row render at once; the grid shows parchment card skeletons (thumb block + two text bars) under one skeleton section heading. No spinner text. Search and the switch are usable as soon as data lands.
- **Empty family** (no published stories): no groups; one quiet centered line `No stories yet.` (copy needs Jared stamp). Search, the toggle and the switch are disabled. The timeline button still shows. New story stays in the header as the path to create (no extra create button; curation is out, Q5).
- **No results:** every card dims (Rules 5–6); the status line reads the matching zero form (Rule 6e). Nothing is hidden.
- **Load error:** quiet inline line with a Retry text button in terracotta (existing error token `#9F403D` only for the line). Copy needs Jared stamp.

### Rule 8: Opening a story
- Tap or Enter on a card → **reader modal** over All Stories (#153 Rule 1: parchment sheet, page dimmed and blurred behind).
- Close X / back → back to All Stories at the same scroll position, grouping and search (#153 Rule 3: close goes back one step).
- Reader behavior, pills and menus are unchanged. Dimmed cards open the same way.

### Rule 9: Reaching a timeline from All Stories (PRD Q3)
- **Current family's timeline:** outlined terracotta stadium pill on the right of the heading row (terracotta 1px border, terracotta label, parchment fill, no icon), label = the Jared-stamped string `View a Timeline of Stories for {Family}` moved here from Landing (Jared to confirm reuse). Opens the existing timeline (`AppRoutes.timeline`) at its default zoom. Outlined, not filled, so New story stays the only filled terracotta control in the header area.
- **A branch family's timeline (UI decision 2):** on a spawn story card, tapping a branch family pill opens that branch's timeline (read), same as M12 marks. The card body (anywhere outside a branch pill) still opens the reader. On a child family's origin card, the `Origin · from {Parent}` tag is a label, not a link (unchanged from M11a; the parent timeline opens from the family menu / M12 ring).
- From the timeline, header Stories returns to All Stories.

### Rule 10: Accessibility
- **Focus order:** header → timeline button → search field → `Started a timeline` toggle → Group by switch → each section heading → its cards in reading order (row by row), with branch pills as their own stops after the card.
- **Focus ring:** 2px terracotta outline with 2px parchment offset on cards, pills, switch segments and buttons; never removed. A focused dimmed card shows the same ring.
- **Contrast:** normal text ≥ 4.5:1 everywhere, dimmed cards included (#6A6358 on parchment = 5.56:1). Terracotta on parchment = 5.18:1. Sage text (#7A8B74, 3.41:1) is the existing Origin pill token; it is only used with an icon and the word "Origin", never as the only signal.
- **Semantics:** page title is heading level 1; each group heading is level 2 with its count. The switch is a radio group named "Group by". The status line is a polite live region. Each card is one button named "{title}, {date}, {people}"; adds ", matches" or ", not a match" while search and/or the toggle is active (Rule 6d); spawn stories add "Started the {Family} timeline". Branch pills are separate buttons named "Open the {Family} timeline".
- **Targets:** ≥ 44×44 for pills, the clear X and switch segments (DESIGN.md: large tap targets for elders).
- **Toggle:** toggle button named `Started a timeline`, pressed false/true (Rule 6c); state also shown by fill + check icon, not color alone.
- **Pinned row:** stays in the tab order where it sits; content scrolled under it never hides the focused card (Rule 1).
- **Motion:** the 240ms slide and dim transitions drop to instant under reduced motion.

## Supersedes

1. `79-family-landing.md` **Pack lock 1**: "Header **Stories** → timeline. Landing links there." → Header Stories → All Stories; Landing CTA → All Stories.
2. `79-family-landing.md` **Pack lock 5**: "Landing has clear timeline CTA" → Landing CTA goes to All Stories; timelines open from All Stories.
3. `79-family-landing.md` **Pack lock 6** and **Copy table "Timeline CTA"**: `View a Timeline of Stories for {Family}` → `View all stories for {Family}`.
4. `79-family-landing.md` **Rule 7′** copy and "Route/behavior unchanged: tap → existing timeline (`AppRoutes.timeline`)" → tap → All Stories. Look unchanged.
5. `79-family-landing.md` **Rule 5** last sentence: "Timeline CTA (Rule 7′) remains visible so members can reach the full timeline" → the CTA remains visible so members can reach All Stories.
6. `79-family-landing.md` **Locked UI decision 6** (Timeline nav, Q6): "Header Stories primary + Landing timeline CTA" → header Stories and the Landing CTA both go to All Stories.
7. `79-family-landing.md` **Locked UI decision 1** clarified: Stories underlined on All Stories and timeline, not on Landing.
8. `uxd-handoff.md` **R2**: "Timeline. It returns to the timeline for the current family." (already relabeled Stories by #130) → Stories opens All Stories for the current family.

## Out of scope (PRD Q5 + baseline)
- Saved filters or saved searches.
- Editing, curating, reordering, selecting or deleting stories from All Stories.
- Cross-family search (branch pills open a branch timeline, they do not widen search).
- Place as a search field (Q6).
- Pointing the header search icon at All Stories (UI decision 4; #130 Rule 5 unchanged).
- Any change to the timeline, reader, Search screen, #130 chrome look, Landing hero or Latest shelf, or #79 Rule 9.

## Patch list for other docs/ux files (Erlich applies; Mugatu does not edit)
1. `79-family-landing.md` Pack lock 1 → `Opening a family → **Family Landing**. Header **Stories** → All Stories (#80). Landing CTA → All Stories.`
2. `79-family-landing.md` Pack lock 5 → `Header **Stories** stays primary; Landing CTA goes to All Stories (#80); story cards open the story.`
3. `79-family-landing.md` Pack lock 6 + Copy table row → `Landing CTA: View all stories for {Family} (PRD #80 Q3b, 2026-10-30 5:19 PM CT).`
4. `79-family-landing.md` Rule 7′ title + route line → `Rule 7′ — Path to All Stories` / `Route: tap → All Stories (#80). Look unchanged.`
5. `79-family-landing.md` Rule 5 → `...CTA (Rule 7′) remains visible so members can reach All Stories.`
6. `79-family-landing.md` Locked UI decision 1 → `Stories un-underlined on Landing; underlined on All Stories and on the timeline (#80).`
7. `79-family-landing.md` Locked UI decision 6 → `Header Stories + Landing CTA → All Stories; timelines open from All Stories (#80 Q3).`
8. `79-family-landing.md` intro "Primary user / JTBD" → `...with a clear path into All Stories via header **Stories** and the Landing CTA.`
9. `130-header-cleanup.md` Rule 3 first bullet → append `Target: All Stories (#80), was the timeline.` (nav target only; Rule 5 search icon is unchanged, so no Rule 5 patch.)
10. `uxd-handoff.md` R2 "Timeline" bullet → `Stories (was Timeline, #130). Opens All Stories for the current family (#80); the timeline opens from there.`

## Locked UI decisions (Bill 2026-10-30 6:01 PM CT, via Erlich; doc still DRAFT pending lock)
1. **Spawn highlight = both:** always-on Origin/branch pills + dashed sage ring, **and** a `Started a timeline` toggle in the pinned row that dims all other stories with the search dim treatment (Rule 6).
2. **Branch pill** on a card opens that branch's timeline; the card body still opens the reader (Rule 9).
3. **Group by Member:** a story repeats under each person tagged; `No one tagged` group for none (Rule 4).
4. **Header search icon** keeps opening the existing Search screen; #130 Rule 5 unchanged (Rule 2).
5. **Pinned controls:** search + toggle + Group by row is pinned under the header while scrolling (Rule 1).
6. **Child family's All Stories** includes its `Origin · from {Parent}` story with its Origin mark (Rule 6b).

## Open UI questions
None open. Closed rev 1.1:
1. ~~Jared copy stamps~~ — CLOSED: Bill stamped all #80 copy 2026-10-30 6:16 PM CT (Decisions "### #80 copy stamps", https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166). C4 load error = `Couldn't load stories.` + `Retry`; C5 reuses `View a Timeline of Stories for {Family}` on All Stories. Decisions is the copy source of truth.
2. ~~Bill lock~~ — CLOSED: Bill locked this doc 2026-10-30 6:10 PM CT, default grouping = Date (Rule 4).

Non-UI dependencies for Gilfoyle (not blocking UX): stories carry a usable place (PRD Assumption 1) and enough date precision for decades (Assumption 2); how "started a timeline" is read for a story (PRD Assumption 3).

## Stitch screens

Project: `12192342757314667328` (Tell Me a Story). Design system: `assets/18104844965535020843` (Memory Album). DESKTOP 2560 px wide (1280 @2x), same as existing keepers. Use `?node-id=` links.

| Id | Description | Screen id | Link |
|----|-------------|-----------|------|
| A | Grouped by Date (decades) | `5bde084b159045aeadf8f544c1ad0696` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=5bde084b159045aeadf8f544c1ad0696 |
| B | Grouped by Member | `3f1695af6a4b4dc68ac5b02d7a9b84fc` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=3f1695af6a4b4dc68ac5b02d7a9b84fc |
| C | Grouped by Place + No place yet | `38102f4d36c84ce68145ade688908ea8` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=38102f4d36c84ce68145ade688908ea8 |
| D | Search "Sarah", non-matches dimmed | `46b3fe1091404d7587ebb5250939d138` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=46b3fe1091404d7587ebb5250939d138 |
| E | By Date, `Started a timeline` toggle ON in pinned row, only spawn stories undimmed | `8948a8cad982447eafb23ff5d4b1b4f7` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=8948a8cad982447eafb23ff5d4b1b4f7 |
| — | Landing new CTA label | no screen (Rule 3; #79 Rev 2.1 keepers + new label) | n/a |

Mock quirks (written rules win):
- All: names, photos, places and counts are Stitch filler, not product data.
- A: 2020s cards are not newest-first (2021, 2023, 2020). Rule 4 wins: newest first in each group. Not regenerated in rev 0.2 (one-call budget); E shows the correct order.
- A–D: drawn before UI decision 5/1, so they show no `Started a timeline` toggle and an unpinned control row. Rules 1 and 6 win; E is the reference for the pinned row and toggle.
- C: the "Unassigned location" subtext under `No place yet` is filler; drop it.
- D: the timeline button picked up a leading chart icon; Rule 9 says no icon. Dimmed text may render lighter than #6A6358; Rule 5 floor wins. The 1970s heading should dim (Rule 5) even if the mock barely shows it.
- B/C: dimming and status line are D/E-only; A–C show no search or toggle state.
- E (PNG `/workspace/m80/E_all-stories-started-timeline.png`): toggle ON chip keeps the ring glyph and puts the check **trailing**; Rule 6c wins (check leading, replaces ring). Dimmed text renders lighter than the #6A6358 floor; Rule 5/6c wins. Spawn-card ring reads small/faint; Rule 6a wins (16px dashed sage). Wedding cover is drawn as an inset photo-in-frame; ordinary cover crop applies.

## Hand-off

LOCKED rev 1.1. UI locked by Bill 2026-10-30 6:10 PM CT; copy stamped by Bill 6:16 PM CT (Decisions "### #80 copy stamps"). Erlich applies the patch list in docs PR #155 (Mugatu cannot push); Gilfoyle confirms place data (PRD Assumption 1), date precision (Assumption 2) and how "started a timeline" is read (Assumption 3).

Change log: rev 1.1 (2026-10-30 ~6:18 PM CT) — closed Open UI Qs 1–2 (copy stamped 6:16 PM CT; lock 6:10 PM CT) and updated Hand-off to LOCKED; no rule, screen or copy text changed.
