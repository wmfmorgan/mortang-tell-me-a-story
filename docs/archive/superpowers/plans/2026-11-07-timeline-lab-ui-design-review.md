# Timeline Lab UI Design Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify lab visual system, align graphic style with Memory Album brand. One time scale, one axis look, one marker vocabulary, fewer shell controls, token-driven type/spacing/color. All scoped to `apps/timeline_lab/`.

**Architecture:** Three phases.
- **Phase 1** extracts shared primitives (`TimeScale`, `CanvasLabel`, cursor/camera helpers, one story colour), consolidates shell controls. Tasks 2–4 golden-neutral refactors.
- **Phase 2** adds design tokens (`LabSpace`, `LabRadius`, `LabStroke`, `LabMarker`, `LabText`, rule/sage tints) to `lab_theme.dart`. Fixes component themes, restyles `StoryCard`, introduces one marker primitive.
- **Phase 3** restyles each renderer on top: shared axis painter, zoom bubbles, tree edges + labels, treemap shading, list + lane text roles, empty state.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 (pinned in `mise.toml`), `google_fonts` only, `flutter_test` goldens. No new deps.

All commands run from `apps/timeline_lab` unless noted.

**Gate** (must stay green after every task): `flutter analyze` (0 issues) · `dart format --output=none --set-exit-if-changed .` (exit 0) · `flutter test` (all pass; baseline 104).

---

## Findings

Ranked by user impact. Evidence uses `file:line` in `apps/timeline_lab/` at `bdd128d`, plus golden names in `test/goldens/`. Contrast ratios computed with WCAG 2.x formula from token hex. Golden pixels sampled with PIL.

1. **High · a11y/brand. Selected segmented buttons fail text contrast everywhere.**
   - Every selected segment = parchment label on sage, **3.41:1** (below 4.5:1). Covers Hide/Dim, Sweep/Steps, People/Families, Time/Family, Decade/Family/Person.
   - Cause: `lib/theme/lab_theme.dart:54-65` sets no `secondaryContainer`, so M3 `SegmentedButton` falls back to `secondary` (sage) + `onSecondary` (parchment).
   - Evidence: selected "Dim" segment in `sliverList_all.png` samples `(122,139,116)`, exactly `labSage`.
   - Product lock = filled **terracotta** pill, parchment label (`docs/ux/80-all-stories.md:64`), 5.18:1.
2. **High · legibility. Dimmed markers near-vanish; colour/opacity only signal.**
   - Dimming multiplies dot alpha by `labDimOpacity` 0.35 (`lib/renderers/story_marker.dart:18`). Same pattern in `painter_rail_renderer.dart:357`, `sliver_list_renderer.dart:176`, `zoom_canvas_renderer.dart:375`, `swimlanes_renderer.dart:357`, `tree_graph_renderer.dart:298`.
   - On parchment: **1.62:1** (terracotta), **1.45:1** (sage), **1.55:1** (moss), below 3:1 non-text min.
   - Visible in `painterRail_dim.png` (dim dot samples `(212,193,184)`) and `treeGraph_dim.png`.
   - Dimmed *text* correct everywhere. Sampled glyphs in sliver, RenderBox, swimlane, tree, treemap `_dim` goldens exactly `#6A6358` (5.56:1), meets floor in `docs/ux/80-all-stories.md:79`.
3. **High · colour system. Family palette ambiguous, spends product's reserved green.**
   - Terracotta, sage, moss differ only 1.20–1.52:1 luminance.
   - Machado deuteranopia sim: terracotta vs moss 18.8 RGB units apart (60.7 normal vision).
   - `lib/renderers/story_marker.dart:8-12` makes moss Okafor family colour; moss also origin ring (`painter_rail_renderer.dart:360`, `tree_graph_renderer.dart:303`). Okafor origin story = moss ring around moss dot.
   - Product reserves branch green for origin ring + callout ("One green", `docs/ux/branch-callout.md:42-43`). Story dots stay terracotta (`docs/ux/branch-callout.md:23`).
4. **High · simplification. Core primitives duplicated across renderers.**
   - **Year→px mappings (4):** `painter_rail_renderer.dart:94-97`; `zoom_canvas_renderer.dart:79-80`, re-derived inline at `:543`, `:557`, `:342`; `render_box_layout_renderer.dart:307`; `swimlanes_renderer.dart:99-101` and `:114-115`.
   - **Axis/tick painters (3), each own look:**
     - `painter_rail_renderer.dart:314-332`: ink 60%, 10/4 px ticks.
     - `render_box_layout_renderer.dart:362-381` and `:418-440`: full ink 2 px spine, 16/6 px ticks, pill labels.
     - `zoom_canvas_renderer.dart:537-565`: ink 60%, 12/6/3 px ticks.
   - **`TextPainter` boilerplate (6 sites):** `painter_rail_renderer.dart:302`, `:385`; `render_box_layout_renderer.dart:425`; `zoom_canvas_renderer.dart:523`; `tree_graph_renderer.dart:217`, `:282`.
   - **Playback-cursor painters (4):** `painter_rail_renderer.dart:396-406`, `render_box_layout_renderer.dart:404-414`, `zoom_canvas_renderer.dart:566-575`, `swimlanes_renderer.dart:261-290`.
   - **"Follow at 65%" copies (3):** `painter_rail_renderer.dart:219-224`, `swimlanes_renderer.dart:118-126`, `zoom_canvas_renderer.dart:151-163`.
   - **"Open at newest" post-frame jumps (5):** `painter_rail_renderer.dart:191-195`, `render_box_layout_renderer.dart:40-45`, `swimlanes_renderer.dart:95-102`, `tree_graph_renderer.dart:39-42`, `zoom_canvas_renderer.dart:113-127`.
   - **Family→colour maps (3):** `story_marker.dart:8-12`; `tree_graph_renderer.dart:227-235`; `treemap_layout.dart:109-119` plus `treemap_renderer.dart:130-134`.
5. **Medium · consistency. Four marker, selection, badge vocabularies.**
   - **Dot sizes:** 12 px (`sliver_list_renderer.dart:168`), 10 px (`painter_rail_renderer.dart:358`, `zoom_canvas_renderer.dart:368`), 8 px (`swimlanes_renderer.dart:403`, tree leaves `tree_graph_renderer.dart:299`), 12 px tree groups.
   - **Selection styles:**
     - terracotta ring r8 (rail, tree);
     - **ink** 2 px border (`zoom_canvas_renderer.dart:376-378`);
     - left bar + fill (`swimlanes_renderer.dart:380-386`);
     - card border (sliver).
   - **Ring collision:** origin ring (r7) + selected ring (r8) both 2 px wide. Merge into one blob when origin story selected (`painter_rail_renderer.dart:359-366`, `tree_graph_renderer.dart:302-309`). Zoom canvas has no origin mark.
   - **`+N` badges, four styles:**
     - 22×12 ink pill, **8 px** text (`painter_rail_renderer.dart:376-393`);
     - 16×12 box with external "+N more" (`tree_graph_renderer.dart:276-290`);
     - radius-12 chip (`zoom_canvas_renderer.dart:478-485`);
     - plain text (`swimlanes_renderer.dart:360-363`).
6. **Medium · shell. Too many controls, clipped app bar, two status lines.**
   - **Control count:** 3 app-bar controls, 25 filter-panel controls (search, Hide/Dim, era, 21 chips, Clear), up to 8 playback controls, 3 per-renderer switches.
   - **Inconsistent switch vocabulary:** "People/Families" (`swimlanes_renderer.dart:154-155`), "Time/Family" (`tree_graph_renderer.dart:131-132`), "Decade/Family/Person" (`treemap_renderer.dart:84-86`).
   - **Clipped labels:** floating labels of two `DropdownMenu`s ("Renderer", "Stories", `lib/lab_app.dart:98-124`) cut by app-bar top edge in **every** shell golden (ink pixel at row 0 in `sliverList_all.png`).
   - **Wrong font in live app:** `[observed in the live web build at :8099]` dropdown values render in Literata (body serif), not UI sans.
   - **Two status lines:** caption row (`lib/widgets/playback_bar.dart:132-144`) + status bar (`lib/lab_app.dart:215-227`) = two stacked lines for related state.
7. **Medium · type and brand drift.**
   - **Tiny type:** rail badge 8 px (`painter_rail_renderer.dart:388`). Axis labels 11 px `labelSmall` (`painter_rail_renderer.dart:241`, `render_box_layout_renderer.dart:98`, `zoom_canvas_renderer.dart:214`), same for swimlane titles (`swimlanes_renderer.dart:341`) and tree leaves (`tree_graph_renderer.dart:165`). Brand iPad-first, wants large targets for elders (`docs/ux/uxd-handoff.md:105`, `docs/ux/80-all-stories.md:123`).
   - **Sans titles on compact cards:** compact cards switch title to `titleSmall` sans (`lib/widgets/story_card.dart:78`), but product titles always Newsreader (`docs/ux/80-all-stories.md:45`). RenderBox + zoom cards read sans, sliver cards serif (`renderBoxLayout_all.png` vs `sliverList_all.png`).
   - **Card fill:** cards use `labSurface` #FFF8F6, dialog surface (`story_card.dart:49`). Reads pink on parchment (`zoomCanvas_lod_cards.png`). Product cards = parchment + sage 45% border (`apps/tell_me_a_story/lib/core/theme/album_theme.dart:86-93`).
   - **Filter chips:** lab uses pill fill/border, beige selection (`lab_theme.dart:77-84`). Product uses parchment, sage 35% selection, sage border, radius 8 (`album_theme.dart:94-100`).
   - **Place line:** product cards show sage `location_on` icon before place (`docs/ux/80-all-stories.md:45`). Lab cards text only.
8. **Medium · redundancy. Painter rail duplicates two other renderers.**
   - Picture = zoom canvas *years* LOD: family lanes of dots on horizontal axis (compare `painterRail_all.png` with `zoomCanvas_lod_years.png`).
   - Technique (one `CustomPainter`, manual hit testing, `CustomPainterSemantics`) also exercised by tree graph (`tree_graph_renderer.dart:153-170`, `:338-362`).
   - Unique defects:
     - Lane labels painted at x=4 inside horizontal scroll (`painter_rail_renderer.dart:343`), so off-screen in all four `painterRail_*.png` (opens at newest story).
     - Rail uses ~280 px of 630 px viewport.
9. **Medium · treemap shading carries no info until filter dims.**
   - Shade = `0.12 + 0.5 × matchedShare` (`lib/renderers/treemap_layout.dart:216`). No filter → every share 1, so `treemap_all.png` and `treemap_hide.png` = wall of identical 62% terracotta.
   - Continuous ramp in `treemap_dim.png` hard to bucket by eye.
   - Groups ordered by count (`treemap_layout.dart:121`, `:198`), so decades read 2000s, 2020s, 1970s, 1930s. See Decision D5.
10. **Medium · tree graph ink-heavy, labels collide.**
    - Group nodes solid ink 12 px dots (`tree_graph_renderer.dart:299`).
    - Edges ink 35%; dimmed edges ink 12% (1.27:1) (`:250-252`).
    - Group labels above-right on top of incoming edges, no knockout (`:315-317`). See "1999" and "2000" in `treeGraph_dim.png`.
11. **Low · watermark layering.**
    - Year watermark stacked *after* renderer (`lib/lab_app.dart:162-166`), though doc comment says "behind the renderer" (`lib/widgets/playback_bar.dart:152`).
    - Draws over tiles in `treemap_playback.png` and over 1986 card in `renderBoxLayout_playback.png`.
12. **Low · empty states.**
    - Only tree (`tree_graph_renderer.dart:144`) and treemap (`treemap_renderer.dart:40`) have one, different styles.
    - Other five renderers show blank chrome in Hide mode with zero matches. No golden covers it.
13. **Low · spacing has no scale.**
    - Ad-hoc: 2, 4, 6, 8, 12, 16, 24 px (e.g. `swimlanes_renderer.dart:378`, `sliver_list_renderer.dart:157`, `filter_panel.dart:45`, `:102-103`).
    - Filter chips 4 px apart. At 800 px tall, Families below fold (`sliverList_all.png`). Brand wants "forms that breathe" (`docs/ux/uxd-handoff.md:118`).

## Decisions for the user

**Decided 2026-11-07:** D1 drop the rail · D2 all-terracotta dots · D3 consolidate · D4 segmented switch · D6 hollow rings. D5 not raised; recommendation (keep treemap) stands. Every task below runs as written.

Each decision has recommendation. **Tasks implement recommended option**; each task says what changes if otherwise.

| # | Decision | Recommendation | If you choose otherwise |
|---|---|---|---|
| D1 | Drop **painter rail**? (Finding 8) | **Drop.** Visually covered by zoom canvas years LOD, technically by tree graph. Fold README a11y notes into tree graph row. | Skip Task 1. Rail gets same treatment as zoom canvas in Tasks 2–5, 10, 11. Rail sub-steps inline, marked *(only if D1 = keep)*. |
| D2 | How markers encode **family**? (Finding 3) | **(a)** Every story dot terracotta, as product. Family via lanes + labels; moss reserved for origin rings. | **(b)** Keep three family colours, Okafor `labInk` not moss. Variant code in Task 5. |
| D3 | **Consolidate shell controls** (Finding 6)? | **Yes:** Sweep/Steps + speed into one options menu labelled with state (`Sweep · 1×`). Dataset size + perf overlay into one bench menu. Hide/Dim + playback caption into status row. | Skip matching steps in Task 6. Fix only clipped dropdown labels with `toolbarHeight: 72`. |
| D4 | Renderer picker as **segmented switch** not dropdown? | **Yes.** Switching renderer = lab's core action; switch makes it one tap. Matches product "one quiet row" zoom switch (`docs/ux/uxd-handoff.md:171`). | Keep `DropdownMenu`, add `toolbarHeight: 72` so label not clipped. |
| D5 | **Treemap**: keep, keep count order? | **Keep** as only area-encoding overview, restyled in Task 14. Keep squarified count order; chronological needs different layout algorithm (out of scope). | Dropping = repeat Task 1 for `treemap*` files. |
| D6 | **Dimmed marker = hollow ring** instead of 35% opacity? (Finding 2) | **Yes.** Filled = match, hollow = dimmed. Terracotta stroke stays 5.18:1; signal no longer relies on colour/opacity alone. | Keep `labDimOpacity` on markers. In Task 10, `paintStoryMarker` draws `color.withValues(alpha: labDimOpacity)` filled instead of hollow ring; delete hollow-radius test. |

## Coordination with the iPad plan

iPad plan written in parallel, saved beside this file in `docs/superpowers/plans/`. Plans aligned via direct exchange.

**Ownership.**
- **This plan** owns colours, type, spacing, radii, strokes, markers, axis styling, which controls exist + how they merge.
- **iPad plan** owns breakpoints, filter placement (sidebar or sheet), card + column widths, hit radii + gestures, keyboard shortcuts, SafeArea, orientation, selected-panel max height.

**Order.** Design Tasks 1–10 (phases 1–2), then iPad plan, then design Tasks 11–17 (phase 3).

**Stable keys** iPad plan addresses: `renderer-picker`, `dataset-size`, `playback-design`, `playback-bar`, `playback-caption`, `status-bar`, `selected-panel`, `filter-search`, `filter-era`, `filter-mode`, `playback-play`, `playback-prev`, `playback-next`, `playback-stop`, `playback-scrubber`.
- Task 6 keeps all.
- `filter-mode` and `playback-caption` move inside `status-bar`.
- `playback-speed` **removed**. Speed now in `playback-design` menu as `playback-speed-<value>` items.

**Tokens.** Task 8 creates `abstract final class Lab*` token pattern in `lib/theme/lab_theme.dart`. iPad plan adds `abstract final class LabTarget { static const min = 44.0; static const touchSlop = 22.0; }` in same file + style. No second token convention.

**Shared files.**
- **`lib/lab_app.dart`:** this plan edits AppBar (Task 6), status row (Task 6), renderer slot (Task 16). iPad plan edits body layout (breakpoint, sheet, SafeArea, Shortcuts), not AppBar contents. Task 6 fixes app-bar overflow iPad plan measured at 320–375 px wide. iPad plan then adds 320-px no-overflow test.
- **`painter_rail_renderer.dart`:** if D1 = drop (Task 1), iPad plan's rail hit-test tasks void.
- **`zoom_canvas_renderer.dart`, `tree_graph_layout.dart`, `swimlanes_renderer.dart` (`LaneCell`):** iPad plan edits hit-testing. This plan edits paint + styling only.
  - Task 10's `StoryDot` grows zoom year-dot widget 10 px → 26 px, enlarging tap area. iPad min-target work should measure after Task 10.
- **Goldens:** both plans regenerate. Run each plan's golden update only after own tasks. Then check `git status --short test/goldens/` against task's list.

**Scratch files.** `test/zz_ipad_scratch_test.dart` and `test/zz_ipad2_scratch_test.dart` belong to iPad planner, deleted by it. If still present when this plan runs, delete before Task 1 — they reference `painter_rail_renderer.dart` and `playback-speed`.

## File structure

Created:

| File | Responsibility |
|---|---|
| `lib/renderers/time_scale.dart` | `TimeScale`: only fractional-year ↔ px mapping, plus year/decade/month ticks. |
| `lib/renderers/canvas_label.dart` | `CanvasLabel` / `paintLabel`: one-line canvas text with anchor maths. |
| `lib/renderers/time_axis_painter.dart` | `timeAxisMarks` (pure), `paintTimeAxis`, `paintSpineLabels`: one axis look. |
| `lib/widgets/view_switch.dart` | `ViewSwitch<T>`: one in-renderer "group by" switch. |
| `lib/widgets/empty_timeline.dart` | `EmptyTimeline`: one empty state, with Clear filters. |
| `test/time_scale_test.dart`, `test/canvas_label_test.dart`, `test/camera_follow_test.dart`, `test/lab_theme_test.dart`, `test/story_card_test.dart`, `test/story_marker_test.dart`, `test/time_axis_painter_test.dart` | Unit + widget tests for above. |
| `test/support/contrast.dart` | WCAG contrast helper shared by theme + treemap tests. |
| `test/goldens/sliverList_empty.png` | Visual record of empty state. |

Modified:

| File | Change |
|---|---|
| `lib/theme/lab_theme.dart` | Token classes, rule/sage tints, component themes (segmented, chip, input, menu, text button). `labCardRadius` replaced by `LabRadius.card`. |
| `lib/renderers/story_marker.dart` | `MarkerSpec`, `paintStoryMarker`, `StoryDot`. `markerColor` + `entryOpacity` deleted. |
| `lib/playback/reveal.dart` | `kFollowAt`, `kFocusAlignment`, `scrollOffsetToPlace`, `paintPlaybackCursor`. |
| `lib/renderers/renderer_contract.dart` | Drop `painterRail` (D1). Add `TimelineViewData.anyDimmed`. |
| `lib/renderers/{zoom_canvas,render_box_layout,swimlanes,tree_graph,treemap,sliver_list}_renderer.dart`, `treemap_layout.dart`, `tree_graph_layout.dart` | Use shared primitives + tokens. |
| `lib/lab_app.dart`, `lib/widgets/playback_bar.dart`, `lib/widgets/filter_panel.dart`, `lib/widgets/story_card.dart` | Shell consolidation + card restyle. |
| `lib/playback/playback_controller.dart` | Drop `painterRail` from `defaultDesignFor` (D1). |
| `test/golden_test.dart`, `test/lab_app_test.dart`, `test/playback_controller_test.dart`, `test/tree_graph_test.dart`, `test/treemap_test.dart`, `test/zoom_canvas_test.dart` | Follow changes. |
| `README.md` | Renderer list, controls, visual system, LOC column. |

Deleted (D1): `lib/renderers/painter_rail_renderer.dart`, `test/painter_rail_test.dart`, `test/goldens/painterRail_{all,dim,hide,playback}.png`.

---

# Phase 1 — Shared primitives and simplification

### Task 1: Drop the painter rail (D1)

*Skip if D1 = keep.*

**Files:**
- Delete: `lib/renderers/painter_rail_renderer.dart`, `test/painter_rail_test.dart`, `test/goldens/painterRail_all.png`, `painterRail_dim.png`, `painterRail_hide.png`, `painterRail_playback.png`
- Modify: `lib/renderers/renderer_contract.dart:6,16,25,73`, `lib/playback/playback_controller.dart:33-41`, `test/lab_app_test.dart:6,84-107,193`, `test/playback_controller_test.dart:107`, `README.md:3-4,37,41,56,61,68-69,95,136,143,154`

- [ ] **Step 1: Write the failing test.** In `test/lab_app_test.dart`, delete import line 6 (`painter_rail_renderer.dart`). Replace `roots` map in "renderer picker switches the renderer" test (lines 86-94) with below; add length expectation right after:

```dart
    const roots = {
      RendererKind.sliverList: SliverListTimeline,
      RendererKind.renderBoxLayout: RenderBoxTimeline,
      RendererKind.zoomCanvas: ZoomCanvasTimeline,
      RendererKind.swimlanes: SwimlanesTimeline,
      RendererKind.treeGraph: TreeGraphTimeline,
      RendererKind.treemap: TreemapTimeline,
    };
    expect(RendererKind.values, hasLength(roots.length));
```

  Line 193: `c.setRenderer(RendererKind.painterRail);` → `c.setRenderer(RendererKind.zoomCanvas);`.

  `test/playback_controller_test.dart:107`: `lab.setRenderer(RendererKind.painterRail);` → `lab.setRenderer(RendererKind.zoomCanvas);`.

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/lab_app_test.dart --plain-name "renderer picker"`
  - Expected: FAIL with `Expected: an object with length of <6> Actual: ... length of <7>`.

- [ ] **Step 3: Delete the rail.**

```bash
git rm lib/renderers/painter_rail_renderer.dart test/painter_rail_test.dart \
  test/goldens/painterRail_all.png test/goldens/painterRail_dim.png \
  test/goldens/painterRail_hide.png test/goldens/painterRail_playback.png
```

  In `lib/renderers/renderer_contract.dart`, delete line 6 (`import 'painter_rail_renderer.dart';`), line 16 (`painterRail,`), line 25 (`painterRail => 'Painter rail',`), line 73 (`RendererKind.painterRail => PainterRailTimeline(data: data),`).

  In `lib/playback/playback_controller.dart`, replace lines 33-41 with:

```dart
  static PlaybackDesign defaultDesignFor(RendererKind kind) => switch (kind) {
    RendererKind.zoomCanvas ||
    RendererKind.swimlanes ||
    RendererKind.treeGraph ||
    RendererKind.treemap => PlaybackDesign.sweep,
    RendererKind.sliverList ||
    RendererKind.renderBoxLayout => PlaybackDesign.steps,
  };
```

- [ ] **Step 4: Update `README.md`.**
  - **Lines 3-4:** "seven renderers (five timelines, a tree graph and a treemap)" → "six renderers (four timelines, a tree graph and a treemap)".
  - **Line 37:** "(default for the painter rail, zoom canvas, swimlanes, tree graph" → "(default for the zoom canvas, swimlanes, tree graph".
  - **Line 41:** "a line (rail, zoom)" → "a line (zoom)".
  - **Line 56:** "The rail's `+N`, the swimlane `+N`" → "The swimlane `+N`".
  - **Line 61:** "the rail and the RenderBox axis only" → "the RenderBox axis only".
  - **Lines 68-69:** "The painter rail's semantics list every story at all times; playback is visual only there." → "The tree graph's semantics list every node at all times; playback is visual only there."
  - **Line 95:** delete "Painter rail" golden-index row.
  - **Line 136:** delete "`painter_rail_test.dart`, ".
  - **Line 143:** delete "B. Painter rail" comparison row; append one sentence to F (tree graph) row's "Text & a11y" cell: "This is the lab's only `CustomPainterSemantics` renderer since the painter rail was removed (it duplicated the zoom canvas's years level)."
  - **Line 154:** "(B, C, D)" → "(C, D)".

- [ ] **Step 5: Run the tests and check they pass.**
  - Run: `flutter test test/lab_app_test.dart test/playback_controller_test.dart`
  - Expected: PASS.

- [ ] **Step 6: Run the Gate.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: `No issues found!`, exit 0, `All tests passed!` with 104 − 9 = 95 tests (5 rail unit tests + 4 rail goldens removed).
  - Run: `git status --short test/goldens/`
  - Expected: only four `D test/goldens/painterRail_*.png` lines.

- [ ] **Step 7: Commit.**

```bash
git add -A lib/renderers/renderer_contract.dart lib/playback/playback_controller.dart test/lab_app_test.dart test/playback_controller_test.dart README.md
git commit -m "refactor(lab): drop painter rail; zoom canvas years LOD covers it"
```

### Task 2: One `TimeScale` for every year→px mapping

**Goldens expected to change:** none. **Guard:** `test/time_scale_test.dart`.

**Files:**
- Create: `lib/renderers/time_scale.dart`, `test/time_scale_test.dart`
- Modify: `lib/renderers/zoom_canvas_renderer.dart:76-80,117,137,160,193-218,294,342,348-349,359,400,494-588`, `lib/renderers/render_box_layout_renderer.dart:307,340,354,366,372-381,406,422-424`, `lib/renderers/swimlanes_renderer.dart:99-101,114-115,124,242`

- [ ] **Step 1: Write the failing test** `test/time_scale_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/time_scale.dart';

void main() {
  const oldestFirst = TimeScale(
    minYear: 1950,
    maxYear: 1959,
    pxPerYear: 40,
    leading: 24,
  );
  const newestFirst = TimeScale(
    minYear: 1950,
    maxYear: 1959,
    pxPerYear: 80,
    newestFirst: true,
  );

  test('oldest-first maps year boundaries left to right after the pad', () {
    expect(oldestFirst.toPx(1950), 24);
    expect(oldestFirst.toPx(1951.5), 24 + 60);
    expect(oldestFirst.toPx(1960), 24 + 400);
    expect(oldestFirst.span, 400);
  });

  test('newest-first puts the end of maxYear at the leading edge', () {
    expect(newestFirst.toPx(1960), 0);
    expect(newestFirst.toPx(1959), 80);
    expect(newestFirst.toPx(1950), 800);
  });

  test('toYear inverts toPx in both directions', () {
    for (final y in [1950.0, 1953.25, 1959.9]) {
      expect(oldestFirst.toYear(oldestFirst.toPx(y)), closeTo(y, 1e-9));
      expect(newestFirst.toYear(newestFirst.toPx(y)), closeTo(y, 1e-9));
    }
  });

  test('year ticks cover every boundary and flag decades', () {
    final ticks = oldestFirst.yearTicks().toList();
    expect(ticks.map((t) => t.year), [for (var y = 1950; y <= 1960; y++) y]);
    expect(
      ticks.where((t) => t.kind == TickKind.decade).map((t) => t.year),
      [1950, 1960],
    );
  });

  test('month ticks: eleven per year, strictly inside the span', () {
    final months = oldestFirst.monthTicks().toList();
    expect(months, hasLength(10 * 11));
    expect(months.first.px, greaterThan(oldestFirst.toPx(1950)));
    expect(months.last.px, lessThan(oldestFirst.toPx(1960)));
  });

  test('equal parameters compare equal (painters repaint on change only)', () {
    expect(
      const TimeScale(minYear: 1950, maxYear: 1959, pxPerYear: 40, leading: 24),
      oldestFirst,
    );
    expect(oldestFirst == newestFirst, isFalse);
  });
}
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/time_scale_test.dart`
  - Expected: FAIL to compile, `Target of URI doesn't exist: 'package:timeline_lab/renderers/time_scale.dart'`.

- [ ] **Step 3: Implement** `lib/renderers/time_scale.dart`:

```dart
/// Maps fractional years to pixels along one axis. Every renderer that
/// places stories in time goes through one of these.
class TimeScale {
  const TimeScale({
    required this.minYear,
    required this.maxYear,
    required this.pxPerYear,
    this.leading = 0,
    this.newestFirst = false,
  });

  final int minYear;
  final int maxYear;
  final double pxPerYear;

  /// Pixels before the first year boundary on the axis.
  final double leading;

  /// True when px grows toward older years (vertical, newest at the top).
  final bool newestFirst;

  /// Pixels covered by `[minYear, maxYear + 1)`, excluding [leading].
  double get span => (maxYear - minYear + 1) * pxPerYear;

  double toPx(double year) =>
      leading +
      (newestFirst ? maxYear + 1 - year : year - minYear) * pxPerYear;

  double toYear(double px) {
    final years = (px - leading) / pxPerYear;
    return newestFirst ? maxYear + 1 - years : minYear + years;
  }

  /// One tick per year boundary, `minYear..maxYear + 1`.
  Iterable<TimeTick> yearTicks() sync* {
    for (var y = minYear; y <= maxYear + 1; y++) {
      yield TimeTick(
        year: y,
        px: toPx(y.toDouble()),
        kind: y % 10 == 0 ? TickKind.decade : TickKind.year,
      );
    }
  }

  /// Eleven month boundaries inside each year, `minYear..maxYear`.
  Iterable<TimeTick> monthTicks() sync* {
    for (var y = minYear; y <= maxYear; y++) {
      for (var m = 1; m < 12; m++) {
        yield TimeTick(year: y, px: toPx(y + m / 12), kind: TickKind.month);
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TimeScale &&
      other.minYear == minYear &&
      other.maxYear == maxYear &&
      other.pxPerYear == pxPerYear &&
      other.leading == leading &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode =>
      Object.hash(minYear, maxYear, pxPerYear, leading, newestFirst);
}

enum TickKind { decade, year, month }

class TimeTick {
  const TimeTick({required this.year, required this.px, required this.kind});

  final int year;
  final double px;
  final TickKind kind;
}
```

- [ ] **Step 4: Run it and check it passes.**
  - Run: `flutter test test/time_scale_test.dart`
  - Expected: PASS (6 tests).

- [ ] **Step 5: Migrate the zoom canvas.**

  In `lib/renderers/zoom_canvas_renderer.dart`, add `import 'time_scale.dart';`. Replace lines 77-80 (`worldWidth` and `_xFor`) with:

```dart
  TimeScale get _scale =>
      TimeScale(minYear: minYear, maxYear: maxYear, pxPerYear: _pxPerYear);
  double get worldWidth => _scale.span;
```

  Then:
  - Every remaining `_xFor(` → `_scale.toPx(`. Covers lines 117, 137, 160, 217, 294, 359, 400.
  - Delete `_yearAt` (line 342); its two calls (lines 348-349) → `_scale.toYear(`.
  - In `_ZoomAxisPainter(...)` call (lines 207-218), replace `minYear: minYear,` and `maxYear: maxYear,` with `timeScale: _scale,`.

  In `_ZoomAxisPainter`:
  - Fields `final int minYear;` and `final int maxYear;` → `final TimeScale timeScale;`; update constructor params to match.
  - In `shouldRepaint`, `old.minYear != minYear || old.maxYear != maxYear ||` → `old.timeScale != timeScale ||`.
  - Replace lines 542-565 with:

```dart
    for (final t in timeScale.yearTicks()) {
      if (t.kind == TickKind.decade) {
        canvas.drawLine(
          Offset(t.px, axisY),
          Offset(t.px, axisY + 12 / scale),
          paint,
        );
        _label(canvas, '${t.year}', Offset(t.px, axisY));
        continue;
      }
      if (lod == ZoomLod.decades) continue;
      canvas.drawLine(
        Offset(t.px, axisY),
        Offset(t.px, axisY + 6 / scale),
        paint,
      );
      if (timeScale.pxPerYear * scale >= 48) {
        _label(canvas, '${t.year}', Offset(t.px, axisY));
      }
    }
    if (lod == ZoomLod.cards) {
      for (final t in timeScale.monthTicks()) {
        canvas.drawLine(
          Offset(t.px, axisY),
          Offset(t.px, axisY + 3 / scale),
          paint,
        );
      }
    }
```

- [ ] **Step 6: Migrate the RenderBox layout.**

  In `lib/renderers/render_box_layout_renderer.dart`, add `import 'time_scale.dart';`. Replace line 307 (`_yFor`) with:

```dart
  TimeScale get _scale => TimeScale(
    minYear: minYear,
    maxYear: maxYear,
    pxPerYear: pxPerYear,
    newestFirst: true,
  );
```

  Then:
  - `_yFor(` → `_scale.toPx(` at lines 340, 366, 406.
  - `(maxYear - minYear + 1) * pxPerYear` at line 354 → `_scale.span`.
  - Tick loop at lines 372-381 → :

```dart
    for (final t in _scale.yearTicks()) {
      final half = t.kind == TickKind.decade ? 8.0 : 3.0;
      canvas.drawLine(
        offset + Offset(_axisX - half, t.px),
        offset + Offset(_axisX + half, t.px),
        tick,
      );
    }
```

  - Decade loop header at lines 422-424 (`firstDecade`, `for (var y = firstDecade; …)`, `final ty = _yFor(…)`) → below. In loop body, use `'${t.year}'` for text and `t.px` in place of `ty`.

```dart
    for (final t in _scale.yearTicks()) {
      if (t.kind != TickKind.decade) continue;
```

- [ ] **Step 7: Migrate the swimlanes.**

  In `lib/renderers/swimlanes_renderer.dart`, add `import 'time_scale.dart';` and this getter to `_SwimlanesTimelineState`:

```dart
  TimeScale get _scale => TimeScale(
    minYear: widget.data.dataset.minYear,
    maxYear: widget.data.dataset.maxYear,
    pxPerYear: _colWidth,
  );
```

  Then:
  - Lines 99-100 (`final right = …`) → `final right = _scale.toPx(newest.start.year + 1.0);`.
  - Delete `_cursorX` (lines 114-115).
  - In `_follow`, `_cursorX(year)` → `_scale.toPx(year)`.
  - Line 242: `xForYear: _cursorX,` → `xForYear: (y) => _scale.toPx(y),`.

  *(Only if D1 = keep)* In `painter_rail_renderer.dart`, add `late final TimeScale scale = TimeScale(minYear: minYear, maxYear: maxYear, pxPerYear: pxPerYear, leading: leftPad);` to `PainterRailGeometry`. `xForYear` body → `scale.toPx(fractionalYear)`; axis loop at lines 323-332 → `for (final t in g.scale.yearTicks())`, using `t.px` and `t.kind == TickKind.decade`.

- [ ] **Step 8: Run the tests and the unchanged goldens.**
  - Run: `flutter test test/time_scale_test.dart test/zoom_canvas_test.dart test/render_box_layout_test.dart test/swimlanes_test.dart test/golden_test.dart`
  - Expected: PASS, **no golden diffs**. Arithmetic same, except floating-point reordering in month ticks.
  - If `zoomCanvas_lod_cards` fails, inspect `test/failures/` (diff must be invisible). Then regenerate only that file: `flutter test --update-goldens test/golden_test.dart --plain-name "zoomCanvas_lod_cards"`.

- [ ] **Step 9: Run the Gate.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: `No issues found!`, exit 0, `All tests passed!` (+6 tests).

- [ ] **Step 10: Commit.**

```bash
git add lib/renderers/time_scale.dart test/time_scale_test.dart lib/renderers/zoom_canvas_renderer.dart lib/renderers/render_box_layout_renderer.dart lib/renderers/swimlanes_renderer.dart
git commit -m "refactor(lab): one TimeScale for every year-to-px mapping"
```

### Task 3: `CanvasLabel` replaces the hand-rolled `TextPainter`s

**Goldens expected to change:** none. **Guard:** `test/canvas_label_test.dart`.

**Files:**
- Create: `lib/renderers/canvas_label.dart`, `test/canvas_label_test.dart`
- Modify: `lib/renderers/zoom_canvas_renderer.dart:522-534`, `lib/renderers/render_box_layout_renderer.dart:418-440`, `lib/renderers/tree_graph_renderer.dart:201-223,282-290,312-327`

- [ ] **Step 1: Write the failing test** `test/canvas_label_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/canvas_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const style = TextStyle(fontSize: 10, fontFamily: 'Roboto');

  test('originFor puts the anchor point of the label box at the point', () {
    final l = CanvasLabel('1980', style);
    addTearDown(l.dispose);
    final s = l.size;
    const at = Offset(100, 50);
    expect(l.originFor(at), at);
    expect(
      l.originFor(at, anchor: Alignment.center),
      Offset(100 - s.width / 2, 50 - s.height / 2),
    );
    expect(
      l.originFor(at, anchor: Alignment.bottomLeft),
      Offset(100, 50 - s.height),
    );
  });

  test('maxWidth truncates to a single line', () {
    final l = CanvasLabel(
      'A very long story title that will never fit',
      style,
      maxWidth: 40,
    );
    addTearDown(l.dispose);
    expect(l.size.width, lessThanOrEqualTo(40));
    expect(l.size.height, lessThan(2 * 10 * 1.5));
  });

  test('paintLabel returns the rect it painted', () {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = paintLabel(
      canvas,
      '+3',
      style,
      const Offset(20, 20),
      anchor: Alignment.center,
    );
    recorder.endRecording().dispose();
    expect(rect.center.dx, closeTo(20, 1e-9));
    expect(rect.center.dy, closeTo(20, 1e-9));
  });
}
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/canvas_label_test.dart`
  - Expected: FAIL to compile (URI doesn't exist).

- [ ] **Step 3: Implement** `lib/renderers/canvas_label.dart`:

```dart
import 'package:flutter/painting.dart';

/// A one-line label for painters. Lay it out once, read [size] for pills or
/// knockouts, then [paint] it with an anchor point.
class CanvasLabel {
  CanvasLabel(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) : _painter = TextPainter(
         text: TextSpan(text: text, style: style),
         textDirection: TextDirection.ltr,
         maxLines: 1,
         ellipsis: '…',
       )..layout(maxWidth: maxWidth);

  final TextPainter _painter;

  Size get size => _painter.size;

  /// Top-left corner when the label's [anchor] point sits at [at].
  Offset originFor(Offset at, {Alignment anchor = Alignment.topLeft}) =>
      at - anchor.alongSize(size);

  void paint(
    Canvas canvas,
    Offset at, {
    Alignment anchor = Alignment.topLeft,
  }) => _painter.paint(canvas, originFor(at, anchor: anchor));

  void dispose() => _painter.dispose();
}

/// Lays out, paints and disposes a label in one call; returns its rect.
Rect paintLabel(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset at, {
  Alignment anchor = Alignment.topLeft,
}) {
  final label = CanvasLabel(text, style);
  final rect = label.originFor(at, anchor: anchor) & label.size;
  label.paint(canvas, at, anchor: anchor);
  label.dispose();
  return rect;
}
```

- [ ] **Step 4: Run it and check it passes.**
  - Run: `flutter test test/canvas_label_test.dart`
  - Expected: PASS (3 tests).

- [ ] **Step 5: Migrate the zoom axis label.** In `lib/renderers/zoom_canvas_renderer.dart`, add `import 'canvas_label.dart';`, replace `_label` (lines 522-534) with:

```dart
  void _label(Canvas canvas, String text, Offset at) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(1 / scale);
    paintLabel(
      canvas,
      text,
      labelStyle,
      const Offset(2, -2),
      anchor: Alignment.bottomLeft,
    );
    canvas.restore();
  }
```

- [ ] **Step 6: Migrate the RenderBox decade pills.** In `lib/renderers/render_box_layout_renderer.dart`, add `import 'canvas_label.dart';`. Replace decade loop body (`TextPainter … tp.dispose();` block from Task 2) with:

```dart
      final label = CanvasLabel('${t.year}', labelStyle);
      final rect = Rect.fromCenter(
        center: offset + Offset(_axisX, t.px),
        width: label.size.width + 8,
        height: label.size.height + 2,
      );
      top.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        pill,
      );
      label.paint(top, rect.topLeft + const Offset(4, 1));
      label.dispose();
```

- [ ] **Step 7: Migrate the tree labels.** In `lib/renderers/tree_graph_renderer.dart`, add `import 'canvas_label.dart';`.
  - `final Map<TreeNode, TextPainter> _labels = {};` (line 202) → `final Map<TreeNode, CanvasLabel> _labels = {};`.
  - `_label` return type → `CanvasLabel`; replace its `return TextPainter(…)..layout(…);` with:

```dart
    return CanvasLabel(
      n.label,
      style,
      maxWidth: leaf ? layout.labelWidth - 16 : layout.levelGap - 24,
    );
```

  - Overflow text block (lines 282-290, `final tp = TextPainter(` to `tp.dispose();`) → :

```dart
        paintLabel(
          canvas,
          _overflowText(shown),
          labelStyle.copyWith(color: labInk.withValues(alpha: r)),
          p + const Offset(12, 0),
          anchor: Alignment.centerLeft,
        );
```

  - Label placement (lines 315-317): `label.height` → `label.size.height`. `label.paint(canvas, at)` and `at & label.size` work unchanged.

  *(Only if D1 = keep)* In `painter_rail_renderer.dart`:
  - `_text(...)` calls → `paintLabel(canvas, s, labelStyle, at)`; delete `_text`.
  - Badge `TextPainter` block (lines 385-393) → `paintLabel(canvas, '+$shown', labelStyle.copyWith(color: labParchment, fontSize: 8), b.at, anchor: Alignment.center);`.

- [ ] **Step 8: Run the affected tests and the unchanged goldens.**
  - Run: `flutter test test/canvas_label_test.dart test/tree_graph_test.dart test/zoom_canvas_test.dart test/golden_test.dart`
  - Expected: PASS, no golden diffs.

- [ ] **Step 9: Run the Gate.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean (+3 tests).

- [ ] **Step 10: Commit.**

```bash
git add lib/renderers/canvas_label.dart test/canvas_label_test.dart lib/renderers/zoom_canvas_renderer.dart lib/renderers/render_box_layout_renderer.dart lib/renderers/tree_graph_renderer.dart
git commit -m "refactor(lab): CanvasLabel replaces hand-rolled TextPainters"
```

### Task 4: One playback cursor and one camera-follow rule

**Goldens expected to change:** none. **Guard:** `test/camera_follow_test.dart`.

**Files:**
- Create: `test/camera_follow_test.dart`
- Modify: `lib/playback/reveal.dart:1-3,159`, `lib/renderers/swimlanes_renderer.dart:98-101,118-126,273-285`, `lib/renderers/zoom_canvas_renderer.dart:1-10,160,566-575`, `lib/renderers/render_box_layout_renderer.dart:404-414`, `lib/renderers/tree_graph_renderer.dart:71-82`

- [ ] **Step 1: Write the failing test** `test/camera_follow_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/playback/reveal.dart';

ScrollMetrics _metrics({double viewport = 1000, double max = 5000}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: max,
      pixels: 0,
      viewportDimension: viewport,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );

void main() {
  test('puts content at the viewport fraction', () {
    expect(scrollOffsetToPlace(3000, _metrics(), kFollowAt), 2350);
  });

  test('clamps to the scroll range', () {
    expect(scrollOffsetToPlace(100, _metrics(), kFollowAt), 0);
    expect(scrollOffsetToPlace(9000, _metrics(), kFollowAt), 5000);
  });
}
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/camera_follow_test.dart`
  - Expected: FAIL, `Undefined name 'scrollOffsetToPlace'`.

- [ ] **Step 3: Implement.** In `lib/playback/reveal.dart`, replace lines 1-3 with block below. Then line 159: `alignment: 0.4,` → `alignment: kFocusAlignment,`.

```dart
import 'package:flutter/widgets.dart';

import '../theme/lab_theme.dart';
import 'playback_controller.dart';

/// Viewport fraction where camera follow keeps the playback cursor
/// (horizontal renderers).
const kFollowAt = 0.65;

/// Viewport fraction where vertical renderers put a focused story.
const kFocusAlignment = 0.4;

/// Scroll offset that puts content position [contentPx] at [fraction] of
/// the viewport, clamped to the scroll range.
double scrollOffsetToPlace(
  double contentPx,
  ScrollMetrics m,
  double fraction,
) => (contentPx - m.viewportDimension * fraction).clamp(0.0, m.maxScrollExtent);

/// The playback cursor line, the same in every renderer. [zoom] is the
/// canvas scale, so the stroke stays 2 screen px in a scaled canvas.
void paintPlaybackCursor(
  Canvas canvas,
  Offset from,
  Offset to, {
  double zoom = 1,
}) => canvas.drawLine(
  from,
  to,
  Paint()
    ..color = labTerracotta
    ..strokeWidth = 2 / zoom,
);
```

- [ ] **Step 4: Run it and check it passes.**
  - Run: `flutter test test/camera_follow_test.dart`
  - Expected: PASS (2 tests).

- [ ] **Step 5: Migrate the call sites.**

  **Swimlanes:** In `swimlanes_renderer.dart`, replace open-at-newest jump (lines 98-101) with:

```dart
      final right = _scale.toPx(newest.start.year + 1.0);
      _hCtl.jumpTo(scrollOffsetToPlace(right, _hCtl.position, 1));
```

  `_follow` body after guard (lines 122-125) → `_hCtl.jumpTo(scrollOffsetToPlace(_scale.toPx(year), _hCtl.position, kFollowAt));`. In `_CursorPainter.paint`, `canvas.drawLine(…)` (lines 278-284) → `paintPlaybackCursor(canvas, Offset(x, 0), Offset(x, size.height));`.

  **Zoom canvas:** In `zoom_canvas_renderer.dart`, add `import '../playback/reveal.dart';`. Then:
  - Line 160: `_viewport.width * 0.65` → `_viewport.width * kFollowAt`.
  - Lines 566-575: cursor block → :

```dart
    final cx = cursorX;
    if (cx != null) {
      paintPlaybackCursor(
        canvas,
        Offset(cx, axisY - 4 / scale),
        Offset(cx, bottomY),
        zoom: scale,
      );
    }
```

  **RenderBox:** In `render_box_layout_renderer.dart`, cursor `canvas.drawLine(…)` (lines 407-413) → `paintPlaybackCursor(canvas, offset + Offset(0, cy), offset + Offset(size.width, cy));`.

  **Tree graph:** In `tree_graph_renderer.dart`, `_vCtl.jumpTo(…)` in `_scrollToStory` (lines 76-81) → :

```dart
    _vCtl.jumpTo(
      scrollOffsetToPlace(
        layout!.positions[node]!.dy,
        _vCtl.position,
        kFocusAlignment,
      ),
    );
```

  *(Only if D1 = keep)* In `painter_rail_renderer.dart`:
  - `_scrollTo` body → `_hCtl.jumpTo(scrollOffsetToPlace(x, _hCtl.position, fraction));`.
  - `_follow` uses `kFollowAt`.
  - Cursor (lines 396-406) → `paintPlaybackCursor(canvas, Offset(x, baseY - 4), Offset(x, size.height));`.

- [ ] **Step 6: Run the affected tests and the unchanged goldens.**
  - Run: `flutter test test/camera_follow_test.dart test/lab_app_test.dart test/tree_graph_test.dart test/golden_test.dart`
  - Expected: PASS, no golden diffs.

- [ ] **Step 7: Run the Gate.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean (+2 tests).

- [ ] **Step 8: Commit.**

```bash
git add lib/playback/reveal.dart test/camera_follow_test.dart lib/renderers/swimlanes_renderer.dart lib/renderers/zoom_canvas_renderer.dart lib/renderers/render_box_layout_renderer.dart lib/renderers/tree_graph_renderer.dart
git commit -m "refactor(lab): one playback cursor and one follow/focus rule"
```

### Task 5: One story colour (D2)

**Goldens expected to change (D2 = a):** `sliverList_{all,dim,hide,playback,narrow}`, `swimlanes_{all,dim,hide,playback}`, `treeGraph_{all,dim,hide,playback}`, `zoomCanvas_lod_years` (14 files). Sage + moss story dots become terracotta. **Guard:** `flutter analyze` (no `markerColor` or `TreemapColor` reference survives) + goldens. No new unit test: task deletes a mapping.

**Files:**
- Modify: `lib/renderers/story_marker.dart:7-12`, `lib/renderers/sliver_list_renderer.dart:173-176`, `lib/renderers/zoom_canvas_renderer.dart:372-375`, `lib/renderers/swimlanes_renderer.dart:334,356,395-411`, `lib/renderers/tree_graph_renderer.dart:227-235`, `lib/renderers/treemap_layout.dart:94-119,136-192`, `lib/renderers/treemap_renderer.dart:130-134,207-221,229-263,347-350`

- [ ] **Step 1: Delete `markerColor`.** Delete lines 7-12 of `story_marker.dart`. In their place (above `isOrigin`'s doc comment, blank line between), write plain comment:

```dart
// Story dots are terracotta in every renderer; family shows through lanes
// and labels, and moss is reserved for origin rings (Decision D2,
// docs/ux/branch-callout.md Rule 4 "One green").
```

- [ ] **Step 2: Replace the call sites with `labTerracotta`.**
  - `sliver_list_renderer.dart:173-176`: `color: markerColor(s, data.dataset).withValues(alpha: entryOpacity(entry)),` → `color: labTerracotta.withValues(alpha: entryOpacity(entry)),`.
  - `zoom_canvas_renderer.dart:372-375`: `color: markerColor(e.story, data.dataset).withValues(alpha: entryOpacity(e)),` → `color: labTerracotta.withValues(alpha: entryOpacity(e)),`.
  - `swimlanes_renderer.dart`:
    - Delete `color` field + param from `_Dot` (lines 395-411). Decoration colour → `labTerracotta.withValues(alpha: alpha)`.
    - Calls at 334 and 356 → `_Dot(alpha: …)`.
  - `tree_graph_renderer.dart:227-235`: `_nodeColor` → :

```dart
  Color _nodeColor(TreeNode n) =>
      n.kind == TreeNodeKind.story ? labTerracotta : labInk;
```

- [ ] **Step 3: Remove the treemap colour plumbing.**
  - In `treemap_layout.dart`:
    - Delete `color` param + field from `TreemapGroup` (lines 96, 101-102), `TreemapColor` enum (lines 109-111), `_familyColor` (lines 115-119).
    - Delete `TreemapColor color,` param of `add(...)` (line 139) and its use at line 146. Result: `() => TreemapGroup(id: groupId, label: groupLabel),`.
    - Delete three colour args at lines 164, 174, 185.
  - In `treemap_renderer.dart`:
    - Delete `_tokenColor` (lines 130-134).
    - Delete `color: _tokenColor(group.color),` (line 216) and `color` field + param of `TreemapCellTile` (lines 233, 240).
    - Two remaining `color.withValues(` in `_build` (lines 263, 276) → `labTerracotta.withValues(`.
    - Lines 347-350: `color: markerColor(e.story, data.dataset).withValues(alpha: e.matched ? 0.18 : 0.06),` → `color: labTerracotta.withValues(alpha: e.matched ? 0.18 : 0.06),`.

  *(If D2 = b instead)* Keep one mapping in `story_marker.dart`, call it everywhere `labTerracotta` written above. Keep `TreemapGroup` but replace `color` with `final String? familyId;`, set only in family mode. Add `final String? familyId;` to `TreeNode`, set at `tree_graph_layout.dart:235`.

```dart
/// The only family → colour map. Okafor is ink so moss stays the origin
/// ring's colour.
Color familyColor(String? familyId) => switch (familyId) {
  'fam-reyes' => labSage,
  'fam-okafor' => labInk,
  _ => labTerracotta,
};
```

- [ ] **Step 4: Run the tests.**
  - Run: `flutter analyze && flutter test test/treemap_test.dart test/tree_graph_test.dart test/swimlanes_test.dart test/zoom_canvas_test.dart`
  - Expected: `No issues found!` and PASS.

- [ ] **Step 5: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart`
  - Then `git status --short test/goldens/`.
  - Expected: exactly 14 files above show `M`.
  - Open `test/goldens/swimlanes_all.png` and `test/goldens/treeGraph_all.png` in image viewer. Every story dot terracotta.

- [ ] **Step 6: Run the Gate.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

- [ ] **Step 7: Commit.**

```bash
git add lib/renderers test/goldens
git commit -m "refactor(lab): one story colour; moss reserved for origin rings"
```

### Task 6: Shell consolidation (D3, D4) and the watermark behind content

**Goldens expected to change:** every shell golden = all `*_all|dim|hide|playback` plus `sliverList_narrow` (25 files, D1 applied). App bar, playback bar, status row all change. `zoomCanvas_lod_*` unchanged. **Guards:** four new tests in `test/lab_app_test.dart` + updated renderer-picker test.

**Files:**
- Modify: `lib/lab_app.dart` (whole file below), `lib/widgets/playback_bar.dart` (whole file below), `lib/widgets/filter_panel.dart:61-71`, `test/lab_app_test.dart:95-106` plus new tests, `README.md:20-29`

- [ ] **Step 1: Write the failing tests.**

  In `test/lab_app_test.dart`, add `import 'package:timeline_lab/playback/playback_schedule.dart';` and `import 'package:timeline_lab/widgets/playback_bar.dart';`. Replace loop body of "renderer picker switches the renderer" (lines 99-102) with:

```dart
      final segment = find.descendant(
        of: find.byKey(const Key('renderer-picker')),
        matching: find.text(kind.label),
      );
      await tester.ensureVisible(segment);
      await tester.tap(segment);
      await tester.pumpAndSettle();
```

  Add these tests inside `main()`:

```dart
  testWidgets('bench menu sets the dataset size', (tester) async {
    final c = await _pump(tester);
    await tester.tap(find.byKey(const Key('dataset-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dataset-size-1000')));
    await tester.pumpAndSettle();
    expect(c.datasetSize, 1000);
    // Button label and status line.
    expect(find.text('1000 stories'), findsNWidgets(2));
  });

  testWidgets('playback options menu sets design and speed', (tester) async {
    await _pump(tester);
    final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
    await tester.tap(find.byKey(const Key('playback-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playback-design-sweep')));
    await tester.pumpAndSettle();
    expect(pb.design, PlaybackDesign.sweep);
    await tester.tap(find.byKey(const Key('playback-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('playback-speed-2.0')));
    await tester.pumpAndSettle();
    expect(pb.speed, 2.0);
    expect(find.text('Sweep · 2×'), findsOneWidget);
  });

  testWidgets('status row holds the count, the caption and Hide/Dim', (
    tester,
  ) async {
    await _pump(tester);
    final row = find.byKey(const Key('status-bar'));
    for (final key in ['filter-mode', 'playback-caption']) {
      expect(
        find.descendant(of: row, matching: find.byKey(Key(key))),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: row, matching: find.text('120 stories')),
      findsOneWidget,
    );
  });

  testWidgets('the year watermark sits behind the renderer', (tester) async {
    await _pump(tester);
    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(PlaybackWatermark),
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(stack.children.first, isA<PlaybackWatermark>());
  });
```

- [ ] **Step 2: Run them and check they fail.**
  - Run: `flutter test test/lab_app_test.dart`
  - Expected: FAIL. Bench: `dataset-size-1000` not found. Options: `playback-design-sweep` not found. Status row: `filter-mode` not in `status-bar`. Watermark: `isA<PlaybackWatermark>` fails. Renderer picker fails: segment text not under key.

- [ ] **Step 3: Replace `lib/widgets/playback_bar.dart`** with:

```dart
import 'package:flutter/material.dart';

import '../lab_controller.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_schedule.dart';
import '../theme/lab_theme.dart';

String speedLabel(double s) => '${s == s.roundToDouble() ? s.toInt() : s}×';

String designLabel(PlaybackDesign d) => switch (d) {
  PlaybackDesign.sweep => 'Sweep',
  PlaybackDesign.steps => 'Steps',
};

/// Transport, scrubber, options and camera follow. Only this bar, the
/// caption and the watermark rebuild on ticks; renderers listen directly.
class PlaybackBar extends StatelessWidget {
  const PlaybackBar({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) {
      final pb = playback;
      final steps = pb.design == PlaybackDesign.steps;
      return Container(
        key: const Key('playback-bar'),
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: labBorder)),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('playback-play'),
              tooltip: pb.playing ? 'Pause' : 'Play',
              icon: Icon(pb.playing ? Icons.pause : Icons.play_arrow),
              onPressed: pb.total == 0
                  ? null
                  : (pb.playing ? pb.pause : pb.play),
            ),
            IconButton(
              key: const Key('playback-stop'),
              tooltip: 'Stop and show all',
              icon: const Icon(Icons.stop),
              onPressed: pb.active ? pb.stop : null,
            ),
            if (steps) ...[
              IconButton(
                key: const Key('playback-prev'),
                tooltip: 'Previous',
                icon: const Icon(Icons.skip_previous),
                onPressed: pb.total == 0 ? null : () => pb.step(-1),
              ),
              IconButton(
                key: const Key('playback-next'),
                tooltip: 'Next',
                icon: const Icon(Icons.skip_next),
                onPressed: pb.total == 0 ? null : () => pb.step(1),
              ),
            ],
            Expanded(
              child: Slider(
                key: const Key('playback-scrubber'),
                value: pb.progress,
                onChangeStart: (_) => pb.pause(),
                onChanged: pb.total == 0
                    ? null
                    : (v) => pb.seek(v * pb.duration),
              ),
            ),
            _PlaybackOptions(playback: pb),
            IconButton(
              key: const Key('playback-follow'),
              tooltip: pb.follow
                  ? 'Camera follows playback'
                  : 'Camera free (tap to follow)',
              isSelected: pb.follow,
              icon: const Icon(Icons.center_focus_weak),
              selectedIcon: const Icon(Icons.center_focus_strong),
              onPressed: () => pb.setFollow(!pb.follow),
            ),
          ],
        ),
      );
    },
  );
}

/// Design and speed in one menu whose label shows both (`Sweep · 1×`).
class _PlaybackOptions extends StatelessWidget {
  const _PlaybackOptions({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final pb = playback;
    return MenuAnchor(
      menuChildren: [
        for (final d in PlaybackDesign.values)
          MenuItemButton(
            key: Key('playback-design-${d.name}'),
            leadingIcon: Icon(d == pb.design ? Icons.check : null),
            onPressed: () => pb.setDesign(d),
            child: Text(designLabel(d)),
          ),
        const Divider(height: 1),
        for (final s in playbackSpeeds)
          MenuItemButton(
            key: Key('playback-speed-$s'),
            leadingIcon: Icon(s == pb.speed ? Icons.check : null),
            onPressed: () => pb.setSpeed(s),
            child: Text(speedLabel(s)),
          ),
      ],
      builder: (context, menu, _) => TextButton.icon(
        key: const Key('playback-design'),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.tune),
        label: Text('${designLabel(pb.design)} · ${speedLabel(pb.speed)}'),
      ),
    );
  }
}

/// Playback state in words; a polite live region in the status row.
class PlaybackCaption extends StatelessWidget {
  const PlaybackCaption({
    super.key,
    required this.controller,
    required this.playback,
  });

  final LabController controller;
  final PlaybackController playback;

  String _caption() {
    final pb = playback;
    if (!pb.active) return 'Press play to replay the timeline';
    final count = '${pb.revealedCount} of ${pb.total}';
    final current = pb.current;
    if (pb.design == PlaybackDesign.steps && current != null) {
      return '${controller.dataset.dateLabel(current)} · ${current.title} '
          '· $count';
    }
    return '${pb.cursorYear!.floor()} · $count';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) => Semantics(
      liveRegion: true,
      child: Text(
        _caption(),
        key: const Key('playback-caption'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    ),
  );
}

/// Large year behind the renderer while a session is active (Gapminder).
class PlaybackWatermark extends StatelessWidget {
  const PlaybackWatermark({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context) => Positioned(
    right: 24,
    bottom: 8,
    child: IgnorePointer(
      child: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final year = playback.cursorYear;
          if (year == null) return const SizedBox.shrink();
          return Text(
            '${year.floor()}',
            key: const Key('playback-watermark'),
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontSize: 72, color: labInk.withValues(alpha: 0.12)),
          );
        },
      ),
    ),
  );
}
```

- [ ] **Step 4: Replace `LabHome` and `_LabAppState.build` in `lib/lab_app.dart`.** Keep lines 1-37 (imports, `LabApp`, state fields, `dispose`); add `import 'filter/timeline_filter.dart';` if missing. Replace line 38 to end with:

```dart
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    showPerformanceOverlay: _showPerf,
    theme: labTheme(useGoogleFonts: widget.useGoogleFonts),
    home: LabHome(
      controller: _controller,
      playback: _playback,
      showPerf: _showPerf,
      onTogglePerf: () => setState(() => _showPerf = !_showPerf),
    ),
  );
}

class LabHome extends StatelessWidget {
  const LabHome({
    super.key,
    required this.controller,
    required this.playback,
    this.showPerf = false,
    this.onTogglePerf,
  });

  final LabController controller;
  final PlaybackController playback;
  final bool showPerf;
  final VoidCallback? onTogglePerf;

  @override
  Widget build(BuildContext context) {
    // Reduced motion → instant reveals. iOS reports Reduce Motion separately
    // from disableAnimations, so check both.
    playback.reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final c = controller;
    final renderer = KeyedSubtree(
      key: ValueKey((c.renderer, c.datasetSize)),
      child: buildRenderer(
        c.renderer,
        TimelineViewData(
          dataset: c.dataset,
          entries: c.entries,
          mode: c.filter.mode,
          selectedId: c.selectedStoryId,
          onSelect: c.select,
          playback: playback,
        ),
      ),
    );
    final selected = c.selectedStory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline Lab'),
        actions: [
          _BenchMenu(
            controller: c,
            showPerf: showPerf,
            onTogglePerf: onTogglePerf,
          ),
          const SizedBox(width: 8),
        ],
        bottom: _RendererSwitch(controller: c),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                // One Flex in both layouts so the renderer keeps its element
                // (scroll, zoom, lane mode) across the breakpoint.
                return Flex(
                  direction: wide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      SizedBox(
                        width: 300,
                        child: SingleChildScrollView(
                          child: FilterPanel(controller: c),
                        ),
                      )
                    else
                      ExpansionTile(
                        title: const Text('Filters'),
                        children: [FilterPanel(controller: c)],
                      ),
                    if (wide)
                      const VerticalDivider(width: 1)
                    else
                      const Divider(height: 1),
                    Expanded(
                      child: Stack(
                        children: [
                          // Behind the renderer: tiles and cards cover it.
                          PlaybackWatermark(playback: playback),
                          Positioned.fill(child: renderer),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          PlaybackBar(playback: playback),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: selected == null
                ? const SizedBox(width: double.infinity)
                : DecoratedBox(
                    key: const Key('selected-panel'),
                    decoration: const BoxDecoration(
                      color: labPillFill,
                      border: Border(top: BorderSide(color: labBorder)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StoryCard(
                            story: selected,
                            dataset: c.dataset,
                            matched: true,
                            selected: false,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selected.body,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          IconButton(
                            key: const Key('selected-close'),
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                            onPressed: () => c.select(null),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          _StatusRow(controller: c, playback: playback),
        ],
      ),
    );
  }
}

/// One tap per renderer: comparing them is the point of the lab.
class _RendererSwitch extends StatelessWidget implements PreferredSizeWidget {
  const _RendererSwitch({required this.controller});

  final LabController controller;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<RendererKind>(
        key: const Key('renderer-picker'),
        showSelectedIcon: false,
        segments: [
          for (final k in RendererKind.values)
            ButtonSegment(value: k, label: Text(k.label)),
        ],
        selected: {controller.renderer},
        onSelectionChanged: (s) => controller.setRenderer(s.first),
      ),
    ),
  );
}

/// Dataset size and the performance overlay: bench settings, one button.
class _BenchMenu extends StatelessWidget {
  const _BenchMenu({
    required this.controller,
    required this.showPerf,
    this.onTogglePerf,
  });

  final LabController controller;
  final bool showPerf;
  final VoidCallback? onTogglePerf;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final n in datasetSizes)
        MenuItemButton(
          key: Key('dataset-size-$n'),
          leadingIcon: Icon(n == controller.datasetSize ? Icons.check : null),
          onPressed: () => controller.setDatasetSize(n),
          child: Text('$n stories'),
        ),
      const Divider(height: 1),
      CheckboxMenuButton(
        value: showPerf,
        onChanged: (_) => onTogglePerf?.call(),
        child: const Text('Performance overlay'),
      ),
    ],
    builder: (context, menu, _) => TextButton.icon(
      key: const Key('dataset-size'),
      onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      icon: const Icon(Icons.speed),
      label: Text('${controller.datasetSize} stories'),
    ),
  );
}

/// Match count, playback caption and Hide/Dim on one line.
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.controller, required this.playback});

  final LabController controller;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final filter = c.filter;
    return Container(
      key: const Key('status-bar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: labBorder)),
      ),
      child: Row(
        children: [
          Text(
            statusLine(c.matchCount, c.dataset.stories.length, filter),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PlaybackCaption(controller: c, playback: playback),
          ),
          const SizedBox(width: 16),
          SegmentedButton<FilterMode>(
            key: const Key('filter-mode'),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: FilterMode.hide, label: Text('Hide')),
              ButtonSegment(value: FilterMode.dim, label: Text('Dim')),
            ],
            selected: {filter.mode},
            onSelectionChanged: (s) =>
                c.setFilter(filter.copyWith(mode: s.first)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Remove Hide/Dim from the filter panel.** In `lib/widgets/filter_panel.dart`, delete lines 61-71: `SegmentedButton<FilterMode>` + following `SizedBox(height: 16)`. `SizedBox(height: 16)` at line 60 now separates search from era label.

- [ ] **Step 6: Run the tests and check they pass.**
  - Run: `flutter test test/lab_app_test.dart`
  - Expected: PASS (+4 tests).

- [ ] **Step 7: Update the `README.md` "Run" section.** Replace lines 20-29 ("The top bar has three controls:" to "picks the filter mode.") with:

```markdown
The top bar has two controls:

- The **renderer** switch, one segment per renderer.
- The **bench** menu (speed icon): dataset size (120, 1 000 or 5 000
  stories, all seed 42) and the performance overlay.

The filters are people, places and families (each multi-select), an era
brush and text search. Search covers title, body and person names, but not
place, which matches All Stories `matchesSearch`. The status row at the
bottom shows the match count, the playback caption and the per-session
**Hide / Dim** switch. Playback design and speed share one options menu
(tune icon) labelled with the current choice, e.g. `Sweep · 1×`.
```

- [ ] **Step 8: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart`, then `git status --short test/goldens/`.
  - Expected: 25 shell goldens `M`; `zoomCanvas_lod_*` not.
  - Open `sliverList_all.png`. App bar: no clipped label. Renderer switch on own row, Sliver list selected; one status row "120 stories · Press play… · Hide | Dim".

- [ ] **Step 9: Run the Gate.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

- [ ] **Step 10: Commit.**

```bash
git add lib/lab_app.dart lib/widgets/playback_bar.dart lib/widgets/filter_panel.dart test/lab_app_test.dart README.md test/goldens
git commit -m "feat(lab): consolidate shell controls; watermark behind content"
```

### Task 7: One in-renderer view switch

**Goldens expected to change:** `swimlanes_*`, `treeGraph_*`, `treemap_*` (12 files). **Guard:** new test in `test/lab_app_test.dart`.

**Files:**
- Create: `lib/widgets/view_switch.dart`
- Modify: `lib/renderers/swimlanes_renderer.dart:149-160`, `lib/renderers/tree_graph_renderer.dart:126-141`, `lib/renderers/treemap_renderer.dart:73-121`, `test/lab_app_test.dart:157`

- [ ] **Step 1: Write the failing test.** Add below to `test/lab_app_test.dart`. Then line 157 `find.text('Families')` → `find.text('Family')`.

```dart
  testWidgets('renderer view switches use singular segment names', (
    tester,
  ) async {
    final c = await _pump(tester);
    for (final (kind, key, names) in [
      (RendererKind.swimlanes, 'lane-by', ['Person', 'Family']),
      (RendererKind.treeGraph, 'tree-by', ['Time', 'Family']),
      (RendererKind.treemap, 'treemap-by', ['Decade', 'Family', 'Person']),
    ]) {
      c.setRenderer(kind);
      await tester.pumpAndSettle();
      for (final n in names) {
        expect(
          find.descendant(of: find.byKey(Key(key)), matching: find.text(n)),
          findsOneWidget,
          reason: '$kind $n',
        );
      }
    }
  });
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/lab_app_test.dart --plain-name "singular"`
  - Expected: FAIL on `swimlanes Person`.

- [ ] **Step 3: Implement** `lib/widgets/view_switch.dart`:

```dart
import 'package:flutter/material.dart';

/// The in-renderer view switch (swimlanes, tree graph, treemap): one
/// placement, one label style, singular segment names. Scrolls sideways on
/// narrow screens instead of overflowing.
class ViewSwitch<T> extends StatelessWidget {
  const ViewSwitch({
    super.key,
    required this.switchKey,
    required this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.trailing = const [],
  });

  /// Goes on the `SegmentedButton` itself, so tests can read `.selected`.
  final Key switchKey;
  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        SegmentedButton<T>(
          key: switchKey,
          showSelectedIcon: false,
          segments: [
            for (final v in values)
              ButtonSegment(value: v, label: Text(labelOf(v))),
          ],
          selected: {selected},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        ...trailing,
      ],
    ),
  );
}
```

- [ ] **Step 4: Use it in the three renderers.**

  In `swimlanes_renderer.dart`, add `import '../widgets/view_switch.dart';`, replace lines 149-160 with:

```dart
        ViewSwitch<LaneBy>(
          switchKey: const Key('lane-by'),
          label: 'Lanes',
          values: LaneBy.values,
          labelOf: (v) => switch (v) {
            LaneBy.person => 'Person',
            LaneBy.family => 'Family',
          },
          selected: _laneBy,
          onChanged: (v) => setState(() => _laneBy = v),
        ),
```

  In `tree_graph_renderer.dart`, add import, replace lines 126-141 with:

```dart
        ViewSwitch<TreeBy>(
          switchKey: const Key('tree-by'),
          label: 'Tree',
          values: TreeBy.values,
          labelOf: (v) => switch (v) {
            TreeBy.time => 'Time',
            TreeBy.family => 'Family',
          },
          selected: _by,
          onChanged: (v) => setState(() {
            _by = v;
            _expanded.clear();
            _rebuild();
          }),
        ),
```

  In `treemap_renderer.dart`, add import, replace lines 77-121 (`Padding(…Row(…))` header) with:

```dart
        ViewSwitch<TreemapBy>(
          switchKey: const Key('treemap-by'),
          label: 'Group by',
          values: TreemapBy.values,
          labelOf: (v) => switch (v) {
            TreemapBy.decade => 'Decade',
            TreemapBy.family => 'Family',
            TreemapBy.person => 'Person',
          },
          selected: _by,
          onChanged: (v) => setState(() {
            _by = v;
            _groupId = null;
            _cellId = null;
          }),
          trailing: [
            const SizedBox(width: 16),
            TextButton(
              key: const Key('treemap-crumb-root'),
              onPressed: () => setState(() {
                _groupId = null;
                _cellId = null;
              }),
              child: Text('All', style: crumbStyle),
            ),
            if (group != null) ...[
              const Text('›'),
              TextButton(
                key: const Key('treemap-crumb-group'),
                onPressed: () => setState(() => _cellId = null),
                child: Text(group.label, style: crumbStyle),
              ),
            ],
            if (cell != null) ...[
              const Text('›'),
              TextButton(
                onPressed: null,
                child: Text(cell.label, style: crumbStyle),
              ),
            ],
          ],
        ),
```

- [ ] **Step 5: Run the tests and check they pass.**
  - Run: `flutter test test/lab_app_test.dart test/treemap_test.dart test/tree_graph_test.dart test/swimlanes_test.dart`
  - Expected: PASS (+1 test).

- [ ] **Step 6: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: only `swimlanes_*`, `treeGraph_*`, `treemap_*` show `M` (12 files).

- [ ] **Step 7: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/widgets/view_switch.dart lib/renderers test/lab_app_test.dart test/goldens
git commit -m "refactor(lab): one view switch with singular names in every renderer"
```

---

# Phase 2 — Visual system

### Task 8: Design tokens and component themes in `lab_theme.dart`

**Goldens expected to change:** 25 shell goldens (segment, chip, field colours; filter chip spacing). `zoomCanvas_lod_*` unchanged. **Guards:** `test/lab_theme_test.dart` (contrast + segmented-theme tests) and `test/support/contrast.dart`.

**Files:**
- Create: `test/support/contrast.dart`, `test/lab_theme_test.dart`
- Modify: `lib/theme/lab_theme.dart` (whole file below), `lib/widgets/story_card.dart:51`, `lib/renderers/zoom_canvas_renderer.dart:482`, `lib/renderers/treemap_renderer.dart:357`, `lib/renderers/sliver_list_renderer.dart:167`, `lib/widgets/playback_bar.dart` (watermark colour), `lib/widgets/filter_panel.dart:44-57,98-160`

- [ ] **Step 1: Write the contrast helper** `test/support/contrast.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

double _channel(double c) => c <= 0.03928
    ? c / 12.92
    : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.x contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [fg] (possibly translucent) composited over opaque [bg].
Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);
```

- [ ] **Step 2: Write the failing test** `test/lab_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

import 'support/contrast.dart';

void main() {
  group('text contrast ≥ 4.5:1', () {
    final pairs = <String, (Color, Color)>{
      'ink on parchment': (labInk, labParchment),
      'dimmed ink on parchment': (labDimmedInk, labParchment),
      'dimmed ink on pill fill': (labDimmedInk, labPillFill),
      'terracotta date on parchment': (labTerracotta, labParchment),
      'selected segment label': (labParchment, labTerracotta),
      'selected chip label': (labInk, over(labSageTint, labParchment)),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () => expect(contrast(fg, bg), greaterThanOrEqualTo(4.5)));
    }
  });

  test('selected segment is terracotta with a parchment label', () {
    final style = labTheme(useGoogleFonts: false).segmentedButtonTheme.style!;
    expect(style.backgroundColor!.resolve({WidgetState.selected}), labTerracotta);
    expect(style.foregroundColor!.resolve({WidgetState.selected}), labParchment);
  });
}
```

- [ ] **Step 3: Run it and check it fails.**
  - Run: `flutter test test/lab_theme_test.dart`
  - Expected: FAIL to compile, `Undefined name 'labSageTint'`.

- [ ] **Step 4: Replace `lib/theme/lab_theme.dart`** with:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token copies of `apps/tell_me_a_story/lib/core/theme/album_theme.dart`.
/// Every color in `lib/` comes from this file.
const labParchment = Color(0xFFFBF7F2);
const labInk = Color(0xFF2C2416);
const labTerracotta = Color(0xFF8B5E4B);
const labSage = Color(0xFF7A8B74);
const labMoss = Color(0xFF5B7F3A);
const labPillFill = Color(0xFFF6F1EB);
const labPillBorder = Color(0xFFE7DECE);
const labSurface = Color(0xFFFFF8F6);
const labBorder = Color(0xFFE6DCD1);

/// Darkest allowed dimmed text (docs/ux/80-all-stories.md).
const labDimmedInk = Color(0xFF6A6358);

/// Dimmed decoration (pill fills, card borders). Never text.
const labDimOpacity = 0.35;

/// Ink tints for lines; text never uses them.
const labRuleStrong = Color(0x992C2416); // 60%: axis spines, ticks
const labRule = Color(0x332C2416); // 20%: rails, connectors, edges
const labWatermark = Color(0x1F2C2416); // 12%: playback year

/// Album sage accents (album_theme.dart:91-98), one alpha per role.
const labSageTint = Color(0x597A8B74); // 35%: selected filter chip
const labSageLine = Color(0x737A8B74); // 45%: card, chip, field borders

abstract final class LabSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

abstract final class LabRadius {
  static const tile = 4.0;
  static const chip = 8.0;
  static const card = 12.0;
  static const pill = 20.0;
}

abstract final class LabStroke {
  static const hairline = 1.0;
  static const rule = 1.5;
  static const mark = 2.0;
}

/// Story-dot geometry (diameters and ring strokes, logical px).
abstract final class LabMarker {
  static const dot = 10.0;
  static const small = 8.0;
  static const gap = 2.0;
  static const ring = 2.0;
  static const hollow = 1.5;
}

/// Text roles on top of the theme's TextTheme. Nothing below 11 px.
abstract final class LabText {
  static TextStyle axis(TextTheme t) => t.labelMedium!.copyWith(
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle badge(TextTheme t) =>
      t.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: labParchment);
  static TextStyle count(TextTheme t) =>
      t.labelMedium!.copyWith(color: labDimmedInk);
  static TextStyle lane(TextTheme t) =>
      t.labelLarge!.copyWith(fontWeight: FontWeight.w600);
  static TextStyle group(TextTheme t) => t.titleSmall!;
}

ThemeData labTheme({required bool useGoogleFonts}) {
  TextStyle serifHeading() => useGoogleFonts
      ? GoogleFonts.newsreader(color: labInk, fontWeight: FontWeight.w600)
      : const TextStyle(
          fontFamily: 'Roboto',
          color: labInk,
          fontWeight: FontWeight.w600,
        );
  TextStyle sans({FontWeight? weight}) => useGoogleFonts
      ? GoogleFonts.sourceSans3(color: labInk, fontWeight: weight)
      : TextStyle(fontFamily: 'Roboto', color: labInk, fontWeight: weight);
  TextStyle body() => useGoogleFonts
      ? GoogleFonts.literata(color: labInk)
      : const TextStyle(fontFamily: 'Roboto', color: labInk);

  final textTheme = TextTheme(
    headlineLarge: serifHeading(),
    headlineMedium: serifHeading(),
    headlineSmall: serifHeading(),
    titleLarge: serifHeading(),
    titleMedium: serifHeading(),
    titleSmall: sans(weight: FontWeight.w600),
    bodyLarge: body(),
    bodyMedium: body(),
    bodySmall: body(),
    labelLarge: sans(),
    labelMedium: sans(),
    labelSmall: sans(),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(LabRadius.chip),
    borderSide: const BorderSide(color: labSageLine),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: useGoogleFonts ? null : 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: labTerracotta,
      onPrimary: labParchment,
      secondary: labSage,
      onSecondary: labParchment,
      tertiary: labSage,
      onTertiary: labParchment,
      surface: labParchment,
      onSurface: labInk,
      error: labTerracotta,
      onError: labParchment,
    ),
    scaffoldBackgroundColor: labParchment,
    canvasColor: labParchment,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: labParchment,
      foregroundColor: labInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: serifHeading().copyWith(fontSize: 22),
    ),
    dividerColor: labBorder,
    // docs/ux/80-all-stories.md Rule 4: selected = terracotta pill,
    // parchment label; others ink on the soft beige track.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? labTerracotta : labPillFill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? labParchment : labInk,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: labSageLine)),
        textStyle: WidgetStatePropertyAll(
          sans(weight: FontWeight.w600).copyWith(fontSize: 14),
        ),
      ),
    ),
    // album_theme.dart:94-100.
    chipTheme: ChipThemeData(
      backgroundColor: labParchment,
      selectedColor: labSageTint,
      checkmarkColor: labInk,
      labelStyle: textTheme.labelLarge,
      secondaryLabelStyle: textTheme.labelLarge,
      side: const BorderSide(color: labSageLine),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LabRadius.chip),
      ),
    ),
    // album_theme.dart:131-139; Rule 5 focus = 2 px terracotta.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: labParchment,
      isDense: true,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(
          color: labTerracotta,
          width: LabStroke.mark,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: labInk,
        textStyle: sans(weight: FontWeight.w600).copyWith(fontSize: 14),
      ),
    ),
    // Menus use the dialog surface, as the product's family menu does
    // (docs/ux/121-family-menu.md:14).
    menuTheme: const MenuThemeData(
      style: MenuStyle(backgroundColor: WidgetStatePropertyAll(labSurface)),
    ),
    // The default inactive track vanishes on parchment; the playback
    // scrubber needs its full length visible.
    sliderTheme: const SliderThemeData(inactiveTrackColor: labBorder),
  );
}
```

- [ ] **Step 5: Migrate the token users.**
  - `labCardRadius` gone: replace with `LabRadius.card` at `story_card.dart:51` and `zoom_canvas_renderer.dart:482`. At `treemap_renderer.dart:357`, `labCardRadius / 2` → `LabRadius.tile`.
  - `sliver_list_renderer.dart:167`: `labInk.withValues(alpha: 0.2)` → `labRule`.
  - `playback_bar.dart`, `PlaybackWatermark`: `color: labInk.withValues(alpha: 0.12)` → `color: labWatermark`.
  - `filter_panel.dart`:
    - Add `import '../theme/lab_theme.dart';`.
    - In `TextField` decoration (lines 52-57), delete `border: OutlineInputBorder(),` and `isDense: true,` — theme provides them.
    - `padding: const EdgeInsets.all(16)` → `padding: const EdgeInsets.all(LabSpace.l)`.
    - In three chip `Wrap`s, `spacing: 4, runSpacing: 4,` → `spacing: LabSpace.s, runSpacing: LabSpace.s,`.
    - Each `SizedBox(height: 16)` → `SizedBox(height: LabSpace.l)`, each `SizedBox(height: 8)` → `SizedBox(height: LabSpace.s)`, each `SizedBox(height: 4)` → `SizedBox(height: LabSpace.xs)`.

- [ ] **Step 6: Run the tests and check they pass.**
  - Run: `flutter test test/lab_theme_test.dart`
  - Expected: PASS (7 tests).

- [ ] **Step 7: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: 25 shell goldens `M`.
  - Open `sliverList_dim.png`. Selected "Dim" + "Sliver list" segments terracotta with parchment text, selected person chips sage tint, chips 8 px apart.

- [ ] **Step 8: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean (+7 tests).

```bash
git add lib test/support/contrast.dart test/lab_theme_test.dart test/goldens
git commit -m "feat(lab): design tokens and album-aligned component themes"
```

### Task 9: Restyle `StoryCard` to the album card

**Goldens expected to change:** `sliverList_*` (5), `renderBoxLayout_*` (4), `zoomCanvas_lod_cards` (10 files). Changes: parchment fill, sage border, serif compact titles, place icon, Origin pill. **Guard:** `test/story_card_test.dart`.

**Files:**
- Create: `test/story_card_test.dart`
- Modify: `lib/widgets/story_card.dart:32-148`

- [ ] **Step 1: Write the failing test** `test/story_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/model/lab_models.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/theme/lab_theme.dart';
import 'package:timeline_lab/widgets/story_card.dart';

Future<void> _pumpCard(
  WidgetTester tester,
  LabStory s,
  LabDataset d, {
  bool matched = true,
  bool compact = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: labTheme(useGoogleFonts: false),
    home: Scaffold(
      body: Center(
        child: StoryCard(
          story: s,
          dataset: d,
          matched: matched,
          selected: false,
          compact: compact,
        ),
      ),
    ),
  ),
);

void main() {
  final d = generateDataset();

  testWidgets('dimmed card text sits exactly at the dim floor', (
    tester,
  ) async {
    final s = d.stories.firstWhere(
      (s) => s.personIds.isNotEmpty && s.placeId != null,
    );
    await _pumpCard(tester, s, d, matched: false);
    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(StoryCard),
        matching: find.byType(Text),
      ),
    );
    for (final t in texts) {
      expect(t.style!.color, labDimmedInk, reason: t.data);
    }
    expect(
      find.descendant(
        of: find.byType(StoryCard),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('compact titles keep the serif title role', (tester) async {
    final s = d.stories.first;
    await _pumpCard(tester, s, d, compact: true);
    final title = tester.widget<Text>(find.text(s.title));
    final theme = Theme.of(tester.element(find.byType(StoryCard))).textTheme;
    expect(title.style!.fontSize, theme.titleMedium!.fontSize);
  });

  testWidgets('origin stories carry an Origin pill, not only a border', (
    tester,
  ) async {
    final originId = d.families.values
        .map((f) => f.originStoryId)
        .whereType<String>()
        .first;
    await _pumpCard(tester, d.stories.firstWhere((s) => s.id == originId), d);
    expect(find.text('Origin'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/story_card_test.dart`
  - Expected: FAIL in "compact titles" (14 vs 16) and "Origin pill" (zero widgets found).

- [ ] **Step 3: Implement.** In `lib/widgets/story_card.dart`, replace `build` (lines 32-123) and `_Pill` (lines 126-148) with:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ink = matched ? labInk : labDimmedInk;
    final decorationAlpha = matched ? 1.0 : labDimOpacity;
    final origin = isOrigin(story, dataset);
    final borderColor = selected
        ? labTerracotta
        : origin
        ? labMoss
        : labSageLine;
    final borderWidth = selected || origin ? LabStroke.mark : LabStroke.hairline;
    final names = dataset.personNames(story);
    final place = dataset.placeLabel(story);

    return SizedBox(
      width: width,
      child: Material(
        color: labParchment,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LabRadius.card),
          side: BorderSide(
            color: borderColor.withValues(
              alpha: borderColor.a * decorationAlpha,
            ),
            width: borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? LabSpace.s : LabSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dataset.dateLabel(story),
                  style: theme.labelMedium?.copyWith(
                    color: matched ? labTerracotta : labDimmedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium?.copyWith(color: ink),
                ),
                if (!compact && (origin || names.isNotEmpty)) ...[
                  const SizedBox(height: LabSpace.s),
                  Wrap(
                    spacing: LabSpace.xs,
                    runSpacing: LabSpace.xs,
                    children: [
                      if (origin)
                        _Pill(
                          label: 'Origin',
                          ink: ink,
                          alpha: decorationAlpha,
                          border: labMoss,
                        ),
                      for (final n in names.take(3))
                        _Pill(label: n, ink: ink, alpha: decorationAlpha),
                    ],
                  ),
                ],
                if (!compact && (place != null || story.photoCount > 0)) ...[
                  const SizedBox(height: LabSpace.s),
                  Row(
                    children: [
                      if (place != null) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: matched ? labSage : labDimmedInk,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            place,
                            overflow: TextOverflow.ellipsis,
                            style: theme.labelMedium?.copyWith(color: ink),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (story.photoCount > 0) ...[
                        Icon(Icons.photo_outlined, size: 16, color: ink),
                        const SizedBox(width: 2),
                        Text(
                          '${story.photoCount}',
                          style: theme.labelMedium?.copyWith(color: ink),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.ink,
    required this.alpha,
    this.border = labPillBorder,
  });

  final String label;
  final Color ink;
  final double alpha;
  final Color border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: labPillFill.withValues(alpha: alpha),
      border: Border.all(color: border.withValues(alpha: alpha)),
      borderRadius: BorderRadius.circular(LabRadius.pill),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: LabSpace.s, vertical: 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: ink),
      ),
    ),
  );
}
```

  Also update class doc comment (lines 7-12) to "Album card (album_theme.dart CardTheme): parchment fill, sage border, Newsreader title."

- [ ] **Step 4: Run the tests and check they pass.**
  - Run: `flutter test test/story_card_test.dart test/lab_app_test.dart test/render_box_layout_test.dart test/zoom_canvas_test.dart`
  - Expected: PASS (+3 tests). RenderBox overlap test still holds: card heights only grow, pushing cards apart.

- [ ] **Step 5: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: 10 files above, no others.
  - Open `renderBoxLayout_all.png`. Titles match sliver cards' size + weight.

- [ ] **Step 6: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/widgets/story_card.dart test/story_card_test.dart test/goldens
git commit -m "feat(lab): album story card: parchment, sage border, serif titles, Origin pill"
```

### Task 10: One story-marker primitive (D6)

**Goldens expected to change:** `sliverList_*` (5), `swimlanes_*` (4), `treeGraph_*` (4), `zoomCanvas_lod_years` (14 files). Dimmed dots → hollow rings. **Guards:** `test/story_marker_test.dart` + 2 marker-contrast tests in `test/lab_theme_test.dart`.

**Files:**
- Create: `test/story_marker_test.dart`
- Modify: `lib/renderers/story_marker.dart` (whole file below), `lib/renderers/sliver_list_renderer.dart:162-181`, `lib/renderers/zoom_canvas_renderer.dart:365-381`, `lib/renderers/swimlanes_renderer.dart:329-358,395-411`, `lib/renderers/tree_graph_renderer.dart:262-310`, `test/lab_theme_test.dart`

- [ ] **Step 1: Write the failing tests.** Create `test/story_marker_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/story_marker.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

void main() {
  test('origin ring leaves a gap around the dot', () {
    const m = MarkerSpec(matched: true, origin: true);
    expect(m.originRadius - LabMarker.ring / 2 - m.dotRadius, LabMarker.gap);
  });

  test('selection ring clears the origin ring', () {
    const m = MarkerSpec(matched: true, origin: true, selected: true);
    expect(
      m.selectedRadius - LabMarker.ring / 2,
      greaterThan(m.originRadius + LabMarker.ring / 2),
    );
    expect(
      2 * (m.selectedRadius + LabMarker.ring / 2),
      lessThanOrEqualTo(MarkerSpec.extent(m.diameter)),
    );
  });

  testWidgets('StoryDot keeps one size in every state', (tester) async {
    for (final spec in const [
      MarkerSpec(matched: true),
      MarkerSpec(matched: false, origin: true, selected: true),
    ]) {
      await tester.pumpWidget(Center(child: StoryDot(spec: spec)));
      expect(
        tester.getSize(find.byType(StoryDot)),
        Size.square(MarkerSpec.extent(LabMarker.dot)),
      );
    }
  });
}
```

  Then add below to `test/lab_theme_test.dart`, inside `main()`:

```dart
  group('marker graphics ≥ 3:1 on parchment', () {
    test('terracotta dot and hollow ring', () {
      expect(contrast(labTerracotta, labParchment), greaterThanOrEqualTo(3));
    });
    test('moss origin ring', () {
      expect(contrast(labMoss, labParchment), greaterThanOrEqualTo(3));
    });
  });
```

- [ ] **Step 2: Run them and check they fail.**
  - Run: `flutter test test/story_marker_test.dart`
  - Expected: FAIL to compile, `Undefined class 'MarkerSpec'`.

- [ ] **Step 3: Replace `lib/renderers/story_marker.dart`** with:

```dart
import 'package:flutter/widgets.dart';

import '../model/lab_models.dart';
import '../theme/lab_theme.dart';

// Story dots are terracotta in every renderer; family shows through lanes
// and labels, and moss is reserved for origin rings (Decision D2,
// docs/ux/branch-callout.md Rule 4 "One green").

/// True when some branch family starts at this story.
bool isOrigin(LabStory s, LabDataset d) =>
    d.families.values.any((f) => f.originStoryId == s.id);

/// Family ids in lane order: root first, then branches by branch year.
List<String> familyLaneOrder(LabDataset d) {
  final fams = d.families.values.toList()
    ..sort((a, b) => (a.branchYear ?? 0).compareTo(b.branchYear ?? 0));
  return [for (final f in fams) f.id];
}

/// One story dot (Decision D6). Matched dots are filled and dimmed dots are
/// hollow, so a match never rests on colour or opacity alone. The origin
/// (moss) and selection (terracotta) rings nest outside the dot without
/// touching.
class MarkerSpec {
  const MarkerSpec({
    required this.matched,
    this.origin = false,
    this.selected = false,
    this.diameter = LabMarker.dot,
  });

  final bool matched;
  final bool origin;
  final bool selected;
  final double diameter;

  double get dotRadius => diameter / 2;

  /// Centre-line radius of the hollow (dimmed) stroke.
  double get hollowRadius => dotRadius - LabMarker.hollow / 2;

  double get originRadius => dotRadius + LabMarker.gap + LabMarker.ring / 2;

  double get selectedRadius =>
      (origin ? originRadius + LabMarker.ring / 2 : dotRadius) +
      LabMarker.gap +
      LabMarker.ring / 2;

  /// Square that holds the dot and both rings, whatever the state.
  static double extent(double diameter) =>
      diameter + 4 * (LabMarker.gap + LabMarker.ring);
}

void paintStoryMarker(
  Canvas canvas,
  Offset c,
  MarkerSpec m, {
  double reveal = 1,
}) {
  final dot = Paint()..color = labTerracotta.withValues(alpha: reveal);
  if (m.matched) {
    canvas.drawCircle(c, m.dotRadius, dot);
  } else {
    canvas.drawCircle(
      c,
      m.hollowRadius,
      dot
        ..style = PaintingStyle.stroke
        ..strokeWidth = LabMarker.hollow,
    );
  }
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = LabMarker.ring;
  if (m.origin) {
    canvas.drawCircle(
      c,
      m.originRadius,
      ring..color = labMoss.withValues(alpha: reveal),
    );
  }
  if (m.selected) {
    canvas.drawCircle(
      c,
      m.selectedRadius,
      ring..color = labTerracotta.withValues(alpha: reveal),
    );
  }
}

/// Widget form for the sliver list, zoom canvas and swimlanes. It always
/// occupies [MarkerSpec.extent], so selecting a story never shifts layout.
/// [reserveRings] false sizes it to the bare dot (swimlane cells show
/// selection on the cell instead).
class StoryDot extends StatelessWidget {
  const StoryDot({super.key, required this.spec, this.reserveRings = true});

  final MarkerSpec spec;
  final bool reserveRings;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(
      reserveRings ? MarkerSpec.extent(spec.diameter) : spec.diameter,
    ),
    painter: _StoryDotPainter(spec),
  );
}

class _StoryDotPainter extends CustomPainter {
  _StoryDotPainter(this.spec);

  final MarkerSpec spec;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStoryMarker(canvas, size.center(Offset.zero), spec);

  @override
  bool shouldRepaint(_StoryDotPainter old) =>
      old.spec.matched != spec.matched ||
      old.spec.origin != spec.origin ||
      old.spec.selected != spec.selected ||
      old.spec.diameter != spec.diameter;
}
```

- [ ] **Step 4: Migrate the renderers.**

  **Sliver list.** In `sliver_list_renderer.dart`, replace 12 px `Container` dot (lines 168-178) with:

```dart
                  StoryDot(
                    spec: MarkerSpec(
                      matched: entry.matched,
                      origin: isOrigin(s, data.dataset),
                      selected: s.id == data.selectedId,
                    ),
                  ),
```

  **Zoom canvas.** In `zoom_canvas_renderer.dart`, `_yearDots`, replace `GestureDetector`'s `child: Container(…)` (lines 367-380) with:

```dart
              child: StoryDot(
                spec: MarkerSpec(
                  matched: e.matched,
                  origin: isOrigin(e.story, data.dataset),
                  selected: e.story.id == data.selectedId,
                ),
              ),
```

  **Swimlanes.** In `swimlanes_renderer.dart`, delete `_Dot` (lines 395-411). Single-entry branch: replace `_Dot(alpha: …)` with:

```dart
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: StoryDot(
                spec: MarkerSpec(matched: e.matched, diameter: LabMarker.small),
                reserveRings: false,
              ),
            ),
```

  Multi-entry branch: replace `_Dot(alpha: entryOpacity(e) * reveal(e))` with:

```dart
            Opacity(
              opacity: reveal(e),
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: StoryDot(
                  spec: MarkerSpec(
                    matched: e.matched,
                    diameter: LabMarker.small,
                  ),
                  reserveRings: false,
                ),
              ),
            ),
```

  **Tree graph.** In `tree_graph_renderer.dart`, in `paint`:
  - Delete `ring` paint (lines 263-265).
  - Replace lines 298-310 (`fill.color …` dot + two rings) with block below.
  - In label placement, story-label offset `p + Offset(10, …)` → `p + Offset(MarkerSpec.extent(LabMarker.small) / 2 + 2, -label.size.height / 2)`.

```dart
      if (n.kind == TreeNodeKind.story) {
        paintStoryMarker(
          canvas,
          p,
          MarkerSpec(
            matched: n.matched,
            origin: isOrigin(_stories[n.storyId]!, dataset),
            selected: n.storyId == selectedId,
            diameter: LabMarker.small,
          ),
          reveal: r,
        );
      } else {
        fill.color = _nodeColor(n).withValues(alpha: r * dim);
        canvas.drawCircle(p, 6, fill);
      }
```

  Delete `isLeafLike`, now unused. `entryOpacity` has no callers left after this task (removed in Step 3).

- [ ] **Step 5: Run the tests and check they pass.**
  - Run: `flutter test test/story_marker_test.dart test/lab_theme_test.dart test/swimlanes_test.dart test/zoom_canvas_test.dart test/tree_graph_test.dart test/lab_app_test.dart`
  - Expected: PASS (+5 tests).

- [ ] **Step 6: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: 14 files above.
  - Open `swimlanes_dim.png` and `treeGraph_dim.png`. Dimmed stories = hollow terracotta rings, matches = filled dots.

- [ ] **Step 7: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/renderers test/story_marker_test.dart test/lab_theme_test.dart test/goldens
git commit -m "feat(lab): one story marker: filled=match, hollow=dimmed, nested rings"
```

---

# Phase 3 — Per-renderer restyle

*Run after iPad plan lands (see Coordination). Re-read each file before editing: line numbers below relative to end of Phase 2. If iPad plan moved code, locate by symbol named in each step.*

### Task 11: One time-axis look (RenderBox layout, zoom canvas)

**Goldens expected to change:** `renderBoxLayout_*` (4) and `zoomCanvas_*` (all/dim/hide/playback + three `lod_*`, 7 files), 11 total. **Guard:** `test/time_axis_painter_test.dart`.

**Files:**
- Create: `lib/renderers/time_axis_painter.dart`, `test/time_axis_painter_test.dart`
- Modify: `lib/renderers/render_box_layout_renderer.dart` (`RenderBoxTimeline.build`, `TimeAxisLayout`, `RenderTimeAxisLayout` fields and `paint`), `lib/renderers/zoom_canvas_renderer.dart` (`_ZoomAxisPainter`)

- [ ] **Step 1: Write the failing test** `test/time_axis_painter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/time_axis_painter.dart';
import 'package:timeline_lab/renderers/time_scale.dart';

void main() {
  const scale = TimeScale(minYear: 1948, maxYear: 1961, pxPerYear: 10);

  test('decade density keeps only labelled decade ticks', () {
    final marks = timeAxisMarks(scale, finest: TickKind.decade);
    expect(marks.map((m) => m.label), ['1950', '1960']);
    expect(marks.every((m) => m.length == decadeTickLength), isTrue);
  });

  test('year density adds short unlabelled year ticks', () {
    final marks = timeAxisMarks(scale);
    expect(marks, hasLength(1962 - 1948 + 1));
    expect(
      marks.where((m) => m.label != null).map((m) => m.label),
      ['1950', '1960'],
    );
    expect(
      marks.where((m) => m.label == null).every((m) => m.length == yearTickLength),
      isTrue,
    );
  });

  test('labelYears labels every year tick', () {
    expect(
      timeAxisMarks(scale, labelYears: true).every((m) => m.label != null),
      isTrue,
    );
  });

  test('month density adds eleven month ticks per year', () {
    final months = timeAxisMarks(scale, finest: TickKind.month)
        .where((m) => m.length == monthTickLength);
    expect(months, hasLength((1961 - 1948 + 1) * 11));
  });
}
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/time_axis_painter_test.dart`
  - Expected: FAIL to compile (URI doesn't exist).

- [ ] **Step 3: Implement** `lib/renderers/time_axis_painter.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../theme/lab_theme.dart';
import 'canvas_label.dart';
import 'time_scale.dart';

const decadeTickLength = 10.0;
const yearTickLength = 4.0;
const monthTickLength = 2.0;

class AxisMark {
  const AxisMark(this.px, this.length, this.label);

  final double px;
  final double length;
  final String? label;
}

/// Ticks and labels for [scale], finest first. Pure, so it can be tested.
List<AxisMark> timeAxisMarks(
  TimeScale scale, {
  TickKind finest = TickKind.year,
  bool labelYears = false,
}) => [
  if (finest == TickKind.month)
    for (final m in scale.monthTicks()) AxisMark(m.px, monthTickLength, null),
  for (final t in scale.yearTicks())
    if (t.kind == TickKind.decade)
      AxisMark(t.px, decadeTickLength, '${t.year}')
    else if (finest != TickKind.decade)
      AxisMark(t.px, yearTickLength, labelYears ? '${t.year}' : null),
];

enum TickSide { after, both }

/// The one time-axis look: an ink-60% spine, ticks from [timeAxisMarks],
/// labels in [labelStyle] above and right of their tick. [zoom] is the canvas
/// scale, so strokes, lengths and labels stay constant on screen.
void paintTimeAxis(
  Canvas canvas,
  TimeScale scale, {
  required Axis direction,
  required double cross,
  required TextStyle labelStyle,
  TickKind finest = TickKind.year,
  bool labelYears = false,
  bool labels = true,
  TickSide side = TickSide.after,
  double spineWidth = LabStroke.hairline,
  double zoom = 1,
  double? spineFrom,
  double? spineTo,
}) {
  Offset at(double t, double c) =>
      direction == Axis.horizontal ? Offset(t, c) : Offset(c, t);
  canvas.drawLine(
    at(spineFrom ?? scale.toPx(scale.minYear.toDouble()), cross),
    at(spineTo ?? scale.toPx(scale.maxYear + 1.0), cross),
    Paint()
      ..color = labRuleStrong
      ..strokeWidth = spineWidth / zoom,
  );
  final tick = Paint()
    ..color = labRuleStrong
    ..strokeWidth = LabStroke.hairline / zoom;
  for (final m in timeAxisMarks(scale, finest: finest, labelYears: labelYears)) {
    final len = m.length / zoom;
    final start = side == TickSide.both ? cross - len / 2 : cross;
    canvas.drawLine(at(m.px, start), at(m.px, start + len), tick);
    final label = m.label;
    if (!labels || label == null) continue;
    final o = at(m.px, cross);
    canvas
      ..save()
      ..translate(o.dx, o.dy)
      ..scale(1 / zoom);
    paintLabel(
      canvas,
      label,
      labelStyle,
      const Offset(3, -3),
      anchor: Alignment.bottomLeft,
    );
    canvas.restore();
  }
}

/// Decade labels on parchment pills centred on a vertical spine. Paint them
/// after the cards so that neither side covers them.
void paintSpineLabels(
  Canvas canvas,
  TimeScale scale, {
  required double spineX,
  required TextStyle labelStyle,
}) {
  final pill = Paint()..color = labParchment;
  for (final m in timeAxisMarks(scale, finest: TickKind.decade)) {
    final label = CanvasLabel(m.label!, labelStyle);
    final rect = Rect.fromCenter(
      center: Offset(spineX, m.px),
      width: label.size.width + LabSpace.s,
      height: label.size.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(LabRadius.tile)),
      pill,
    );
    label.paint(canvas, rect.center, anchor: Alignment.center);
    label.dispose();
  }
}
```

- [ ] **Step 4: Run it and check it passes.**
  - Run: `flutter test test/time_axis_painter_test.dart`
  - Expected: PASS (4 tests).

- [ ] **Step 5: Migrate the zoom canvas.** In `zoom_canvas_renderer.dart`:
  - Add `import 'time_axis_painter.dart';`.
  - In `_ZoomAxisPainter(...)` call, pass `labelStyle: LabText.axis(Theme.of(context).textTheme),`.
  - Delete `_label`; replace `_ZoomAxisPainter.paint` with:

```dart
  @override
  void paint(Canvas canvas, Size size) {
    paintTimeAxis(
      canvas,
      timeScale,
      direction: Axis.horizontal,
      cross: axisY,
      labelStyle: labelStyle,
      finest: switch (lod) {
        ZoomLod.decades => TickKind.decade,
        ZoomLod.years => TickKind.year,
        ZoomLod.cards => TickKind.month,
      },
      labelYears: timeScale.pxPerYear * scale >= 48,
      zoom: scale,
      spineFrom: 0,
      spineTo: size.width,
    );
    final cx = cursorX;
    if (cx != null) {
      paintPlaybackCursor(
        canvas,
        Offset(cx, axisY - 4 / scale),
        Offset(cx, bottomY),
        zoom: scale,
      );
    }
  }
```

  Zoom canvas no longer uses `canvas_label.dart`; remove that import.

- [ ] **Step 6: Migrate the RenderBox layout.** In `render_box_layout_renderer.dart`:
  - Delete `axisColor` field, its constructor param, `createRenderObject` + `updateRenderObject` lines, `RenderTimeAxisLayout` `_axisColor` field + setter. In `RenderBoxTimeline.build`, delete `axisColor: labInk,`, change `labelStyle:` to `LabText.axis(Theme.of(context).textTheme)`.
  - Add `import 'time_axis_painter.dart';`, drop `import 'canvas_label.dart';`.
  - Replace `paint` with:

```dart
  @override
  void paint(PaintingContext context, Offset offset) {
    final scale = _scale;
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    // docs/ux/uxd-handoff.md R3: a solid 2 px line runs through the centre.
    paintTimeAxis(
      canvas,
      scale,
      direction: Axis.vertical,
      cross: _axisX,
      labelStyle: labelStyle,
      labels: false,
      side: TickSide.both,
      spineWidth: LabStroke.mark,
    );

    final connector = Paint()..strokeWidth = LabStroke.hairline;
    var child = firstChild;
    while (child != null) {
      final pd = child.parentData! as TimeAxisParentData;
      final r = _playback?.reveal(pd.storyId) ?? 1;
      if (r > 0) {
        connector.color = labRule.withValues(alpha: labRule.a * r);
        final from = Offset(_axisX, pd.idealY);
        final edgeX = pd.side == AxisSide.left
            ? pd.offset.dx + child.size.width
            : pd.offset.dx;
        canvas
          ..drawLine(
            from,
            Offset(edgeX, pd.offset.dy + child.size.height / 2),
            connector,
          )
          ..drawCircle(from, 2, connector);
      }
      child = pd.nextSibling;
    }

    final cursor = _playback?.cursorYear;
    if (cursor != null) {
      final cy = scale.toPx(cursor);
      paintPlaybackCursor(canvas, Offset(0, cy), Offset(size.width, cy));
    }
    canvas.restore();

    defaultPaint(context, offset);

    // Decade pills go last, so cards never cover them. Children may have
    // pushed layers, so re-read the canvas.
    final top = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    paintSpineLabels(top, scale, spineX: _axisX, labelStyle: labelStyle);
    top.restore();
  }
```

- [ ] **Step 7: Run the tests and check they pass.**
  - Run: `flutter test test/time_axis_painter_test.dart test/render_box_layout_test.dart test/zoom_canvas_test.dart`
  - Expected: PASS.

- [ ] **Step 8: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: 11 files above.
  - Open `renderBoxLayout_all.png` and `zoomCanvas_lod_years.png`. Spine ink 60%, ticks 10/4 px, year labels 12 px semibold tabular figures.

- [ ] **Step 9: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean (+4 tests).

```bash
git add lib/renderers/time_axis_painter.dart test/time_axis_painter_test.dart lib/renderers/render_box_layout_renderer.dart lib/renderers/zoom_canvas_renderer.dart test/goldens
git commit -m "feat(lab): one time-axis look for the RenderBox and zoom canvases"
```

### Task 12: Zoom canvas: decade bubbles, chips and lane labels

**Goldens expected to change:** `zoomCanvas_{all,dim,hide,playback}`, `zoomCanvas_lod_decades`, `zoomCanvas_lod_cards` (6 files). **Guard:** new test in `test/zoom_canvas_test.dart`.

**Files:**
- Modify: `lib/renderers/zoom_canvas_renderer.dart` (`_laneLabels`, `_decadeBubbles`, the overflow chip in `_cards`), `test/zoom_canvas_test.dart`

- [ ] **Step 1: Write the failing test.** Append below to `test/zoom_canvas_test.dart`; add missing imports (`package:timeline_lab/filter/timeline_filter.dart`, `lab_controller.dart`, `theme/lab_theme.dart`, `renderers/renderer_contract.dart`).

```dart
  testWidgets('a decade with no matches draws a hollow bubble', (
    tester,
  ) async {
    final c = LabController()
      ..setFilter(const TimelineFilter(fromYear: 1990, toYear: 1999));
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: Scaffold(
          body: ZoomCanvasTimeline(
            data: TimelineViewData(
              dataset: c.dataset,
              entries: c.entries,
              mode: c.filter.mode,
              selectedId: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    BoxDecoration bubble(int decade) =>
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byKey(Key('decade-bubble-$decade')),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(bubble(2020).color, isNull);
    expect(bubble(2020).border, isNotNull);
    expect(bubble(1990).color, labTerracotta);
  });
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/zoom_canvas_test.dart --plain-name "hollow bubble"`
  - Expected: FAIL. 2020 bubble colour = terracotta at 35% alpha, not null.

- [ ] **Step 3: Implement.**

  In `_decadeBubbles`, replace `final style = …` and `Column(children: [...])` with:

```dart
    final theme = Theme.of(context).textTheme;
    // …
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2 * (8 + math.sqrt(c.all) * 3),
                  height: 2 * (8 + math.sqrt(c.all) * 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Decision D6: filled = has matches, hollow = all dimmed.
                    color: c.matched > 0 ? labTerracotta : null,
                    border: c.matched > 0
                        ? null
                        : Border.all(
                            color: labTerracotta,
                            width: LabMarker.hollow,
                          ),
                  ),
                ),
                const SizedBox(height: LabSpace.xs),
                Text('${decade}s', style: LabText.axis(theme)),
                Text(
                  c.matched == c.all
                      ? '${c.all} stories'
                      : '${c.matched} of ${c.all}',
                  style: LabText.count(theme),
                ),
              ],
            ),
```

  In `_laneLabels`, `final style = Theme.of(context).textTheme.labelMedium;` → `final style = LabText.lane(Theme.of(context).textTheme);`.

  In `_cards`:
  - `final chipStyle = Theme.of(context).textTheme.labelMedium?.copyWith(color: labParchment);` → `final chipStyle = LabText.badge(Theme.of(context).textTheme);`.
  - Chip's `borderRadius: BorderRadius.circular(LabRadius.card)` → `BorderRadius.circular(LabRadius.pill)`.

  `labDimOpacity` no longer appears in this file.

- [ ] **Step 4: Run the tests and check they pass.**
  - Run: `flutter test test/zoom_canvas_test.dart`
  - Expected: PASS (+1 test).

- [ ] **Step 5: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: 6 files above.

- [ ] **Step 6: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/renderers/zoom_canvas_renderer.dart test/zoom_canvas_test.dart test/goldens
git commit -m "feat(lab): zoom canvas bubbles, chips and lane labels on the token set"
```

### Task 13: Tree graph: calm edges, hollow groups, label knockouts, one badge

**Goldens expected to change:** `treeGraph_*` (4 files). **Guards:** 2 new tests in `test/tree_graph_test.dart` (`treeEdgeColor` and `TimelineViewData.anyDimmed`).

**Files:**
- Modify: `lib/renderers/renderer_contract.dart` (`TimelineViewData`), `lib/renderers/tree_graph_renderer.dart` (`build`, `TreePainter`), `test/tree_graph_test.dart`

- [ ] **Step 1: Write the failing tests.** Append below to `test/tree_graph_test.dart`; add imports for `theme/lab_theme.dart`, `renderers/renderer_contract.dart`, `filter/timeline_filter.dart`, `model/seed.dart` if missing:

```dart
  test('edges into matches are strong only while something is dimmed', () {
    expect(treeEdgeColor(childMatched: true, dimming: true), labRuleStrong);
    expect(treeEdgeColor(childMatched: false, dimming: true), labRule);
    expect(treeEdgeColor(childMatched: true, dimming: false), labRule);
  });

  test('anyDimmed is true only when some entry is unmatched', () {
    final d = generateDataset();
    TimelineViewData view(TimelineFilter f) => TimelineViewData(
      dataset: d,
      entries: applyFilter(d, f),
      mode: f.mode,
      selectedId: null,
      onSelect: (_) {},
    );
    expect(view(const TimelineFilter()).anyDimmed, isFalse);
    expect(view(const TimelineFilter(fromYear: 1990)).anyDimmed, isTrue);
    expect(
      view(const TimelineFilter(fromYear: 1990, mode: FilterMode.hide))
          .anyDimmed,
      isFalse,
    );
  });
```

- [ ] **Step 2: Run them and check they fail.**
  - Run: `flutter test test/tree_graph_test.dart`
  - Expected: FAIL to compile (`treeEdgeColor` and `anyDimmed` undefined).

- [ ] **Step 3: Implement.**

  In `renderer_contract.dart`, `TimelineViewData`, add:

```dart
  /// Dim mode with at least one unmatched entry: the only state where
  /// renderers should emphasise matches.
  bool get anyDimmed => entries.any((e) => !e.matched);
```

  In `tree_graph_renderer.dart`, add `import 'canvas_label.dart';` if missing, plus top-level function:

```dart
/// Edges into matched nodes read as the path only while something is
/// dimmed; otherwise every edge recedes.
Color treeEdgeColor({required bool childMatched, required bool dimming}) =>
    dimming && childMatched ? labRuleStrong : labRule;
```

  In `_TreeGraphTimelineState.build`, pass to `TreePainter(...)`:

```dart
                            headingStyle: LabText.group(theme),
                            badgeStyle: LabText.badge(theme),
                            dimming: widget.data.anyDimmed,
```

  In `TreePainter`:
  - Add fields `final TextStyle badgeStyle;` and `final bool dimming;` with `required this.badgeStyle, required this.dimming,` in constructor.
  - Add `old.dimming != dimming ||` to `shouldRepaint`.
  - Delete `_nodeColor`.
  - Replace `paint` with code below; add `_paintOverflow`.

```dart
  @override
  void paint(Canvas canvas, Size size) {
    final pos = layout.positions;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = LabStroke.rule;
    for (final n in layout.nodes) {
      final from = pos[n]!;
      for (final c in n.children) {
        final r = _reveal(c.revealId);
        if (r == 0) continue;
        final to = pos[c]!;
        final midX = (from.dx + to.dx) / 2;
        final base = treeEdgeColor(childMatched: c.matched, dimming: dimming);
        edge.color = base.withValues(alpha: base.a * r);
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy),
          edge,
        );
      }
    }

    final knockout = Paint()..color = labParchment;
    for (final n in layout.nodes) {
      final r = _reveal(n.revealId);
      if (r == 0) continue;
      final p = pos[n]!;
      if (n.kind == TreeNodeKind.overflow) {
        _paintOverflow(canvas, n, p, r);
        continue;
      }
      final story = n.kind == TreeNodeKind.story;
      if (story) {
        paintStoryMarker(
          canvas,
          p,
          MarkerSpec(
            matched: n.matched,
            origin: isOrigin(_stories[n.storyId]!, dataset),
            selected: n.storyId == selectedId,
            diameter: LabMarker.small,
          ),
          reveal: r,
        );
      } else {
        // Groups: filled ink when anything under them matches, hollow
        // dimmed ink when nothing does (Decision D6).
        final group = Paint()
          ..color = (n.matched ? labInk : labDimmedInk).withValues(alpha: r);
        if (!n.matched) {
          group
            ..style = PaintingStyle.stroke
            ..strokeWidth = LabMarker.hollow;
        }
        canvas.drawCircle(p, LabMarker.small / 2, group);
      }

      final label = _label(n);
      final at = story
          ? p +
                Offset(
                  MarkerSpec.extent(LabMarker.small) / 2 + 2,
                  -label.size.height / 2,
                )
          : p + Offset(8, -label.size.height - 1);
      final box = at & label.size;
      // Group labels sit where incoming edges run; knock the edges out.
      if (!story) canvas.drawRect(box.inflate(2), knockout);
      if (r < 1) {
        canvas.saveLayer(box, Paint()..color = labInk.withValues(alpha: r));
        label.paint(canvas, at);
        canvas.restore();
      } else {
        label.paint(canvas, at);
      }
    }
  }

  /// `+N more` as one ink pill holding its own text.
  void _paintOverflow(Canvas canvas, TreeNode n, Offset p, double r) {
    final shown = n.hiddenStoryIds.where((id) => _reveal(id) > 0).length;
    final label = CanvasLabel(
      _overflowText(shown),
      badgeStyle.copyWith(color: labParchment.withValues(alpha: r)),
    );
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        p.dx - LabSpace.xs,
        p.dy - label.size.height / 2 - 2,
        label.size.width + 2 * LabSpace.s,
        label.size.height + 4,
      ),
      const Radius.circular(LabRadius.pill),
    );
    canvas.drawRRect(pill, Paint()..color = labInk.withValues(alpha: r));
    label.paint(
      canvas,
      Offset(pill.left + LabSpace.s, p.dy),
      anchor: Alignment.centerLeft,
    );
    label.dispose();
    if (n.hiddenStoryIds.contains(selectedId)) {
      canvas.drawRRect(
        pill.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = LabMarker.ring
          ..color = labTerracotta,
      );
    }
  }
```

- [ ] **Step 4: Run the tests and check they pass.**
  - Run: `flutter test test/tree_graph_test.dart`
  - Expected: PASS (+2 tests). Existing tap tests use `layout.hitTest`, unchanged.

- [ ] **Step 5: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: `treeGraph_*` only (4 files).
  - Open `treeGraph_dim.png`. "1999" and "2000" labels on parchment, no edge crossing; matched paths darker; dimmed groups hollow.

- [ ] **Step 6: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/renderers/renderer_contract.dart lib/renderers/tree_graph_renderer.dart test/tree_graph_test.dart test/goldens
git commit -m "feat(lab): tree graph calm edges, hollow groups, label knockouts"
```

### Task 14: Treemap: quiet until dimming, then a stepped ramp

**Goldens expected to change:** `treemap_*` (4 files). **Guard:** 3 new tests in `test/treemap_test.dart` (2 shade, 1 contrast).

**Files:**
- Modify: `lib/renderers/treemap_layout.dart:214-216`, `lib/renderers/treemap_renderer.dart` (`build`, `_GroupTile`, `_CellGrid`, `TreemapCellTile`), `test/treemap_test.dart`

- [ ] **Step 1: Write the failing tests.** Add `import 'package:timeline_lab/theme/lab_theme.dart';` and `import 'support/contrast.dart';` to `test/treemap_test.dart`, then append:

```dart
  test('shade is quiet and uniform while nothing is dimmed', () {
    expect(treemapShade(1, dimming: false), treemapShade(0.3, dimming: false));
  });

  test('dim shading steps up with the matched share', () {
    expect(
      [for (final s in [0.0, 0.3, 0.6, 1.0]) treemapShade(s, dimming: true)],
      [0.0, 0.16, 0.28, 0.40],
    );
  });

  test('ink stays ≥ 4.5:1 on the strongest shade', () {
    final strongest = labTerracotta.withValues(
      alpha: treemapShade(1, dimming: true),
    );
    expect(
      contrast(labInk, over(strongest, labParchment)),
      greaterThanOrEqualTo(4.5),
    );
  });
```

- [ ] **Step 2: Run them and check they fail.**
  - Run: `flutter test test/treemap_test.dart`
  - Expected: FAIL to compile (`treemapShade` undefined).

- [ ] **Step 3: Implement.**

  In `treemap_layout.dart`, replace lines 214-216 (`treemapFillAlpha`) with:

```dart
/// Cell shade. With nothing dimmed every cell gets the same quiet tint (area
/// is the information). In dim mode the matched share steps through four
/// readable buckets; 0 stays bare parchment.
double treemapShade(double matchedShare, {required bool dimming}) {
  if (!dimming) return 0.10;
  if (matchedShare == 0) return 0;
  if (matchedShare < 0.5) return 0.16;
  if (matchedShare < 1) return 0.28;
  return 0.40;
}
```

  In `treemap_renderer.dart`:
  - In `_TreemapTimelineState.build`, compute `final dimming = data.anyDimmed;`.
  - Thread `required this.dimming` `bool` field through `_GroupTile`, `_CellGrid`, `TreemapCellTile`. Construct at each `_CellGrid(...)` and `TreemapCellTile(...)` call, incl. drill-down `_CellGrid(..., large: true)`.
  - In `TreemapCellTile._build`, replace `final fill = …` and `color: labTerracotta.withValues(alpha: 0.05),` with:

```dart
    final fill = labTerracotta.withValues(
      alpha: treemapShade(share, dimming: dimming),
    );
```

  and

```dart
            color: labParchment,
            border: Border.all(
              color: selected ? labTerracotta : labBorder,
              width: selected ? LabStroke.mark : LabStroke.hairline,
            ),
```

  Then label colour → `share > 0 || !dimming ? labInk : labDimmedInk`.

- [ ] **Step 4: Run the tests and check they pass.**
  - Run: `flutter test test/treemap_test.dart`
  - Expected: PASS (+3 tests).

- [ ] **Step 5: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: `treemap_*` only.
  - Open `treemap_all.png`. Tiles light even tint, not 62% terracotta. `treemap_dim.png`: four distinct steps visible.

- [ ] **Step 6: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/renderers/treemap_layout.dart lib/renderers/treemap_renderer.dart test/treemap_test.dart test/goldens
git commit -m "feat(lab): treemap quiet by default, stepped ramp while dimming"
```

### Task 15: Sliver list and swimlanes text roles

**Goldens expected to change:** `sliverList_*` (5) and `swimlanes_*` (4), 9 total. **Guard:** new test in `test/lab_app_test.dart`.

**Files:**
- Modify: `lib/renderers/sliver_list_renderer.dart` (`_DecadeHeader`), `lib/renderers/swimlanes_renderer.dart` (year strip, lane labels, `LaneCell`), `test/lab_app_test.dart`

- [ ] **Step 1: Write the failing test.** Append to `test/lab_app_test.dart`:

```dart
  testWidgets('decade header count reads as quiet copy', (tester) async {
    final c = await _pump(tester);
    final n = c.entries.where((e) => e.story.decade == 2020).length;
    expect(
      find.descendant(
        of: find.byKey(const Key('decade-header-2020')),
        matching: find.text('$n stories'),
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/lab_app_test.dart --plain-name "quiet copy"`
  - Expected: FAIL (header reads `12 of 12`).

- [ ] **Step 3: Implement.**

  **Sliver list.** In `_DecadeHeader.build`, replace `Text('$matched of $count', style: theme.labelMedium)` with:

```dart
          Text(
            matched == count ? '$count stories' : '$matched of $count',
            style: LabText.count(theme),
          ),
```

  **Swimlanes.** In `swimlanes_renderer.dart`:
  - In `build`, `final labelStyle = Theme.of(context).textTheme.labelMedium;` → `final theme = Theme.of(context).textTheme;`.
  - Year strip uses `style: LabText.axis(theme)`; lane names use `style: LabText.lane(theme)`.
  - In `LaneCell._build`:
    - Single title style → `Theme.of(context).textTheme.labelMedium?.copyWith(color: e.matched ? labInk : labDimmedInk)`.
    - `+N` text style → `LabText.count(Theme.of(context).textTheme)`.
    - `padding: const EdgeInsets.all(6)` → `padding: const EdgeInsets.all(LabSpace.s)`.

- [ ] **Step 4: Run the tests and check they pass.**
  - Run: `flutter test test/lab_app_test.dart test/swimlanes_test.dart`
  - Expected: PASS (+1 test).

- [ ] **Step 5: Update the goldens.**
  - Run: `flutter test --update-goldens test/golden_test.dart && git status --short test/goldens/`
  - Expected: 9 files above.

- [ ] **Step 6: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean.

```bash
git add lib/renderers/sliver_list_renderer.dart lib/renderers/swimlanes_renderer.dart test/lab_app_test.dart test/goldens
git commit -m "feat(lab): list and lane text roles from LabText"
```

### Task 16: One empty state

**Goldens expected to change:** none existing. **Added:** `sliverList_empty.png`. **Guard:** new test in `test/lab_app_test.dart`.

**Files:**
- Create: `lib/widgets/empty_timeline.dart`, `test/goldens/sliverList_empty.png` (generated)
- Modify: `lib/lab_app.dart` (the `renderer` local in `LabHome._build`), `lib/widgets/filter_panel.dart` (search sync), `lib/renderers/tree_graph_renderer.dart` (`layout == null` branch), `lib/renderers/treemap_renderer.dart:39-40`, `test/lab_app_test.dart`, `test/golden_test.dart`

- [ ] **Step 1: Write the failing test.** Append to `test/lab_app_test.dart`:

```dart
  testWidgets('no matches in Hide mode shows the empty state; Clear restores', (
    tester,
  ) async {
    final c = await _pump(tester);
    c.setFilter(
      const TimelineFilter(query: 'zzz-no-match', mode: FilterMode.hide),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('empty-timeline')), findsOneWidget);

    await tester.tap(find.byKey(const Key('empty-clear')));
    await tester.pumpAndSettle();
    expect(c.filter.isActive, isFalse);
    expect(c.filter.mode, FilterMode.hide);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('filter-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byKey(const Key('empty-timeline')), findsNothing);
  });
```

- [ ] **Step 2: Run it and check it fails.**
  - Run: `flutter test test/lab_app_test.dart --plain-name "empty state"`
  - Expected: FAIL (`empty-timeline` not found).

- [ ] **Step 3: Implement** `lib/widgets/empty_timeline.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/lab_theme.dart';

/// The only empty state: nothing left to draw after Hide-mode filtering.
class EmptyTimeline extends StatelessWidget {
  const EmptyTimeline({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('empty-timeline'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'No stories match these filters.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: LabSpace.s),
        TextButton(
          key: const Key('empty-clear'),
          onPressed: onClear,
          child: const Text('Clear filters'),
        ),
      ],
    ),
  );
}
```

  In `lib/lab_app.dart`, add `import 'widgets/empty_timeline.dart';`. In `LabHome._build`, change `final renderer = KeyedSubtree(` to below; close extra paren after `KeyedSubtree(...)`:

```dart
    final renderer = c.entries.isEmpty
        ? EmptyTimeline(
            onClear: () => c.setFilter(TimelineFilter(mode: c.filter.mode)),
          )
        : KeyedSubtree(
```

  In `lib/widgets/filter_panel.dart`, keep search box synced with controller so any clear (this one or panel's own) empties it. In `_FilterPanelState`, add below and change `dispose` to:

```dart
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncSearch);
  }

  /// Runs on controller notifications, never during build.
  void _syncSearch() {
    final q = widget.controller.filter.query;
    if (_search.text != q) _search.text = q;
  }
```

```dart
  @override
  void dispose() {
    widget.controller.removeListener(_syncSearch);
    _search.dispose();
    super.dispose();
  }
```

  Then delete `_search.clear();` from Clear button's `onPressed` — listener does it now.

  Delete duplicate empty states, now covered by shell:
  - `tree_graph_renderer.dart`: `layout == null ? Center(child: Text('No stories', style: theme.bodyMedium))` → `layout == null ? const SizedBox.shrink()`.
  - `treemap_renderer.dart:39-40`: `body = const Center(child: Text('No stories'));` → `body = const SizedBox.shrink();`.

  Add golden to `test/golden_test.dart`, after `sliverList_narrow`:

```dart
  testWidgets('golden sliverList_empty', (tester) async {
    _surface(tester, const Size(1280, 800));
    final c = LabController()
      ..setFilter(
        const TimelineFilter(query: 'zzz-no-match', mode: FilterMode.hide),
      );
    addTearDown(c.dispose);
    await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LabHome),
      matchesGoldenFile('goldens/sliverList_empty.png'),
    );
  });
```

- [ ] **Step 4: Run the tests and check they pass.**
  - Run: `flutter test test/lab_app_test.dart`
  - Expected: PASS (+1 test).

- [ ] **Step 5: Generate the new golden.**
  - Run: `flutter test --update-goldens test/golden_test.dart --plain-name "sliverList_empty" && git status --short test/goldens/`
  - Expected: only `?? test/goldens/sliverList_empty.png`.
  - Open it. Centred serif line + "Clear filters" button.

- [ ] **Step 6: Run the Gate, then commit.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: clean (+2 tests incl. golden).

```bash
git add lib/widgets/empty_timeline.dart lib/lab_app.dart lib/widgets/filter_panel.dart lib/renderers/tree_graph_renderer.dart lib/renderers/treemap_renderer.dart test/lab_app_test.dart test/golden_test.dart test/goldens/sliverList_empty.png
git commit -m "feat(lab): one empty state with Clear filters"
```

### Task 17: README visual-system notes, LOC refresh and final verification

**Files:**
- Modify: `README.md` (new "Visual system" section after "Tests and goldens"; LOC column of comparison table; goldens index gains `sliverList_empty`)

- [ ] **Step 1: Add the section** after "Tests and goldens":

```markdown
## Visual system

Colours, spacing, radii, strokes, marker sizes and text roles live in
`lib/theme/lab_theme.dart` (`LabSpace`, `LabRadius`, `LabStroke`,
`LabMarker`, `LabText`, plus `labRule`, `labRuleStrong`, `labWatermark`,
`labSageTint`, `labSageLine`). Shared drawing primitives:

- `TimeScale` (`lib/renderers/time_scale.dart`): the only year ↔ px mapping.
- `paintTimeAxis` / `paintSpineLabels` (`lib/renderers/time_axis_painter.dart`):
  the one axis look.
- `CanvasLabel` / `paintLabel` (`lib/renderers/canvas_label.dart`): canvas text.
- `MarkerSpec` / `paintStoryMarker` / `StoryDot`
  (`lib/renderers/story_marker.dart`): filled = match, hollow = dimmed, moss
  ring = origin, outer terracotta ring = selected. Story dots are always
  terracotta; family shows through lanes and labels.
- `paintPlaybackCursor`, `scrollOffsetToPlace`, `kFollowAt`,
  `kFocusAlignment` (`lib/playback/reveal.dart`).
- `ViewSwitch` and `EmptyTimeline` (`lib/widgets/`).
```

  Add `sliverList_empty` to goldens index.

- [ ] **Step 2: Refresh the LOC column.**
  - Run: `wc -l lib/renderers/*.dart`
  - Replace each renderer's "Implementation cost (LOC)" cell with new count for its renderer file. Tree graph: add `tree_graph_layout.dart`; treemap: add `treemap_layout.dart`. Shared primitives not counted per renderer.

- [ ] **Step 3: Run the full verification.**
  - Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
  - Expected: `No issues found!`, exit 0, `All tests passed!`.
  - `[UNVERIFIED]` expected count: 104 − 9 (Task 1) + 6 + 3 + 2 + 4 + 1 + 7 + 3 + 5 + 4 + 1 + 2 + 3 + 1 + 2 = **139**. If D1 = keep, 148.
- [ ] **Step 4: Check the repo state.**
  - Run from repo root: `git status --short` and `cd apps/tell_me_a_story && git diff --quiet -- . && echo untouched`.
  - Expected: only `apps/timeline_lab/` paths, and `untouched`.

- [ ] **Step 5: Commit.**

```bash
git add README.md
git commit -m "docs(lab): visual system notes and refreshed LOC"
```

---

## Self-review

**Spec coverage.**

| Required item | Where it is handled |
|---|---|
| Duplicated primitives | Finding 4 → Tasks 2, 3, 4, 5, 11 |
| `TimeScale` and axis painter | Tasks 2, 11 |
| Shell control count | Finding 6 → Tasks 6, 7 (D3, D4) |
| Redundant renderers | Finding 8 → Task 1 (D1), D5 |
| Type hierarchy | Finding 7 → Tasks 8 (`LabText`), 9, 11, 15 |
| Colour, dim and contrast | Findings 1–3 → Tasks 5, 8, 10, 14, contrast tests in `lab_theme_test`/`treemap_test` |
| Spacing | Finding 13 → Task 8 (`LabSpace`, chip spacing) |
| Cards and chips | Task 8 (chip theme), Task 9 (card) |
| Axis, ticks and labels | Task 11 |
| Cursor and watermark | Task 4 (one cursor), Task 6 (watermark behind) |
| Treemap shading | Task 14 |
| Tree edges | Task 13 |
| Empty states | Task 16 |
| Cross-renderer consistency | Tasks 7, 10, 11 |
| Brand alignment | Tasks 5, 8, 9 |
| Golden lists | Every task names goldens + guard tests. |
| Coordination and file structure | Present. |
| User decisions | D1–D6, each with recommendation. |

**Placeholder scan.** No TBDs. Every code step shows code. Phase 3 line numbers explicitly symbol-anchored, since iPad plan runs between.

**Type consistency.**
- `TimeScale.toPx/toYear/span/yearTicks/monthTicks`, `TickKind`, `TimeTick.year/px/kind`: Task 2, used in Tasks 11–12.
- `CanvasLabel(text, style, {maxWidth})`, `.size`, `.paint(canvas, at, {anchor})`, `.originFor`, `paintLabel`: Task 3, used in Tasks 11, 13.
- `scrollOffsetToPlace`, `kFollowAt`, `kFocusAlignment`, `paintPlaybackCursor(canvas, from, to, {zoom})`: Task 4, used in Task 11.
- `MarkerSpec({matched, origin, selected, diameter})`, `.extent`, `paintStoryMarker(canvas, c, spec, {reveal})`, `StoryDot({spec, reserveRings})`: Task 10, used in Task 13.
- `LabText.axis/badge/count/lane/group(TextTheme)`: Task 8, used in Tasks 11–15.
- `TimelineViewData.anyDimmed`: Task 13, used in Task 14.
- `treemapShade(share, {dimming})` replaces `treemapFillAlpha` everywhere (only caller `TreemapCellTile`).