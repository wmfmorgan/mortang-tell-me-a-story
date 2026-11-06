# #84 Photo editing

**Status: LOCKED rev 1.2 — 2026-11-06 2:16 PM CT; pending Bill via Erlich** (delta: F-04 conflict/reload and dirty-work interactions; F-05 exact sticker assets and existing serif). Rev 1.1 locked 8:24 AM CT (delta: hero display change dropped; already fixed by #151). Rev 1.0 locked 8:16 AM CT. Bill, in his 1:1: screens "i approve!" (8:15); Q1 "Rotate only"; Q2 "Edits follow the draft" (8:16).

Changelog: rev 1.2 adds the version-conflict dialog and explicit retry, the dirty reload guard, twelve original bundled SVG sticker IDs/files, and the existing `GoogleFonts.literata` Text-tool identifier; no prior editor, hero or tool behavior changes.

Open UI questions: **F-04 interaction picks below, pending Bill via Erlich.** These close the spec’s open behavior choices; Jared still stamps C30–C37. Stitch links and previews: [Stitch screens](#stitch-screens).

## Sources

Read only the requested linked sources and named sections:
- PRD, **“### Photo editing”** (approved rev 1, 2026-11-06 8:02 AM CT): https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2
- Decisions, **“## 2026-11-06: Photo editing”** (approved rev 1): https://app.notion.com/p/3e0c4bcef238818d8f00c50e88a46166
- Implementation spec, **§17 Open questions** and its directly cited **§9 API / interface contracts** and **§10 Client behavior lock**: https://app.notion.com/p/822c4bcef238827faf560187425383b2
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

**Add text** creates one centered, selected text layer; editing existing text uses a focused text field. One font only: **Literata**, via `GoogleFonts.literata()`, the app’s existing restrained body serif (**Mugatu pick**). Do not introduce a second editor font. Evidence at main `9213fd7e28653d563410b5005f4927528b5b3fe8`: `apps/tell_me_a_story/lib/core/theme/album_theme.dart:62–64` applies `GoogleFonts.literata` to bodyLarge/bodyMedium/bodySmall; the same file’s headings use `GoogleFonts.newsreader` at lines 38, 42, 46, 50 and 54. `apps/tell_me_a_story/pubspec.yaml:45` has `google_fonts: ^8.2.1`; lines 71–72 list the only bundled asset and lines 80–96 are commented font examples, so there is **no bundled serif or active `fonts:` family declaration**. Use the existing runtime Google Fonts identifier `GoogleFonts.literata`, not an invented bundled family. Size 16–96px via labeled slider plus accessible numeric field; initial 32px. Color choices: parchment, ink, terracotta, sage and branchMoss; swatches expose their color names and selected state. Drag to move, pinch or corner handle to scale. Selected layer has visible bounds and **Delete text**. Text may wrap; no alignment/rotation controls in v1 (**Mugatu pick**). Multiple text layers supported. Overlaid text is decorative to assistive technology; users must not be told it supplies the photo’s alt text.

### Stickers

Tray of twelve built-in line-art choices, four columns on phone and right rail, each with a visible name and 44×44 minimum target: **Heart, Star, House, Tree, Leaf, Flower, Sun, Birthday cake, Gift, Camera, Book, Music note** (**Mugatu pick**). Thin ink line art with only terracotta/sage/branchMoss accents; no upload action.

Exact twelve stable IDs and files, in tray order; paths are relative to `apps/tell_me_a_story/`. Add `assets/stickers/` to the existing `flutter.assets` list (`pubspec.yaml:71–72`); do not add a new top-level assets folder.

| ID | Bundled asset | sha256 |
|---|---|---|
| `heart` | `assets/stickers/heart.svg` | `6e43e3b859248d2d18fa0975304b5f9f31bf0f2e0bbada1ee53eab4c999b964e` |
| `star` | `assets/stickers/star.svg` | `ecf0cadcea79910e02449319ad6587b572bc1867f8ee840e373117780249e469` |
| `house` | `assets/stickers/house.svg` | `fbcc2507eef45241dd5cbe6397c1862c0f52f4a527539ccea941c00a0cf688b0` |
| `tree` | `assets/stickers/tree.svg` | `f5db066ad426f9b774099301511e3b7e809e564dd2aac809261a7a2b4d4cdde1` |
| `leaf` | `assets/stickers/leaf.svg` | `4284abca60b75b941dae039f5fe399f9fb7797702cced5a41cd79a47948ddd1d` |
| `flower` | `assets/stickers/flower.svg` | `4e373213656d739273a25f43658f6d4c9ec38b377e0174ba74f5c576b5c74b76` |
| `sun` | `assets/stickers/sun.svg` | `1d45060017a7d704141597c5725a4a2921d391f8bb56ebc33fbb431206d0e1b5` |
| `birthday_cake` | `assets/stickers/birthday_cake.svg` | `1729ad56a429ea31ee16fc2adfe69b18aff414ac0d4cb2f2282e1d285b73a043` |
| `gift` | `assets/stickers/gift.svg` | `4015476f0d6ec0f09acaee2a4654b61ddcf74b9a34f70ff8255b9b13ecce320b` |
| `camera` | `assets/stickers/camera.svg` | `0be1a8f0cab5724ce2eff15d6d336cc04ce9735b67d468e8c72bfcd3c881289f` |
| `book` | `assets/stickers/book.svg` | `01c4ba4b607ca5f014bec34bc94c89d6e05667ce8a914a21117521766c37b49b` |
| `music_note` | `assets/stickers/music_note.svg` | `3b2829f02094d3d4e2cf6a2ade36f21783a3d7e896dc1473642acc1c56c01c9d` |

Source files and contact sheet are in `/workspace/pr84-photo-editing/stickers/` (`contact.png`, sha256 `bc57c6593583414125916333639dbdc959d5e49e8684e1a23a3857f22a654535`). Copy the twelve SVGs to the repo paths above. **License/provenance:** original work created for this repository by Mugatu; no bought, copied or third-party assets. Flat 256×256 viewBox, ink outline, palette-only fills, parchment keyline; no gradients, glow, text or external fonts. SVG `role="img"` labels name the tray artwork; interactive tile names remain the accessibility contract.

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

## Conflict, retry and reload (F-04)

The spec saves and resets by compare-and-swap against the photo’s **opened `edit_version` N**. A zero-row/`CONFLICT: photo edit version` result means another session saved or reset first. Retain the current canvas and history; never silently overwrite, merge, rebase, reload or retry. These rules add no recovery/export feature.

### Version conflict on Save or Reset to original

- **Trigger:** the save/reset RPC reports `CONFLICT: photo edit version`. Stop the pending operation and remove only the unused candidate per the spec; the previous saved copy remains active. This is not the generic save/reset failure state.
- **Presentation:** a modal parchment dialog centered within the safe viewport, maximum width 400px, over the unchanged editor. On phone it sits above the bottom tool sheet; at ≥840px it sits above canvas and 360px right rail. Do not turn the tool sheet/rail into an error screen. Ink text, visible border, AA contrast, no glow; all actions ≥44×44.
- **Copy and order:** title **This photo changed in another session.** Body **Your work is still here. Try again, or load the latest photo and let your unsaved edits go.** Actions in reading order: primary **Try save again** (or **Try reset again** for the reset flow), secondary destructive **Load latest**, text **Keep editing**. **Keep editing** receives initial focus and is the safe/default action, including Enter when no other button was explicitly focused.
- **Keep editing / dismiss:** close only the dialog, restore focus to Save or Reset, and retain the exact canvas, selection and history. Escape, Android/system back, scrim tap and browser back while this dialog is open do this; they never choose reload or discard. A further back/Escape with no dialog uses the ordinary dirty Cancel guard.
- **Try save/reset again:** explicitly re-read the latest stored row/version, retain the local edited canvas/history, then retry that same operation once against the newly read version. For save, generate the next candidate from that version; do not reuse a stale candidate path. The user’s explicit action, not an automatic rebase, authorizes this retry. Keep the conflict dialog closed and show the existing Saving photo… state. Success closes/refreshes as usual. Another conflict reopens this dialog; transport/storage failure uses C23 or C27 with the existing Retry, still preserving work. No automatic retry loop.
- **Load latest:** if the session has unsaved edits, replace the conflict dialog with the dirty reload confirmation below. If clean, load the latest effective photo and opened version immediately. A confirmed reload replaces the canvas and clears session undo/redo; it never deletes the original or silently resets a newer saved edit. After loading, the editor remains open and Save is enabled only after a new edit.
- Reset-specific conflict copy does not imply that **Try reset again** saves in-progress edits: it explicitly retries clearing the saved edited copy at the latest version while retaining this session’s canvas/history on failure. On reset success, follow the existing Reset to original behavior.

### Dirty reload, refresh or navigation

- **Trigger:** with edits not yet saved in this session, any in-app request to reload the photo, browser/page refresh, route/back navigation, X/Cancel, or closing the editor. X/Cancel, route/back and Escape keep the existing C16–C18 **Discard edits?** flow. **Load latest** from a conflict or another explicit photo-reload request uses **Load latest photo?** below. Clean sessions reload/close without a dirty-work dialog.
- **Dialog:** **Load latest photo?** / **Your unsaved edits will be replaced. Your latest saved photo will be loaded.** Actions: primary safe **Keep editing**, secondary destructive **Load latest**. Match the conflict dialog’s responsive placement, targets and no-glow styling. Initial focus **Keep editing**; Escape, system back and scrim tap cancel reload and restore focus to its invoking control. Do not put a destructive action on Enter by default.
- **Browser/OS limits:** register the platform’s unsaved-changes prompt for refresh/tab close while dirty. Use the browser’s native prompt and wording where custom dialogs are not supported; never claim the custom dialog will survive forced process termination. Returning to a still-live dirty editor preserves its canvas/history. No autosave, draft recovery or cross-session restore is added.
- **Retry while dirty:** ordinary save/reset failure Retry repeats that same operation only on an explicit tap and preserves canvas/history; it does not reload or discard. Reload failure retains the current canvas/history and returns to the conflict/reload dialog with the existing **Couldn’t open this photo.** + **Retry** + **Back**; Back means Keep editing here, not discard. Never show a blank editor while recoverable local work exists.

## Hero-crop response

**No hero display change in #84 (rev 1.1).** The issue's "zooms in too far and cuts off the top" was already fixed on main by [PR #151](https://github.com/wmfmorgan/mortang-tell-me-a-story/pull/151) (235df7c, 2026-10-29, "show reader and card photos whole"): the reader's large photo (`photo_frame.dart`) and the timeline card photo use `BoxFit.contain` on a parchment field, so the whole photo shows. Keep `contain`; do not switch any surface to `cover` + `topCenter`. The Family Landing featured hero (16:9 `cover`, locked in 79-family-landing) is unchanged. "Adjustable" in the issue is met by the editor's Crop tool, and the cropped copy shows everywhere per the Save rules.

## Accessibility

- Every icon-only button has a specific semantics label and tooltip: Cancel, Undo, Redo, zoom in/out, rotate, layer deletion and per-slider reset. Selected tools/presets expose selected state. Stickers have visible names.
- All targets at least 44×44 including swatches, handles’ interaction regions, tool icons and tray tiles. Visible keyboard focus uses a solid 2px ink or parchment contrast ring appropriate to its backdrop, not glow. DOM focus order follows canvas → contextual controls → tools → actions; modal focus is trapped, starts on Keep editing/Keep edits, and returns to invocation on close.
- Text and icons meet WCAG AA (4.5:1 normal text, 3:1 large text and meaningful controls). Verify final implementation rather than trusting palette choices alone. Text placed over imagery needs a contrasting parchment or ink backing selected automatically or manually; swatch alone cannot guarantee photo contrast.
- Sliders expose name, value and bounds and support arrow keys. All drag/pinch operations have button or keyboard equivalents. Escape invokes the unsaved guard, not data loss.
- Conflict/reload dialogs have programmatic titles, alert-dialog semantics and trapped focus; initial focus Keep editing, with focus returned to the invoking control. Retry progress and errors are announced politely. Save failure or a failed reload moves focus to its error heading. Respect reduced motion with no transition longer than 150ms. Decorative added layers do not replace useful photo alt text.

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
| 30 | Conflict title | This photo changed in another session. |
| 31 | Conflict body | Your work is still here. Try again, or load the latest photo and let your unsaved edits go. |
| 32 | Conflict retry actions | Try save again / Try reset again |
| 33 | Conflict load action | Load latest |
| 34 | Conflict safe action | Keep editing |
| 35 | Dirty reload title | Load latest photo? |
| 36 | Dirty reload body | Your unsaved edits will be replaced. Your latest saved photo will be loaded. |
| 37 | Dirty reload actions | Keep editing / Load latest |

**37 numbered entries**; combined labels in a cell are one stamp row, not separate strings. C1–C29 are unchanged; C30–C37 are new and need Jared’s stamp.

## Resolved UI questions

1. **Flip:** LOCKED rotate-only, 90° steps; no horizontal/vertical flip (Bill, 2026-11-06 8:15 AM CT: "Rotate only").
2. **Attach-time edits:** LOCKED to follow the existing draft-photo lifecycle; if the draft is discarded, its photo edits go with it. No new retention promise (Bill, 2026-11-06 8:16 AM CT: "Edits follow the draft").

3. **F-04 interaction picks (pending Bill via Erlich):** centered modal on both responsive layouts; Keep editing as default focus/safe action; explicit version-refreshing retry rather than automatic retry/rebase; destructive Load latest always confirmed when dirty; browser-native prompt when refresh/tab-close cannot show the custom dialog. No new persistence, merge or recovery scope.
4. **F-05 asset/font picks:** stable IDs/files above; original SVG artwork licensed for this repo; Text uses the existing `GoogleFonts.literata` identifier only. Stickers and Text remain in scope; “Rotate only” only excluded flip.

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
