# #130 Cleanup the Header (UX rev 1.1, LOCKED)

Status: LOCKED 2026-10-27 7:58 PM CT by Bill via Erlich (UI Qs 1–5 + screens A/B). **Amended 2026-10-27 ~9:00 PM CT** — Bill visual correction via Erlich: closed family name is **single-line** with **more room before ellipsis** (supersedes Q1 wrap). Written rules win over mock quirks.
Source: PRD "Cleanup the Header (#130)", APPROVED by Bill 2026-10-27 7:45 PM CT (via Erlich): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2 . Decisions entry 2026-10-27 #130: https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166 . Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/130
Amends: R2 Timeline header; #121 family-menu UX (`docs/ux/121-family-menu.md`) labels and dropdown order; **rev 1.1** Q1/Rule 4 (single-line family name + more flex before ellipsis). #82 switch rules, invite flow, search screen, wordmark, profile menu, and reader header are unchanged.
UI only. No membership, invite-rule, or search-filter change.

## What changes today
| Today (post-#121 / main) | #130 |
|---|---|
| Header right: search pill + Invite + New story + avatar | Invite leaves the header. Right: magnifying-glass icon only, then New story, then avatar |
| Nav labels "Timeline" / "Drafts" | "Stories" / "Draft Stories" (routes/behavior unchanged) |
| Closed family switcher truncates long names | Closed switcher: **single line**; grows to take remaining room left of the right cluster; ellipsis only when that space runs out; full name in tooltip/semantics |
| Dropdown: nested families → divider → "Add a timeline branch to {Family}" → Manage families | Nested families → divider → **"Invite a family member to {family}"** → **"Add a family branch to {Family}"** (when shown) → Manage families |
| Branch labels use "timeline branch" | Menu/dialog: "Add a family branch to {Family}"; reader: "Add a family branch from this story" |
| Manage Families dropdown missing add-branch | Same dropdown everywhere the menu appears, including Manage Families (include add-branch when it applies) |
| Sage vertical guide can overshoot the divider (issue shot) | Guide stops at the last nested child; never crosses the divider into action rows |

## Rule 1: Invite leaves the header right
- Remove the Invite control from the shared R2 header right side (timeline/Stories, drafts/Draft Stories, new story, Manage families — every page that uses the shared bar).
- Invite is now a family-dropdown action row only. Same invite flow as today (dialog/tabs unchanged). Any member who can invite today still can.
- Exact label: **"Invite a family member to {family}"**, where `{family}` is the current family name as stored. Single line; when it doesn't fit, the whole label truncates at the end with an ellipsis. Full label in the row's tooltip/semantics.
- Leading icon: sage Material `Icons.person_add_outlined` (19px), same `_menuRow` chrome as other action rows.

## Rule 2: Branch labels (amends #121 Rule 3)
- Dropdown item + create-dialog title: **"Add a family branch to {Family}"** (replaces "Add a timeline branch to {Family}").
- Story reader menu item: **"Add a family branch from this story"** (replaces "Add a timeline branch from this story").
- Visibility, flow, fields, buttons, and other dialog copy stay as #121 / M11b. Snack / "Create timeline" button stay as #121 Open Q8 default (unchanged).

## Rule 3: Nav labels
- Shared-header nav: **"Stories"** (was "Timeline"). Active underline on the Stories route as today.
- Shared-header nav: **"Draft Stories"** (was "Drafts"). Sibling of Stories.
- Routes and behavior unchanged.

## Rule 4: Closed family control — single line, more room before ellipsis
- The closed header family switcher (name + `expand_more`) stays on **one line**. **No wrap.**
- The control **grows** to take the remaining horizontal room left of the right cluster (search / New story / avatar). Do not reserve a tight fixed max that truncates early while free space still sits elsewhere in the header.
- Ellipsis at the **end** only when that remaining room is exhausted. Full name always in tooltip/semantics.
- Check / monogram / open-menu behavior unchanged.
- **Rev 1.1 (Bill ~9:00 PM CT via Erlich):** supersedes the prior “wrap to 2 lines max” Q1 lock.

## Rule 5: Search is icon-only
- Replace the "Search archive…" / search input pill on the shared header with a **magnifying glass only** (`Icons.search`).
- No pill chrome, no placeholder text, no expandable field in the header.
- Hit target ≥ 40×40. Ink icon; hover/focus uses existing header icon treatment.
- Placement: same slot the pill occupied (left of New story, after nav).
- Tapping opens today's Search screen. Search screen keeps its own bar. No M7 filter reopen.

## Rule 6: One dropdown everywhere
- Every page that shows the family menu uses the **same** rows, order, nesting, sort, and chrome — including Manage Families.
- "Add a family branch to {Family}" shows under the same condition as on Stories (members, when `_canStartTimeline` / today's gate). If the gate fails, the row is absent everywhere, Manage included.
- "Invite a family member to {family}" shows whenever Invite was available on the header today (any member who can invite).

## Rule 7: Sage guide does not cross the divider
- The 1px `albumSage` vertical guide for nested children runs from the first to the **last child of that parent only**.
- It **stops above** the post-families divider. It never continues into Invite / Add a family branch / Manage families rows.
- Fixes the overshoot in the #130 issue screenshot.

## Dropdown order after #130
1. Your families (nested, sorted — #121 Rules 4–5)
2. Divider
3. Invite a family member to {family}
4. Add a family branch to {Family} (only when it applies)
5. Manage families

## Visual spec (Mugatu calls)
Tokens from `album_theme.dart` only: `albumParchment` #FBF7F2, `albumTerracotta` #8B5E4B, `albumSage` #7A8B74, `albumInk` #2C2416, `albumDialogSurface` #FFF8F6. No new colors, fonts, or icons; Material icons only.
- Menu surface, radius, border, row heights, check column, monograms, indent, sort: unchanged from #121 Visual spec.
- Header height 72px, parchment, thin ink 15% bottom border: unchanged.
- Right cluster after #130: search icon → New story (terracotta) → avatar. No Invite button. **Even gaps** between the three controls (re-spaced after Invite removal — not the old leftover gaps).
- Nav cluster: Stories | Draft Stories (Source Sans 3). Active = ink underline on the current route.

## Screens (Stitch project 12192342757314667328)
| # | Screen | Stitch id | URL | PNG |
|---|---|---|---|---|
| A | Header CLOSED — Stories/Draft Stories, full family name, search icon only, no Invite | 9b967a2b9b6c4f2f8fcc9f894b9c4a1b | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=9b967a2b9b6c4f2f8fcc9f894b9c4a1b | shots/A_header-closed-wide.png |
| B | Header dropdown OPEN — Invite above Add a family branch; sage guide stops at divider | dec2feb150c64a44b348e3c7abeaa9a5 | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=dec2feb150c64a44b348e3c7abeaa9a5 | shots/B_header-dropdown-wide.png |

Screens A/B **LOCKED** with UI Qs 1–5 (Q5 = re-space even gaps). Mock spacing that still looks like old leftover gaps loses to the written even-gap rule. **Rev 1.1:** if Screen A shows a wrapped family name, that mock loses to Rule 4 (single line + more room before ellipsis). No new Stitch required for this amend.

Phone, dialog title wrap, and reader menu item are written-rule only (same lean cut as #121).

Mock quirks (written rules win):
- A: decorative hero ("FAMILY ARCHIVE & CHRONICLE", decade scroller chrome, footer quote) is Stitch filler — not product. Header chrome is the SoT.
- A: family chip may render as a pill; keep today's switcher chrome. **Rev 1.1:** single-line name with flex before ellipsis — not wrap.
- B: timeline cards behind the menu are placeholder. Sage guide must stop above the divider even if a mock draws it longer.

## Locked UI questions (all five — Bill via Erlich 2026-10-27)
1. Extremely long family name on a phone-width closed switcher: grow until wrap, or always single-line ellipsis after a max width? **Originally LOCKED 2026-10-27 7:54 PM CT (wrap 2 lines)**. **AMENDED & RE-LOCKED 2026-10-27 ~9:00 PM CT (Bill via Erlich, UX amend): single line (no wrap); more room / flex before ellipsis; full name in tooltip/semantics.**
2. Invite row when the user cannot invite (if that state exists today): hide or disable? **LOCKED 2026-10-27 7:55 PM CT (Bill via Erlich, verbatim: "#130 UI Q2: option 1 — Hide the row")**: Hide the row — same as today’s Invite control visibility.
3. Does "Add a family branch…" on Manage Families use the Manage page's current family (header switcher) as {Family}? **LOCKED 2026-10-27 7:56 PM CT (Bill via Erlich, verbatim: "#130 UI Q3: option 1 — The current family from the shared header switcher (same as on Stories)")**: Yes — current family from the shared header, same as Stories.
4. Search icon color at rest: ink or sage? **LOCKED 2026-10-27 7:57 PM CT (Bill via Erlich, verbatim: "#130 UI Q4: option 1 — Ink (#2C2416) — matches other header chrome; sage stays for dropdown action icons")**: Ink (#2C2416) — matches other header chrome; sage stays for dropdown action icons.
5. After Invite moves into the menu, does the header right cluster keep the same gaps as today minus the Invite control? **LOCKED 2026-10-27 7:58 PM CT (Bill via Erlich, verbatim: "#130 UI Q5: option 2 — Re-space the cluster (new even gaps between search / New story / avatar)")**: Re-space — new even gaps between search / New story / avatar.

## Out of scope
New invite rules, search filters, wordmark/profile, reader header chrome, membership/#82.

## Handoff
- UX locked 2026-10-27 7:58 PM CT. Erlich opens `docs/ux/130-header-cleanup.md` PR (Mugatu cannot push).
- Bill go 2026-10-27 ~7:58 PM CT (via Erlich): Gilfoyle gated to start SAD on this locked UX.
- **Rev 1.1 amend locked 2026-10-27 ~9:00 PM CT (Bill via Erlich):** Rule 4 / Q1 → single-line family name + more room before ellipsis. Erlich: docs amend on `docs/ux/130-header-cleanup.md` (Mugatu cannot push). Coding + Spec-match may proceed against this amend; format-only CI fix on #139 is untouched.
