# Branch callout: Decades, Years and Days timeline views (UX LOCKED)

Status: **LOCKED** rev **1.5** (2026-11-05, ~11:19 AM CT; open questions closed ~11:49 AM CT), per Bill via Erlich. Matches PR #164 @ `17f7345` as built, except where noted (no glow anywhere, Rule 1; the Rule 8 / Rule 7 parent-origin card chrome and glow-guard restore in the Dev note).
Prior status: **LOCKED** rev **1.3** (2026-11-03, ~6:31 PM CT). Rev 1.3 locked by Bill, relayed verbatim by Erlich ("Drop the parent ring too, no dashes anywhere"; "Park the two-callout case for now"). Rev 1.2 scope calls locked by Bill via Erlich ~6:10 PM CT ("i dont want the dashes or glow"; "the branch dot should end up being the last dot"). Rev 1.0/1.1 locked 2026-11-03 by Bill in his 1:1 with Mugatu (approach ok'd on Decades; Decades v3, Years v1 and Days v1 screens locked ~2:42 PM CT America/Chicago). Written rules win over mock quirks.
Delta baseline (main @ `016e3a1`): `docs/ux/uxd-handoff.md` (M12, M12 Related families menu, M11a), `docs/ux/80-all-stories.md` rev 1.2.
Lane: 2 (UI change). UX delta only. Covers how a branch (a story that started another family's timeline) is marked on the timeline. Does **not** reopen zoom behavior (R3/M12/M13), the reader (M9/#153), the #130 header, All Stories (#80), or M11b creation.

Tokens: parchment `#FBF7F2`, ink `#2C2416`, terracotta `#8B5E4B`, sage `#7A8B74`, albumDialogSurface `#FFF8F6`. **New:** `branchMoss` `#5B7F3A`, one token (named by Bill's call, rev 1.1). Fonts: Newsreader (headings), Source Sans 3 (UI). Material icons only.

## Purpose

Replace the floating sage caption and the dashed hollow ring (M12/M11a) with a **branch callout** tied to the story that started the branch. The callout is a green ring on that story's rail dot, a leader line, and a `{Family name} Branch` label (rev 1.5). On Years and Days it also gives the story's card a green border. The branch then reads as part of the story, not as a separate mark floating on the rail.

## Rules

### Who gets a callout
- Only a **direct child family whose origin story is on this rail** gets the branch callout, on that origin story.
- Every other related family (no origin story, an unpublished origin story, siblings, grandchildren, others) gets **no mark on the rail**: no dashed ring, no callout. They stay reachable from the M12 Related families menu.
- **Rev 1.5:** the **parent family** gets a **parent callout** in a child family's timeline, on the child family's own origin story, when that story is published on this rail (Rule 8). It replaces the rev 1.3 "parent gets no rail mark" rule. The parent stays reachable from the M12 Related families menu as well.
- So the only branch marks on any timeline rail are the child branch callout and the parent callout. There are **no dashed rings** on Decades, Years or Days.

### Rule 1: Ring
- A hollow ring in `branchMoss` (`#5B7F3A`), ~2px stroke, around the **branching story's own rail dot**. The dot keeps its normal terracotta look inside the ring, with a small parchment gap between them.
- The grey rail continues behind the ring and dot without a break.
- There is no separate mark on the rail for the branch: no dashed circle, no parchment disc, no second dot.
- **No glow or halo** on the branching story's dot or card in any view, including when it is focused or centered. Nothing covers the green ring.
- **Rev 1.5:** this applies to **every** branch dot and card, parent and child, including the origin story's dot under a parent callout (Rule 8). No glow anywhere.

### Rule 2: Leader line
- Same green, ~2px stroke. It is the same thin weight in every view, never heavier.
- Starts at the ring's **lower-right** outer edge with a ~2px parchment gap. It **never overlaps or enters the ring**.
- Runs **diagonally down-right** at **45°**, then turns **horizontal** to the right. The horizontal run is visible and **at least 24px** long before the label gap.
- On a **left-side** story the callout mirrors: it starts at the ring's lower-left edge, runs diagonally down-left at 45°, then goes horizontal to the left, with the label at its end.
- The ring's tap target (Rule 6) sits **above** the dot's own tap target, so a tap on the ring always opens the branch.

### Rule 3: Label
- Copy (**rev 1.5**): `{Family name} Branch`, e.g. `The WFM Morgans Branch`. The year is dropped, whether or not the family has a branch year. The same copy is used for child and parent callouts. (Rev 1.3 copy `{Family name} · {year}` is superseded.)
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
  - The branching dot and its label **always come last in the decade row**, so the label never pushes other dots aside. The dot stays vertically aligned with the other dots in the row.
- **Years:** the label sits on the line. The story's compact card sits **directly below the label**, left-aligned with where the label starts, so line, label and card read as one unit.
  - The card has a thin green border, rounded corners and a light parchment fill.
  - It keeps its terracotta date chip, place, `1 photo` meta and serif title.
  - It stays on its **zigzag side** (alternating left/right) with the same vertical spacing as the other stories.
  - Plain (non-branching) stories are unchanged.
  - When the story is focused or centered there is **no glow or halo** and no terracotta border. Only the green border shows. Years and Days behave the same.
- **Days:** same as Years, with the **expanded** card.
  - The card keeps its terracotta date and neutral meta pills (people, place).
  - It must **fit within the page width**. Meta pills and footer (`Added by …`, `{n} photo · {n} note`) are **never clipped**.

### Rule 8: Parent callout (rev 1.5, locked as built in #164)
- **Who:** when the open family has a parent family in the tree and its own origin story is published on this rail, that origin story gets one parent callout naming the parent. If the parent is already a child callout on that story, no parent callout is added. If the parent row is missing from the tree, there is no parent callout.
- **Copy and type:** `{Parent name} Branch` (Rule 3), `branchMoss`, Source Sans 3 medium (500). Single line, end ellipsis. Size: Decades uses the same label size as the child callout (theme label style), Years uses 16px and Days uses 20px.
- **Leader:** same green, ~2px stroke. It runs **up** at 45°, then turns horizontal, with the label at the end of the horizontal run and vertically centered on it. The horizontal run is at least 24px, with a 6px gap before the label. Rule 2's down-right shape is mirrored upward.
- **Decades:** the leader leaves the **upper-right** 45° point of the ring (2px gap), with a 16px diagonal, and always runs to the right. The origin dot gets the moss ring (Rule 1 ring sizes). There is no caption. The dot's tooltip reads `{title} · Origin ({date})`. Like a child callout, the dot goes **last in its decade row** and stays level with the other dots. An origin dot with no callout of either kind still gets the moss ring on Decades, and no glow.
- **Years:** there is **no ring**. The leader starts 2px above the **top center of the card**, rises at 45° for 24px (16px plus an 8px lift), then runs horizontally out to the **card's side** (left for a left card, right for a right card). The label is 16px.
- **Days:** there is **no ring**. The leader starts 2px above the top center of the story card as painted (it follows the focus scale), rises at 45° for 16px, then runs horizontally to the card's side on wide screens and to the right on narrow screens. The label is 20px.
- **Tap and keyboard:** the **label** opens the parent family's timeline, with accessible name `Open {Parent name} timeline` as a button. Its hit height is at least 44px. On Decades the ring is not a separate target: a tap on the dot opens the story. The line is not a target. The card keeps its normal behavior (it opens the story).
- **No glow (Bill, rev 1.5):** no glow or halo on the origin dot or card, in any view or state (Rule 1).
- **Focused Years / Days card (Bill ~11:49 AM CT):** when the parent-origin story is focused or centered, the card uses a **`branchMoss` border** (same as a child branch card, Rule 7), **no 1.05 scale**, and **no shadow** (no glow). This supersedes the terracotta + 1.05 treatment that #164 still builds for a parent-only story (`branched` is `frame.branchesStory`, which is false when there is no child callout).
- **Dev note (PR #164 @ `17f7345`, must change):**
  1. Restore a glow guard at `timeline_page.dart:1500` so no branch dot, parent or child, glows. The current `boxShadow: highlighted` reaches the parent origin through `_farParent` (`:1307`) and the child branch through `_farBranch` (`:1336`).
  2. Treat a focused parent-origin story like a branch card on Years and Days: `branchMoss` border, scale 1, no shadow. Today a parent-only story still takes the plain focused paths (Years card `timeline_page.dart:2064-2080`, Days scale around `:3097` / `:2582`-equivalent, Days dot `:3328`, Days card `:3393`).

## Supersedes (do not edit those docs here; Erlich applies)

| File | Section | What this replaces |
|------|---------|--------------------|
| `docs/ux/uxd-handoff.md` | `## M12 — timeline branch marks (UX locked 2026-10-06)` | "Dashed sage hollow rings are marks (not stories)", plus the Macro/Mid/Full Cards branch-mark screens (`a6259996…`, `5a0fa594…`, `974665eb…`): forks, hollow-ring pills, and ring markers *between* cards. The branch is now a callout on the story's own dot. The mark-opens-related-timeline behavior is kept only through the callout (Rule 6). Related families without a callout get no rail mark (see Who gets a callout). |
| `docs/ux/uxd-handoff.md` | `## M12 Related families menu (LOCKED Bill 2026-10-10)`, the "Timeline marks (…)" paragraph | "hollow sage ring with the family name as its label". Color and shape are replaced. Rev 1.5: the copy is now `{Family name} Branch` (Rule 3), so the `Name · year` copy and no-year handling no longer apply. |
| `docs/ux/uxd-handoff.md` | M11a build rules, the "**M11a narrow Full Cards**" bullet | The *parent* ring in a child family's timeline is replaced by the rev 1.5 **parent callout** (Rule 8). The parent is still reachable from the Related families menu. |
| `docs/ux/uxd-handoff.md` | `## M11a — origin stories (LOCKED Bill 2026-10-11)` → `### Build rules (these override the mocks)` | "origin story keeps its own dot … with the ring beside it" (the ring now goes around the dot), "Ring labels go on the empty side of the rail", "On Full Cards the ring label sits on the side … away from the origin card", and "Ring tokens are unchanged from M12: 16px dashed sage hollow ring …". |

Not superseded, flagged for consistency (Bill or Mugatu to decide; out of this lock):
- ~~`docs/ux/80-all-stories.md` header Tokens line / Rule 6a cover ring / 6c toggle glyph~~ — **resolved in #80 rev 1.4** (Bill ~11:49 AM CT): cover ring and toggle glyph removed; people pills behind Members. Not a timeline concern.

## Out of scope

Zoom behavior and view switching; the header; reader; All Stories; creating a branch (M11b); data for branch year.

## Open UI questions

None.

Parked (Bill, 2026-11-03 ~6:31 PM CT, "Park the two-callout case for now"): **two callouts on one story** is not designed. Builds do not need to design for it. Whatever the current code does in that case is acceptable for now, and it is not a UX-match finding.

Resolved in rev 1.1 (Bill, 2026-11-03 ~2:45 PM CT):

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
- Decades: rings sit mid-row (overridden: the branching dot comes last in its row, per Rule 7), count text is small, and the lower canvas is empty. Only the callout is the reference.
- Years and Days: the empty parchment above, below and around the rail is canvas, not spacing.

## Hand-off

LOCKED rev 1.5 (Bill via Erlich, 2026-11-05 ~11:19 AM CT; open questions closed ~11:49 AM CT). It matches PR #164 @ `17f7345` as built, except for the Dev note (glow guard + parent-origin moss border / no 1.05 / no shadow). Erlich applies the supersede notes to the listed docs (Mugatu does not edit them). No open UI questions; two callouts on one story is still parked.

Change log: rev 1.0 (2026-11-03, ~2:42 PM CT): first locked rev, by Bill in his 1:1 with Mugatu. Branch callout replaces the M12/M11a dashed sage ring and floating caption across Decades/Years/Days. Screens: Decades v3, Years v1, Days v1.
rev 1.1 (2026-11-03, ~2:45 PM CT): Bill closed both open questions. Collision needs no special rule because stories alternate sides, and the token is `branchMoss` `#5B7F3A`. Lane corrected to 2.
rev 1.2 (2026-11-03, ~6:10 PM CT, Bill via Erlich): who gets a callout (direct child with its origin story on this rail); every other related family gets no rail mark (no dashes); the parent ring stays as built. No glow or halo on branch dots or cards in any view, green border only. Decades: the branching dot and label always come last in the row. Left-side callouts mirror. Rule 2 now states a 45° diagonal, a horizontal run of at least 24px, and a ring tap target above the dot's. Two callouts on one story added as an open question. Hand-off line corrected from rev 1.0.

rev 1.3 (2026-11-03, ~6:31 PM CT, Bill via Erlich): parent ring removed, so the parent family gets no rail mark in a child timeline (reachable from the Related families menu) and there are no dashed rings on any timeline rail. The M11a narrow Full Cards parent-ring bullet moves from flagged to superseded. Two callouts on one story is parked, not designed, and no longer an open question. (Rev 1.5 supersedes the parent part: see Rule 8.)

rev 1.5 (2026-11-05, ~11:19 AM CT, Bill via Erlich; open Q closed ~11:49 AM CT): parent callouts on Decades, Years and Days are locked as built in PR #164 @ `17f7345` (Rule 8). This replaces the rev 1.3 "parent gets no rail mark" rule and the parent-ring removal note in Supersedes. The child and parent label is now `{Family name} Branch`, with the year dropped (Rule 3). There is no glow or halo on any branch dot or card, parent or child (Rule 1). Focused parent-origin Years/Days cards use a `branchMoss` border, no 1.05 scale, and no shadow (Rule 8, locked ~11:49 AM CT). The PR must restore the glow guard at `timeline_page.dart:1500` and apply the moss / no-scale / no-shadow card chrome (Rule 8 Dev note). The Decades moss ring on the origin dot stays as built. Rev 1.4 is skipped: that number belongs to a parked, unlocked draft. Source: `timeline_branching.dart:17-24` (constants), `:150-185` (`_parentLink`), `:411-540` (`decadeParentMark`), `:551-645` (`parentCalloutOverlay`), `:700-730` (`_CalloutVisuals` ring); `timeline_zoom.dart:60-65` (`dotTooltip`), `:204-205` (`branchMarkLabel`); `timeline_page.dart:1197-1219` (Decades row order), `:1297-1322` (`_farParent`), `:1336`, `:1440-1467` (`_OriginDot`), `:1500` and `:1513-1516` (dot glow and tooltip), `:2231-2250` (Years), `:3073-3090` (Days); all at `17f7345`.
