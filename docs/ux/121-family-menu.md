# #121 Family menu cleanup (UX rev 1, LOCKED)

Status: LOCKED by Bill 2026-10-23 10:46 AM CT (via Erlich, verbatim): "Lock #121 UX as shown with Mugatu's defaults". The recommended defaults under Open UI questions are approved as written. Written rules win over mock quirks.
Source: PRD "Family menu cleanup (#121)", APPROVED by Bill 2026-10-23 10:36 AM CT (via Erlich): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2 . Decisions entry 2026-10-23 #121: https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166 . Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/121
Code read: main @ `34249aa` (2026-10-23 9:46 AM CT). Applies to the header family menu (`_FamilyMenu`, `core/theme/album_header.dart`), the Manage families hub (`features/family/manage_families_page.dart`), the create dialog (`features/family/start_timeline_dialog.dart`) and the story reader menu (`features/stories/story_reader_page.dart`).
UI only. No flow, permission or data change. #82 switch rules, the story-first rule and tree read access are unchanged.

## What changes today (code facts)
| Today (main) | #121 |
|---|---|
| Dropdown: your families, divider, "Start a family" (`family-menu-start`), "Start a new timeline" (timeline page, when `_canStartTimeline`), "Manage families" (only if you own/co-own a family: `stewarded.any(countsForManage)`), then divider + "Related families" label + related rows | Your families (nested), divider, "Add a timeline branch to {Family}" (same condition as today), "Manage families" (everyone). No Start a family, no Related families block |
| Family list is flat, in API order | Nested by branch, sorted (below) |
| Check mark: ink `Icons.check` 16px in a 24px column, row text regular weight | Terracotta check, current name medium (w500) |
| Menu uses the stock Material popup surface and width | `albumDialogSurface` #FFF8F6, max width 320 on wide (see Phone) |
| Hub lists only owner/co-owner families (`_ownedActive`); members can't reach the hub | Members reach a non-owner view (below); owners/co-owners see today's hub unchanged |
| Start button: top-right of the hub title row (`manage-families-start`), terracotta, plus-circle + "Start a family" | Unchanged, same place in both hub views |
| Create dialog form title "Start a new timeline"; reader item "Start a new timeline from this story" (`reader-start-timeline`) | Renamed (Labels below) |

## Rule 1: Start a family leaves the dropdown
- Remove the `family-menu-start` row. "Start a family" stays only on the Manage families hub (existing button, top-right of the title row) and the first-run empty state. No other new entry point.

## Rule 2: Manage families for everyone
- The "Manage families" row shows in the dropdown for every signed-in user, on every screen that shows the menu.
- Owner or co-owner of at least one family: today's hub, unchanged (cards, Enter, Recoverable section).
- Not owner/co-owner of any family: the non-owner view (below).

## Rule 3: labels (exact strings)
- Dropdown item: **"Add a timeline branch to {Family}"**, where {Family} is the current family name as stored (for example "Add a timeline branch to The Morgans"). Single line; when it doesn't fit, the whole label truncates at the end with an ellipsis ("Add a timeline branch to The Whitfield-Abern…"). Full label in the row's tooltip/semantics.
- Create dialog title (form step, replaces "Start a new timeline"): **"Add a timeline branch to {Family}"**, same {Family}. In the dialog the title may wrap to two lines rather than truncate (see Open questions 3).
- Story reader menu item (replaces "Start a new timeline from this story"): **"Add a timeline branch from this story"**. Same place, same visibility (members of the story's own family).
- Flow, fields, buttons and other copy in the dialog are unchanged (origin picker "Pick the origin story", Timeline name, Owner, Members, "Attaches in *", "You'll stay in {Parent}.", Cancel / Create timeline).
- The row shows exactly when "Start a new timeline" shows today: members, on the timeline page. Nowhere else.

## Rule 4: nested family list
- Only families you're a member of (any role). No Related families block; non-member tree families stay reachable from the dial branch marks, read-only, as today.
- Each parent row, then its child families indented beneath it. Nesting follows the branch tree to any depth; each level indents another 24px.
- A child whose parent you aren't in sits at top level, sorted with the other top-level rows. It is not indented and shows no parent hint.
- Soft-deleted families stay out of the dropdown as today.
- Picking any row, nested or not, follows #82 (different family lands on its timeline; current family closes the menu).

## Rule 5: sort
- Top level: A to Z, case-insensitive, ignoring a leading "The " (same rule as `familyMonogram`). "The Morgans" sorts as "Morgans".
- Children under a parent: oldest attach year first; ties A to Z with the same "The" rule.

## Dropdown order
1. Your families (nested, sorted)
2. Divider
3. Add a timeline branch to {Family} (only when it applies)
4. Manage families

## Visual spec (Mugatu calls)
Tokens from `album_theme.dart` only: `albumParchment` #FBF7F2, `albumTerracotta` #8B5E4B, `albumSage` #7A8B74, `albumInk` #2C2416, `albumDialogSurface` #FFF8F6. No new colors, fonts or icons; Material icons only.
- Menu surface `albumDialogSurface`, 12px radius, 1px #E6DCD1 border (same as the avatar menu today).
- Family row: 24px check column, then the existing 28px `FamilyMonogram`, 8px gap, name. Min height 48px for every row, children included. Names single line, ellipsis.
- Current family: `Icons.check` 16px in `albumTerracotta`, name at medium weight (w500). Others regular.
- Child rows: indented 24px per level. A 1px `albumSage` vertical guide line runs down the left of each indented block, from the first to the last child of that parent. No tree glyphs (├ └).
- Divider: 1px `albumSage` at low opacity (~0.3).
- Action rows: leading 19px `albumSage` icon, 12px gap, ink label (same `_menuRow` look as the avatar menu). "Add a timeline branch to {Family}": `Icons.account_tree_outlined`. "Manage families": `Icons.group_outlined` (or `Icons.manage_accounts_outlined`; pick one, both are stock Material).
- Width: max ~320px on wide screens, anchored under the family switcher.
- Phone (~390px wide): the menu spans the screen width minus 16px margins on each side, sheet-like, same rows, order and styling; rows keep 48px height and names truncate earlier. No separate phone screen was mocked (scope cut); this prose is the spec.

## Non-owner Manage families
For a user who is not owner/co-owner of any family.
- Same page chrome as today's hub: shared header with the family menu active, 1024px max column, title "Manage families" (Newsreader 48), subtitle "Switch between your active family archives or create a new shared space." (existing copy).
- "Start a family" filled terracotta button in the same place as the owner hub: right side of the title row. Same dialog, same result (new family becomes current, go to timeline).
- Section heading "Your families" (existing copy) with the existing count pill "{n} active", where n = number of rows listed.
- One list of your families, same nesting, 24px indent, sage guide line and sort as the dropdown. Each row: `FamilyMonogram`, family name (single line, ellipsis), and your role on the right in `albumSage` using `familyRoleLabel` ("Member"). Rows min 48px (mock uses 56px).
- Tapping a row switches to that family and opens its timeline (same as picking it in the dropdown, #82).
- No rename, transfer, delete, invite, Enter, overflow menus, member/story counts or Recoverable section. No new explanatory copy.
- Phone: same content stacked in one column with 24px side padding; the Start a family button may drop below the title (see Open questions 7).

## Screens (Stitch project 12192342757314667328)
| # | Screen | Stitch id | URL | PNG |
|---|---|---|---|---|
| A | Header family dropdown open, wide, timeline page, member who can add a branch | 253cf090a91f46b89d8c025e2f5d3c6a | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=253cf090a91f46b89d8c025e2f5d3c6a | shots/A_header-dropdown-wide.png |
| C | Manage families, non-owner view, wide | 15b95207c1a74c36b5dceed69f09a875 | https://stitch.withgoogle.com/projects/12192342757314667328?node-id=15b95207c1a74c36b5dceed69f09a875 | shots/C_manage-families-nonowner-wide.png |
B (phone dropdown), D (phone hub), E (dialog) and F (reader) were not mocked; written rules above cover them.

Mock quirks (written rules win):
- A: the current row also gets a light terracotta tint behind it; optional, not required. Timeline content behind the menu is placeholder.
- C: count pill says "5 active" but lists 6 families; it should read "6 active" (n = rows). The long name fits at 1280 so the ellipsis isn't visible there. The Start button's plus-circle icon renders outlined; use the existing filled `PlusLabel`. Rows carry a sage chevron_right affordance; keep or drop at build (no copy impact). Child indent renders ~20px; spec is 24px.

## Open UI questions (recommended default in brackets)
1. Only one family: does the dropdown still show the single family row, divider and actions? [Yes, same layout; one checked row.]
2. On a child timeline, do the current family's children and its parent still show nested as usual? [Yes, the list never changes with the current family; only the check moves.]
3. Long names in the create dialog title: wrap or truncate? [Wrap to two lines max, then ellipsis; dialogs have room and the name matters there.]
4. Owner of one family who is a plain member of others: today's hub shows only owned families, so their member families don't appear in Manage. Keep it unchanged as the rule says, or list member families below? [Unchanged for now, per rule 2; flag to Bill.]
5. Non-owner hub with no families: can it happen? A signed-in user with no families gets the first-run empty state, so the list can't be empty here. [Treat as impossible; if reached, show only title, subtitle and Start button, no new copy.]
6. Does "Add a timeline branch to {Family}" need truncation for the {Family} part only (keeping "Add a timeline branch to" visible)? [Truncate the whole label at the end; prefix is always visible because names come last.]
7. Phone hub: Start a family button beside the title or below it? [Below the subtitle, full width, when the row can't fit; matches how the title row wraps.]
8. Snack after create still says "{name} timeline created", and the dialog button "Create timeline". Rename to "branch"? [Leave as is; rule 3 changes only the three labels. Flag to Bill.]
9. Picker step title "Pick the origin story" — does "the create dialog title" mean the form step only? [Form step only; picker step unchanged.]
10. Should the Manage families row show the active underline on the switcher when on the hub (today `header-underline-family`)? [Yes, unchanged.]
