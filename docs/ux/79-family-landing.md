# #79 Family Landing Page (UX LOCKED)

Status: **LOCKED** 2026-10-28 ~10:58 AM CT America/Chicago — Bill via Erlich (UI Qs 1–5 + Stitch A–D keepers). Rev 1.0.
sha256: `e8ee40a0d6e291be4879eebfcef9d97c991a81b865033da69730cc4fcbb97304`
Source: PRD Family Landing (#79) APPROVED 2026-10-28 ~10:47 AM CT (Bill via Erlich): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2  
Decisions: https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166 · Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/79  
Lane: 3 (full path). Amends: family home after open/switch (was timeline). Does **not** reopen #130 header chrome rules, timeline redesign, Manage Families hub, or public family pages.

Tokens (album_theme): parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`, albumDialogSurface `#FFF8F6`. Fonts: Newsreader (headings/wordmark), Source Sans 3 (UI). Material icons only.

## Primary user / JTBD

A family member opening their family — land on a family “face” (photo + story highlights) before the chronological Stories timeline, with a clear path into the timeline via header **Stories** and on-page Landing links.

## Pack locks (product — do not invent)

1. Opening a family (default home / family switch) → **Family Landing**. Header **Stories** → timeline. Landing links → timeline.
2. Owner + co-owners customize (same as other family admin). Members view only.
3. Featured = owner/co-owner curated picks; empty until they pick.
4. Dedicated family photo upload by owner/co-owners; placeholder until set.
5. Same ship: photo + curated featured + fixed latest 3 + fixed oldest 3; **no** further shelf reconfiguration.

Out of scope: public family pages; timeline redesign; Manage Families hub; open-ended shelf builder.

## Screen map

| Id | Screen | Who |
|----|--------|-----|
| A | Landing — populated (photo + featured + latest + oldest) | Any member |
| B | Landing — empty/placeholder (no photo, empty featured, thin latest/oldest or empty) | Any member |
| C | Landing — owner/co-owner chrome (edit photo + edit featured) | Owner / co-owner |
| D | Choose featured stories (modal) | Owner / co-owner |
| E | Family photo picker / crop confirm (simple) | Owner / co-owner |

Route: Family Landing is the default after open/switch for the current family. Header Stories navigates to existing timeline. Wordmark stays brand (not a second home control unless Q locks it).

## Layout rules (LOCKED)

### Rule 1 — Shared header (#130 chrome unchanged)
Same closed header as #130 rev 1.3: wordmark · family switcher · **Stories** · **Draft Stories** · search icon · New story · avatar. Invite stays in the family menu. On Landing, **Stories is not underlined** (timeline is elsewhere) — **LOCKED** Bill via Erlich ~10:51 AM CT. Written #130 rules win over mock quirks.

### Rule 2 — Hero family photo
Full-bleed-within-content (max width of page column, **16:9 LOCKED**, rounded 12px, parchment behind). Photo set → shows dedicated family photo. Unset → placeholder: soft parchment panel + family monogram (M10 rule: first letter, skip “The”) + quiet ink caption. Owner/co-owner: caption/CTA **Add a family photo**; members: monogram only, no CTA.

### Rule 3 — Three fixed shelves (order locked)
Vertical scroll under the hero, parchment page:
1. **Featured** — curated; up to 3 cards; empty state until picks.
2. **Latest** — fixed newest 3 published stories for current family (auto).
3. **Oldest** — fixed oldest 3 published stories for current family (auto).

No drag-reorder of shelves. No “add shelf.” Fewer than 3 published → show what exists; zero → empty shelf copy.

### Rule 4 — Story card (shelf tile)
Horizontal row of up to 3 cards. Each card: cover thumb (first story photo or parchment blank) · saved title (2-line max, then ellipsis; no invented “Untitled”) · recorded-event year/precision line — **LOCKED** thumb+title+year. Tap → existing story reader. Empty slot: do not render a ghost card.

### Rule 5 — Empty Featured
Members: “No featured stories yet.” Owner/co-owner: same + terracotta text button **Choose featured stories** (opens D).

### Rule 6 — Owner/co-owner chrome only (**LOCKED** Bill via Erlich ~10:57 AM CT)
- Photo: always-visible overlay edit affordance (Material `photo_camera` or `edit`) top-right of hero → upload/replace.
- Featured shelf: always-visible trailing text control **Edit** → same picker D.
- Members never see edit/camera/Choose controls. No single Customize gate.

### Rule 7 — Path to timeline
Under shelves (and/or after hero): terracotta text link **Browse all stories** → timeline. Header **Stories** also → timeline. Do not invent a second timeline UI.

### Rule 8 — Latest / Oldest empty
If the family has no published stories: both shelves show “No published stories yet.” Featured stays its own empty. Landing still shows (photo/placeholder).

### Rule 9 — Featured picker (D)
Modal over Landing (`albumDialogSurface`). Title **Choose featured stories**. List current family’s published stories (title + year); multi-select up to **3**; Save / Cancel. Cannot pick drafts. Order in the shelf = pick order (first selected leftmost). Clearing all → empty Featured.

### Rule 10 — Family photo (E)
Owner/co-owner file pick → preview → Save / Cancel. Replace overwrites. Remove photo returns to placeholder (owner/co-owner only).

## Copy (locked defaults)

| Spot | Copy |
|------|------|
| Featured empty (member) | No featured stories yet. |
| Featured empty (owner) | No featured stories yet. · Choose featured stories |
| Latest empty | No published stories yet. |
| Oldest empty | No published stories yet. |
| Photo placeholder (owner) | Add a family photo |
| Timeline link | Browse all stories |
| Picker title | Choose featured stories |

## Locked UI decisions

1. **Header active on Landing** (Bill via Erlich ~10:51 AM CT): Stories stays **un-underlined** on Landing; only underlined on the timeline. No Home nav label. No wordmark-as-Home active treatment.
2. **Hero aspect** (Bill via Erlich ~10:53 AM CT): **16:9** wide banner (full content width, rounded 12px).
3. **Featured shelf label** (Bill via Erlich ~10:55 AM CT): **Featured** (not Top stories / Highlights). Cap remains up to 3 curated picks.
4. **Owner edit chrome** (Bill via Erlich ~10:57 AM CT): Always-visible camera affordance on the hero + **Edit** on the Featured shelf. Members never see either. No single Customize gate.
5. **Shelf card density** (Bill via Erlich ~10:58 AM CT): **Thumb + title + year** on Featured / Latest / Oldest cards (cover thumb or parchment blank · 2-line title max then ellipsis · year/precision line).

No open UI questions.

## Stitch screens

Project: `12192342757314667328`  
Written rules win over mock quirks. Keepers only (ignore asset-only screens Stitch spawned with A).

| Id | Description | Screen id | Link |
|----|-------------|-----------|------|
| A | Landing populated | `f78fc1cdc87641dbb9d8fe1d1e02b51f` | https://stitch.withgoogle.com/projects/12192342757314667328/screen/f78fc1cdc87641dbb9d8fe1d1e02b51f |
| A′ | Landing populated (alt) | `97ef21efde354b01817ca574ccac6061` | https://stitch.withgoogle.com/projects/12192342757314667328/screen/97ef21efde354b01817ca574ccac6061 |
| B | Landing empty/placeholder | `4aaedcc89ec04d92ad14c06065058031` | https://stitch.withgoogle.com/projects/12192342757314667328/screen/4aaedcc89ec04d92ad14c06065058031 |
| C | Landing owner chrome | `bad3c697c4df4db0a68017750f86e89c` | https://stitch.withgoogle.com/projects/12192342757314667328/screen/bad3c697c4df4db0a68017750f86e89c |
| D | Choose featured modal | `f9e77825af3f4ab78e3b605ecb69a6a0` | https://stitch.withgoogle.com/projects/12192342757314667328/screen/f9e77825af3f4ab78e3b605ecb69a6a0 |

## Hand-off

LOCKED. Erlich opens docs PR for `docs/ux/79-family-landing.md`. Gilfoyle starts SAD after docs land / Bill go.
