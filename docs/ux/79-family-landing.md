# #79 Family Landing Page (UX LOCKED)

Status: **LOCKED** 2026-10-28 ~11:30 AM CT America/Chicago — Bill via Erlich (amended pack APPROVED ~11:26 AM CT; Q1/Q2/Q4/Q3b/Q6). Rev **2.0** (supersedes Rev 1.x Featured/Oldest keepers).
sha256: `1d5969129266185305a6c18a9db2f713b3d938690be8fee92af610ec350c37ef`
Source: PRD Family Landing (#79) APPROVED amended: https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2  
Decisions: https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166 · Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/79  
Lane: 3 (full path). Does **not** reopen #130 header chrome, timeline redesign, Manage Families hub, or public family pages.

Tokens (album_theme): parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`, albumDialogSurface `#FFF8F6`. Fonts: Newsreader (headings/wordmark), Source Sans 3 (UI). Material icons only.

## Primary user / JTBD

A family member opening their family — land on a family “face” (hero photo + recent stories) before the chronological Stories timeline, with a clear path into the timeline via header **Stories** and Landing **View all stories**.

## Pack locks (product — amended — do not invent)

1. Opening a family → **Family Landing**. Header **Stories** → timeline. Landing links there.
2. Owner + co-owners customize = **hero image only** (same admin who as other family admin).
3. Dedicated family/hero photo upload by owner/co-owners; placeholder until set.
4. **One shelf only:** latest **3** stories **added in the past 7 days**. No Featured. No Oldest. No curated picks. No Choose featured modal.
5. Header **Stories** stays primary; Landing has clear **View all stories** CTA; story cards open the story.

Out of scope: public family pages; timeline redesign; Manage Families hub; Featured/Oldest/shelf builder; owner-curated story picks.

## Screen map

| Id | Screen | Who |
|----|--------|-----|
| A | Landing — populated (hero + up to 3 latest-7d cards + View all stories) | Any member |
| B | Landing — empty week (hero or placeholder; zero stories in past 7 days + View all stories) | Any member |
| C | Landing — owner/co-owner chrome (camera on hero only) | Owner / co-owner |

Route: Family Landing is the default after open/switch. Header Stories → existing timeline. Wordmark stays brand. **No** Featured picker screen.

## Layout rules (LOCKED)

### Rule 1 — Shared header (#130 chrome unchanged)
Same closed header as #130 rev 1.3: wordmark · family switcher · **Stories** · **Draft Stories** · search icon · New story · avatar. Invite stays in the family menu. On Landing, **Stories is not underlined** (timeline is elsewhere) — still stands from prior UI Q1. Written #130 rules win over mock quirks.

### Rule 2 — Hero family photo (16:9)
Full-bleed-within-content (max width of page column, **16:9**, rounded 12px, parchment behind). Photo set → dedicated family photo. Unset → placeholder: soft parchment panel + family monogram (M10: first letter, skip “The”) + quiet ink caption. Owner/co-owner: **Add a family photo**; members: monogram only, no CTA.

### Rule 3 — One shelf: Latest (past 7 days)
Vertical scroll under the hero, parchment page:
1. **Latest** — up to 3 stories **added** (published into the family) in the **past 7 days**, newest first. Quiet subcopy under the shelf title: **Added in the past 7 days.**

No Featured. No Oldest. No drag-reorder. Fewer than 3 matching → show what exists; zero → empty shelf copy (Rule 5).

### Rule 4 — Story card
Horizontal row of up to 3 cards. Each: cover thumb (first story photo or parchment blank) · saved title (2-line max, then ellipsis; no invented “Untitled”) · recorded-event year/precision line. **Tap → story reader** (Q6). Empty slot: do not render a ghost card.

### Rule 5 — Empty week
Shelf empty copy: **No stories added in the past 7 days.** Landing still shows (hero/placeholder). **View all stories** remains visible so members can reach the full timeline.

### Rule 6 — Owner/co-owner chrome (hero only)
- Photo: always-visible overlay edit affordance (Material `photo_camera` or `edit`) top-right of hero → upload/replace/remove.
- **No** Featured Edit. **No** Choose featured stories control or modal.
- Members never see camera/edit on the hero.

### Rule 7 — Path to timeline (Q6)
Terracotta text link **View all stories** under the Latest shelf (and visible in empty-week state) → timeline. Header **Stories** also → timeline. Do not invent a second timeline UI.

### Rule 8 — Family photo flow
Owner/co-owner file pick → preview → Save / Cancel. Replace overwrites. Remove photo returns to placeholder (owner/co-owner only).

## Copy (locked defaults)

| Spot | Copy |
|------|------|
| Shelf title | Latest |
| Shelf subcopy | Added in the past 7 days. |
| Empty week | No stories added in the past 7 days. |
| Photo placeholder (owner) | Add a family photo |
| Timeline CTA | View all stories |

## Locked UI decisions

1. **Header active on Landing** (~10:51 AM CT): Stories un-underlined on Landing; underlined on timeline.
2. **Hero aspect** (~10:53 AM CT): **16:9** wide banner.
3. **Shelves (amended ~11:24 AM CT / Q3b):** Latest 3 in past 7 days only — **no** Featured, **no** Oldest.
4. **Owner customize (amended ~11:24 AM CT):** Hero image only.
5. **Card density** (~10:58 AM CT): Thumb + title + year.
6. **Timeline nav (Q6 ~11:26 AM CT):** Header Stories primary + Landing **View all stories** CTA; cards open the story.

No open UI questions.

## Stitch screens

Project: `12192342757314667328`  
Written rules win over mock quirks. Use `?node-id=` deep links. Rev 1.x Featured keepers are **obsolete** — do not build from them.

| Id | Description | Screen id | Link |
|----|-------------|-----------|------|
| A | Landing populated (7d) | `74836d3845d643e09f580655ce517c26` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=74836d3845d643e09f580655ce517c26 |
| B | Landing empty week | `b784ce7d81424a0ab72cd016443a76c5` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=b784ce7d81424a0ab72cd016443a76c5 |
| C | Landing owner chrome | `117c4a9f346b4d32aa70f4e0835a7d19` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=117c4a9f346b4d32aa70f4e0835a7d19 |

## Hand-off

LOCKED Rev 2.0 after Stitch IDs filled. Erlich opens docs PR for `docs/ux/79-family-landing.md`. Gilfoyle starts SAD after docs land / Bill go.
