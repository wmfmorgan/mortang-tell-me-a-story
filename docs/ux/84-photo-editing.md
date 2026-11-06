# #84 Photo editing

**Status: LOCKED rev 1.1 — 2026-11-06 8:24 AM CT** (delta: hero display change dropped; already fixed by #151). Rev 1.0 locked 8:16 AM CT. Bill, in his 1:1: screens "i approve!" (8:15); Q1 "Rotate only"; Q2 "Edits follow the draft" (8:16).

Open UI questions: none. Stitch links and previews: [Stitch screens](#stitch-screens).

## Sources

Read only the requested linked sources and named sections:
- PRD, **“### Photo editing”** (approved rev 1, 2026-11-06 8:02 AM CT): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2
- Decisions, **“## 2026-11-06: Photo editing”** (approved rev 1): https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166
- [GitHub issue #84](https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/84) body: “The large photo image on the full story card needs to be adjustable, it also zooms in too far and cuts off the top.”
- Bill’s supplied editor reference: rounded frosted bottom tool sheet, round labeled tools, selected filled tool, X/apply actions. Adapted for still photos; video Trim/filmstrip are not carried over.

## Scope

**Primary user and job (PRD):** story authors tidying photos attached to a story. After publish, edit access is the same as story editing: author plus owners/co-owners.

**V1:** crop, rotate, text, a built-in sticker set, brightness/contrast, undo and reset to original, including reset after save. Keep the original; the story shows the edited copy. The edited copy replaces that photo everywhere the story shows it: reader, carousel and hero.

## Entry points

1. **While attaching:** each attached photo card has a 44×44 **Edit photo** action alongside the existing remove affordance. It opens the editor with that image. Save returns to the attachment flow with the edited preview; Cancel returns without committing this editing session. The original remains retained after save.
2. **From the story’s existing photos:** authorized users see **Edit** in the photo detail/carousel view, not over the story hero. Saving returns to that photo and its new edited copy appears in reader, carousel and hero. **Reset to original** lives beside Edit and appears only when that photo has edits (**Mugatu pick**).

## Editor layout

- Tokens: parchment `#FBF7F2`, ink `#2C2416`, terracotta `#8B5E4B` for selected/primary, sage `#7A8B74` for supporting details, branchMoss `#5B7F3A` sparingly. No glow.
- **Phone:** a header with **Edit photo**, X Cancel at left, Undo and Redo at right. The remaining viewport is photo canvas. A rounded parchment tool sheet sits at the bottom with a 32×4 grab handle and 24px top radii. “Frosted” means a faint parchment veil over the photo only; the sheet keeps an opaque parchment reading surface, a visible border and no glow. Below contextual controls: a horizontally scrollable row of five 56px circular icons with text labels, ordered **Crop · Rotate · Text · Stickers · Adjust** (**Mugatu pick**). Selected tool = filled terracotta icon circle with a 3px border and selected semantics. A bottom action row holds **Cancel** and a 48px-high terracotta **Save** button.
- **Web / ≥840px:** same controls and order, in a 360px right-hand tool rail rather than covering the canvas. X Cancel / title remain top-left; Undo / Redo top-right; Cancel and Save sit at the bottom of the rail. Canvas receives remaining width. At 600–839px use the phone bottom sheet within the available width. Never shrink targets to keep five tools visible; scroll the row.
- **Canvas:** image starts fully visible and centered; zoom with pinch/wheel and the 44×44 minus/plus controls (**Mugatu pick**). All editing previews are live. Dragging text/stickers takes precedence over canvas pan only while dragging its selected handle/body. No filmstrip, Canvas tool, Trim or Bg.
- **Loading:** retain the editor frame with a skeleton canvas and progress label **Preparing photo…**. Disable all tools, Cancel remains available. After Save show **Saving photo…**, disable repeated save and all editing.
- **Load error:** inline state in the canvas, **Couldn’t open this photo.** + **Retry** + **Back**. **Save failure:** preserve the current canvas and history, re-enable editor and show **Couldn’t save your edits. Try again.** + **Retry**. No silent discard or automatic retry.
- **Reset failure:** preserve the edited photo, close no data, show **Couldn’t restore the original. Try again.** + **Retry**.

## Tools

### Crop

Drag corner/edge handles; subtle thirds grid appears while adjusting. Aspect presets in this order: **Free** (initial), **Original**, **1:1**, **4:3**, **3:4**, **16:9** (**Mugatu pick**). Presets anchor around image center, retain maximum available image and remain draggable. **Re-center crop** restores centered maximum crop within the selected ratio. No automatic zoom beyond the crop needed to fill the selected ratio. Allow direct manipulation plus keyboard-operable handle controls.

### Rotate

Buttons **Rotate left 90°** and **Rotate right 90°**, each a discrete undoable step. Crop bounds stay inside the rotated image. No flip in v1 (LOCKED, Bill: "Rotate only").

### Text

**Add text** creates one centered, selected text layer; editing existing text uses a focused text field. One font only: the app’s restrained serif (**Mugatu pick**). Size 16–96px via labeled slider plus accessible numeric field; initial 32px. Color choices: parchment, ink, terracotta, sage and branchMoss; swatches expose their color names and selected state. Drag to move, pinch or corner handle to scale. Selected layer has visible bounds and **Delete text**. Text may wrap; no alignment/rotation controls in v1 (**Mugatu pick**). Multiple text layers supported. Overlaid text is decorative to assistive technology; users must not be told it supplies the photo’s alt text.

### Stickers

Tray of twelve built-in line-art choices, four columns on phone and right rail, each with a visible name and 44×44 minimum target: **Heart, Star, House, Tree, Leaf, Flower, Sun, Birthday cake, Gift, Camera, Book, Music note** (**Mugatu pick**). Thin ink line art with only terracotta/sage/branchMoss accents; no upload action.

Tap adds a selected sticker at canvas center. Drag to move, pinch/corner handle to scale, top rotate handle to rotate; **Delete sticker** removes selected sticker. Multiple stickers supported. A small +/− stepper provides non-gesture scaling and a **Rotate sticker 15°** button provides non-gesture rotation (**Mugatu pick**).

### Adjust

Independent **Brightness** and **Contrast** sliders, each −100…0…+100, initially 0, with current numeric value and left/right keyboard operation. Each has **Reset brightness** / **Reset contrast** which sets only that slider to 0 as one undoable step (**Mugatu pick**). Preview updates live. No filters or effects.

## Undo/Reset/Save rules

- Each completed crop commit, rotation, text/sticker add/edit/delete/move/scale/rotate gesture, brightness/contrast gesture and per-slider reset pushes one history entry. Undo steps backward; any new edit after Undo clears Redo. Switching tools, selection and zooming the viewport do not create history. Controls are disabled at their respective ends (**Mugatu pick**).
- Undo/Redo apply only within this editing session. Saved state is not silently rewritten by an old session.
- X/Cancel with no changes closes immediately. With changes it asks **Discard edits?** / **Your changes to this photo won’t be saved.** / **Keep editing** (default focus) / **Discard edits**. Browser back or Escape uses the same guard. Discard retains previous saved copy.
- Save writes a new edited copy, retains the original, closes editor and refreshes every representation of this photo (reader, carousel, hero) when those views next render. Save is disabled when unchanged or during a save.
- **Reset to original** after a saved edit is available beside Edit in existing-photo detail and in the editor header. It asks the confirmation below. On confirmation it clears the saved edited copy and restores original everywhere this photo appears. Original file is never deleted by editing or resetting.
- **Reset edits** inside an active editor returns the canvas to its state at opening, as one undoable action; it is distinct from post-save **Reset to original** (**Mugatu pick**).

## Hero-crop response

**No hero display change in #84 (rev 1.1).** The issue's "zooms in too far and cuts off the top" was already fixed on main by [PR #151](https://github.com/wmfmorgan/mortang-tell-me-a-story/pull/151) (235df7c, 2026-10-29, "show reader and card photos whole"): the reader's large photo (`photo_frame.dart`) and the timeline card photo use `BoxFit.contain` on a parchment field, so the whole photo shows. Keep `contain`; do not switch any surface to `cover` + `topCenter`. The Family Landing featured hero (16:9 `cover`, locked in 79-family-landing) is unchanged. "Adjustable" in the issue is met by the editor's Crop tool, and the cropped copy shows everywhere per the Save rules.

## Accessibility

- Every icon-only button has a specific semantics label and tooltip: Cancel, Undo, Redo, zoom in/out, rotate, layer deletion and per-slider reset. Selected tools/presets expose selected state. Stickers have visible names.
- All targets at least 44×44 including swatches, handles’ interaction regions, tool icons and tray tiles. Visible keyboard focus uses a solid 2px ink or parchment contrast ring appropriate to its backdrop, not glow. DOM focus order follows canvas → contextual controls → tools → actions; modal focus is trapped, starts on Keep editing/Keep edits, and returns to invocation on close.
- Text and icons meet WCAG AA (4.5:1 normal text, 3:1 large text and meaningful controls). Verify final implementation rather than trusting palette choices alone. Text placed over imagery needs a contrasting parchment or ink backing selected automatically or manually; swatch alone cannot guarantee photo contrast.
- Sliders expose name, value and bounds and support arrow keys. All drag/pinch operations have button or keyboard equivalents. Escape invokes the unsaved guard, not data loss.
- Progress and errors are announced politely; save failure moves focus to error heading. Respect reduced motion with no transition longer than 150ms. Decorative added layers do not replace useful photo alt text.

## Copy strings needing Jared’s stamp

| # | Where | Proposed string |
|---|---|---|
| 1 | Editor title | Edit photo |
| 2 | Attach entry | Edit photo |
| 3 | Existing photo | Edit |
| 4 | Tools | Crop / Rotate / Text / Stickers / Adjust |
| 5 | Crop presets | Free / Original / 1:1 / 4:3 / 3:4 / 16:9 |
| 6 | Crop action | Re-center crop |
| 7 | Rotation | Rotate left 90° / Rotate right 90° |
| 8 | Text actions | Add text / Delete text |
| 9 | Text settings | Font / Size / Color |
| 10 | Sticker setting | Delete sticker |
| 11 | Adjust settings | Brightness / Contrast |
| 12 | Slider reset | Reset brightness / Reset contrast |
| 13 | Global actions | Cancel / Save / Undo / Redo |
| 14 | Current-session reset | Reset edits |
| 15 | Post-save reset | Reset to original |
| 16 | Unsaved title | Discard edits? |
| 17 | Unsaved body | Your changes to this photo won’t be saved. |
| 18 | Unsaved actions | Keep editing / Discard edits |
| 19 | Load progress | Preparing photo… |
| 20 | Save progress | Saving photo… |
| 21 | Load error | Couldn’t open this photo. |
| 22 | Load actions | Retry / Back |
| 23 | Save error | Couldn’t save your edits. Try again. |
| 24 | Reset title | Reset to original? |
| 25 | Reset body | This removes the edits everywhere this photo appears. Your original photo will be restored. |
| 26 | Reset actions | Keep edits / Reset |
| 27 | Reset error | Couldn’t restore the original. Try again. |
| 28 | Zoom semantics | Zoom in / Zoom out |
| 29 | Sticker keyboard action | Rotate sticker 15° |

**29 numbered entries**; combined labels in a cell are one stamp row, not separate strings.

## Resolved UI questions

1. **Flip:** LOCKED rotate-only, 90° steps; no horizontal/vertical flip (Bill, 2026-11-06 8:15 AM CT: "Rotate only").
2. **Attach-time edits:** LOCKED to follow the existing draft-photo lifecycle; if the draft is discarded, its photo edits go with it. No new retention promise (Bill, 2026-11-06 8:16 AM CT: "Edits follow the draft").

All other unspecified choices above are pure UI choices expressly labeled **Mugatu pick**.

## Out of scope

Per PRD: drawing/freehand markup; red-eye, blur and retouching; custom sticker uploads; profile/family photo editing. Filters/color effects and frames/borders are nice-to-haves only and later deltas, not v1. Video Trim/filmstrip, multi-photo batch edits, focal-point editing and typography libraries are also not v1.

## Stitch screens

Project: `12876921041580101222` — https://stitch.withgoogle.com/projects/12876921041580101222

| Screen / purpose | Screen id | Link | Local PNG |
|---|---|---|---|
| A — attach photo with Edit entry | `05697e0ccc0e49fdb8b6e68dc1be31d0` | https://stitch.withgoogle.com/projects/12876921041580101222/screens/05697e0ccc0e49fdb8b6e68dc1be31d0 | `/workspace/pr84-photo-editing/stitch/A.png` |
| B — Crop | `e5d83fca99534d45b338a5845b09425f` | https://stitch.withgoogle.com/projects/12876921041580101222/screens/e5d83fca99534d45b338a5845b09425f | `/workspace/pr84-photo-editing/stitch/B.png` |
| C — Text | `742a49eaed1548118a68ec238cd13538` | https://stitch.withgoogle.com/projects/12876921041580101222/screens/742a49eaed1548118a68ec238cd13538 | `/workspace/pr84-photo-editing/stitch/C.png` |
| D — Sticker tray | `4acd82705e9f41eca68202aa75388242` | https://stitch.withgoogle.com/projects/12876921041580101222/screens/4acd82705e9f41eca68202aa75388242 | `/workspace/pr84-photo-editing/stitch/D.png` |
| E — Adjust | `a287332db6fa4519abacc15af61396ec` | https://stitch.withgoogle.com/projects/12876921041580101222/screens/a287332db6fa4519abacc15af61396ec | `/workspace/pr84-photo-editing/stitch/E.png` |
| F — Story photo + reset confirmation | `e2ab2e0b51af4d63b641fbf5d4ada5b7` | https://stitch.withgoogle.com/projects/12876921041580101222/screens/e2ab2e0b51af4d63b641fbf5d4ada5b7 | `/workspace/pr84-photo-editing/stitch/F.png` |

Screens are visual direction, not authorization for unapproved embellishments. E is a wide Stitch render of the phone-width editor; the phone-rail stack and wide-web right rail above govern responsive behavior. B contains exploratory extra controls (flip/leveling) not part of v1; use required crop presets and handles only. F’s decorative archival metadata is not required copy. The written rules above supersede those rendering deviations.
