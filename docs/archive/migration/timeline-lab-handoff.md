# Timeline lab: handoff to the client refactor

The timeline lab (`apps/timeline_lab/`) is a scratch Flutter app that compared timeline renderers, a visual system and iPad behaviour on synthetic data before the Serverpod refactor. This document is what the refactor should take from it. The lab itself is not part of the product: nothing in `apps/tell_me_a_story` imports it, it is not in CI, and its strings are scratch copy that is not subject to the UXD copy rule.

- **Run it:** `just lab` (Chrome) or `cd apps/timeline_lab && flutter run -d chrome|macos`. Tests: `just lab-test` (272 tests, 36 golden PNGs in `apps/timeline_lab/test/goldens/`).
- **Evidence:** `apps/timeline_lab/README.md` has the renderer comparison table, observations, the visual-system notes and the iPad section. The plans that shaped it are `docs/superpowers/plans/2026-11-07-timeline-lab-ui-design-review.md` and `docs/superpowers/plans/2026-11-07-timeline-lab-ipad-review.md` (decisions recorded in each).
- **Status:** complete except iPad Task 22, a frame-time measurement on a real iPad in Safari (release web build). Performance on iPad hardware is **unmeasured**.

## 1. What the lab concluded

| Question | Answer from the lab | Evidence |
|---|---|---|
| Which renderer fits the main timeline? | A lazy sliver list with pinned decade headers (renderer A). It matches today's `ListView` rails (`timeline_page.dart` `_FarRail`, `_MidRail`, `_FullCardRail`), stays lazy, and gets text, semantics and focus from real widgets. | README comparison table, observation 4 |
| What about time-true layouts? | The RenderBox layout is not lazy (about 7 s first frame at 5 000 stories, debug web). The zoom canvas zooms both axes equally, so lanes drift apart at card level; only worth it with x-only zoom. Swimlanes work only at year granularity. | Observations 1, 6; table rows C, D, E |
| Are the tree graph and treemap worth keeping? | As **secondary views**, not the main timeline. The family tree is the only view that shows lineage (branches hang off their origin story). The treemap is the clearest density overview. | Observations 7, 8 |
| Hide or dim when filtering? | Both are useful. Dim keeps context; hide shows real empty stretches on time-true views. Dimmed text never goes lighter than `#6A6358` (`docs/ux/80-all-stories.md`). | Observations 2, 3 |
| Playback? | Works as a presentation feature (sweep = time cursor, steps = story by story); research says animation is weak for analysis beyond about 200 items. | README "Playback", observation 5 |

## 2. What to port

Each item names the lab source to copy from and the app area it lands in. Product decisions are in section 4; items that depend on one say so.

### 2.1 Visual system (into `lib/core/theme/album_theme.dart`)

- **Tokens.** Spacing, radii, strokes, marker sizes and text roles: `LabSpace`, `LabRadius`, `LabStroke`, `LabMarker`, `LabText`, plus the ink and sage tints `labRule`, `labRuleStrong`, `labWatermark`, `labSageTint`, `labSageLine` (`apps/timeline_lab/lib/theme/lab_theme.dart`). The lab's colours are copies of the album tokens, so only the new tints are additions.
- **Selected toggles.** Terracotta pill with a parchment label (5.18:1). The default Material selected colour gives parchment on sage at 3.41:1, which fails WCAG AA. Lab: `segmentedButtonTheme` in `lab_theme.dart`.
- **Story markers.** Filled = match, hollow ring = dimmed (instead of 35% opacity, which reached only about 1.5:1), moss ring = branch origin, outer terracotta ring = selected. All story dots are terracotta; family shows through lanes and labels, and moss stays reserved for branches. Lab: `lib/renderers/story_marker.dart`.
- **Corners.** Two families. Pills (stadium) for small tappable controls: segmented switches, filter chips, tags, badges. Containers get continuous (superellipse) corners on a 4 / 8 / 12 / 16 scale, with nested containers using the outer radius minus the gap. Text fields use `LabFieldBorder`, a superellipse `InputBorder` paired with hint text, because `OutlineInputBorder` draws circular corners and cuts a notch for a floating label. Lab: `labContainerShape`, `LabFieldBorder` in `lab_theme.dart`. The app today uses circular 8/12/16 radii and 8 px chips.
- **Chip label fade (bug, likely present in the app).** On the web, `RawChip` fades its whole label top to bottom when the real text layout comes out a fraction of a pixel taller than its dry layout, which happens with the brand fonts. Fix: give chip labels `maxLines: 1, overflow: TextOverflow.ellipsis` (lab: `_ChipLabel` in `lib/widgets/filter_panel.dart`). The app uses chips in `drafts_page.dart`, `start_timeline_dialog.dart`, `invite_modal.dart`, `search_page.dart` and `new_story_page.dart`. [UNVERIFIED in the app: check those screens on web before and after.]
- **Card.** Parchment album card with sage-line border; compact cards keep the serif title. Lab: `lib/widgets/story_card.dart`.

### 2.2 Shared timeline primitives

These replaced four copies of the year-to-pixel maths, three axis painters and hand-rolled `TextPainter`s in the lab. The app's `timeline_page.dart` (3 775 lines) has the same kind of duplication across its rails.

| Primitive | Lab file |
|---|---|
| `TimeScale`: the only year ↔ px mapping (pair it with `LabStory.fractionalYear`, which divides by the year's real day count so Dec 31 of a leap year stays in its year) | `lib/renderers/time_scale.dart` |
| `paintTimeAxis` / `paintSpineLabels`: one axis look | `lib/renderers/time_axis_painter.dart` |
| `CanvasLabel` / `paintLabel`: canvas text | `lib/renderers/canvas_label.dart` |
| `MarkerSpec` / `paintStoryMarker` / `StoryDot` | `lib/renderers/story_marker.dart` |
| `ViewSwitch`, `EmptyTimeline` | `lib/widgets/` |

### 2.3 iPad behaviour

The lab is checked at 11 iPad sizes (iPad mini, Air and 12.9" Pro in both orientations, Split View ⅓ and ½, Slide Over) by no-overflow tests, plus goldens at iPad mini portrait, landscape and Slide Over.

- **Breakpoints.** At 900 pt and wider, persistent filter sidebar. Below 900 pt, filters move to an end drawer whose header shows the live match count. Below 600 pt, the playback bar and selected-story panel stack, and the panel is capped at 30% of the height (`LabBreakpoint`).
- **Insets.** The keyboard never squeezes the timeline, and the bottom bars clear the home indicator.
- **Touch.** A finger gets a 22 pt radius around painted points (`LabTarget`, `hitRadiusFor` in `lib/input/pointer_input.dart`). When several stories share one target, a chooser lists them all (`lib/widgets/story_chooser.dart`). A finger tap on a treemap cell smaller than 44 pt opens its group.
- **Keyboard.** Space plays or pauses, arrows step, ⌘F focuses search, Esc closes the drawer first and then clears the selection. Space and the arrows only act when no control has focus. Shortcuts are in `lib/shell/lab_shortcuts.dart`; the actions and their guards are in `lib/lab_app.dart`. Mouse drag does **not** pan (decision D-i4).
- **State across layout changes.** One `Flex` serves both layouts, so the renderer keeps its scroll, zoom and view mode across the breakpoint and on rotation. A filter with no matches keeps the renderer mounted (offstage, out of the focus order) so its state survives.

### 2.4 Playback (only if the product wants it; section 4)

- Reveal is a pure function of a clock (`PlaybackSchedule`), and every renderer lays out all stories and fades them in where they sit ("ghost layout"), so nothing reflows and scrubbing backwards is free.
- The clock is a raw `Ticker`, not an `AnimationController`, because the latter runs at 5% of its duration when the platform disables animations. Reduced motion (`disableAnimations` or iOS Reduce Motion) makes reveals instant.
- Badges count revealed stories only, so they never leak the future.
- Lab: `lib/playback/`, `lib/widgets/playback_bar.dart`.

## 3. What not to port

- The synthetic data (`lib/model/seed.dart`) and the lab's `LabController`; the app has its own data gateways and state.
- The renderer switch, dataset-size menu and performance overlay; they exist to compare renderers.
- The painter rail (removed in the lab; it duplicated the zoom canvas's years level).
- The RenderBox layout as a main view (not lazy).
- Lab copy strings.

## 4. Open decisions for the refactor

1. **Main timeline view.** Recommended: sliver list (renderer A) with the shared primitives and the visual system. Alternative: keep the app's current three-rail zoom structure and port only the visual system and iPad rules.
2. **Secondary views.** Ship the family tree and/or the treemap, or keep them in the lab.
3. **Playback.** Ship it (sweep, steps or both) or not.
4. **When.** These are client-only UI changes and don't depend on the Serverpod phases. Phase 4 (client cutover) rewrites the gateways that `timeline_page.dart` calls, so doing the timeline UI after Phase 4 avoids two large concurrent changes to the same screen.
5. **iPad performance.** Profile a release web build in Safari on a real iPad (lab iPad Task 22) before committing to a renderer that paints every node (the tree graph) at large sizes.
