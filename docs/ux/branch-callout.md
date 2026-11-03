# Branch callout: Decades, Years and Days timeline views (UX LOCKED)

Status: **LOCKED** rev **1.1**. Locked 2026-11-03 by Bill in his 1:1 with Mugatu (approach ok'd on Decades; Decades v3, Years v1 and Days v1 screens locked ~2:42 PM CT America/Chicago). Written rules win over mock quirks.
Delta baseline (main @ `016e3a1`): `docs/ux/uxd-handoff.md` (M12, M12 Related families menu, M11a), `docs/ux/80-all-stories.md` rev 1.2.
Lane: 2 (UI change). UX delta only. Covers how a branch (a story that started another family's timeline) is marked on the timeline. Does **not** reopen zoom behavior (R3/M12/M13), the reader (M9/#153), the #130 header, All Stories (#80), or M11b creation.

Tokens: parchment `#FBF7F2`, ink `#2C2416`, terracotta `#8B5E4B`, sage `#7A8B74`, albumDialogSurface `#FFF8F6`. **New:** `branchMoss` `#5B7F3A`, one token (named by Bill's call, rev 1.1). Fonts: Newsreader (headings), Source Sans 3 (UI). Material icons only.

## Purpose

Replace the floating sage caption and the dashed hollow ring (M12/M11a) with a **branch callout** tied to the story that started the branch. The callout is a green ring on that story's rail dot, a leader line, and a `Family name · year` label. On Years and Days it also gives the story's card a green border. The branch then reads as part of the story, not as a separate mark floating on the rail.

## Rules

### Rule 1: Ring
- A hollow ring in `branchMoss` (`#5B7F3A`), ~2px stroke, around the **branching story's own rail dot**. The dot keeps its normal terracotta look inside the ring, with a small parchment gap between them.
- The grey rail continues behind the ring and dot without a break.
- There is no separate mark on the rail for the branch: no dashed circle, no parchment disc, no second dot.

### Rule 2: Leader line
- Same green, ~2px stroke. It is the same thin weight in every view, never heavier.
- Starts at the ring's **lower-right** outer edge with a ~2px parchment gap. It **never overlaps or enters the ring**.
- Runs **diagonally down-right**, then turns **horizontal** to the right.

### Rule 3: Label
- Copy: `{Family name} · {year}`, e.g. `The WFM Morgans · 1995`. The year is the branch year, same format as M12 (no "Est.", no tilde). When there's no branch year, the label is the family name alone. This keeps M12's no-year rule; flag if Bill wants it otherwise.
- Same green, Source Sans 3, medium (500).
- Attached at the **end of the horizontal run**, vertically centered on the line, with a small gap after the line end. It never floats on its own.
- There is no box, fill or shadow behind the label (no ghost box).

### Rule 4: One green
- The ring, line, label and (on Years and Days) card border all use the **same** branch-green token. No sage, no terracotta and no second green in the callout.

### Rule 5: Removed
- The dashed circle at the top of the rail or beside the dot.
- The ghost box or panel behind the label.
- The terracotta nub where the line met the card. **The line never touches the card.**
- The floating sage caption.

### Rule 6: Tap target
- The **ring and the label** open the branch family's timeline (read), the same destination as the M12 mark tap. This was Mugatu's recommendation, accepted by Bill as part of the approach.
- The line itself is not a separate target. The card keeps its normal behavior (it opens the story, not the branch).
- The hit area is ≥ 44×44px around the ring and covers the whole label.
- Accessible name: `Open {Family name} timeline`. It is a button. Its state is not shown by color alone, because the label carries the family name.

### Rule 7: Per view
- **Decades:** the ring goes on the story's dot in its decade row. The callout runs to the label. **No card.**
- **Years:** the label sits on the line. The story's compact card sits **directly below the label**, left-aligned with where the label starts, so line, label and card read as one unit.
  - The card has a thin green border, rounded corners and a light parchment fill.
  - It keeps its terracotta date chip, place, `1 photo` meta and serif title.
  - It stays on its **zigzag side** (alternating left/right) with the same vertical spacing as the other stories.
  - Plain (non-branching) stories are unchanged.
- **Days:** same as Years, with the **expanded** card.
  - The card keeps its terracotta date and neutral meta pills (people, place).
  - It must **fit within the page width**. Meta pills and footer (`Added by …`, `{n} photo · {n} note`) are **never clipped**.

## Supersedes (do not edit those docs here; Erlich applies)

| File | Section | What this replaces |
|------|---------|--------------------|
| `docs/ux/uxd-handoff.md` | `## M12 — timeline branch marks (UX locked 2026-10-06)` | "Dashed sage hollow rings are marks (not stories)", plus the Macro/Mid/Full Cards branch-mark screens (`a6259996…`, `5a0fa594…`, `974665eb…`): forks, hollow-ring pills, and ring markers *between* cards. The branch is now a callout on the story's own dot. The mark-opens-related-timeline behavior is kept (Rule 6). |
| `docs/ux/uxd-handoff.md` | `## M12 Related families menu (LOCKED Bill 2026-10-10)`, the "Timeline marks (…)" paragraph | "hollow sage ring with the family name as its label". The `Name · year` copy and no-year handling are kept. Color and shape are replaced. |
| `docs/ux/uxd-handoff.md` | `## M11a — origin stories (LOCKED Bill 2026-10-11)` → `### Build rules (these override the mocks)` | "origin story keeps its own dot … with the ring beside it" (the ring now goes around the dot), "Ring labels go on the empty side of the rail", "On Full Cards the ring label sits on the side … away from the origin card", and "Ring tokens are unchanged from M12: 16px dashed sage hollow ring …". |

Not superseded, flagged for consistency (Bill or Mugatu to decide; out of this lock):
- `docs/ux/uxd-handoff.md` M11a build rules, the "**M11a narrow Full Cards**" bullet: the *parent* ring shown in a child family's timeline. These screens don't cover that case.
- `docs/ux/80-all-stories.md` header Tokens line ("Branch ring (M12/M11a): 16px dashed sage hollow ring …"), `### Rule 6` 6a (dashed ring on the cover photo) and 6c (dashed-ring glyph on the toggle). All Stories is a different surface, and those still use the M12 ring.

## Out of scope

Zoom behavior and view switching; the header; reader; All Stories; creating a branch (M11b); data for branch year.

## Open UI questions

None. Resolved in rev 1.1 (Bill, 2026-11-03 ~2:45 PM CT):

1. **Callout collision: closed, no special rule.** Stories alternate sides of the rail, so callouts rarely collide. Each callout follows its story's side.
2. **Token name: `branchMoss` = `#5B7F3A`.** One token, used by the ring, line, label and card border.

## Stitch screens

Project: `12192342757314667328` (Tell Me a Story). Design system: `assets/18104844965535020843` (Memory Album). DESKTOP 2560px (1280 @2x). Use `?node-id=` links.

| View | Screen id | Link | Local PNG (box) |
|------|-----------|------|-----------------|
| Decades | `f6faa8e35b804886afd190d16dfca418` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=f6faa8e35b804886afd190d16dfca418 | `/workspace/branch-redesign/decades-v3.png` (`decades-v3.sm.png`, `decades-v3_zoom.png`) |
| Years | `1cb7dced96a8469d9466e7bb8156d772` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=1cb7dced96a8469d9466e7bb8156d772 | `/workspace/branch-redesign/years-v1.png` (`years-v1.sm.png`, `years-v1_zoom.png`) |
| Days | `d038c69b083e4a0da7663ae89d3fc12d` | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=d038c69b083e4a0da7663ae89d3fc12d | `/workspace/branch-redesign/days-v1.png` (`days-v1.sm.png`, `days-v1_zoom.png`) |

Mock quirks (written rules win):
- All: names, places and counts are filler. **Placeholder content is not part of the design:** the Days wedding photo (it reads modern rather than 1990s) and the Years `May 2016 · Amherst` chip on "David Graduates College" (not in Bill's concept).
- Decades: rings sit mid-row, count text is small, and the lower canvas is empty. Only the callout is the reference.
- Years and Days: the empty parchment above, below and around the rail is canvas, not spacing.

## Hand-off

LOCKED rev 1.0. Erlich applies the supersede notes to the listed docs (Mugatu does not edit them). No open UI questions.

Change log: rev 1.0 (2026-11-03, ~2:42 PM CT): first locked rev, by Bill in his 1:1 with Mugatu. Branch callout replaces the M12/M11a dashed sage ring and floating caption across Decades/Years/Days. Screens: Decades v3, Years v1, Days v1.
rev 1.1 (2026-11-03, ~2:45 PM CT): Bill closed both open questions. Collision needs no special rule because stories alternate sides, and the token is `branchMoss` `#5B7F3A`. Lane corrected to 2.
