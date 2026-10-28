# #79 Family Landing Page (UX LOCKED)

Status: **LOCKED** 2026-10-28 ~3:47 PM CT America/Chicago — Bill via Erlich (Lane 2 CTA polish). Rev **2.1** (amends Rev 2.0 Rule 7 + Timeline CTA copy only). Jared Decisions stamp ~3:27 PM CT: Landing CTA → **View a Timeline of Stories for {Family}**.
sha256: `293e7553774c253ed84ccdf9a083d0613b59a41db9e11f13cfa47be88e94e639`
Source: PRD Family Landing (#79) APPROVED amended: https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2  
Decisions: https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166 · Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/79  
Lane: **2** (UX match only — skip SAD / Spec / Trinity). Does **not** reopen hero, Latest shelf, Featured/Oldest, or #130 header chrome.

Tokens (album_theme): parchment `#FBF7F2`, terracotta `#8B5E4B`, sage `#7A8B74`, ink `#2C2416`, albumDialogSurface `#FFF8F6`. Fonts: Newsreader (headings/wordmark), Source Sans 3 (UI). Material icons only.

## Primary user / JTBD

A family member opening their family — land on a family “face” (hero photo + recent stories) before the chronological Stories timeline, with a clear prominent path into the timeline via header **Stories** and Landing timeline CTA.

## Pack locks (product — amended — do not invent)

1. Opening a family → **Family Landing**. Header **Stories** → timeline. Landing links there.
2. Owner + co-owners customize = **hero image only** (same admin who as other family admin).
3. Dedicated family/hero photo upload by owner/co-owners; placeholder until set.
4. **One shelf only:** latest **3** stories **added in the past 7 days**. No Featured. No Oldest. No curated picks. No Choose featured modal.
5. Header **Stories** stays primary; Landing has clear timeline CTA; story cards open the story.
6. **CTA copy (Jared stamp ~3:27 PM CT):** `View a Timeline of Stories for {Family}` (`{Family}` = current header family display name).

Out of scope: public family pages; timeline redesign; Manage Families hub; Featured/Oldest/shelf builder; owner-curated story picks; SAD/Spec/Trinity for this polish.

## Screen map

| Id | Screen | Who |
|----|--------|-----|
| A | Landing — populated (hero + up to 3 latest-7d cards + timeline CTA pill) | Any member |
| B | Landing — empty week (hero or placeholder; zero stories in past 7 days + timeline CTA pill) | Any member |
| C | Landing — owner/co-owner chrome (camera on hero only + timeline CTA pill) | Owner / co-owner |

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
Horizontal row of up to 3 cards. Each: cover thumb (first story photo or parchment blank) · saved title (2-line max, then ellipsis; no invented “Untitled”) · recorded-event year/precision line. **Tap → story reader**. Empty slot: do not render a ghost card.

### Rule 5 — Empty week
Shelf empty copy: **No stories added in the past 7 days.** Landing still shows (hero/placeholder). Timeline CTA (Rule 7′) remains visible so members can reach the full timeline.

### Rule 6 — Owner/co-owner chrome (hero only)
- Photo: always-visible overlay edit affordance (Material `photo_camera` or `edit`) top-right of hero → upload/replace/remove.
- **No** Featured Edit. **No** Choose featured stories control or modal.
- Members never see camera/edit on the hero.

### Rule 7′ — Path to timeline (CTA polish — Lane 2)

Replace the terracotta text link with a **centered** terracotta stadium **FilledButton** under the Latest shelf (same vertical slot; empty-week still shows it).

**Match header New story pill treatment:**
- Fill: `albumTerracotta` / `#8B5E4B`
- Label color: parchment / on-terracotta
- Shape: `StadiumBorder` (pill)
- Soft elevation ~1
- Horizontal/vertical padding in the New-story family (≈16×10)
- **No** plus icon (this is not create)

**Larger type** than header New story (~14): Landing CTA uses Source Sans 3 **18 / w600** so it reads as the primary path to the full timeline.

**Copy (Jared stamped):** `View a Timeline of Stories for {Family}` with live family display name from the header switcher.

**Long names:** single line, end ellipsis; full string in tooltip/semantics (same spirit as #130 family-name rule).

**Alignment:** horizontally centered in the content column.

Route/behavior unchanged: tap → existing timeline (`AppRoutes.timeline`). Header **Stories** still primary nav; cards still open the story reader. Key stays `family-landing-view-all`.

### Rule 8 — Family photo flow
Owner/co-owner file pick → preview → Save / Cancel. Replace overwrites. Remove photo returns to placeholder (owner/co-owner only).

## Copy (locked)

| Spot | Copy |
|------|------|
| Shelf title | Latest |
| Shelf subcopy | Added in the past 7 days. |
| Empty week | No stories added in the past 7 days. |
| Photo placeholder (owner) | Add a family photo |
| Timeline CTA | View a Timeline of Stories for {Family} *(Jared Decisions ~3:27 PM CT)* |

Supersedes Rev 2.0 **View all stories** for this control only.

## Locked UI decisions

1. **Header active on Landing** (~10:51 AM CT): Stories un-underlined on Landing; underlined on timeline.
2. **Hero aspect** (~10:53 AM CT): **16:9** wide banner.
3. **Shelves (amended ~11:24 AM CT / Q3b):** Latest 3 in past 7 days only — **no** Featured, **no** Oldest.
4. **Owner customize (amended ~11:24 AM CT):** Hero image only.
5. **Card density** (~10:58 AM CT): Thumb + title + year.
6. **Timeline nav (Q6 ~11:26 AM CT):** Header Stories primary + Landing timeline CTA; cards open the story.
7. **CTA polish (Lane 2 ~3:27–3:32 PM CT):** Jared-stamped copy; centered; New-story-matching terracotta stadium pill; larger type (18/w600).

No open UI questions.

## Stitch screens

Project: `12192342757314667328`  
Written rules win over mock quirks. Use `?node-id=` deep links. Rev 2.0 keepers are **obsolete for the CTA** — build from Rev 2.1 keepers below.

| Id | Description | Screen id | Link |
|----|-------------|-----------|------|
| A | Landing populated + CTA pill | `8b079c3bb1934bb1bd81bd2258241c2a` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=8b079c3bb1934bb1bd81bd2258241c2a |
| B | Landing empty week + CTA pill | `4bef8c8ee0a94ff09335bd3f3000dd4f` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=4bef8c8ee0a94ff09335bd3f3000dd4f |
| C | Landing owner chrome + CTA pill | `f5f4498bed9d4de1a20490b007822d18` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=f5f4498bed9d4de1a20490b007822d18 |

## Hand-off

**LOCKED** Rev 2.1 — Stitch A/B/C filled 2026-10-28 ~3:47 PM CT. Erlich opens docs PR for `docs/ux/79-family-landing.md`. Lane 2 → coding (skip SAD / Spec / Trinity). Erlich routes coding.
