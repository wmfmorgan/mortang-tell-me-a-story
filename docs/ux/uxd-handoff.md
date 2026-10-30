# 🎨 UXD — v1 Handoff (locked)

Status: **UX locked for v1** — ready for architecture (Gilfoyle). Product scope stays with Jared.
Stitch project: `12192342757314667328` (Tell Me a Story)
Open (Bill’s Google account): [https://stitch.withgoogle.com/projects/12192342757314667328](https://stitch.withgoogle.com/projects/12192342757314667328)
Design system: Tell Me a Story — Memory Album (`assets/18104844965535020843`)
**Access:** Project is **PRIVATE** — link only works when signed into the Google account that owns the Stitch project. Not a public share URL for anonymous agents.
**For coding agents (Grok Build):** Prefer Impl Spec §10 screen inventory + this handoff over freestyling from Stitch. Use Stitch for visual reference when Bill’s account session is available.
**Stitch access (for Bill / designers):** Project is **PRIVATE** — there is no public share URL from the Stitch API. Open in Google Stitch under Bill’s Google account and search project id `12192342757314667328`, or use the Stitch UI project list titled **Tell Me a Story**.
**For coding agents (Grok Build):** Do **not** require a Stitch link. Treat this handoff + Impl Spec §10 screen inventory as the look lock. Screenshots/HTML live under the Stitch project; behavior/copy locks are on this page and Client copy & chrome locks.
Related: [✏️ UXD — Story capture (design note)](https://app.notion.com/p/3e0c4bcef23881548ccbe8da0b6497c0) · [📋 PRD](https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2) · [✅ Decisions](https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166)
---
## Locked product anchors (from Jared — do not invent)
- Private family app; primary iPad/mobile
- Capture: timeframe, people (shared list), place (address → map pin; favorites + recents), text; drafts
- Anyone can attach pictures; story author edits core + pictures
- Comments (short) vs perspectives (full alternate tellings) — separate
- Timeline: chronological per family unit; branching family units in v1
- Invites: email + shareable link (any member). **Server-sent SMS deferred to fast follow** (v1 UI: Email + Link channels only)
- Search by person / place / timeframe
- Out of scope v1: public multi-family, AI-written stories, genealogy-tree primary UX, live chat, DNA
---
## Final Stitch screens (use these)
<table header-row="true">
<tr>
<td>Flow</td>
<td>Screen</td>
<td>Notes</td>
</tr>
<tr>
<td>Capture</td>
<td>New Story</td>
<td>Timeframe, people chips, place+map, text, photos, Save draft / Publish</td>
</tr>
<tr>
<td>Capture</td>
<td>Add Person — pick existing</td>
<td>Family list</td>
</tr>
<tr>
<td>Capture</td>
<td>Add Person — create new</td>
<td>Relationship **required**; email optional (invite)</td>
</tr>
<tr>
<td>Capture</td>
<td>Place picker</td>
<td>Google Maps–style basemap + pin; favorites/recents</td>
</tr>
<tr>
<td>Reader</td>
<td>Published story reader</td>
<td>Comments vs Perspectives as separate sections</td>
</tr>
<tr>
<td>Reader</td>
<td>Add Perspective</td>
<td>Full alternate telling overlay (not a comment)</td>
</tr>
<tr>
<td>Timeline</td>
<td>Far zoom</td>
<td>Story dots by decade; pinch / +/− / Fit all / tap</td>
</tr>
<tr>
<td>Timeline</td>
<td>Mid zoom</td>
<td>Years + title stubs; branch fork peek</td>
</tr>
<tr>
<td>Timeline</td>
<td>Near zoom</td>
<td>Full cards; tap-to-zoom focus</td>
</tr>
<tr>
<td>Search</td>
<td>Full-screen search</td>
<td>From header; Person / Place / Timeframe chips; story results</td>
</tr>
<tr>
<td>Invite</td>
<td>Email tab</td>
<td>Address + optional note</td>
</tr>
<tr>
<td>Invite</td>
<td>Link tab</td>
<td>Copyable URL; expires 7 days; family still confirms</td>
</tr>
<tr>
<td>Invite</td>
<td>~~Text (SMS) tab~~</td>
<td>**Out of v1** — deferred to fast follow (do not build server SMS)</td>
</tr>
<tr>
<td>Drafts</td>
<td>Drafts list</td>
<td>Filter by missing fields; Continue writing / Discard</td>
</tr>
</table>
### Superseded (ignore for build)
- Early Family Timeline screens without the locked zoom chrome (two older “Jenkins Family Archive” passes)
---
## Locked UX decisions
- **Feel:** warm memory album; forms that breathe; iPad-first
- **Timeline zoom:** continuous pinch like a map; ladder dots → years → title stubs → full cards; also +/−, tap-to-zoom, Fit all
- **Search:** full-screen from header (not inline dropdown, not dedicated nav tab)
- **Invites:** one modal from + Invite; **Email + Link** only in v1 (album feel not SaaS); any member can invite; SMS deferred
- **Drafts:** private until published; status chips for what’s missing
---
## [DESIGN.md](http://DESIGN.md) (Memory Album)
```markdown
# Tell Me a Story — Memory Album

Warm, calm private-family storytelling. iPad-first. Paper-and-photo album feel — never cold SaaS, never cluttered.

## Principles
- Forms that breathe: generous padding, clear section hierarchy
- People and places as soft chips from shared family lists
- Place always shows a small map with a pin when selected
- Primary actions: Save draft (secondary), Publish story (primary)
- Large tap targets for elders; readable body text

## Color
- Warm parchment backgrounds (#FBF7F2)
- Soft terracotta / sepia primary (#8B5E4B)
- Ink brown for text (#2C2416)
- Muted sage for secondary accents

## Typography
- Headlines: Newsreader
- Body: Literata
- Labels: Source Sans 3

## Shape
- Roundness: 8–12px cards, soft borders

## Components
- Rounded cards (12px), soft borders
- Chip selectors for people/places/timeframe decades
- Mini map card under place field
- Photo strip with add tile
```
---
## R2 — shared header (UX locked 2026-10-04)
Bill locked this. R2 is the header only. It is not a new screen, and it does not reopen M6 or M7.
One shared bar on the timeline, drafts, and new story:
- Wordmark. It is the name, not a link.
- Family menu. It sets the family for the whole session, so New story and Invite follow it. A menu that only changes the timeline page fails.
- Timeline. It returns to the timeline for the current family.
- Drafts, immediately after Timeline. Same ink text. It opens drafts for the current family, and it stays on the bar when you are already in Drafts.
- Search chip, the one that already opens `/search`
Invite and New story sit on the right. Invite is ink text. New story is the only filled terracotta button. On the New story page those two come off, and Save draft and Publish stay instead. The reader keeps its back control. Search keeps its own bar, because the field is the page.
Stories, Family Members, Places, and Help come off. They are not destinations.
Gilfoyle owns how the session family is stored. No new table unless he says the current read cannot hold it.
---
## Autosave drafts (LOCKED 2026-10-16)
- Source: PRD must-have 'Save unfinished story drafts' ([📋 PRD](https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2)), locked by Bill 2026-10-16.
- No new screen. The New story header stays as locked in R2: Save draft and Publish remain.
- An in-progress story autosaves into the existing Drafts screen (M4.5). Amended 2026-10-22 (#82, Bill): leaving New story or Edit story with input that isn't saved yet shows the "Leave this story?" Save / Discard / Stay prompt. A fully autosaved draft still leaves quietly. See [82-family-switch.md](82-family-switch.md).
- Saves happen after a pause in typing and when leaving the page (back, cancel, navigating away).
- The draft is created on the first keystroke, so no blank drafts.
- After each successful autosave, a small grey 'Saved' label shows in the New story header, left of Save draft, in the existing muted ink token from album_theme.dart. The copy 'Saved' was approved by Bill. No other new copy, except "No date yet" (approved by Bill 2026-10-17): shown in the same muted ink on a Drafts row with no start date, and those drafts sort last.
- Tapping Save draft still saves and returns as before.
- Failed autosave (locked by Bill 2026-10-16): the header shows a grey "Not saved" in the same spot and muted ink token as "Saved". The text stays in the editor, and the app retries quietly at the next pause. No popup. Save draft and Publish still work by hand and show the real error if saving keeps failing. Bill approved the copy "Not saved".
---
## R3 — full-card timeline (2026-10-04)
R3 rebuilds the full-card timeline only. It does not reopen M6 or M7, and it does not change the R2 header.
Build from [Family Timeline (Full Cards Variant)](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=c2c1a5e91d4a449490b92ef53b0cf72c) (`c2c1a5e91d4a449490b92ef53b0cf72c`). The earlier full-card passes, `015a7a24ebd746bf96f69c4132fc1d9c` and `0ef65157329747aaba45e529d0a33947`, and the old near screen `b50f9265a875446abc4025d1cf84b8a3`, are not this rebuild.
The page scrolls the whole published timeline for the current family as full cards, newest toward the top. The card in the center of the viewport is sharp and full opacity. Cards fade into parchment as they leave the top and bottom. A card shows the year, the saved title, people chips, place chips, and photos. Titles are required on publish, so this page prints the saved title. Do not print the body or the body's first line. The center dot is terracotta with a ring. The other dots are quiet. A solid 2px line runs through the center. It is a mark, not a dashed sage rail and not a second timeline.
Under the shared header, one quiet row holds the zoom control. On the left, a beige pill reads “Zoom Level: 100% (Full Cards)”. On the right, one segmented switch reads Macro, Mid, Full Cards, with Full Cards selected. That switch is the zoom control. There is no plus, no minus, and no Fit all. There is no “in focus” badge on the card, no dial label, no era name, and no “Near zoom view”.
The header stays the R2 bar: wordmark, family menu, Timeline, Drafts, search chip, ink Invite, terracotta New story. Stories, Family Members, Places, and Help stay off.
---
## M9 — reader modal, meta line, Macro year tap (UX locked 2026-10-05)
Bill picked this screen. It does not reopen M6, M7, M8, R2, or R3.
Build from [Story Reader Modal — Tell Me a Story](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=221229a5b4844e7a9b3a2d1b3ef034e5) (`221229a5b4844e7a9b3a2d1b3ef034e5`). The earlier candidate `e3692b8710ea4fe395d9e03ebdf1a934` and the full-page reader `3ca683beb0144a658fd5074b665fe6af` are not M9.
**Reader as a modal.** Tapping a story on the timeline opens the reader as a large parchment sheet centered over the timeline. The timeline and the R2 header stay visible behind it, dimmed and blurred. The sheet scrolls inside itself. The top bar of the sheet holds the “Family Keepsake” label on the left and a round X close on the right. There is no back link. Closing returns to the same timeline position and zoom. The existing reader route stays as the deep-link target.
**Meta line.** One line under the title: “Recorded event: \{event date\} · Documented \{month year\} by \{author\} \{avatar\} · \{n\} min read”. The avatar is a small circle after the author’s name. It shows the author’s photo, or their initials when there is none (M8 circle rule). Under the M9 rule, everyone in the family sees the author’s photo. There is no separate “Written by” line.
**Below the meta line.** Chips for people, then the place and the decade. Then the story’s hero photo (first by sort order; see #153 amend) as the hero, with no caption (photos have no caption column; captions are OPEN with Jared). The hero keeps the photo’s own shape, clamped 3:4 to 16:9, shown whole on parchment (amended 2026-10-29, #151). “Documented \{month year\}” reads from the story’s published date. Then the body with a drop cap. Comments and Perspectives stay as they are.
**Macro year / decade tap.** Tapping a year chip or a decade label on Macro opens Mid (`0cd5bfaa63c64008b81a836c48e8abd3`) centered on that year, with the chip reading “\{year\} · IN FOCUS”. No new screen.
### M9 amendment — Macro tap + invite restyle (Bill 2026-10-06)
Bill re-locked these on [PR #22](https://github.com/wmfmorgan/mortang-tell-me-a-story/pull/22) head `00c18dc`. They override the earlier “Macro dot opens the reader” note from Jared’s M9 product pass.
- **Macro dot → Mid.** A far/Macro story dot opens Mid centered near that story. It does **not** open the reader.
- **Mid rail circle → Full Cards.** Tapping the Mid dial node / rail circle opens Full Cards (Near).
- **Story opens still.** Mid stubs and Full Cards still open the reader modal. Year chip and decade label still open Mid.
- **Arrow keys.** Optional client-only: arrow keys step through each rail. Not a blocker.
- **Invite restyle.** The invite dialog restyle may ride this PR. Email and Link behave as before. A Text (SMS) tab may appear as a **placeholder that does not send**. Server-sent SMS stays deferred (fast follow). Do not treat the SMS tab as a product ship.
> ❓ OPEN (Bill / Jared): the screen also shows Print and Share buttons beside the X. Neither is in the PRD. Do not build them in M9 unless Bill adds them to scope.
---
## Far-zoom amendment — matches main after PR #21 (2026-10-05)
This replaces the far chrome of `02972cf4e7ca4facaececdcb9e16991f`. The dots and layout of that screen stay.
- Every zoom level uses the same sub-header: “Continuous Family Dial” plus one year chip.
- On Macro/Far the chip reads a single year, for example “1980 · IN FOCUS”. Not a range. That year is the one a tap drills into (M9).
- The Macro / Mid / Full Cards switch has a terracotta pill that slides to the chosen zoom in 240ms.
- On a freshly opened timeline the pill already sits on the current zoom. It only slides when the zoom changes on that same timeline. This is polish, not a blocker.
---
## For Gilfoyle
UX is locked for v1. Architecture next. Do not invent product scope — Jared owns that. Prefer the final screen list above; ignore superseded timeline drafts.
---
## M10 — Manage families (UX locked 2026-10-06)
Bill locked these four screens plus the transfer and soft-delete modals below. ~~Manage lives on the profile avatar menu (extend M8), not the R2 family menu.~~ **Replaced 2026-10-10:** Manage lives in the R2 family dropdown. See **M10 navigation** below. This does not reopen M6, M7, M8, M9, R2, or R3.
Stitch project: `12192342757314667328` · Design system: `assets/18104844965535020843`
<table header-row="true">
<tr>
<td>Flow</td>
<td>Screen</td>
<td>Stitch id</td>
<td>Behavior</td>
</tr>
<tr>
<td>Profile</td>
<td>Avatar menu (open)</td>
<td>[`6b07fcdcaa204d028e79ab4494ca975a`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=6b07fcdcaa204d028e79ab4494ca975a)</td>
<td>~~Rows in order: Settings · Manage families · Logout.~~ **Superseded 2026-10-10** by `76b65f5e53684fd7a487148717af53a2` (Settings · Logout). See M10 navigation.</td>
</tr>
<tr>
<td>Manage</td>
<td>Manage families hub</td>
<td>[`b429823c1f6a44aea297aaeef195bedd`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=b429823c1f6a44aea297aaeef195bedd)</td>
<td>R2 shared header. ~~List of families you own or belong to with role chips (Owner / Co-owner / Member).~~ **Superseded 2026-10-10** by `622ceebb3b434b6c88143f888cca8ef9`: lists only families you own or co-own (no Member rows). **Start a family** creates a root. **Recoverable (60 days)** lists soft-deleted archives; owner/co-owner **Recover** restores all links. Supersedes earlier hub `f1949c8fd1db41b4baf0c5e9fdb387ce` (no R2 bar).</td>
</tr>
<tr>
<td>Manage</td>
<td>Start a family</td>
<td>[`78ba55e6adf1449685fe9dadcc1ccdfc`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=78ba55e6adf1449685fe9dadcc1ccdfc)</td>
<td>Root create only (branching is M11). Family name required. Create lands on that family’s empty timeline. Cancel returns to the hub.</td>
</tr>
<tr>
<td>Manage</td>
<td>Family detail (owner)</td>
<td>[`1c097b0e40cd4703a76fb8b1baf1ebc7`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=1c097b0e40cd4703a76fb8b1baf1ebc7)</td>
<td>Rename anytime. Up to two co-owners with same powers as owner. Members list; owner/co-owner may remove a member (full drop from the tree; story name tags stay). Owners cannot remove each other; owner may remove their own co-owner. **Transfer ownership…** and **Delete family…** (soft-delete, owner only, hidden 60 days then permanent). Invite from manage covers every family in the tree you’re on; R2 Invite stays.</td>
</tr>
</table>
### M10 modals (UX locked 2026-10-06)
Bill locked these with the four M10 core screens.
<table header-row="true">
<tr>
<td>Flow</td>
<td>Screen</td>
<td>Stitch id</td>
<td>Behavior</td>
</tr>
<tr>
<td>Manage</td>
<td>Transfer ownership</td>
<td>[`5a400d28acc24b9eb8f17da6ac3074e9`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=5a400d28acc24b9eb8f17da6ac3074e9)</td>
<td>Modal over Family detail. Pick new owner from co-owners. Required: after transfer you become **Co-owner** or **Member**. Primary: Transfer ownership. Cancel.</td>
</tr>
<tr>
<td>Manage</td>
<td>Delete family confirmation</td>
<td>[`505fa619379b4ca797208e8087ccf630`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=505fa619379b4ca797208e8087ccf630)</td>
<td>Soft-delete confirm: hidden 60 days then permanent; owner/co-owner Recover from Manage hub; type-to-confirm; Confirm delete + Cancel.</td>
</tr>
</table>
## M12 — timeline branch marks (UX locked 2026-10-06)
Bill locked these. Dial branch marks + related-families labels at Macro / Mid / Full Cards. Dashed sage hollow rings are marks (not stories); solid dots/nodes are published stories. Mark opens that related family’s timeline (read). R2 family menu still switches current family. Does not reopen M6–M10, R2, or R3 chrome rules except adding marks.
<table header-row="true">
<tr>
<td>Flow</td>
<td>Screen</td>
<td>Stitch id</td>
<td>Behavior</td>
</tr>
<tr>
<td>Timeline</td>
<td>Macro with branch marks</td>
<td>[`a6259996a3b1408486c6074a4fa75f5d`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=a6259996a3b1408486c6074a4fa75f5d)</td>
<td>Far dial + dashed sage hollow-ring forks labeled (e.g. Everest Cousins, Oak Ridge). Macro selected on zoom switch. Supersedes flat Macro `02972cf4e7ca4facaececdcb9e16991f` for branch chrome.</td>
</tr>
<tr>
<td>Timeline</td>
<td>Mid with branch marks</td>
<td>[`5a0fa5949a9647daa363c3daf34bd49e`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=5a0fa5949a9647daa363c3daf34bd49e)</td>
<td>Mid dial + hollow-ring branch pills with related-family names. Mid selected. Supersedes Mid `0cd5bfaa63c64008b81a836c48e8abd3` for branch chrome.</td>
</tr>
<tr>
<td>Timeline</td>
<td>Full Cards with branch marks</td>
<td>[`974665ebd3a44254a61da7f1cf45a3f2`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=974665ebd3a44254a61da7f1cf45a3f2)</td>
<td>Full-card scroll + hollow-ring markers between cards at fork years (not story cards). Full Cards selected. Supersedes Full Cards `c2c1a5e91d4a449490b92ef53b0cf72c` for branch chrome.</td>
</tr>
</table>
Jared does not stamp §15. After smoke, §15 is Big Head.
---
## M10 navigation (UX locked Bill 2026-10-10)
Bill locked this in the room. It replaces the avatar-menu placement of Manage families. It ships in M10 on PR #23. Matches Design Doc “M10 navigation (LOCKED Bill 2026-10-10)” and Impl Spec §15 M10.
<table header-row="true">
<tr>
<td>Flow</td>
<td>Screen</td>
<td>Stitch id</td>
<td>Behavior</td>
</tr>
<tr>
<td>Header</td>
<td>Family dropdown (open)</td>
<td>[`9dd2079031004573be8c92226a9c707f`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=9dd2079031004573be8c92226a9c707f)</td>
<td>Order: live families with a terracotta check on the current one (no section label; the mock’s “Your families” label is not built, Bill 2026-10-11), divider, **  • Start a family** (everyone; opens the existing Start dialog over the current page), **Manage families** (only if you are owner or co-owner of any family, soft-deleted included). Soft-deleted families never appear in the switch list. Each family has a monogram circle: first letter of the family name, skipping a leading “The”, on parchment. No new data. The mock shows “R” for Grandma Ruth’s Side; the rule makes it “G”.</td>
</tr>
<tr>
<td>Profile</td>
<td>Avatar menu (open)</td>
<td>[`76b65f5e53684fd7a487148717af53a2`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=76b65f5e53684fd7a487148717af53a2)</td>
<td>Rows: **Settings · Logout**. Supersedes `6b07fcdcaa204d028e79ab4494ca975a`.</td>
</tr>
<tr>
<td>Manage</td>
<td>Manage families hub (family menu active)</td>
<td>[`622ceebb3b434b6c88143f888cca8ef9`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=622ceebb3b434b6c88143f888cca8ef9)</td>
<td>On the hub and Family detail, the family menu carries the active nav state (same treatment as Timeline/Drafts when they are current); Timeline and Drafts are plain. Lists only families you own or co-own, with role chip; soft-deleted ones under Recoverable (60 days) with Recover. Family rows use the same monogram as the dropdown. Supersedes `b429823c1f6a44aea297aaeef195bedd` for header state and list.</td>
</tr>
</table>
**Landing rule.** On app start, if you have no live family of any role and at least one soft-deleted family you own or co-own, open the Manage hub. If you have no families at all, show the existing empty Start state. Otherwise land on the current family’s timeline as usual.
**Purge.** After the 60-day purge, a family is gone; if it was the last family you owned or co-owned, Manage disappears from the dropdown.
---
## M10 Add co-owner dialog (UX locked Bill 2026-10-10)
Bill locked this in the room. It ships in M10 on PR #23. Matches Impl Spec §15 M10 “M10 Add co-owner dialog — LOCKED (Bill 2026-10-10)”. No new table, column, Edge function, or route.
<table header-row="true">
<tr>
<td>Flow</td>
<td>Screen</td>
<td>Stitch id</td>
<td>Behavior</td>
</tr>
<tr>
<td>Manage</td>
<td>Add co-owner (modal over Family detail)</td>
<td>[`71ccb38d05c54f75b6c830e480b06bc0`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=71ccb38d05c54f75b6c830e480b06bc0)</td>
<td>Opens from **  • Add co-owner** on the Family detail Co-owners card. The whole page behind it is dimmed and blurred, header to bottom, same as Transfer and Delete. Title “Add a co-owner”; subtitle “Co-owners have the same powers as you. \{Family\} can have up to two.” Counter “\{n\} of 2 co-owner spots used”. A search field filters a single-select radio list of this family’s current members who are not owner or co-owner (avatar or initials, name, “Member”). Helper: “Only people already in this family can be co-owners. To add someone new, invite them first.” No email field. **Make co-owner** (terracotta, disabled until one is picked) calls existing `add-co-owner` \{ family_id, user_id \}. Cancel and X close with no change. Owner or co-owner can open it. At two co-owners the + Add co-owner button is hidden. Supersedes draft `51303fd5139144d9a124040e32d89cd6` (partial scrim).</td>
</tr>
</table>
## M10 Co-owner row actions (UX, Bill sent 2026-10-10)
\<table header-row="true"\>\<tr\>\<td\>Item\</td\>\<td\>Behavior\</td\>\</tr\>\<tr\>\<td\>Make member\</td\>\<td\>Plain ink text button on a co-owner row, left of the red Remove. Owner only. Calls `remove-co-owner`. Confirm: "Make \{name\} a member? They keep their stories and access but lose co-owner powers." Buttons: Cancel, Make member.\</td\>\</tr\>\<tr\>\<td\>Remove (co-owner row)\</td\>\<td\>Red text button. Owner only. Calls `remove-member`.\</td\>\</tr\>\<tr\>\<td\>Visibility\</td\>\<td\>Co-owners see neither action on co-owner rows. Nobody sees actions on the owner's row or on their own row.\</td\>\</tr\>\<tr\>\<td\>After action\</td\>\<td\>Reload detail so the co-owner count drops and "+ Add co-owner" returns when under 2.\</td\>\</tr\>\<tr\>\<td\>Confirm dialogs\</td\>\<td\>Follow the M10 modal standard: full-page blur and dim from header to bottom, parchment card, Newsreader title, matching Add co-owner, Transfer, and Delete. Not a stock AlertDialog.\</td\>\</tr\>\</table\>
</table>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
\</table\>
> ❓ OPEN (Bill): Remove has no confirm in the build (co-owner and member rows), and it removes the person across the whole branch tree. Proposed confirm: "Remove \{name\} from \{family\}? They lose access to \{family\} and its branches. Their stories stay." Buttons: Cancel, Remove (red). Not locked yet.
## M10 Pending Invites (LOCKED by Bill 2026-10-10, rides PR #23)
Stitch screen: Family detail with Pending Invites `16384b751bcb46678b2483cb6b856d66` (bottom of the Members card, below member rows). Server: Gilfoyle's `POST /resend-invite` and `POST /revoke-invite` (see Design Doc and Impl Spec §15 M10).
<table header-row="true">
<tr>
<td>Item</td>
<td>Locked behavior</td>
</tr>
<tr>
<td>Placement</td>
<td>Inside the Members card, below member rows. Kicker "PENDING INVITES" left, "\{n\} waiting" right.</td>
</tr>
<tr>
<td>Visibility</td>
<td>Only the family owner and co-owners see the section. Plain members never see it. Hidden entirely when there are no pending invites (status pending, including expired). Accepted and revoked invites never show.</td>
</tr>
<tr>
<td>Email invite row</td>
<td>Email address; meta "Sent \{Mon D\} · Expires \{Mon D\}"; Pending pill; actions Resend (ink text) and Cancel invite (red #9F403D text).</td>
</tr>
<tr>
<td>Expired row</td>
<td>Meta "Sent \{Mon D\} · Expired \{Mon D\}"; Expired pill (pale red); same actions, Resend and Cancel invite.</td>
</tr>
<tr>
<td>Link-only row</td>
<td>Label "Invite link" with link icon; meta "Created \{Mon D\} · Expires \{Mon D\}"; Pending or Expired pill; Cancel invite only (no Resend).</td>
</tr>
<tr>
<td>Helper line</td>
<td>"Resend emails the invite again and gives it 7 more days. Cancel stops the link from working."</td>
</tr>
<tr>
<td>Resend</td>
<td>No confirm. Calls resend-invite. Button shows a busy state and is disabled while the call runs. On success, inline note under the row: "Invite sent again to \{email\}. The old link no longer works." Then reload so dates and pill update (Expired becomes Pending). On error, inline red text from the error catalog; row stays.</td>
</tr>
<tr>
<td>Cancel invite</td>
<td>Opens a confirm using the M10 modal standard (full-page blur like Add co-owner 71ccb38d and Delete family 505fa619; not a stock AlertDialog). Title "Cancel this invite?" Body (email): "\{email\} won't be able to join \{family\} with this link. You can invite them again any time." Body (link-only): "This invite link won't work for anyone anymore. You can make a new one any time." Buttons: Keep invite (ink, closes, calls nothing) and Cancel invite (filled red #9F403D). Confirm calls revoke-invite, closes, and reloads; the row disappears and the count drops. If it was the last one, the section hides.</td>
</tr>
<tr>
<td>Token rotation</td>
<td>Resend replaces the invite link (Bill's lock, per Big Head). Copy above says so.</td>
</tr>
</table>
> 🚫 FORBIDDEN: showing the section or its actions to plain members; Resend on link-only invites; deleting invite rows; client writes to invites.
## M10 Remove confirm (LOCKED by Bill 2026-10-10, rides PR #23)
Supersedes the OPEN callout in "M10 Co-owner row actions". Remove on co-owner and member rows opens a confirm before calling remove-member, using the M10 full-page blur modal standard (not AlertDialog). Title/body: "Remove \{name\} from \{family\}? They lose access to \{family\} and its branches. Their stories stay." Buttons: Cancel (ink, closes, calls nothing) and Remove (filled red #9F403D, calls remove-member, closes, reloads). Make member uses the same blur modal with its locked copy.
### M10 polish (2026-10-10, from visual review of PR #23 at fe99884)
- Make member confirm: title "Make \{name\} a member?", body "They keep their stories and access but lose co-owner powers." Same text as before, now split into title and body to match Remove.
- Pending Invites kicker renders uppercase: "PENDING INVITES". "\{n\} waiting" stays.
## M12 Related families menu (LOCKED Bill 2026-10-10)
The M12 entry point in the R2 family dropdown. It extends the M10 menu (dropdown 9dd2079031004573be8c92226a9c707f) and does not change it.
<table header-row="true">
<tr>
<td>Element</td>
<td>Behavior</td>
</tr>
<tr>
<td>M10 block</td>
<td>Unchanged: the families you're a member of, a check on the open one, a divider, + Start a family, then Manage families for an owner or co-owner.</td>
</tr>
<tr>
<td>Related block</td>
<td>Below the M10 block: a divider, then a disabled label row `Related families`, then one row per other family in the tree. Each row shows the same letter monogram plus `families.name`, with no year.</td>
</tr>
<tr>
<td>Source</td>
<td>The same `list_family_tree` result the timeline marks use. Soft-deleted families never appear.</td>
</tr>
<tr>
<td>Empty</td>
<td>When the tree has no other families, the whole block is hidden, including the divider and the label.</td>
</tr>
<tr>
<td>Open family</td>
<td>When the open family is a related family you're not a member of, its row in the related block shows the same check as the M10 rows, and no membership row is checked.</td>
</tr>
<tr>
<td>Select</td>
<td>Uses the same path as a timeline mark: remember the family, then reload the timeline in place.</td>
</tr>
</table>
Timeline marks (Macro a6259996, Mid 5a0fa594, Full Cards 974665eb): hollow sage ring with the family name as its label. When `branch_year` is set, the label reads `Name · 1972`. There's no "Est." and no tilde. Branches with no year form a group at the newest end of the rail, which is the top on Macro and Mid and above the first card on Full Cards.
> 🚫 FORBIDDEN: a year in the menu rows, demo copy ("Est. \~1972", Jenkins, Oak Ridge), and any change to the M10 block.
## M11a — origin stories (LOCKED Bill 2026-10-11)
Every timeline has an origin story. Owners and co-owners can change it later. M11b (starting new timelines) is separate and not designed yet.
<table header-row="true">
<tr>
<td>Screen</td>
<td>Stitch</td>
</tr>
<tr>
<td>Story reader, ⋯ menu open with "Set as origin for \{Child\}"</td>
<td>[cb9313522baa44deb49841c11c99caf6](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=cb9313522baa44deb49841c11c99caf6)</td>
</tr>
<tr>
<td>Timeline with the Set origin story banner</td>
<td>[3ed7c63cac35408e8c00d4720a03461e](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=3ed7c63cac35408e8c00d4720a03461e)</td>
</tr>
<tr>
<td>Child timeline with the origin story and parent ring</td>
<td>[e6460f5208024f58be19e5a2fc457261](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=e6460f5208024f58be19e5a2fc457261)</td>
</tr>
<tr>
<td>Delete origin story warning</td>
<td>[564334d791e243b395f879c00bae5100](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=564334d791e243b395f879c00bae5100)</td>
</tr>
</table>
### Behavior
- A parent story's ⋯ menu shows "Set as origin for \{Child\}" once for each child family the viewer owns or co-owns.
- A family with no origin shows the banner to its owners and co-owners. On a child family the button reads "Choose from \{Parent\}" and opens the parent timeline.
- A root family picks one of its own stories as its origin. That story gets a plain sage "Origin" tag. There is no mock for this; use the tag style from screen 3 with the text "Origin".
- On a child timeline the origin story shows with the tag "Origin · from \{Parent\}" and the parent ring beside it.
- Child-family members can comment on the origin story and add perspectives and pictures. Only the author edits the story itself.
- Deleting an origin story shows the warning first: "This story starts the \{X\} timeline. Delete anyway?" After a confirmed delete, that family's owners see the Set origin story banner again.
### Build rules (these override the mocks)
- The origin story keeps its own dot on the rail, with the ring beside it. The mock draws only the ring.
- Ring labels go on the empty side of the rail, not under the ring as screen 2 draws them.
- Drop "Candidate beginning" and the extra note in the delete warning.
- Drop the "Only owners and co-owners of \{Child\} see this option…" note in the Set origin confirm. The confirm is title, body, Cancel, and Set origin only.
- The menu item always names the family: "Set as origin for \{Family\}", including a root family's own story. Never a bare "Set as origin".
- A root family's banner reads "Every timeline starts with a story. Set the origin story for \{Family\}." then "Open one of your stories and choose Set as origin for \{Family\}." There's no choose button, and the banner is hidden when the root has no published stories.
- On Full Cards the ring label sits on the side of the rail away from the origin card, not always to the right.
- Ring tokens are unchanged from M12: 16px dashed sage hollow ring, centered on the rail, parchment disc behind it, no "Est.".
> 🚫 FORBIDDEN: any screen for starting a new timeline (that's M11b), demo names from the mocks, and edit rights on the origin story for anyone but its author.
- **M11a narrow Full Cards (Mugatu 2026-10-11, PR #26 review):** ignore cardOnLeft. The parent ring sits on the rail, centered in the 28px left column, 8px below the origin dot, with no label (the card's "Origin · from \{Parent\}" tag names the parent). Tap opens the parent timeline. Never over the card or outside the column. Test: wide with card on the right puts the label left of the ring; narrow ring center x equals dot center x, no label, no overlap with the card.
## M13 — Fit & Finish (LOCKED Bill 2026-10-11)
Status: **LOCKED by Bill on 2026-10-11 in his 1:1.** Build order: M11b first, then M13 (M13 approved but held until M11b ships). Scope is the eight items Bill approved 2026-10-11 (item 8 Edit a story included) (PRD M13, Decisions row “Fit & Finish (M13)”). Nothing here adds scope. How a partial date is stored, sorted, or turned into a decade is Gilfoyle’s; this section only says what people see and tap.
Stitch project: `12192342757314667328` · Design system: `assets/18104844965535020843`
<table header-row="true">
<tr>
<td>Screen</td>
<td>Stitch</td>
<td>Purpose</td>
</tr>
<tr>
<td>Add a story — date picker</td>
<td>[`a9fd84de2e094f6e9e234c8fb9387a94`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=a9fd84de2e094f6e9e234c8fb9387a94)</td>
<td>Item 3. “When did this happen?” card with three plain boxes side by side: Year (1987), Month (March), Day (14); preview “Shows as: March 14, 1987”. No precision selector, no decade chips. Shared header bar (wordmark, family menu, Timeline, search chip; Save draft + Publish right). Only the date field and create chips change; the rest of New Story stays as built. Replaces old `5b929a4c` (superseded; do not build from it).</td>
</tr>
<tr>
<td>Add person — blurred backdrop</td>
<td>[`d1f8f94f2e0c45ffb59836f7c2636c22`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=d1f8f94f2e0c45ffb59836f7c2636c22)</td>
<td>Items 1 + 2 on a non-M10 dialog. Full-page dim + blur behind the modal; “⊕ Create new person” tab.</td>
</tr>
<tr>
<td>Family detail — create buttons</td>
<td>[`4173413ee3894a5c9fe7e8081981235a`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=4173413ee3894a5c9fe7e8081981235a)</td>
<td>Item 2. “⊕ Add co-owner” on the Co-owners card and “⊕ New story” in the R2 header.</td>
</tr>
<tr>
<td>Landing + sign in</td>
<td>[`1939575036dd4c9396d124461df8572f`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=1939575036dd4c9396d124461df8572f)</td>
<td>Item 6. One public page: headline, photo, email field, “Email me a sign-in link”.</td>
</tr>
<tr>
<td>Landing — check your email</td>
<td>[`6cdb77ad4e204d29be8cc3dc875e6607`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=6cdb77ad4e204d29be8cc3dc875e6607)</td>
<td>Item 6 sent state. Card swaps to “Check your email”.</td>
</tr>
<tr>
<td>Invite sign in</td>
<td>[`830d27ceec9c412a8826d8303d56689b`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=830d27ceec9c412a8826d8303d56689b)</td>
<td>Item 7 + clarification 7. Own page for invite links. Family monogram, “YOU’RE INVITED”, “Join \{Family\}”, then “Bill Morgan invited you to The Morgans.” under the title.</td>
</tr>
<tr>
<td>Invite sign in — check your email</td>
<td>[`5f80ed88432f42a2a9ca78faee4db746`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=5f80ed88432f42a2a9ca78faee4db746)</td>
<td>Item 7 sent state.</td>
</tr>
<tr>
<td>Reader — partial date</td>
<td>[`d4eb7bc3dc19455b8adb2d3cb312160e`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=d4eb7bc3dc19455b8adb2d3cb312160e)</td>
<td>Item 3. M9 reader with “Recorded event: March 1987”. Decade chip gone.</td>
</tr>
<tr>
<td>Invite link dead</td>
<td>[`8855fdcf599348ec8150295218ccd1d0`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=8855fdcf599348ec8150295218ccd1d0)</td>
<td>Clarification 6. Same invite page shell, no email field: “This invite link no longer works. Ask your family for a new one.”</td>
</tr>
<tr>
<td>Story reader with Edit</td>
<td>[`bdedfd1f423046ed9a1567b739eb2ea2`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=bdedfd1f423046ed9a1567b739eb2ea2)</td>
<td>Item 8. M9 reader with an outlined “Edit” button (pencil) at the top right of the story content, next to the title. Shown only to people who can edit. Meta line “Recorded event: March 1987”.</td>
</tr>
<tr>
<td>New story — full (M13) top</td>
<td>[`125b2d23e0ef4e42a4f4b9a81e07a86b`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=125b2d23e0ef4e42a4f4b9a81e07a86b)</td>
<td>Items 2 + 3, full form (top half). R2 header (Save draft / Publish), Story, Photos & Keepsakes.</td>
</tr>
<tr>
<td>New story — full (M13) bottom</td>
<td>[`c91ba67e72bc4cc7b369ae7785e87dfb`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=c91ba67e72bc4cc7b369ae7785e87dfb)</td>
<td>Items 2 + 3, full form (bottom half). Timeframe card with the three-box date picker, People, Place & Setting, footer.</td>
</tr>
</table>
Items 4 and 5 are behavior only. No new screen.
### Behavior
1. **Blurred modals.** Every modal and dialog uses the M10 standard: the whole page behind it, header to bottom, is dimmed and blurred; parchment card; Newsreader title. That covers Add person, Choose place, Add perspective, Invite, Start a family, Set as origin, the origin delete warning, and every confirm (Make member, Remove, Cancel invite). The reader modal (M9) already does this. No stock AlertDialog anywhere.
2. **Create buttons.** A button that creates something has no “+” in its label. A small filled circle with a plus sits left of the label. On parchment or outline buttons the circle is terracotta with a white plus. On the filled terracotta New story button the circle is parchment with a terracotta plus. Labels: “New story”, “Add co-owner”, “Start a family”, “Add person”, “Create new person”, “Add photo”. Same hide/disable rules as today (Add co-owner still hides at two co-owners).
3. **Story date.** The Timeframe card replaces the decade chips.
	- Three plain input boxes side by side, labeled “Year”, “Month”, “Day”. People fill only the boxes they know. No precision selector.
	- Year: required, four digits. Month: optional, dropdown or numeric box (1–12 / January–December). Day: optional (1–31), disabled until Month is filled; clearing Month clears and disables Day.
	- Precision is derived from which boxes are filled: Year only → year; Year + Month → month; Year + Month + Day → day.
	- Helper: “Year is required. Add the month or day only if you remember. Day unlocks after Month.”
	- Preview: “Shows as: 1987” · “Shows as: March 1987” · “Shows as: March 14, 1987”.
	- Inline errors under the field: “Enter a four-digit year.” · “That day isn’t in that month.”
	- Reader meta line shows exactly what was entered: “Recorded event: 1987” / “March 1987” / “March 4, 1987”. No decade chip on the reader.
	- On timelines a partial date sits at the start of its period: “1987” before “March 1987”.
4. **Macro dot.** Tapping a story dot on Macro opens that story in the reader modal. Closing returns to Macro at the same spot. Year chip and decade label still open Mid (M9). Mid rail circle still opens Full Cards.
5. **Zoom out on empty space.** Clicking or tapping empty space on a timeline steps out one level: Full Cards → Mid → Macro. On Macro it does nothing. Dots, stubs, cards, chips, branch rings, labels, the header, and the zoom switch keep their own taps. The zoom pill slides as it does today.
6. **Landing + sign in (one public page).** Top left wordmark “Tell Me a Story” only.
	- Headline: “Your family’s stories, kept together.”
	- Subhead: “A private place to write down the moments you remember, and read the ones your family remembers too.”
	- Card title: “Sign in or get started” · line: “Enter your email to access your family archive.”
	- Label “Email address”, placeholder `you@example.com`, button “Email me a sign-in link”, helper “We’ll email you a link. No password needed.”
	- Footer: “Private to your family. Stories stay inside the family you share them with.”
	- Bad email (inline): “Please enter a full email address.”
	- Sent state (card swaps, left side stays): title “Check your email”; body “We sent a sign-in link to \{email\}. Tap the link in that email to come in.”; helper “The link works once. Didn’t get it? Check your spam folder.”; ink text buttons “Send it again” and “Use a different email” (back to the empty form).
	- Signed-in visitors skip this page and land per the M10 landing rule.
7. **Invite sign in (its own page).** Invite links open this page, never the public landing. One centered card, wordmark top left, same footer.
	- Family monogram (M10 rule: first letter, skip a leading “The”), kicker “YOU’RE INVITED”, title “Join \{Family\}”.
	- Body: “\{Family\} keeps its stories on Tell Me a Story. Sign in with your email to read them and add your own.”
	- Same email label, placeholder, button, and helper as the landing page.
	- Sent state: kicker stays; title “Check your email”; body “We sent a sign-in link to \{email\}. Tap it to join \{Family\}.”; same helper and the two ink text buttons.
	- Under the title: “\{Inviter\} invited you to \{Family\}.” (clarification 7).
	- \{Family\} is the invite’s family name and \{Inviter\} the inviter’s name (both on the invite). No inviter photo.
8. **M13 item 8 (Edit a story).** A published story can be edited.
	- Who can edit: the story’s author and the owners and co-owners of the timeline the story belongs to. Owners and co-owners of a parent or child timeline in the same tree cannot edit it.
	- Entry: an outlined “Edit” button at the top right of the story content in the reader, shown only to people who can edit. The reader header is otherwise unchanged.
	- Edit covers title, text, date, people, and pictures, using the same form as New story (including the three-box date picker), prefilled. Title “Edit story”. Header actions: “Save changes” (terracotta) and a close X instead of Save draft / Publish. No Cancel (superseded by #153 amend, 2026-10-30).
	- The X returns to the reader. With unsaved edits it first asks save, discard, or stay (“Leave this story?”). Save changes saves and returns to the reader.
	- Comments and perspectives stay editable only by their own authors.
**Clarifications (decided 2026-10-11).** How dates are stored, sorted, or turned into a decade is Gilfoyle’s; these say what people see.
- **Clarification 2 (old decade-only stories).** Old decade-only stories show the decade, e.g. “1980s”, in the reader. The date picker opens empty, and an edit needs at least a Year to save.
- **Clarification 3 (photo dates).** A photo needs at least a year before it can be added.
- **Clarification 4 (Search Timeframe filter).** The Search Timeframe filter stays by decade. Partial dates count toward the decade of their year.
- **Clarification 5 (sorting).** Less precise sorts first: 1987, then January 1987, then January 1, 1987. Remaining ties by created_at.
- **Clarification 6 (dead invite links).** Expired, cancelled, and used invite links all show one message: “This invite link no longer works. Ask your family for a new one.” An already-signed-in user skips login.
- **Clarification 7 (invite page wording).** Invite page line: “\{Inviter\} invited you to \{Family\}.”
### Build rules (these override the mocks)
- Date picker mock is focused (title, body, date only). Keep the built New Story layout (photos, place, map, header); swap only the Timeframe card and the create chips. Ignore the mock’s word count / “All changes saved” row and the literal “nn” in the sample body. The preview reads “Shows as: March 14, 1987” on one line, not the mock’s split “SHOWS AS” label.
- New story full mocks (`125b2d23e0ef4e42a4f4b9a81e07a86b`, `c91ba67e72bc4cc7b369ae7785e87dfb`): Mock is one column for render only; build keeps the locked New story layout (`30237cf012c74948b863c02cb860223a`, two-column) with the Timeframe card's decade chips replaced by the three-box picker. Ignore mock quirks: icon badges/heading size on lower cards, card gap differences, “STORY ENTRY” label, “RIVERTOWN” map label, centred Year/Day values (left-align per `a9fd84de`). Edit story reuses this form titled “Edit story” with Cancel and Save changes (terracotta), both returning to the reader.
- Family detail mock stacks the circle above “New story”. Build it inline, circle left of the label, like Add co-owner.
- Add person mock leaves a thin unblurred strip at the bottom. Build the blur to cover the full viewport.
- Reader mock still shows the hero photo with no caption and no Print/Share: keep it that way (M9).
- Landing sign-in card line “Enter your email to access your family archive.” is from the mock; keep it or drop it, nothing else.
- Circle size: about 20px on chips and small buttons, 32px on the Add photo tile. Same tokens: terracotta #8B5E4B, parchment #FBF7F2, ink #2C2416.
> 🚫 FORBIDDEN: password fields, Google/Apple/social sign-in, or “Forgot password”; a “+” glyph in any create label; decade chips in the add-story flow; a Macro dot opening Mid; inviter names or photos the invite doesn’t carry; any new scope beyond the eight items (item 8 Edit a story included).
> 🚫 FORBIDDEN: No precision selector; no decade chips.
## M11b — Start a new timeline (LOCKED by Bill 2026-10-11)
Locked story-first at 1:58 PM CT. Where a mock differs from the written rules, the rules win (see Mock quirk notes). reader-start-timeline and post-create have no mock; build them from the rules (reader = locked M11a reader cb9313522baa44deb49841c11c99caf6 plus the ⋯ menu item; post-create = parent timeline with the toast).
Re-decided by Bill 2026-10-11 (\~1:35 PM CT) and stamped in the PRD (M11 "Start a new timeline LOCKED 2026-10-11", "M11b story-first RE-CONFIRMED 2026-10-11"). This supersedes the locked v2 "Start a branch" design.
<table header-row="true">
<tr>
<td>Screen</td>
<td>Stitch</td>
<td>Purpose</td>
</tr>
<tr>
<td>reader-start-timeline</td>
<td>Locked from rules, no mock. Build from the locked M11a reader (cb9313522baa44deb49841c11c99caf6) per the rules below.</td>
<td>Story reader (back-only header) with “Start a new timeline from this story” in the reader's ⋯ story-actions menu.</td>
</tr>
<tr>
<td>family-menu-timeline</td>
<td>v3: [7f173351c091430f900f1a61793cb941](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=7f173351c091430f900f1a61793cb941)</td>
<td>R2 family dropdown open: the M10 block exactly as shipped on main, with no label added (family rows with letter monograms and a terracotta check on the current one, divider, + Start a family, Start a new timeline, Manage families), then the M12 related block exactly as M12 shipped (the mock's indented tree rows are not built in M11b; dropped and carried, Bill 2026-10-11). Mock quirk: the current family's monogram circle is filled terracotta and its row is highlighted; build it like the other M10 rows (parchment monogram, check only).</td>
</tr>
<tr>
<td>story-picker</td>
<td>v3: [7d6fcf3bf70a48cb8aee5923b187457c](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=7d6fcf3bf70a48cb8aee5923b187457c)</td>
<td>Modal “Pick the origin story” over the blurred timeline: subtitle “Published stories from The Morgans”, search field, published stories (title + year), a “Write a new story” row, Cancel (ink outline). No drafts. Mock quirks: the search field and footer are pink-tinted (use white/parchment); the backdrop is a card grid with a made-up page title instead of the full-card timeline.</td>
</tr>
<tr>
<td>create-timeline-form</td>
<td>v3: [faaa5d4c913d470a8634e6796f3fc8fd](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=faaa5d4c913d470a8634e6796f3fc8fd)</td>
<td>Modal “Start a new timeline”: origin story card at the top (Bill & Mary's Wedding · 1972, with Change on the menu path), Timeline name, Owner, Members chips (Ana, Luis sage; Rosa, Tom outline), Attaches in \* YEAR 1972, “You'll stay in The Morgans.”, Cancel and Create timeline. Mock quirks: Owner reads “You (Bill Morgan)” (build exactly “You”); delete the helper text beside the year box; Timeline name and Owner fields are pink-tinted (use white).</td>
</tr>
<tr>
<td>post-create</td>
<td>Locked from rules, no mock.</td>
<td>Parent timeline (The Morgans) after create, with a toast “The Morgan-Reyes timeline created”. The PRD doesn't say where the starter lands, so this is the toast-on-parent version.</td>
</tr>
</table>
Superseded v2 screens (do not build): dial-mark-menu f8643416184b4c5a90dac4983bf7acd4, family-menu 4222b8b6af134a63b63b87f42cc46aa1, start-branch-form 2db4c46528e74aaabb0e58f53858925d, branch-created 21bba77a4e5041c7b9a6dfbcde23ee1d (and their v1s 079ce808d0854e579c636067b35ec598, cae5d42fb89a486a892f2d31e2a38538, c4f956ad87bb43fa877803f24f6de1b2, 9efb5459763a4038a2553b67cb289446).
**Behavior rules**
- The name is “Start a new timeline” everywhere. “Start a branch” is gone. There is no entry from timeline/dial marks (no popover on marks).
- A new timeline always starts from a published story. There is no empty start.
- Entry A, story reader: “Start a new timeline from this story” in the reader's story actions. Only members of that story's own family see it (the server refuses anyone else). That story becomes the origin, and it is fixed in the create modal.
- Entry B, family menu: “Start a new timeline”. It opens a required story picker listing published stories from the current (parent) family. No drafts are listed. The picker also offers “Write a new story”: the user writes and publishes it in the normal New story screen, then returns to the create flow with that story attached. There is no draft or pending state, and Create can't be reached without a published origin story.
- Family menu: the M10 family-menu block is unchanged except for the added “Start a new timeline” row, placed right after “+ Start a family” and before “Manage families”. Block order, exactly as shipped on main (no label is added; the mock's “YOUR FAMILIES” label is not built): your families (monogram, terracotta check on the current one), divider, + Start a family, Start a new timeline, Manage families (owner/co-owner only). Then the M12 Related families block, unchanged from what M12 shipped. The indented whole-tree view is not part of M11b (Bill, 2026-10-11: dropped and kept on the carry list). There is no separate tree page.
- Create modal: the origin story sits at the top (title + year). From the menu path it has a “Change” link back to the picker; from the reader path it is fixed. Then Timeline name (placeholder “e.g. The Morgan-Reyes”), Owner (default exactly “You”), Members chosen from the parent family's whole people list (sage chips selected, outline chips unselected, no extra add-member input), and Attaches in \* as one YEAR box prefilled from the origin story's year (or decade) and editable. One line: “You'll stay in \{Parent\}.” Buttons: Cancel (ink outline) and Create timeline (terracotta). No other helper copy.
- The attach year must be a 4-digit year. Create timeline stays disabled until name, owner and year are set.
- Any member can start a new timeline. The starter picks the owner and members and stays a member of the parent family.
- The starter sets the origin at create even if they aren't an owner or co-owner of the new timeline. Changing the origin later is owners/co-owners only (M11a; no new screen here).
- After create: the starter stays on the parent timeline and sees a toast “\{Name\} timeline created”. The PRD doesn't say the user lands on the new timeline.
- The new timeline shows its origin story as its starting point, per M11a: the same story (not a copy), placed by its decade with the “Origin · from \{Parent\}” tag and the parent ring beside it.
- Nesting is capped at 63 levels (Bill, 2026-10-11). Families never see the cap in normal use.
- There is no parent-side revoke.
- Create errors (inline, modal stays open):
	- NOT_FOUND from the menu path: “That story isn't available anymore. Pick another one.”
	- NOT_FOUND from the reader path: “That story isn't available anymore.”
	- FORBIDDEN: “You're not a member of \{Parent\} anymore.”
	- VALIDATION: show the Edge message as returned.
**Decided (Bill 2026-10-11)**
- Long timeline/family names in the family menu and Related families rows truncate with an ellipsis (…) at the menu's max width. No full-name hover or long-press is added; just truncate.
> 🚫 FORBIDDEN: any entry from timeline/dial marks; the wording “Start a branch”; a “+” in the “Start a new timeline” label (“+ Start a family” keeps its frozen M10 glyph); starting a timeline without a published origin story (no empty start, no draft origin); showing the reader action to anyone who isn't a member of the story's family; any change to the M10 family-menu block other than the added row.
## M14 — People profiles (LOCKED 2026-10-12, Bill)
Status: **LOCKED by Bill on 2026-10-12.** Ties to PRD M14 locks. Only the screen ids below are canonical.
Stitch project: `12192342757314667328`
<table header-row="true">
<tr>
<td>Screen</td>
<td>Screen id</td>
<td>Stitch</td>
</tr>
<tr>
<td>Add person</td>
<td>`b473d44aa3d245a190c0e63e4b3a8d5d`</td>
<td>[`b473d44aa3d245a190c0e63e4b3a8d5d`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=b473d44aa3d245a190c0e63e4b3a8d5d)</td>
</tr>
<tr>
<td>Send invite confirm</td>
<td>`b1fe8caf283040809781a10bba45c97c`</td>
<td>[`b1fe8caf283040809781a10bba45c97c`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=b1fe8caf283040809781a10bba45c97c)</td>
</tr>
<tr>
<td>Add person, passed</td>
<td>`58464879b06c48148d22314e9b57ad3c`</td>
<td>[`58464879b06c48148d22314e9b57ad3c`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=58464879b06c48148d22314e9b57ad3c)</td>
</tr>
<tr>
<td>Person profile, member view</td>
<td>`ed49266f0c1e49a08588e65e583b36a9`</td>
<td>[`ed49266f0c1e49a08588e65e583b36a9`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=ed49266f0c1e49a08588e65e583b36a9)</td>
</tr>
<tr>
<td>Person profile, name only</td>
<td>`3e69375b469e4e9ab5878de281428bda`</td>
<td>[`3e69375b469e4e9ab5878de281428bda`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=3e69375b469e4e9ab5878de281428bda)</td>
</tr>
<tr>
<td>Edit person</td>
<td>`98ba67f7f2c04e1187dbbb40f46d26e2`</td>
<td>[`98ba67f7f2c04e1187dbbb40f46d26e2`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=98ba67f7f2c04e1187dbbb40f46d26e2)</td>
</tr>
<tr>
<td>Settings, your profile</td>
<td>`c285e4a01e444a80b784bbbec167af27`</td>
<td>[`c285e4a01e444a80b784bbbec167af27`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=c285e4a01e444a80b784bbbec167af27)</td>
</tr>
<tr>
<td>Invite link, pick a person</td>
<td>`ef1bb744f41a478091a09d80c3538669`</td>
<td>[`ef1bb744f41a478091a09d80c3538669`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=ef1bb744f41a478091a09d80c3538669)</td>
</tr>
</table>
**Copy rule (the written rule wins over the mocks)**
- Labels only: Name, Date of birth, Date of passing, Picture, About, Email.
- Dates use the M13 date picker helper “Year is required. Add the month or day only if you remember. Day unlocks after Month.” and its “Shows as” preview.
- Buttons: “Add person” (with circle-plus) on Add person; “Send invite to \{name\}?” with “Send invite” and “Not now” on the confirm; “Edit” on the profile; “Save” on Edit person and Settings.
- Invite (PRD Lock 13, Bill 2026-10-13): the existing “Invite to the family archive” modal [`89b27d387f644be899da138977ea009c`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=89b27d387f644be899da138977ea009c) stays exactly as is (Email, Text (SMS), Link). Below it, a “Not invited yet” list shows people with no account and no open invite, excluding anyone with a date of passing. Each row shows the picture, name, and email or “No email yet”, with Invite, or Add email then “Save and invite”. Errors show in the row. Colors come from `album_theme.dart` only. This replaces the “Someone new” picker on `ef1bb744`.
- Ignore every other line in the mocks: subtitles, helper/footer text, badges, breadcrumbs, tabs, Stories list, account email, Cancel, link area, Copy link, expiry, counts, sample names.
- Layout, colors, blur and the circle-plus follow the mocks.
**Behavior (PRD M14 locks)**
- Email field is hidden and no invite is offered when Date of passing is set. Saving with an email shows the confirm; no silent send (Lock 6).
- Members of the tree see the full profile; anyone else sees name only (Lock 8).
- Tree members can edit until the person signs in; after that only the person can (Lock 3).
- Settings opens your own profile with one Save (Lock 4).
- Dates use the M13 picker (Lock 5).
- Invite link: pick a not-signed-in person; they're linked on the M13 invite sign-in page [`830d27ceec9c412a8826d8303d56689b`](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=830d27ceec9c412a8826d8303d56689b) with no “this is me” step (Lock 7).
- Removal keeps the profile and story tags, unlinked, using the existing M10 Remove confirm (Lock 9).
- The profile opens from any name pill (Item 4) as a blurred modal.
**Defaults (Bill approved at lock 2026-10-12)**
- Both dates may stay fully blank; Year is required only once a date is started.
- Email can be added later, with the same confirm.
- Choosing “Not now” still saves the email.
- Profiles open from name pills and Settings only.
- The picker lists all not-signed-in people in the tree, except anyone with a date of passing (Bill, 2026-10-12).
- A removed member's profile becomes editable by tree members again.
- No deceased mark.
- An uploaded picture stays until the person replaces it.
> Note: duplicate M14 drafts remain in Stitch intentionally; only the ids above are canonical.
## M14.1 Add person picker (LOCKED 2026-10-15)
Screen of record: [Stitch M14b Add person picker](https://stitch.withgoogle.com/projects/12192342757314667328?node-id=f821c61746fe4895b48c94b2e4e13349). Written rules below win over quirks in the mock.
- A search field labeled "Search people in this family" sits above the people already in the tree. Each row shows the name with years inline.
- People already on this story are left out of the list.
- Tapping a name links that person to the story right away. A highlighted row is a hover state only, not a selection.
- "Create new person" (dashed button) is always visible. It opens the existing M14 Add person form (`add_person_modal.dart`) with the typed name filled in.
- When the tree is empty or nothing matches, only the create row shows.
- Colors use `album_theme.dart` tokens only. No new copy beyond the labels above.
- Extra Stitch copies `1d063d3e…` and `7e11d13d…` are not the record.
## M14.1 polish pass (APPROVED by Bill 2026-10-16, after PR #33 merges)
Screen of record: Stitch f821c61746fe4895b48c94b2e4e13349. Approved copy and colors only, using `album_theme.dart` tokens; no new wording.
- "Create new person" row: a leading + (add) icon before the label. The tap ripple follows the dashed border's rounded corners.
- Years: an en dash, e.g. "1921–1998". A living person shows "1950–". Years sit right after the name in the same line, not pushed to the right edge.
- Picker step: no Cancel footer or divider. Close with the header X, as in Stitch.
- Search: "Search people in this family" goes inside the field as placeholder text, not as a separate label above it.
- Errors: shown in the existing pop-up. Use the `mapRpcError` text when one of the 4 prefixes matches, otherwise "Couldn't save person. Try again." (settled in #33).
## M14.3 — Date of birth and passed away (LOCKED 2026-10-16)
Locked by Bill in the Mortang room ("build 14.3"). Source: PRD M14.3 items 1–8. Written rules win over mock quirks.
### Keeper frames (Stitch project 12192342757314667328)
- Add person: picture, Name (required), About, Email (optional), "Passed away" toggle. No date fields.
- Edit person: the Rose Morgan frame. Same fields as Add person, one Save. The Mary Morgan Edit person copy is a duplicate, not locked.
- Settings — Your profile: picture, Name, Date of birth (Year required, Month optional, Day only once Month is set), "Who can see it" with four options: Hidden, Year only, Year and month, Full date. About. Save.
- Person profile, signed-in member, owner/co-owner view, with the "Mark as passed away?" confirm dialog (title, Cancel, Mark as passed away).
### Rules
- Shared header: every M14.3 screen uses the locked R2 shared header. Ignore the Timeline/Stories/People bar and the Timeline/Drafts variants drawn in the mocks.
- Edit person opens only for a person who has not signed in. Any tree member can use it, including the Passed away toggle.
- Once a person signs in, nobody else gets Edit person on them, owners included. Owners and co-owners get exactly one action: "Mark as passed away", under a section labeled "Family owners". Other members see no action.
- Birth date: the member's full date is stored; other people, owners and co-owners included, see only the part the member chose (trimmed server-side per Gilfoyle).
- People flagged passed away stay out of "Not invited yet" and the invite-link picker.
### Copy rule (cut from mocks)
- Settings: the "Family Chronicler" badge, the "Helps pin…" helper line, the JPG/PNG file line, the "Changes update…" line, and "Remove".
- Mark as passed away dialog: the body sentence, the "Owner Controls" label (replaced by "Family owners"), and the green online dot.
- Anything else Stitch added that is not in the PRD or an existing M14 rule is cut; no new copy.
### Open
- "Family owners" label is my default; Bill may rename it.
- Undo: for a person already marked passed away, the same Family owners slot shows "Unmark passed away" instead, with a confirm dialog in the same layout (title, Cancel, Unmark passed away). No new screen. LOCKED by Bill 2026-10-16 ("Yes, add an Unmark action").

## #153 amend — story modals, reader top bar, hero picker and carousel, story pills (UX locked 2026-10-30)

Bill, verbatim via Erlich, 10:17 AM CT 2026-10-30: “lock as built for mugatu”. Locks PR #153 @ `dac8bf3` as built. Written rules here supersede M9 and the Edit rules above where they differ. No Stitch regen; the build is the reference. Copy is not locked here; it stays with Jared (Decisions stamp).

1. **Story modals everywhere.** The reader, New story, and Edit always open as the see-through modal: parchment sheet, the page behind dimmed and blurred (M10 standard). That includes a direct URL. In-app navigation pushes the modal so the page stays underneath. Opening Edit from the reader does not stack a second blur.
2. **Publish opens the reader.** Publish replaces the capture modal with the reader modal for that story. Saving an edit returns to the reader.
3. **Reader top bar.** Left: story mark icon and the label. Right: Edit (outlined, only for people who can edit), the ellipsis menu, and close X. Edit no longer sits beside the title. Close goes back one step, or to the timeline when there is nothing behind.
4. **Edit has no Cancel.** Header: Save changes (terracotta) and the close X. **Guard (Jared’s locked rule):** with unsaved edits, the X, back, and any other exit ask save, discard, or stay (“Leave this story?”) before leaving.
5. **Hero picker.** On the Edit photo strip each thumb shows a star at top left on a parchment circle: filled terracotta star on the hero, outline ink star on the others. Tapping a star makes that photo the hero by moving it to first. With no choice made, the first photo is the hero.
6. **Hero carousel.** In the reader, a story with two or more photos shows prev and next chevrons on parchment circles at the hero’s left and right edges, and a horizontal swipe steps too. It wraps around. One photo shows no chevrons. Framing stays as in the #151 amend (own shape, 3:4 to 16:9, whole on parchment).
7. **Origin and branch pills.** In the reader chip row, before people and place: an “Origin” pill (sage icon and text) when the story is an origin, then one pill per family: the story’s own family first, then each branch started from it, A–Z. Pills are filled `#F6F1EB` with a `#E7DECE` border, 20px radius, small tree icon. These are reader pills and do not change the Mid dial’s hollow-ring branch pills.

> ❓ OPEN (Mugatu / Bill): a cold deep link to a story, New story, or Edit has nothing under the see-through modal, so it blurs an empty screen. As built; Bill may choose to load the timeline underneath in a follow-up.

