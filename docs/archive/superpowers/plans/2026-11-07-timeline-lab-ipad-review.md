# Timeline Lab on iPad — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/timeline_lab` hold up on iPad every window size, Slide Over (320 pt) to 12.9" landscape. Finger-sized targets, pointer + keyboard support, path to measure frame cost on real iPad hardware.

**Architecture:**
- **Responsive shell.** Below 900 pt, filters move from in-flow `ExpansionTile` to end drawer. Below 600 pt, playback bar + selected-story panel go stacked. Bottom stack respects home indicator; software keyboard no longer squeezes renderer.
- **Kind-aware input.** One helper maps `PointerDeviceKind` → hit radius: 22 pt fingers, precise radius for mouse, trackpad, Pencil. Shared chooser menu resolves taps landing on several stories.
- **Keyboard and pointer.** Shortcuts via `Shortcuts`/`Actions`. Hover cursors only where pointer exists.
- **iOS platform.** Optional, for profile runs on device (Phase 4).

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5 (pinned in `mise.toml`), `flutter_test` goldens, no new deps.

All commands run from `apps/timeline_lab`. Gates stay green after every phase:

```sh
flutter analyze                                     # 0 issues
dart format --output=none --set-exit-if-changed .   # exit 0
flutter test                                        # 104 today + the tests this plan adds
```

---

## Findings

**Methods.** Each finding tagged with how established.

- **[a] Widget sweep.** Throwaway widget/golden tests, now deleted.
  - Pumped `LabApp(useGoogleFonts: false)` for all 7 renderers at 11 window sizes.
  - Setup: `tester.view.devicePixelRatio = 2` and `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` (via `TargetPlatformVariant.only`).
  - System insets: `FakeViewPadding`, 24 pt status bar, 20 pt home indicator.
  - Software keyboard: `viewInsets` 313 pt portrait, 398 pt landscape.
  - Sizes: mini 744×1133 / 1133×744, Air 820×1180 / 1180×820, 12.9" Pro 1024×1366 / 1366×1024, Split View 320×1024, 375×1024, 507×1024, 678×820, Slide Over 320×1133.
- **[b] Browser.** Running dev server at `http://127.0.0.1:8099` in headless Chromium.
  - Viewport 744×1133 at DPR 2.
  - Touch via CDP `Input.dispatchTouchEvent` (tap, drag, two-finger pinch). Mouse via Puppeteer `page.mouse`.
  - `navigator.maxTouchPoints` spoofed to 5 so Flutter web detects iOS like real iPad (see F13).
- **[c] Code.** Code reading only.

Ranked by iPad user impact:

1. **F1 — High. Every renderer overflows at compact widths (Split View ⅓ and Slide Over).** [a]
   - Overflow at 320 pt:
     - App bar actions: 108 px. Fixed width 220 + 12 + 140 + 48 + 8 = 428 px (`lib/lab_app.dart:97-131`, widths at `:102`, `:116`).
     - Playback bar row: 49 px with Sweep, 145 px with Steps (`lib/widgets/playback_bar.dart:50-131`).
     - Sliver-list rows: 72 px. Row = 64 px rail + fixed 280 px `StoryCard` + 48 px padding (`lib/renderers/sliver_list_renderer.dart:156-191`, `lib/widgets/story_card.dart:23`).
     - Treemap toolbar: 81 px (`lib/renderers/treemap_renderer.dart:79-120`).
   - At 375 pt same rows overflow 17–90 px.
   - At 507 and 678 pt no overflow on load, but title truncated to "Ti…" (scratch golden `split12_swimlanes`).
2. **F2 — High. Selected-story panel collapses renderer at compact widths.** [a]
   - Panel row = card 280 + gap 12 + `Expanded(body)` + close 48 (`lib/lab_app.dart:188-210`). Overflows 44 px at 320 pt.
   - Body wraps one char per line → panel grows to **784 px**, renderer gets **0 px**. Both Split View ⅓ and Slide Over (scratch golden `slide_selected`).
3. **F3 — High. Below 900 pt, filters push timeline off screen.** [a][b]
   - Covers iPad mini, Air, 11" portrait (744/820/834 pt), all Split View widths, Slide Over.
   - Filters = `ExpansionTile` inside non-scrolling body `Flex` (`lib/lab_app.dart:138-160`).
     - Opened at 744×1133, renderer keeps ~200 px [b, screenshot].
     - At 320×1024 / 375×1024 / 678×820 / 320×1133 body overflows 142 / 38 / 86 / 33 px [a].
     - Keyboard up at 744×1133: overflows 86 px, timeline gone (scratch golden `mini_p_keyboard`).
   - Search field itself never occluded: bottom y = 201, keyboard top y = 820 [a].
4. **F4 — High. Keyboard squeezes renderer to 9 px.** [a]
   - `Scaffold` resizes for keyboard (default `resizeToAvoidBottomInset`). Bottom stack fixed height: playback 75 + selected panel 142 + status 40.
   - At 1133×744, story selected, 398 pt keyboard up → renderer **9 px** tall.
5. **F5 — High. Painted targets well under 44 pt.**
   - **Painter rail.**
     - Settings: hit radius 12 px (`lib/renderers/painter_rail_renderer.dart:77`), stacked dots 10 px apart (`:75`), clusters within 14 px (`:74`).
     - Finger tap 18 px below dot misses; 8 px below hits [b].
   - **Tree graph.**
     - Only 10 px radius around node centre is target (`lib/renderers/tree_graph_layout.dart:334-348`). Leaf rows 26 px apart (`:287`).
     - Tapping leaf **label text did nothing**; tapping dot selected [b].
   - **Zoom canvas.** Years-level dots are 10×10 `GestureDetector`s (`lib/renderers/zoom_canvas_renderer.dart:365-369`) [c]. Decade bubbles fine, 54–61 px incl. label [a].
   - **Treemap.**
     - Group headers 21 px tall (`lib/renderers/treemap_renderer.dart:166-177`).
     - Overview cells under 44 pt [a]:

       | Stories | 744 pt wide | 507 pt wide |
       |---|---|---|
       | 120 | 3 of 72 | 36 of 72 |
       | 1 000 | 30 of 100 | 59 of 100 (smallest cell 10×7 px) |
   - **Playback bar.** Sweep/Steps `SegmentedButton` 40 px tall (`VisualDensity.compact`, `lib/widgets/playback_bar.dart:92-94`) [a].
   - **Material controls fine.** Chips, search field, era slider, Clear, play, stop, speed, follow all ≥ 48 px tall under iOS density [a].
6. **F6 — Medium. Some stories unreachable by any input.**
   - Swimlane cell with >1 story always selects first matched (`lib/renderers/swimlanes_renderer.dart:367-376`). Others never selectable [c]. "••" cells common at 120 stories [b, screenshot].
   - Rail: nearest dot wins, so finger can't reliably pick one of four dots stacked 10 px apart [b].
7. **F7 — Medium. Rail has dead zone for panning.**
   - Rail canvas 56 + 3 × 84 = 308 px tall (`lib/renderers/painter_rail_renderer.dart:102-105`). Inside vertical `SingleChildScrollView` (`:244-247`), so horizontal scroll view only 308 px tall.
   - In 879 px renderer at 744×1133, horizontal drag at y = 500 did nothing; same drag on lane band panned [b].
   - Tree graph same structure (`lib/renderers/tree_graph_renderer.dart:148-153`) whenever filtered tree shorter than viewport [c].
8. **F8 — Medium. Mouse can't pan, nothing shows hover.**
   - `MaterialScrollBehavior.dragDevices` excludes mouse; iOS shows no scrollbars. With iOS detected [b]:
     - Mouse drag on rail: nothing.
     - Vertical wheel: nothing.
     - Horizontal wheel (trackpad two-finger swipe): scrolled.
   - Painted targets (rail dots, tree nodes) no hover cursor; `lib/` has no `MouseRegion` [c].
   - No hover-only affordance. Material tooltips fall back to long-press on touch [c].
9. **F9 — Medium. No keyboard shortcuts.** [c]
   - `lib/` has no `Shortcuts`, `Actions` or `LogicalKeyboardKey` → Magic Keyboard can't play/pause, step, jump to search.
   - Space shortcut safe. Text fields already swallow Space via `DefaultTextEditingShortcuts`: common map at `$FLUTTER_ROOT/packages/flutter/lib/src/widgets/default_text_editing_shortcuts.dart:328`, and `_macShortcuts` at `:753`, reused by iOS (`:765`). Arrows move text cursor.
10. **F10 — Medium. Status bar sits under home indicator.** [a]
    - No `SafeArea` in `lib/`. With 20 pt bottom inset, status bar bottom edge = view height at every size. `AppBar` already handles top inset.
11. **F11 — Low. App bar dropdowns clip labels.** [a][b]
    - Under iOS (standard) density, each `DropdownMenu` 56 px tall in 56 px toolbar → floating labels "Renderer" and "Stories" cut in half.
    - Both open/select by touch without software keyboard (`requestFocusOnTap` false on iOS) [b].
    - **Owned by design plan**; its TabBar + MenuAnchor replace these dropdowns.
12. **F12 — Low. Nested single-axis scroll views lock to one axis.** [b]
    - Diagonal drag on tree graph (dx −200, dy +300) scrolled horizontal only. Swimlanes, real 2-D viewport, pan both axes [b].
    - Not planned; see Non-goals.
13. **F13 — Info. How Flutter web detects iPad.** [b][c]
    - iPadOS Safari reports `navigator.platform == "MacIntel"`. Flutter web treats as iOS only when `navigator.maxTouchPoints > 2` (`$FLUTTER_ROOT/engine/src/flutter/lib/web_ui/lib/ui_web/src/ui_web/browser_detection.dart:153-161`).
    - Real iPads report 5 → lab runs with iOS density + padded tap targets. Hence tests/goldens use `TargetPlatform.iOS`.
    - Chrome device emulation reports 0. Without spoof, emulated "iPads" render as macOS.
14. **F14 — Info. Already working.**
    - **Rotation mid-playback.** Rotating 744×1133 ↔ 1133×744 during play [a]:
      - playback keeps playing, clock advances;
      - selection + camera follow survive;
      - no exceptions, all 7 renderers.
    - **Renderer state across breakpoint.** Survives (existing test `test/lab_app_test.dart:160-172`).
    - **Touch gestures** [b]:
      - Era `RangeSlider` and scrubber drag correctly.
      - Pinch zooms canvas; one pinch can go decades → cards.
      - Treemap drill-down works.
      - Swimlanes pan both axes.
      - App bar dropdowns open/select.
    - **12.9" portrait.** At 1024 pt already gets sidebar, 723 pt renderer [a].
15. **F15 — Info. Cards use under half portrait width.** [a] Sliver-list cards fixed 280 pt (`lib/widgets/story_card.dart:23`), so at 744 pt card column uses 344 pt. Not planned; see Non-goals.
16. **F16 — Unmeasured. Frame cost on iPad-class hardware unknown.**
    - Package has only `web` and `macos` platforms.
    - Flutter profile mode doesn't run on iOS Simulator → needs device. Phase 4, decision D-i3.

Emulation couldn't show (→ device checklist, Task 22):
- Apple Pencil taps + hover, Scribble into search field.
- Trackpad pointer kinds + pointer effect.
- Magic Keyboard ⌘-hold shortcut overlay.
- Stage Manager free window sizes.
- VoiceOver on painted semantics.
- Real safe-area insets.

## Coordination

Design plan: `docs/superpowers/plans/2026-11-07-timeline-lab-ui-design-review.md`. Both plans on same code. **Agreed order:** design phases 1–2 → this plan → design phase 3.

**Design plan owns:**
- colors, type, markers, axis styling;
- token classes in `lib/theme/lab_theme.dart` (`LabSpace`, `LabRadius`, `LabStroke`, `LabMarker`, `LabText`, `labRule*`);
- control consolidation:
  - renderer `DropdownMenu` → scrollable `TabBar` in `AppBar.bottom`, keeps `Key('renderer-picker')`;
  - dataset size + perf overlay merge into one `MenuAnchor` (`Key('dataset-size')`);
  - Hide/Dim (`Key('filter-mode')`) and playback caption (`Key('playback-caption')`) move into status row;
  - Sweep/Steps + speed merge into one `MenuAnchor` (`Key('playback-design')`); `Key('playback-speed')` removed.

**This plan owns:**
- breakpoints, filter panel placement (sidebar or drawer);
- selected-panel layout + height cap;
- card/column widths inside rows;
- hit radii, gestures, pointer + keyboard input;
- `SafeArea`, keyboard insets, iOS platform.

**Shared files, rule each:**

| File | This plan touches | Rule |
|---|---|---|
| `lib/theme/lab_theme.dart` | adds `LabTarget` and `LabBreakpoint` | Same `abstract final class` style as design tokens, no second convention. |
| `lib/lab_app.dart` | `Scaffold` params, body `Flex`, filter bar/drawer, bottom stack, `LabHome` → stateful, `Shortcuts` | Never `AppBar` contents. Keep design's decoration + colors; structure only. |
| `lib/widgets/playback_bar.dart` | wraps existing controls in compact/regular layout switch | Children moved as-is; design decides children. |
| `lib/widgets/filter_panel.dart` | adds optional `searchFocusNode` | Nothing else. |
| `lib/renderers/treemap_renderer.dart`, `swimlanes_renderer.dart`, `zoom_canvas_renderer.dart`, `tree_graph_*` | gesture handlers, hit boxes, scroll wrappers | No visual changes. |
| `lib/renderers/painter_rail_renderer.dart` | Tasks 14 and 20 | **Only if design decision D1 = keep rail.** If D1 deletes it, skip Task 14, rail parts of Task 20, and `painterRail_playback.png` note. |

**Keys this plan relies on.** Design keeps all: `renderer-picker`, `dataset-size`, `playback-bar`, `playback-play`, `playback-stop`, `playback-prev`, `playback-next`, `playback-scrubber`, `playback-design`, `playback-caption`, `status-bar`, `selected-panel`, `selected-close`, `filter-search`, `filter-era`, `filter-mode`.

**App bar overflow (F1, F11)** fixed by design phases 1–2, not here. Task 2 sweep covers app bar too. If it reports `RenderFlex` overflow inside `NavigationToolbar` at 320/375 pt → design phase 1 not landed. Stop, land it first.

**Goldens.** Both plans change goldens. Regenerate at end of each plan; design phase 3 regenerates last.

## Decisions for the user

**Decided 2026-11-07:**
- D-i1 = (a): goldens at iPad mini portrait, mini landscape, Slide Over.
- D-i2 = (a): filters in end drawer below 900 pt.
- D-i3 = (b): no iOS platform. Profile release web build in iPad Safari (D-i3 = b path at end of Task 22); skip Task 22 iOS steps.
- D-i4 = (b): mouse drag does **not** pan. Skip Task 19. Task 20 + Task 22 checklist assume wheel/trackpad scroll only.
- D-i5 = finger radius only (neither table option): rows stay 26 pt, labels not targets. Task 15 written for this.
- From design plan: D1 = drop painter rail → Task 14 and rail part of Task 20 skipped.

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D-i1 | Which iPad sizes to gate with goldens | **(a)** mini portrait 744×1133, mini landscape 1133×744, Slide Over 320×1133. **(b)** add 12.9" portrait 1024×1366. **(c)** all 11 sizes. | **(a).** Smallest full-screen width (below sidebar breakpoint), shortest height (selected panel + keyboard squeeze hardest), compact layout. Existing 1280×800 goldens cover wide layout. All 11 sizes still gated by no-overflow behaviour tests (Task 2), no PNGs. |
| D-i2 | Filters below 900 pt | **(a)** end drawer (side sheet). **(b)** modal bottom sheet. **(c)** keep `ExpansionTile`, make body scroll. | **(a).** One pattern 320–899 pt, like iPad inspector panels. Overlays not reflows → renderer keeps full height; scrolls above keyboard. Header shows live match count. Bottom sheet suits phones; (c) keeps F3. |
| D-i3 | Add iOS platform to lab | **(a)** add `ios/`, profile on device. **(b)** don't; serve release web build on LAN, profile in iPad Safari with Safari Web Inspector [UNVERIFIED tooling]. **(c)** don't measure. | **(a) if iPad + Apple development team (signing) available**, else (b). Simulator can't run profile mode. |
| D-i4 | Let mouse drag-pan scroll views | **(a)** yes, with `LabScrollBehavior` (macOS desktop too). **(b)** no. | **(a).** Every renderer drag-first; iOS shows no scrollbars. Without it, iPad + mouse can't pan rail, tree, swimlanes (F8). |
| D-i5 | Tree leaf pitch on touch | **(a)** keep 26 pt rows, whole row (dot + label) is target. **(b)** 44 pt rows when platform touch-first. | **(a).** Density is point of tree view; 26 × 260 pt row far easier than today's 20 pt circle. (b) nearly doubles tree height. |

## Non-goals (with reasons)

- **Diagonal pan in tree and rail (F12).** Neither needs it: rail 308 pt tall, barely scrolls vertically; tree ~894 pt wide, barely scrolls horizontally. 2-D viewport conversion rewrites follow + scroll code for little gain.
- **Wider cards on portrait iPads (F15).** Lab compares renderers, not card layouts. Revisit in product app.
- **Zoom overflow chip size.** ~40×28 pt `+N` chip (`zoom_canvas_renderer.dart:472-486`) sits next to full-size cards, cycles its stories. Growing it = visual change → design plan.
- **Double-tap zoom on canvas.** Pinch works (F14). Double-tap would compete with decade-bubble tap.

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `lib/theme/lab_theme.dart` | Modify | `LabTarget` (44 pt min, 22 pt finger radius), `LabBreakpoint` (900 sidebar, 600 compact). |
| `lib/input/pointer_input.dart` | Create | `isFingerLike`, `hitRadiusFor`, `LabScrollBehavior`. |
| `lib/widgets/story_chooser.dart` | Create | `showStoryChooser`: menu for taps covering several stories. |
| `lib/shell/lab_shortcuts.dart` | Create | Intents, `labShortcuts` map, `GuardedAction`. |
| `lib/lab_app.dart` | Modify | `_FilterBar`, end drawer, `_SelectedPanel`, `SafeArea`, keyboard insets, `scrollBehavior`, stateful `LabHome` with `Shortcuts`/`Actions`/`Focus`. |
| `lib/widgets/filter_panel.dart` | Modify | Optional `searchFocusNode`. |
| `lib/widgets/playback_bar.dart` | Modify | Below 600 pt: scrubber own row, controls wrap. |
| `lib/renderers/sliver_list_renderer.dart` | Modify | Card becomes `Flexible` → rows fit at 320 pt. |
| `lib/renderers/treemap_renderer.dart` | Modify | Horizontally scrollable toolbar; finger tap on sub-44 pt cell drills into group. |
| `lib/renderers/painter_rail_renderer.dart` | Modify (if D1 = keep) | `hitTestAll` with radius, chooser for stacks, full-height pan surface, hover cursor. |
| `lib/renderers/tree_graph_layout.dart` | Modify | Leaf rows as hit targets; `hitTest`/`rectOf` take radius. |
| `lib/renderers/tree_graph_renderer.dart` | Modify | Kind-aware tap, full-height pan surface, hover cursor. |
| `lib/renderers/zoom_canvas_renderer.dart` | Modify | 44 pt hit box around each years-level dot. |
| `lib/renderers/swimlanes_renderer.dart` | Modify | `LaneCell` opens chooser when cell holds >1 story. |
| `test/support/ipad.dart` | Create | iPad sizes + insets, `pumpIpad`, `collectFlutterErrors`, `rendererRoot`, `ios` variant. |
| `test/ipad_layout_test.dart` | Create | Overflow sweep, drawer, keyboard, safe area, compact bars, rotation. |
| `test/pointer_input_test.dart` | Create | `hitRadiusFor`. |
| `test/story_chooser_test.dart` | Create | Chooser items + result. |
| `test/ipad_input_test.dart` | Create | Finger + mouse hit tests per renderer, swimlane chooser, treemap small-cell rule, mouse drag, hover cursor. |
| `test/keyboard_test.dart` | Create | Space, arrows, ⌘F, Escape. |
| `test/painter_rail_test.dart`, `test/tree_graph_test.dart` | Modify | Geometry hit tests with radius. |
| `test/golden_test.dart` | Modify | 7 iPad goldens. |
| `README.md` | Modify | "iPad" section + goldens index. |
| `ios/`, `analysis_options.yaml` | Create / Modify (Phase 4, if D-i3 = a) | iOS runner; exclude `ios/**` from analysis. |

---

## Phase 1 — Responsive layout

### Task 1: Layout and target tokens

**Files:**
- Modify: `lib/theme/lab_theme.dart` (append after design plan's token classes, or after `labDimOpacity` if those absent)

- [ ] **Step 1: Add the tokens**

```dart
/// Touch targets (Apple HIG: 44 pt minimum).
abstract final class LabTarget {
  /// Smallest tappable extent for a finger.
  static const min = 44.0;

  /// Hit radius a finger tap gets around a painted point.
  static const fingerRadius = min / 2;
}

/// Window widths where the shell changes layout.
abstract final class LabBreakpoint {
  /// At or above: persistent filter sidebar. Below: filters in an end drawer.
  static const sidebar = 900.0;

  /// Below: stacked playback bar and selected-story panel.
  static const compact = 600.0;
}
```

- [ ] **Step 2: Use the breakpoint in the shell**

In `lib/lab_app.dart`, replace literal in `final wide = constraints.maxWidth >= 900;` (`:138` at `bdd128d`) with `LabBreakpoint.sidebar`.

- [ ] **Step 3: Run the gates**

Run: `flutter analyze && flutter test`
Expected: 0 issues; all pass (no behaviour change).

- [ ] **Step 4: Commit**

```bash
git add apps/timeline_lab/lib/theme/lab_theme.dart apps/timeline_lab/lib/lab_app.dart
git commit -m "feat(lab): LabTarget and LabBreakpoint tokens"
```

### Task 2: iPad test harness and the no-overflow sweep (red)

**Files:**
- Create: `test/support/ipad.dart`
- Create: `test/ipad_layout_test.dart`

- [ ] **Step 1: Write the harness**

`test/support/ipad.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';

/// Logical iPad window sizes in points. Split View and Slide Over widths are
/// the iPadOS values for 11"–13" models.
const ipadSizes = <String, Size>{
  'mini_portrait': Size(744, 1133),
  'mini_landscape': Size(1133, 744),
  'air_portrait': Size(820, 1180),
  'air_landscape': Size(1180, 820),
  'pro13_portrait': Size(1024, 1366),
  'pro13_landscape': Size(1366, 1024),
  'split_third': Size(320, 1024),
  'split_third_wide': Size(375, 1024),
  'split_half': Size(507, 1024),
  'split_half_wide': Size(678, 820),
  'slide_over': Size(320, 1133),
};

/// Status bar and home indicator on Face ID iPads.
const ipadTopInset = 24.0;
const ipadBottomInset = 20.0;

/// iPad software keyboard heights (portrait, landscape).
const ipadKeyboardPortrait = 313.0;
const ipadKeyboardLandscape = 398.0;

/// iOS density and padded tap targets, like Flutter web on a real iPad.
final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

/// The renderer's root: the `KeyedSubtree` keyed by (renderer, dataset size).
final rendererRoot = find.byWidgetPredicate(
  (w) => w is KeyedSubtree && w.key is ValueKey<(RendererKind, int)>,
);

void setIpadView(WidgetTester tester, Size logical, {double dpr = 2}) {
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  final insets = FakeViewPadding(
    top: ipadTopInset * dpr,
    bottom: ipadBottomInset * dpr,
  );
  tester.view.padding = insets;
  tester.view.viewPadding = insets;
  addTearDown(tester.view.reset);
}

/// Shows the software keyboard for a window of [logical] size.
void showKeyboard(WidgetTester tester, Size logical) {
  final dpr = tester.view.devicePixelRatio;
  final height = logical.width > logical.height
      ? ipadKeyboardLandscape
      : ipadKeyboardPortrait;
  tester.view.viewInsets = FakeViewPadding(bottom: height * dpr);
}

Future<LabController> pumpIpad(
  WidgetTester tester,
  Size logical, {
  RendererKind kind = RendererKind.sliverList,
  double dpr = 2,
}) async {
  setIpadView(tester, logical, dpr: dpr);
  final c = LabController()..setRenderer(kind);
  addTearDown(c.dispose);
  await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
  await tester.pumpAndSettle();
  return c;
}

/// Runs [body] and returns the first line of every FlutterError it reports
/// (RenderFlex overflows included), so one test can list them all.
Future<List<String>> collectFlutterErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) =>
      errors.add(d.exceptionAsString().split('\n').first);
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}
```

- [ ] **Step 2: Write the failing sweep**

`test/ipad_layout_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';

import 'support/ipad.dart';

void main() {
  group('no overflow', () {
    for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
      for (final kind in RendererKind.values) {
        testWidgets('$name ${kind.name}', (tester) async {
          final errors = await collectFlutterErrors(() async {
            await pumpIpad(tester, size, kind: kind);
          });
          expect(errors, isEmpty);
        }, variant: ios);
      }

      testWidgets('$name with a selected story', (tester) async {
        final errors = await collectFlutterErrors(() async {
          final c = await pumpIpad(tester, size);
          c.select(c.entries.last.story.id);
          await tester.pumpAndSettle();
        });
        expect(errors, isEmpty);
      }, variant: ios);
    }
  });
}
```

- [ ] **Step 3: Run it and confirm the failures match F1/F2**

Run: `flutter test test/ipad_layout_test.dart`

Expected: FAIL at `split_third`, `split_third_wide`, `slide_over`:
- `split_third` (Steps design, with prev/next): `A RenderFlex overflowed … on the right` from playback bar if design's leaner row still doesn't fit 320 pt. Bar's bigger problem = scrubber squeezed to few px, which overflow can't detect; Task 4 has own test;
- `sliverList`: one more overflow (card row);
- `treemap`: one more overflow (toolbar);
- `with a selected story` cases at those sizes.

Other sizes pass. If `NavigationToolbar` also overflows → design phase 1 not landed (see Coordination).

- [ ] **Step 4: Commit the red test**

```bash
git add apps/timeline_lab/test/support/ipad.dart apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "test(lab): iPad no-overflow sweep (red)"
```

### Task 3: Sliver-list rows fit at 320 pt

**Files:**
- Modify: `lib/renderers/sliver_list_renderer.dart` (`_Row.build`, `:182-191` at `bdd128d`)

- [ ] **Step 1: Make the card flexible**

Replace row's `Align(alignment: Alignment.centerLeft, child: StoryCard(...))` child with:

```dart
            // StoryCard is 280 pt wide via SizedBox; under Flexible the Row
            // hands it a loose max, so it shrinks only when the row can't fit.
            Flexible(
              child: Align(
                alignment: Alignment.centerLeft,
                child: StoryCard(
                  story: s,
                  dataset: data.dataset,
                  matched: entry.matched,
                  selected: s.id == data.selectedId,
                  onTap: () => data.onSelect(s.id),
                ),
              ),
            ),
```

- [ ] **Step 2: Run the sliver-list sweep cases**

Run: `flutter test test/ipad_layout_test.dart --plain-name "sliverList"`
Expected: card-row overflow gone. Playback-bar overflow remains until Task 4.

- [ ] **Step 3: Commit**

```bash
git add apps/timeline_lab/lib/renderers/sliver_list_renderer.dart
git commit -m "fix(lab): sliver list cards shrink below 344 pt"
```

### Task 4: Compact playback bar

**Files:**
- Modify: `lib/widgets/playback_bar.dart` (`PlaybackBar.build`)
- Test: `test/ipad_layout_test.dart`

- [ ] **Step 1: Write the failing test** (append inside `main`)

```dart
  testWidgets('compact playback bar gives the scrubber its own row', (
    tester,
  ) async {
    await pumpIpad(tester, ipadSizes['slide_over']!);
    final bar = tester.getRect(find.byKey(const Key('playback-bar')));
    final scrubber = tester.getRect(
      find.byKey(const Key('playback-scrubber')),
    );
    expect(scrubber.width, greaterThan(bar.width - 48));
  }, variant: ios);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_layout_test.dart --plain-name "compact playback bar"`
Expected: FAIL. Design's row (4 icon buttons + options menu + follow button = 288 pt fixed) → `Expanded` scrubber gets ~8 pt at 320 pt.

- [ ] **Step 3: Implement the layout switch**

Written against bar as design Task 6 leaves it:
- `PlaybackBar({required this.playback})`, no `controller`;
- caption gone from bar (it's `PlaybackCaption` inside `_StatusRow` in `lib/lab_app.dart`);
- `trailing` = `[_PlaybackOptions(playback: pb), IconButton(key: playback-follow …)]`, where `_PlaybackOptions` = design's `MenuAnchor` with `Key('playback-design')`.

Do **not** re-add `SegmentedButton`, speed `TextButton` or caption; would revert design's consolidation. Wrap builder body in `LayoutBuilder`, split existing top-row children into three parts:
- `leading`: everything before scrubber;
- `scrubber`;
- `trailing`: everything after scrubber.

Move each child unchanged. Keep design's `Container` padding + decoration. Result:

```dart
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: playback,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        final pb = playback;
        final steps = pb.design == PlaybackDesign.steps;
        final compact = box.maxWidth < LabBreakpoint.compact;
        final leading = <Widget>[
          /* design's play and stop IconButtons, unchanged
             (Key('playback-play'), Key('playback-stop')) */
          if (steps) ...[
            /* design's prev and next IconButtons, unchanged
               (Key('playback-prev'), Key('playback-next')) */
          ],
        ];
        final scrubber = /* design's Slider(key: Key('playback-scrubber'),
            ...), unchanged */;
        final trailing = <Widget>[
          _PlaybackOptions(playback: pb),
          /* design's IconButton(key: Key('playback-follow'), ...), unchanged */
        ];
        return Container(
          key: const Key('playback-bar'),
          // padding and decoration: keep design's values
          child: compact
              // Compact: the scrubber gets the full width; the controls
              // wrap instead of overflowing.
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scrubber,
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [...leading, ...trailing],
                    ),
                  ],
                )
              : Row(
                  children: [...leading, Expanded(child: scrubber), ...trailing],
                ),
        );
      },
    ),
  );
```

`/* … unchanged */` markers = design's widget expressions, cut/paste as-is. Task changes only placement.

- [ ] **Step 4: Run the test and the sweep**

Run: `flutter test test/ipad_layout_test.dart`
Expected: compact-bar test PASSES, sweep has no playback-bar overflow. Remaining failures: treemap toolbar (Task 5), selected-story cases (Task 6).

- [ ] **Step 5: Run the playback tests**

Run: `flutter test test/lab_app_test.dart test/playback_controller_test.dart`
Expected: PASS (keys unchanged).

- [ ] **Step 6: Commit**

```bash
git add apps/timeline_lab/lib/widgets/playback_bar.dart apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "feat(lab): stacked playback bar below 600 pt"
```

### Task 5: Treemap toolbar scrolls instead of overflowing

**Files:**
- Modify: `lib/renderers/treemap_renderer.dart` (`_TreemapTimelineState.build`, toolbar `Row` at `:79-120` at `bdd128d`)

- [ ] **Step 1: Wrap the toolbar row**

```dart
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          // Grouping segments + breadcrumbs exceed 320 pt; scroll them.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // ...the existing SegmentedButton, SizedBox and crumbs,
                // unchanged...
              ],
            ),
          ),
        ),
```

- [ ] **Step 2: Run the treemap tests and the sweep**

Run: `flutter test test/treemap_test.dart test/ipad_layout_test.dart --plain-name "treemap"`
Expected: `treemap_test.dart` PASSES. Treemap toolbar overflow gone.

- [ ] **Step 3: Commit**

```bash
git add apps/timeline_lab/lib/renderers/treemap_renderer.dart
git commit -m "fix(lab): treemap toolbar scrolls at compact widths"
```

### Task 6: Selected-story panel stacks below 600 pt and is capped at 30% height

**Files:**
- Modify: `lib/lab_app.dart` (`AnimatedSize` child at `:175-214` at `bdd128d`; add `_SelectedPanel`)
- Test: `test/ipad_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('selected panel never starves the renderer (Slide Over)', (
    tester,
  ) async {
    final size = ipadSizes['slide_over']!;
    final c = await pumpIpad(tester, size);
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    final panel = tester.getSize(find.byKey(const Key('selected-panel')));
    expect(panel.height, lessThanOrEqualTo(size.height * 0.3 + 1));
    expect(tester.getSize(rendererRoot).height, greaterThan(300));
  }, variant: ios);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_layout_test.dart --plain-name "selected panel never starves"`
Expected: FAIL. Panel ~784 px tall, renderer ~0 px.

- [ ] **Step 3: Add `_SelectedPanel` and use it**

Add `import 'model/lab_models.dart';` to `lib/lab_app.dart`. Add class:

```dart
/// The selected story under the playback bar. Compact windows stack the card
/// over a 3-line body. The panel never takes more than 30% of the window; it
/// scrolls instead.
class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({required this.controller, required this.story});

  final LabController controller;
  final LabStory story;

  @override
  Widget build(BuildContext context) {
    final window = MediaQuery.sizeOf(context);
    final compact = window.width < LabBreakpoint.compact;
    final card = StoryCard(
      story: story,
      dataset: controller.dataset,
      matched: true,
      selected: false,
    );
    final body = Text(
      story.body,
      maxLines: compact ? 3 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
      style: Theme.of(context).textTheme.bodyMedium,
    );
    final close = IconButton(
      key: const Key('selected-close'),
      tooltip: 'Close',
      icon: const Icon(Icons.close),
      onPressed: () => controller.select(null),
    );
    return DecoratedBox(
      key: const Key('selected-panel'),
      decoration: const BoxDecoration(
        color: labPillFill,
        border: Border(top: BorderSide(color: labBorder)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: window.height * 0.3),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: card,
                          ),
                        ),
                        close,
                      ],
                    ),
                    const SizedBox(height: 8),
                    body,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    card,
                    const SizedBox(width: 12),
                    Expanded(child: body),
                    close,
                  ],
                ),
        ),
      ),
    );
  }
}
```

If design restyled panel, keep their `decoration` + colors, change structure only.

Replace `AnimatedSize` child with:

```dart
            child: selected == null
                ? const SizedBox(width: double.infinity)
                : _SelectedPanel(controller: c, story: selected),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ipad_layout_test.dart test/lab_app_test.dart`
Expected: new test PASSES; `tapping a sliver card opens the selected-story panel` still PASSES. Sweep green every size.

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/lab_app.dart apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "feat(lab): stacked, height-capped selected-story panel"
```

### Task 7: Filters in an end drawer below 900 pt (decision D-i2)

**Files:**
- Modify: `lib/lab_app.dart` (`LabHome._build`: `Scaffold`, body `Flex`; add `_FilterBar`)
- Test: `test/ipad_layout_test.dart`

- [ ] **Step 1: Write the failing tests**

Add `import 'package:timeline_lab/filter/timeline_filter.dart';` to test file, then:

```dart
  testWidgets('below the sidebar breakpoint filters open in an end drawer', (
    tester,
  ) async {
    final c = await pumpIpad(tester, ipadSizes['mini_portrait']!);
    final before = tester.getSize(rendererRoot);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byKey(const Key('filter-search')), findsNothing);

    await tester.tap(find.byKey(const Key('filters-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filters-drawer')), findsOneWidget);
    expect(tester.getSize(rendererRoot), before); // overlay, no reflow

    await tester.tap(find.byKey(const Key('filter-person-p-1')));
    await tester.pumpAndSettle();
    expect(c.filter.personIds, {'p-1'});
    expect(
      find.descendant(
        of: find.byKey(const Key('filters-drawer')),
        matching: find.text(statusLine(c.matchCount, 120, c.filter)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('filters-close')));
    await tester.pumpAndSettle();
    expect(find.text('Filters · 1'), findsOneWidget);
  }, variant: ios);

  for (final name in [
    'mini_portrait',
    'split_half_wide',
    'split_third',
    'slide_over',
  ]) {
    testWidgets('drawer search works with the keyboard up ($name)', (
      tester,
    ) async {
      final size = ipadSizes[name]!;
      await pumpIpad(tester, size);
      final errors = await collectFlutterErrors(() async {
        await tester.tap(find.byKey(const Key('filters-open')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('filter-search')));
        showKeyboard(tester, size);
        await tester.pumpAndSettle();
      });
      expect(errors, isEmpty);
      final field = tester.getRect(find.byKey(const Key('filter-search')));
      expect(field.bottom, lessThanOrEqualTo(size.height - ipadKeyboardPortrait));
    }, variant: ios);
  }
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/ipad_layout_test.dart --plain-name "drawer"`
Expected: FAIL with `Bad state: No element` (no `filters-open` yet).

- [ ] **Step 3: Implement**

Add `import 'dart:math' as math;` to `lib/lab_app.dart`. Add `_FilterBar`:

```dart
/// Below [LabBreakpoint.sidebar]: a single row with the Filters button. The
/// panel opens as an end drawer, so the renderer keeps its full height.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter});

  final TimelineFilter filter;

  int get _activeGroups => [
    filter.query.trim().isNotEmpty,
    filter.fromYear != null || filter.toYear != null,
    filter.personIds.isNotEmpty,
    filter.placeIds.isNotEmpty,
    filter.familyIds.isNotEmpty,
  ].where((on) => on).length;

  @override
  Widget build(BuildContext context) {
    final n = _activeGroups;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: TextButton.icon(
          key: const Key('filters-open'),
          onPressed: () => Scaffold.of(context).openEndDrawer(),
          icon: const Icon(Icons.tune),
          label: Text(n == 0 ? 'Filters' : 'Filters · $n'),
        ),
      ),
    );
  }
}
```

In `_build`, compute layout from window, give `Scaffold` end drawer below breakpoint:

```dart
    final window = MediaQuery.sizeOf(context);
    final wide = window.width >= LabBreakpoint.sidebar;

    return Scaffold(
      appBar: /* unchanged */,
      endDrawer: wide
          ? null
          : Drawer(
              key: const Key('filters-drawer'),
              width: math.min(360, window.width * 0.9),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(
                        children: [
                          Expanded(
                            // Live count: the scrim hides the status bar.
                            child: Text(
                              statusLine(
                                c.matchCount,
                                c.dataset.stories.length,
                                c.filter,
                              ),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              key: const Key('filters-close'),
                              tooltip: 'Close',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  Scaffold.of(context).closeEndDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.viewInsetsOf(context).bottom,
                        ),
                        child: FilterPanel(controller: c),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: /* see below */,
```

In body, remove `LayoutBuilder` that computed `wide` (keep its `Flex`, which preserves renderer element across breakpoint). Replace `ExpansionTile(...)` branch with `_FilterBar(filter: c.filter)`:

```dart
          Expanded(
            // One Flex in both layouts so the renderer keeps its element
            // (scroll, zoom, lane mode) across the breakpoint.
            child: Flex(
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
                  _FilterBar(filter: c.filter),
                if (wide)
                  const VerticalDivider(width: 1)
                else
                  const Divider(height: 1),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: renderer),
                      PlaybackWatermark(playback: playback),
                    ],
                  ),
                ),
              ],
            ),
          ),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ipad_layout_test.dart test/lab_app_test.dart`
Expected: PASS. Existing `renderer state survives the 900px breakpoint` still finds `find.text('Filters')`, now button label.

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/lab_app.dart apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "feat(lab): filters in an end drawer below 900 pt"
```

### Task 8: The keyboard never squeezes the renderer

**Files:**
- Modify: `lib/lab_app.dart` (`Scaffold` + sidebar scroll view)
- Test: `test/ipad_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('keyboard keeps the renderer height (landscape, selected)', (
    tester,
  ) async {
    final size = ipadSizes['mini_landscape']!;
    final c = await pumpIpad(tester, size);
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    final before = tester.getSize(rendererRoot).height;
    final errors = await collectFlutterErrors(() async {
      await tester.tap(find.byKey(const Key('filter-search')));
      showKeyboard(tester, size);
      await tester.pumpAndSettle();
    });
    expect(errors, isEmpty);
    expect(tester.getSize(rendererRoot).height, before);
  }, variant: ios);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_layout_test.dart --plain-name "keyboard keeps"`
Expected: FAIL. Height ~407 → ~9.

- [ ] **Step 3: Implement**

On `Scaffold`, add:

```dart
      // The keyboard covers the playback and status bars rather than
      // shrinking the renderer (F4). Scroll views below pad themselves.
      resizeToAvoidBottomInset: false,
```

Give wide sidebar's scroll view same keyboard padding as drawer:

```dart
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: FilterPanel(controller: c),
                    ),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ipad_layout_test.dart`
Expected: PASS, incl. Task 7 drawer+keyboard cases.

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/lab_app.dart apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "fix(lab): software keyboard no longer squeezes the renderer"
```

### Task 9: The bottom stack clears the home indicator

**Files:**
- Modify: `lib/lab_app.dart` (children under body's `Expanded`)
- Test: `test/ipad_layout_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
  for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
    testWidgets('status bar clears the home indicator ($name)', (
      tester,
    ) async {
      await pumpIpad(tester, size);
      expect(
        tester.getRect(find.byKey(const Key('status-bar'))).bottom,
        lessThanOrEqualTo(size.height - ipadBottomInset),
      );
    }, variant: ios);
  }
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_layout_test.dart --plain-name "home indicator"`
Expected: FAIL all 11 sizes (bottom edge = view height).

- [ ] **Step 3: Wrap everything below the renderer**

Replace `PlaybackBar`, `AnimatedSize` and status-bar children of body `Column` (whatever design made of status row) with single child:

```dart
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlaybackBar(playback: playback),
                AnimatedSize(/* unchanged, child from Task 6 */),
                /* design's _StatusRow (status-bar, PlaybackCaption,
                   filter-mode), unchanged */,
              ],
            ),
          ),
```

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: PASS. Existing goldens unchanged (they set no view padding).

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/lab_app.dart apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "fix(lab): bottom bars respect the home indicator"
```

### Task 10: Regression test for rotation mid-playback (F14)

**Files:**
- Test: `test/ipad_layout_test.dart`

- [ ] **Step 1: Add the test**

Add `import 'package:timeline_lab/lab_app.dart';` to test file, then:

```dart
  for (final kind in RendererKind.values) {
    testWidgets('rotation mid-playback keeps state (${kind.name})', (
      tester,
    ) async {
      final c = await pumpIpad(tester, ipadSizes['mini_portrait']!, kind: kind);
      c.select(c.entries[c.entries.length ~/ 2].story.id);
      await tester.pumpAndSettle();
      final pb = tester.widget<LabHome>(find.byType(LabHome)).playback;
      final renderer = tester.element(rendererRoot);
      pb.play();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final before = pb.clock;
      final errors = await collectFlutterErrors(() async {
        tester.view.physicalSize = ipadSizes['mini_landscape']! * 2;
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      });
      expect(errors, isEmpty);
      expect(pb.playing, isTrue);
      expect(pb.clock, greaterThan(before));
      expect(c.selectedStoryId, isNotNull);
      expect(tester.element(rendererRoot), same(renderer));
      pb.stop();
      await tester.pump();
    }, variant: ios);
  }
```

- [ ] **Step 2: Run it**

Run: `flutter test test/ipad_layout_test.dart --plain-name "rotation"`
Expected: PASS. Characterization test: already works, must not regress with drawer.

- [ ] **Step 3: Commit**

```bash
git add apps/timeline_lab/test/ipad_layout_test.dart
git commit -m "test(lab): rotation mid-playback keeps renderer and playback state"
```

### Task 11: iPad goldens (decision D-i1)

**Files:**
- Modify: `test/golden_test.dart`

- [ ] **Step 1: Add the goldens**

Add `import 'support/ipad.dart';` to test file, append inside `main`:

```dart
  // iPad goldens: logical sizes at DPR 1, iOS density, 24/20 pt insets.
  for (final (name, size, kind) in [
    ('ipad_portrait_sliverList', ipadSizes['mini_portrait']!, RendererKind.sliverList),
    ('ipad_portrait_swimlanes', ipadSizes['mini_portrait']!, RendererKind.swimlanes),
    ('ipad_portrait_treeGraph', ipadSizes['mini_portrait']!, RendererKind.treeGraph),
    ('ipad_portrait_zoomCanvas', ipadSizes['mini_portrait']!, RendererKind.zoomCanvas),
    ('ipad_slideover_sliverList', ipadSizes['slide_over']!, RendererKind.sliverList),
  ]) {
    testWidgets('golden $name', (tester) async {
      await pumpIpad(tester, size, kind: kind, dpr: 1);
      await expectLater(
        find.byType(LabHome),
        matchesGoldenFile('goldens/$name.png'),
      );
    }, variant: ios);
  }

  testWidgets('golden ipad_portrait_filters', (tester) async {
    await pumpIpad(tester, ipadSizes['mini_portrait']!, dpr: 1);
    await tester.tap(find.byKey(const Key('filters-open')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LabHome),
      matchesGoldenFile('goldens/ipad_portrait_filters.png'),
    );
  }, variant: ios);

  testWidgets('golden ipad_landscape_selected', (tester) async {
    final c = await pumpIpad(tester, ipadSizes['mini_landscape']!, dpr: 1);
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(LabHome),
      matchesGoldenFile('goldens/ipad_landscape_selected.png'),
    );
  }, variant: ios);
```

- [ ] **Step 2: Generate and inspect**

Run: `flutter test --update-goldens test/golden_test.dart`

Expected:
- 7 new PNGs: `ipad_portrait_{sliverList,swimlanes,treeGraph,zoomCanvas,filters}.png`, `ipad_slideover_sliverList.png`, `ipad_landscape_selected.png`.
- **Changed:** `sliverList_narrow.png` — `ExpansionTile` row becomes Filters button row.
- No other existing golden changes.

Open `ipad_slideover_sliverList.png`, `ipad_portrait_filters.png`, `ipad_landscape_selected.png` with read tool, confirm:
- no overflow stripes;
- scrubber own row at 320 pt;
- drawer overlays timeline with live count;
- status bar 20 pt above bottom edge.

- [ ] **Step 3: Run the Phase 1 gates**

Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
Expected: 0 issues, exit 0, all pass.

- [ ] **Step 4: Commit**

```bash
git add apps/timeline_lab/test/golden_test.dart apps/timeline_lab/test/goldens
git commit -m "test(lab): iPad goldens"
```

---

## Phase 2 — Touch input

### Task 12: Pointer-kind hit radius

**Files:**
- Create: `lib/input/pointer_input.dart`
- Test: `test/pointer_input_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/input/pointer_input.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

void main() {
  test('fingers get half the 44 pt target; pointers and Pencil stay precise', () {
    expect(hitRadiusFor(PointerDeviceKind.touch, precise: 12), LabTarget.fingerRadius);
    expect(hitRadiusFor(PointerDeviceKind.touch, precise: 30), 30);
    for (final kind in [
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      // Semantics actions and synthesized taps report unknown; keep them exact.
      PointerDeviceKind.unknown,
    ]) {
      expect(hitRadiusFor(kind, precise: 12), 12, reason: '$kind');
    }
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/pointer_input_test.dart`
Expected: FAIL; `pointer_input.dart` doesn't exist.

- [ ] **Step 3: Implement**

`lib/input/pointer_input.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../theme/lab_theme.dart';

/// Fingers are imprecise. Mouse, trackpad and Apple Pencil are not, and
/// semantics actions and synthesized taps (unknown) must hit exactly.
bool isFingerLike(PointerDeviceKind kind) => switch (kind) {
  PointerDeviceKind.touch => true,
  PointerDeviceKind.mouse ||
  PointerDeviceKind.trackpad ||
  PointerDeviceKind.stylus ||
  PointerDeviceKind.invertedStylus ||
  PointerDeviceKind.unknown => false,
};

/// Hit radius around a painted point for a tap from [kind]: [precise] for
/// pointers, at least [LabTarget.fingerRadius] for fingers.
double hitRadiusFor(PointerDeviceKind kind, {required double precise}) =>
    isFingerLike(kind) ? math.max(precise, LabTarget.fingerRadius) : precise;
```

- [ ] **Step 4: Run it**

Run: `flutter test test/pointer_input_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/input/pointer_input.dart apps/timeline_lab/test/pointer_input_test.dart
git commit -m "feat(lab): pointer-kind aware hit radius"
```

### Task 13: Story chooser

**Files:**
- Create: `lib/widgets/story_chooser.dart`
- Test: `test/story_chooser_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/theme/lab_theme.dart';
import 'package:timeline_lab/widgets/story_chooser.dart';

void main() {
  testWidgets('lists every story at 44 pt+ and resolves to the tapped one', (
    tester,
  ) async {
    final d = generateDataset();
    final stories = d.stories.take(3).toList();
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => chosen = await showStoryChooser(
                  context,
                  globalPosition: const Offset(100, 100),
                  stories: stories,
                  dataset: d,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final s in stories) {
      final item = find.byKey(Key('chooser-${s.id}'));
      expect(item, findsOneWidget);
      expect(tester.getSize(item).height, greaterThanOrEqualTo(LabTarget.min));
    }
    await tester.tap(find.byKey(Key('chooser-${stories[1].id}')));
    await tester.pumpAndSettle();
    expect(chosen, stories[1].id);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/story_chooser_test.dart`
Expected: FAIL; import doesn't exist.

- [ ] **Step 3: Implement**

`lib/widgets/story_chooser.dart`:

```dart
import 'package:flutter/material.dart';

import '../model/lab_models.dart';

/// Lets a finger pick one of several stories that share a tap target, such
/// as a stacked rail cluster or a multi-story swimlane cell. Resolves to the
/// chosen id, or null when dismissed.
Future<String?> showStoryChooser(
  BuildContext context, {
  required Offset globalPosition,
  required List<LabStory> stories,
  required LabDataset dataset,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final at = overlay.globalToLocal(globalPosition);
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      at & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final s in stories)
        PopupMenuItem<String>(
          key: Key('chooser-${s.id}'),
          value: s.id,
          child: Text(
            '${s.title} · ${dataset.dateLabel(s)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
```

- [ ] **Step 4: Run it**

Run: `flutter test test/story_chooser_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/widgets/story_chooser.dart apps/timeline_lab/test/story_chooser_test.dart
git commit -m "feat(lab): story chooser for ambiguous taps"
```

### Task 14: Painter rail — finger radius, stack chooser, full-height pan (only if D1 = keep the rail)

**Files:**
- Modify: `lib/renderers/painter_rail_renderer.dart` (`PainterRailGeometry.hitTest` `:140-159`, `_PainterRailTimelineState` `:179-271` at `bdd128d`)
- Test: `test/painter_rail_test.dart`, `test/ipad_input_test.dart` (create)

- [ ] **Step 1: Write the failing geometry tests** (append to `test/painter_rail_test.dart`, add `import 'package:timeline_lab/theme/lab_theme.dart';`)

```dart
  test('a finger radius reaches a dot 20px away; the default does not', () {
    final d = _dataset([_s('a', DateTime.utc(1950, 1, 1))]);
    final g = PainterRailGeometry(_entries(d), d);
    final off = g.points.single.center + const Offset(0, 20);
    expect(g.hitTest(off), isNull);
    expect(_pointId(g.hitTest(off, radius: LabTarget.fingerRadius)), 'a');
  });

  test('hitTestAll lists every stacked dot, nearest first', () {
    final d = _dataset([
      for (var i = 0; i < 3; i++) _s('s$i', DateTime.utc(1970, 3, 1 + i)),
    ]);
    final g = PainterRailGeometry(_entries(d), d);
    final hits = g.hitTestAll(
      g.points.last.center,
      radius: LabTarget.fingerRadius,
    );
    expect([for (final h in hits) _pointId(h)], ['s2', 's1', 's0']);
  });
```

- [ ] **Step 2: Write the failing widget tests**

Create `test/ipad_input_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/painter_rail_renderer.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

import 'support/ipad.dart';

final _railCanvas = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is RailPainter,
);

PainterRailGeometry _rail(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_railCanvas).painter! as RailPainter).geometry;

/// Scrolls the rail so content x sits 300 px into the viewport.
Future<void> _showRailX(WidgetTester tester, double x) async {
  final h = Scrollable.of(
    tester.element(_railCanvas),
    axis: Axis.horizontal,
  ).position;
  h.jumpTo((x - 300).clamp(0, h.maxScrollExtent));
  await tester.pump();
}

void main() {
  group('painter rail', () {
    testWidgets('a finger 20px off a lone dot selects it; a mouse does not', (
      tester,
    ) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['mini_landscape']!,
        kind: RendererKind.painterRail,
        dpr: 1,
      );
      final g = _rail(tester);
      final lone = g.points.firstWhere(
        (p) => g.hitTestAll(p.center, radius: 2 * LabTarget.fingerRadius).length == 1,
      );
      await _showRailX(tester, lone.center.dx);
      final at = tester.getTopLeft(_railCanvas) + lone.center + const Offset(0, 20);

      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(c.selectedStoryId, isNull);

      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(c.selectedStoryId, lone.storyId);
    }, variant: ios);

    testWidgets('a finger on a stack opens the chooser', (tester) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['mini_landscape']!,
        kind: RendererKind.painterRail,
        dpr: 1,
      );
      final g = _rail(tester);
      final stacked = g.points.firstWhere(
        (p) => g
            .hitTestAll(p.center, radius: LabTarget.fingerRadius)
            .whereType<RailPointHit>()
            .length > 1,
      );
      await _showRailX(tester, stacked.center.dx);
      await tester.tapAt(tester.getTopLeft(_railCanvas) + stacked.center);
      await tester.pumpAndSettle();
      final items = find.byType(PopupMenuItem<String>);
      expect(items, findsAtLeastNWidgets(2));
      await tester.tap(items.last);
      await tester.pumpAndSettle();
      expect(c.selectedStoryId, isNotNull);
    }, variant: ios);

    testWidgets('a horizontal drag below the lanes still pans', (tester) async {
      await pumpIpad(
        tester,
        ipadSizes['mini_portrait']!,
        kind: RendererKind.painterRail,
      );
      final h = Scrollable.of(
        tester.element(_railCanvas),
        axis: Axis.horizontal,
      ).position;
      final before = h.pixels;
      final r = tester.getRect(rendererRoot);
      await tester.dragFrom(r.bottomCenter - const Offset(0, 40), const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(h.pixels, lessThan(before));
    }, variant: ios);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/painter_rail_test.dart test/ipad_input_test.dart`
Expected: FAIL. `hitTestAll` and `radius:` param missing; once compiled, widget taps still miss.

- [ ] **Step 4: Implement the geometry**

Replace `hitTest` (`:140-159`) with:

```dart
  /// Every point or badge within [radius] of [local], nearest first. On a
  /// tie the later one comes first (badges after points).
  List<RailHit> hitTestAll(Offset local, {double radius = hitRadius}) {
    final found = <(double, int, RailHit)>[];
    var i = 0;
    for (final p in points) {
      final dist = (p.center - local).distance;
      if (dist <= radius) found.add((dist, i, RailPointHit(p.storyId)));
      i++;
    }
    for (final b in overflowBadges) {
      final dist = (b.at - local).distance;
      if (dist <= radius) found.add((dist, i, RailBadgeHit(b)));
      i++;
    }
    found.sort(
      (a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.compareTo(a.$2),
    );
    return [for (final (_, _, hit) in found) hit];
  }

  /// Nearest point or badge within [radius]; on a tie the later one wins.
  RailHit? hitTest(Offset local, {double radius = hitRadius}) =>
      hitTestAll(local, radius: radius).firstOrNull;
```

- [ ] **Step 5: Implement the widget**

Add imports:

```dart
import '../input/pointer_input.dart';
import '../widgets/story_chooser.dart';
```

In `_PainterRailTimelineState`:

1. Add story lookup next to `_geometry`, rebuild both together in `initState` and `didUpdateWidget`:

   ```dart
     late Map<String, LabStory> _stories;

     void _rebuildGeometry() {
       _geometry = PainterRailGeometry(widget.data.entries, widget.data.dataset);
       _stories = {for (final e in widget.data.entries) e.story.id: e.story};
     }
   ```

   Call `_rebuildGeometry()` where `_geometry = PainterRailGeometry(...)` assigned today (`:188` and `:203`).

2. Add tap handler:

   ```dart
     Future<void> _onTapUp(TapUpDetails details) async {
       final hits = _geometry.hitTestAll(
         details.localPosition,
         radius: hitRadiusFor(
           details.kind,
           precise: PainterRailGeometry.hitRadius,
         ),
       );
       if (hits.isEmpty) return;
       final pointIds = [
         for (final h in hits)
           if (h case RailPointHit(:final storyId)) storyId,
       ];
       // A finger on a stack can't aim at 10 px; let it choose.
       if (isFingerLike(details.kind) &&
           hits.first is RailPointHit &&
           pointIds.length > 1) {
         final id = await showStoryChooser(
           context,
           globalPosition: details.globalPosition,
           stories: [for (final id in pointIds) _stories[id]!],
           dataset: widget.data.dataset,
         );
         if (id != null && mounted) widget.data.onSelect(id);
         return;
       }
       _select(hits.first);
     }
   ```

3. In `build`, make scroll surface fill renderer and use handler:

   ```dart
       return NotificationListener<ScrollStartNotification>(
         onNotification: (n) => disableFollowOnUserScroll(n, _playback),
         child: LayoutBuilder(
           builder: (context, box) => SingleChildScrollView(
             child: ConstrainedBox(
               // Fill the viewport so a drag anywhere pans the rail, not just
               // on the 308 px band the lanes occupy (F7).
               constraints: BoxConstraints(minHeight: box.maxHeight),
               child: SingleChildScrollView(
                 scrollDirection: Axis.horizontal,
                 controller: _hCtl,
                 child: GestureDetector(
                   onTapUp: _onTapUp,
                   child: CustomPaint(
                     size: _geometry.size,
                     painter: RailPainter(/* unchanged arguments */),
                   ),
                 ),
               ),
             ),
           ),
         ),
       );
   ```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/painter_rail_test.dart test/ipad_input_test.dart test/lab_app_test.dart`
Expected: PASS. Existing `hitTest finds a point at its centre and nothing 20px away` still passes with default radius.

- [ ] **Step 7: Commit**

```bash
git add apps/timeline_lab/lib/renderers/painter_rail_renderer.dart apps/timeline_lab/test/painter_rail_test.dart apps/timeline_lab/test/ipad_input_test.dart
git commit -m "feat(lab): rail finger radius, stack chooser, full-height pan"
```

### Task 15: Tree graph — finger radius, full-height pan (decision D-i5 = finger radius only)

D-i5 decided **finger radius only**: rows stay 26 pt apart, labels not targets, finger tap reaches nearest node centre within `LabTarget.fingerRadius`.

**Files:**
- Modify: `lib/renderers/tree_graph_layout.dart` (`hitTest`, `:334-351` at `bdd128d`)
- Modify: `lib/renderers/tree_graph_renderer.dart` (`build`, `:142-176`)
- Test: `test/tree_graph_test.dart`, `test/ipad_input_test.dart`

- [ ] **Step 1: Write the failing layout test** (append to `test/tree_graph_test.dart`; `lab_theme.dart` already imported)

```dart
  test('a finger radius reaches the nearest dot; labels are not targets', () {
    final layout = TreeLayout(buildTimeTree(entries)!);
    final leaf = layout.nodes.firstWhere(
      (n) => n.kind == TreeNodeKind.story && n.children.isEmpty,
    );
    final p = layout.positions[leaf]!;
    // The label is not a target, even for a finger (D-i5).
    expect(
      layout.hitTest(p + const Offset(120, 0), radius: LabTarget.fingerRadius),
      isNull,
    );
    // 12 pt below the dot: outside the precise radius, inside the finger
    // one, and nearer this dot than the next row (26 pt away).
    final q = p + const Offset(0, 12);
    expect(layout.hitTest(q), isNull);
    expect(layout.hitTest(q, radius: LabTarget.fingerRadius), same(leaf));

    // Inner nodes use the same rule.
    final years = [
      for (final n in layout.nodes)
        if (n.kind == TreeNodeKind.year) n,
    ];
    final year = years.firstWhere(
      (y) => years.every(
        (o) =>
            identical(o, y) ||
            (layout.positions[o]! - layout.positions[y]!).distance >
                2 * LabTarget.fingerRadius,
      ),
    );
    final r = layout.positions[year]! + const Offset(0, 18);
    expect(layout.hitTest(r), isNull);
    expect(layout.hitTest(r, radius: LabTarget.fingerRadius), same(year));
  });
```

- [ ] **Step 2: Write the failing widget test** (append group to `test/ipad_input_test.dart`)

If Task 14 skipped (D1 deleted rail), first create `test/ipad_input_test.dart` with this header and empty `void main() {}`. Task 14 imports minus painter-rail import, helpers, group:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/renderer_contract.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

import 'support/ipad.dart';
```

Add imports:

```dart
import 'package:timeline_lab/filter/timeline_filter.dart';
import 'package:timeline_lab/renderers/tree_graph_renderer.dart';
```

Then group:

```dart
  group('tree graph', () {
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is TreePainter,
    );

    testWidgets('a horizontal drag below a short tree still pans', (
      tester,
    ) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['mini_portrait']!,
        kind: RendererKind.treeGraph,
      );
      c.setFilter(
        TimelineFilter(
          mode: FilterMode.hide,
          query: c.entries.first.story.title,
        ),
      );
      await tester.pumpAndSettle();
      final h = Scrollable.of(
        tester.element(canvas),
        axis: Axis.horizontal,
      ).position;
      final before = h.pixels;
      final r = tester.getRect(rendererRoot);
      await tester.dragFrom(
        r.bottomCenter - const Offset(0, 40),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();
      expect(h.pixels, greaterThan(before));
    }, variant: ios);
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/tree_graph_test.dart test/ipad_input_test.dart --plain-name "tree"`
Expected: FAIL. `hitTest` lacks `radius:`, drag below tree doesn't pan.

- [ ] **Step 4: Implement the layout**

Replace `hitTest` in `TreeLayout` (`rectOf` unchanged):

```dart
  static const hitRadius = 10.0;

  /// The node whose centre is nearest [p] within [radius]. Labels are not
  /// targets (D-i5); callers pass `LabTarget.fingerRadius` for finger taps.
  TreeNode? hitTest(Offset p, {double radius = hitRadius}) {
    TreeNode? best;
    var bestDist = double.infinity;
    for (final n in nodes) {
      final dist = (positions[n]! - p).distance;
      if (dist <= radius && dist < bestDist) {
        best = n;
        bestDist = dist;
      }
    }
    return best;
  }
```

Rows stay 26 pt apart → 22 pt finger radius overlaps next row's circle; nearest centre wins, which test pins.

- [ ] **Step 5: Implement the widget**

Add `import '../input/pointer_input.dart';`. Replace scroll + gesture subtree (`:145-175`):

```dart
              : NotificationListener<ScrollStartNotification>(
                  onNotification: (n) =>
                      disableFollowOnUserScroll(n, _playback),
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      controller: _vCtl,
                      child: ConstrainedBox(
                        // A short (filtered) tree still pans anywhere (F7).
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: SingleChildScrollView(
                          controller: _hCtl,
                          scrollDirection: Axis.horizontal,
                          child: GestureDetector(
                            onTapUp: (details) {
                              final hit = layout.hitTest(
                                details.localPosition,
                                radius: hitRadiusFor(
                                  details.kind,
                                  precise: TreeLayout.hitRadius,
                                ),
                              );
                              if (hit != null) _onTap(hit);
                            },
                            child: CustomPaint(
                              size: layout.size,
                              painter: TreePainter(/* unchanged arguments */),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/tree_graph_test.dart test/ipad_input_test.dart`
Expected: PASS. Existing `tapping an overflow node expands it; a leaf selects` still passes (taps node centres).

- [ ] **Step 7: Commit**

```bash
git add apps/timeline_lab/lib/renderers/tree_graph_layout.dart apps/timeline_lab/lib/renderers/tree_graph_renderer.dart apps/timeline_lab/test/tree_graph_test.dart apps/timeline_lab/test/ipad_input_test.dart
git commit -m "feat(lab): finger hit radius and full-height pan in tree graph"
```

### Task 16: Zoom canvas — 44 pt target around years-level dots

**Files:**
- Modify: `lib/renderers/zoom_canvas_renderer.dart` (`_yearDots`, `:365-381` at `bdd128d`)
- Test: `test/ipad_input_test.dart`

- [ ] **Step 1: Write the failing test** (append group to `test/ipad_input_test.dart`)

Add imports:

```dart
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/renderers/zoom_canvas_renderer.dart';
```

Then group:

```dart
  group('zoom canvas', () {
    testWidgets('a finger 15px off a years-level dot selects it', (
      tester,
    ) async {
      setIpadView(tester, ipadSizes['mini_portrait']!, dpr: 1);
      final c = LabController();
      addTearDown(c.dispose);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: labTheme(useGoogleFonts: false),
          home: Scaffold(
            body: ZoomCanvasTimeline(
              initialScale: 3,
              data: TimelineViewData(
                dataset: c.dataset,
                entries: c.entries,
                mode: c.filter.mode,
                selectedId: null,
                onSelect: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dots = find
          .descendant(
            of: find.byType(ZoomCanvasTimeline),
            matching: find.byWidgetPredicate(
              (w) => w is GestureDetector && w.key == null && w.onTap != null,
            ),
          )
          .evaluate()
          .toList();
      final centers = [
        for (final e in dots)
          tester.getCenter(find.byElementPredicate((x) => x == e)),
      ];
      final view = tester.getRect(find.byType(ZoomCanvasTimeline)).deflate(30);
      final i = centers.indexWhere(
        (p) =>
            view.contains(p) &&
            centers.every((q) => q == p || (q - p).distance > 60),
      );
      final id =
          (dots[i].findAncestorWidgetOfExactType<Positioned>()!.key!
                  as ValueKey<String>)
              .value;
      await tester.tapAt(centers[i] + const Offset(0, 15));
      await tester.pump();
      expect(selected, id);
    });
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_input_test.dart --plain-name "years-level dot"`
Expected: FAIL. `selected` null; 10 px dot misses.

- [ ] **Step 3: Implement**

Replace dot's `GestureDetector`:

```dart
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => data.onSelect(e.story.id),
              // 44 pt target around the 10 px dot. The pin anchors this box
              // at its centre, so the dot does not move.
              child: SizedBox.square(
                dimension: LabTarget.min,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(/* unchanged */),
                  ),
                ),
              ),
            ),
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ipad_input_test.dart test/zoom_canvas_test.dart`
Expected: PASS.

- [ ] **Step 5: Confirm the goldens are unchanged**

Run: `flutter test test/golden_test.dart --plain-name zoomCanvas`
Expected: PASS. Hit box transparent.

- [ ] **Step 6: Commit**

```bash
git add apps/timeline_lab/lib/renderers/zoom_canvas_renderer.dart apps/timeline_lab/test/ipad_input_test.dart
git commit -m "feat(lab): 44pt targets for zoom-canvas year dots"
```

### Task 17: Swimlanes — every story in a cell is reachable

**Files:**
- Modify: `lib/renderers/swimlanes_renderer.dart` (`LaneCell._build`, `:367-376` at `bdd128d`)
- Test: `test/ipad_input_test.dart`

- [ ] **Step 1: Write the failing test** (append group to `test/ipad_input_test.dart`)

Add `import 'package:timeline_lab/renderers/swimlanes_renderer.dart';`, then:

```dart
  group('swimlanes', () {
    testWidgets('a multi-story cell opens the chooser', (tester) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['mini_portrait']!,
        kind: RendererKind.swimlanes,
      );
      final multi = find
          .byWidgetPredicate((w) => w is LaneCell && w.entries.length > 1)
          .first;
      final cell = tester.widget<LaneCell>(multi);
      await tester.tap(multi);
      await tester.pumpAndSettle();
      expect(
        find.byType(PopupMenuItem<String>),
        findsNWidgets(cell.entries.length),
      );
      final second = cell.entries[1].story.id;
      await tester.tap(find.byKey(Key('chooser-$second')));
      await tester.pumpAndSettle();
      expect(c.selectedStoryId, second);
    }, variant: ios);
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_input_test.dart --plain-name "multi-story cell"`
Expected: FAIL. No menu; first matched story selected directly.

- [ ] **Step 3: Implement**

Add `import '../widgets/story_chooser.dart';`. Replace cell's `GestureDetector` handler:

```dart
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: shown.isEmpty
          ? null
          : (details) => _onTapUp(context, details, shown),
      child: /* unchanged Container */,
    );
```

Add to `LaneCell`:

```dart
  /// One story selects directly. Several open the chooser, so no story in
  /// the cell is unreachable (F6).
  Future<void> _onTapUp(
    BuildContext context,
    TapUpDetails details,
    List<TimelineEntry> shown,
  ) async {
    if (shown.length == 1) {
      data.onSelect(shown.single.story.id);
      return;
    }
    final id = await showStoryChooser(
      context,
      globalPosition: details.globalPosition,
      stories: [for (final e in shown) e.story],
      dataset: data.dataset,
    );
    if (id != null) data.onSelect(id);
  }
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ipad_input_test.dart test/swimlanes_test.dart test/lab_app_test.dart`
Expected: PASS.

- [ ] **Step 5: Update the README**

In README comparison row for swimlanes, change Hit testing cell from "A tap picks the cell's first matched entry." to "A single-story cell selects on tap. A cell with more stories opens a chooser."

- [ ] **Step 6: Commit**

```bash
git add apps/timeline_lab/lib/renderers/swimlanes_renderer.dart apps/timeline_lab/test/ipad_input_test.dart apps/timeline_lab/README.md
git commit -m "feat(lab): swimlane cells offer every story via a chooser"
```

### Task 18: Treemap — a finger tap on a sub-44 pt cell drills into its group

**Files:**
- Modify: `lib/renderers/treemap_renderer.dart` (`_GroupTile`, `_CellGrid`, `TreemapCellTile`)
- Test: `test/ipad_input_test.dart`

- [ ] **Step 1: Write the failing test** (append group to `test/ipad_input_test.dart`)

Add `import 'package:timeline_lab/renderers/treemap_renderer.dart';`, then:

```dart
  group('treemap', () {
    Future<TreemapCellTile> smallCell(WidgetTester tester) async {
      final c = await pumpIpad(
        tester,
        ipadSizes['split_half']!,
        kind: RendererKind.treemap,
        dpr: 1,
      );
      c.setDatasetSize(1000);
      await tester.pumpAndSettle();
      return find
          .byType(TreemapCellTile)
          .evaluate()
          .firstWhere((e) {
            final s = (e.renderObject! as RenderBox).size;
            return s.width < LabTarget.min || s.height < LabTarget.min;
          })
          .widget as TreemapCellTile;
    }

    testWidgets('finger on a tiny cell opens its group', (tester) async {
      final tile = await smallCell(tester);
      await tester.tapAt(tester.getCenter(find.byWidget(tile)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('treemap-crumb-group')), findsOneWidget);
      expect(
        find.byKey(Key('treemap-story-${tile.cell.entries.first.story.id}')),
        findsNothing,
      );
    }, variant: ios);

    testWidgets('mouse on a tiny cell opens the cell', (tester) async {
      final tile = await smallCell(tester);
      await tester.tapAt(
        tester.getCenter(find.byWidget(tile)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('treemap-story-${tile.cell.entries.first.story.id}')),
        findsOneWidget,
      );
    }, variant: ios);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/ipad_input_test.dart --plain-name "tiny cell"`
Expected: finger test FAILS (opens cell); mouse test PASSES.

- [ ] **Step 3: Implement**

Add `import '../input/pointer_input.dart';`.

1. In `TreemapCellTile`, add field + constructor param:

   ```dart
     /// Tap target for fingers when this cell is under [LabTarget.min] in
     /// either axis (overview only). Null means [onTap] for every input.
     final VoidCallback? onSmallTap;
   ```

   Add `this.onSmallTap` to constructor.

2. In `_build`, wrap `GestureDetector` so it knows its size:

   ```dart
         child: LayoutBuilder(
           builder: (context, box) {
             final small =
                 box.maxWidth < LabTarget.min || box.maxHeight < LabTarget.min;
             return GestureDetector(
               behavior: HitTestBehavior.opaque,
               // A finger can't aim at a sub-44 pt cell. It opens the whole
               // group instead, where cells are large.
               onTapUp: (d) =>
                   (small && onSmallTap != null && isFingerLike(d.kind)
                           ? onSmallTap!
                           : onTap)
                       .call(),
               child: /* unchanged DecoratedBox */,
             );
           },
         ),
   ```

3. In `_CellGrid`:
   - add `final VoidCallback? onGroup;` field and `this.onGroup` constructor param;
   - pass `onSmallTap: large ? null : onGroup` to each `TreemapCellTile`.

4. In `_GroupTile.build`, pass `onGroup: onGroup` to `_CellGrid`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ipad_input_test.dart test/treemap_test.dart`
Expected: PASS. `treemap_test.dart` taps cells only inside drilled group (`large`) → unchanged.

- [ ] **Step 5: Run the Phase 2 gates**

Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
Expected: 0 issues; exit 0; all pass. If Task 14 ran, `painterRail_playback.png` fails (cursor line now runs full renderer height). Regenerate with `flutter test --update-goldens test/golden_test.dart`, open to confirm, commit with this task. No other golden changes.

- [ ] **Step 6: Commit**

```bash
git add apps/timeline_lab/lib/renderers/treemap_renderer.dart apps/timeline_lab/test/ipad_input_test.dart apps/timeline_lab/test/goldens
git commit -m "feat(lab): treemap small cells open their group on touch"
```

---

## Phase 3 — Pointer and keyboard

### Task 19: Mouse drag pans scroll views (SKIPPED: D-i4 = b)

Not run. Kept for reference if D-i4 revisited.

**Files:**
- Modify: `lib/input/pointer_input.dart`, `lib/lab_app.dart` (`_LabAppState.build`)
- Test: `test/ipad_input_test.dart`

- [ ] **Step 1: Write the failing test** (append to `swimlanes` group)

```dart
    testWidgets('a mouse drag pans the grid', (tester) async {
      await pumpIpad(
        tester,
        ipadSizes['mini_landscape']!,
        kind: RendererKind.swimlanes,
      );
      final h = Scrollable.of(
        tester.element(find.byType(LaneCell).first),
        axis: Axis.horizontal,
      ).position;
      final before = h.pixels;
      await tester.dragFrom(
        tester.getCenter(find.byType(LaneGridView)),
        const Offset(300, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(h.pixels, lessThan(before));
    }, variant: ios);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_input_test.dart --plain-name "mouse drag"`
Expected: FAIL; `pixels` unchanged.

- [ ] **Step 3: Implement**

Append to `lib/input/pointer_input.dart` (add `import 'package:flutter/material.dart';`):

```dart
/// Lets a mouse drag pan the lab's scroll views. iOS shows no scrollbars,
/// and the rail, tree and swimlanes are drag-first (F8). Touch, Pencil and
/// trackpad keep Flutter's defaults.
class LabScrollBehavior extends MaterialScrollBehavior {
  const LabScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}
```

In `_LabAppState.build`, add `scrollBehavior: const LabScrollBehavior(),` to `MaterialApp`, import `input/pointer_input.dart`.

- [ ] **Step 4: Run all tests**

Run: `flutter test`
Expected: PASS (goldens unchanged).

- [ ] **Step 5: Commit**

```bash
git add apps/timeline_lab/lib/input/pointer_input.dart apps/timeline_lab/lib/lab_app.dart apps/timeline_lab/test/ipad_input_test.dart
git commit -m "feat(lab): mouse drag pans scroll views"
```

### Task 20: Hover cursor on painted targets (pointer only)

**Files:**
- Modify: `lib/renderers/tree_graph_renderer.dart`
- Modify: `lib/renderers/painter_rail_renderer.dart` (only if D1 = keep rail)
- Test: `test/ipad_input_test.dart`

- [ ] **Step 1: Write the failing test** (append to `tree graph` group)

Add `import 'package:flutter/rendering.dart';` and `import 'package:timeline_lab/renderers/tree_graph_layout.dart';`, then:

```dart
    testWidgets('mouse cursor is a hand over a node only', (tester) async {
      await pumpIpad(
        tester,
        ipadSizes['mini_landscape']!,
        kind: RendererKind.treeGraph,
        dpr: 1,
      );
      final layout = (tester.widget<CustomPaint>(canvas).painter! as TreePainter)
          .layout;
      final origin = tester.getTopLeft(canvas);
      final view = tester.getRect(rendererRoot);
      final leaf = layout.nodes.firstWhere(
        (n) =>
            n.kind == TreeNodeKind.story &&
            view.deflate(40).contains(origin + layout.positions[n]!),
      );
      final at = origin + layout.positions[leaf]!;
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 1,
      );
      await mouse.addPointer(location: view.center);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(at + const Offset(60, 0)); // on the label
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
      await mouse.moveTo(at - const Offset(60, 0)); // between levels: empty
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.click),
      );
    }, variant: ios);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ipad_input_test.dart --plain-name "mouse cursor"`
Expected: FAIL. Cursor `basic`, not `click`.

- [ ] **Step 3: Implement for the tree**

In `_TreeGraphTimelineState`:
- add `final _hoverTarget = ValueNotifier(false);`;
- add `_hoverTarget.dispose();` to `dispose`;
- wrap `GestureDetector` from Task 15:

```dart
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _hoverTarget,
                            // Only the cursor rebuilds; the painter and its
                            // laid-out labels are reused.
                            builder: (context, over, child) => MouseRegion(
                              cursor: over
                                  ? SystemMouseCursors.click
                                  : MouseCursor.defer,
                              onHover: (e) => _hoverTarget.value =
                                  layout.hitTest(e.localPosition) != null,
                              onExit: (_) => _hoverTarget.value = false,
                              child: child,
                            ),
                            child: GestureDetector(/* Task 15, unchanged */),
                          ),
```

`MouseRegion` reacts only to hovering pointers (mouse, trackpad, Pencil hover). Touch never triggers → nothing depends on hover.

- [ ] **Step 4: Implement for the rail (only if D1 = keep)**

Same in `_PainterRailTimelineState`: add `_hoverTarget` `ValueNotifier<bool>`, dispose, wrap `GestureDetector(onTapUp: _onTapUp, ...)` same way, with `onHover: (e) => _hoverTarget.value = _geometry.hitTest(e.localPosition) != null`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/ipad_input_test.dart test/tree_graph_test.dart test/painter_rail_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/timeline_lab/lib/renderers/tree_graph_renderer.dart apps/timeline_lab/lib/renderers/painter_rail_renderer.dart apps/timeline_lab/test/ipad_input_test.dart
git commit -m "feat(lab): hand cursor over painted targets"
```

### Task 21: Keyboard shortcuts (Magic Keyboard)

**Files:**
- Create: `lib/shell/lab_shortcuts.dart`
- Modify: `lib/lab_app.dart` (`LabHome` → `StatefulWidget`)
- Modify: `lib/widgets/filter_panel.dart` (`searchFocusNode`)
- Test: `test/keyboard_test.dart`

Keys:
- **Space:** play/pause.
- **← / →:** step back/forward.
- **⌘F or Ctrl+F:** focus search; below 900 pt opens drawer first.
- **Esc:** close selected story.

- [ ] **Step 1: Write the failing tests**

`test/keyboard_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/playback/playback_controller.dart';

Future<(LabController, PlaybackController)> _pump(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = LabController();
  addTearDown(c.dispose);
  await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
  await tester.pumpAndSettle();
  return (c, tester.widget<LabHome>(find.byType(LabHome)).playback);
}

FocusNode _search(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('filter-search')))
    .focusNode!;

Future<void> _cmdF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Space plays and pauses; → steps to the oldest story', (
    tester,
  ) async {
    final (c, pb) = await _pump(tester, const Size(1280, 800));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pb.playing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pb.playing, isFalse);

    pb.stop();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(pb.current, same(c.entries.first.story));
  });

  testWidgets('⌘F focuses search; Space then types instead of playing', (
    tester,
  ) async {
    final (_, pb) = await _pump(tester, const Size(1280, 800));
    await _cmdF(tester);
    expect(_search(tester).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pb.playing, isFalse);
  });

  testWidgets('⌘F below the sidebar breakpoint opens the drawer first', (
    tester,
  ) async {
    await _pump(tester, const Size(744, 1133));
    await _cmdF(tester);
    expect(find.byKey(const Key('filters-drawer')), findsOneWidget);
    expect(_search(tester).hasFocus, isTrue);
  });

  testWidgets('Esc closes the selected story', (tester) async {
    final (c, _) = await _pump(tester, const Size(1280, 800));
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.selectedStoryId, isNull);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/keyboard_test.dart`
Expected: FAIL. Space does nothing, `focusNode` null.

- [ ] **Step 3: Add the shortcuts file**

`lib/shell/lab_shortcuts.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class StepIntent extends Intent {
  const StepIntent(this.delta);

  final int delta;
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class ClearSelectionIntent extends Intent {
  const ClearSelectionIntent();
}

/// Magic Keyboard and desktop keys. Text fields already swallow Space and
/// the arrows (`DefaultTextEditingShortcuts`), so typing never triggers these.
const labShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft): StepIntent(-1),
  SingleActivator(LogicalKeyboardKey.arrowRight): StepIntent(1),
  SingleActivator(LogicalKeyboardKey.keyF, meta: true): FocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.keyF, control: true): FocusSearchIntent(),
  SingleActivator(LogicalKeyboardKey.escape): ClearSelectionIntent(),
};

/// An action that claims its key only while [enabled] holds. When it is
/// disabled, `Shortcuts` ignores the key and it reaches the focused widget,
/// so a focused chip still toggles on Space.
class GuardedAction<T extends Intent> extends Action<T> {
  GuardedAction({required this.enabled, required this.onInvoke});

  final bool Function() enabled;
  final void Function(T intent) onInvoke;

  @override
  bool isEnabled(T intent) => enabled();

  @override
  Object? invoke(T intent) {
    onInvoke(intent);
    return null;
  }
}
```

- [ ] **Step 4: Give the search field an optional focus node**

In `lib/widgets/filter_panel.dart`:
- add `this.searchFocusNode` to constructor;
- add field `final FocusNode? searchFocusNode;`;
- on search `TextField`, set `focusNode: widget.searchFocusNode,`.

- [ ] **Step 5: Make `LabHome` stateful and wire the shortcuts**

In `lib/lab_app.dart`, add `import 'shell/lab_shortcuts.dart';`, convert `LabHome`. Public constructor + fields stay same (tests read `.playback`):

```dart
class LabHome extends StatefulWidget {
  const LabHome({
    super.key,
    required this.controller,
    required this.playback,
    this.onTogglePerf,
  });

  final LabController controller;
  final PlaybackController playback;
  final VoidCallback? onTogglePerf;

  @override
  State<LabHome> createState() => _LabHomeState();
}

class _LabHomeState extends State<LabHome> {
  final _rootFocus = FocusNode(debugLabel: 'lab-root');
  final _searchFocus = FocusNode(debugLabel: 'filter-search');
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _rootFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Space and the arrows act only when no control has focus.
  bool get _shellFocused => _rootFocus.hasPrimaryFocus;

  void _focusSearch() {
    final scaffold = _scaffoldKey.currentState!;
    if (scaffold.hasEndDrawer && !scaffold.isEndDrawerOpen) {
      scaffold.openEndDrawer();
      // The drawer's FilterPanel attaches the node on the next frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _searchFocus.requestFocus(),
      );
    } else {
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    // Reduced motion → instant reveals. iOS reports Reduce Motion separately
    // from disableAnimations, so check both.
    playback.reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
    return Shortcuts(
      shortcuts: labShortcuts,
      child: Actions(
        actions: {
          PlayPauseIntent: GuardedAction<PlayPauseIntent>(
            enabled: () => _shellFocused && playback.total > 0,
            onInvoke: (_) =>
                playback.playing ? playback.pause() : playback.play(),
          ),
          StepIntent: GuardedAction<StepIntent>(
            enabled: () => _shellFocused && playback.total > 0,
            onInvoke: (i) => playback.step(i.delta),
          ),
          FocusSearchIntent: GuardedAction<FocusSearchIntent>(
            enabled: () => true,
            onInvoke: (_) => _focusSearch(),
          ),
          ClearSelectionIntent: GuardedAction<ClearSelectionIntent>(
            enabled: () => widget.controller.selectedStoryId != null,
            onInvoke: (_) => widget.controller.select(null),
          ),
        },
        child: Focus(
          focusNode: _rootFocus,
          autofocus: true,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => _build(context),
          ),
        ),
      ),
    );
  }

  // _build moves here unchanged, with these edits:
  //  - `controller` → `widget.controller`, `playback` → `widget.playback`,
  //    `onTogglePerf` → `widget.onTogglePerf` (where design kept it);
  //  - `Scaffold(key: _scaffoldKey, ...)`;
  //  - both `FilterPanel(controller: c)` (sidebar and drawer) become
  //    `FilterPanel(controller: c, searchFocusNode: _searchFocus)`;
  //  - the renderer `Stack` is wrapped so that touching the timeline takes
  //    focus back from the search field (and dismisses the keyboard):
  //      Listener(
  //        onPointerDown: (_) => _rootFocus.requestFocus(),
  //        child: Stack(children: [Positioned.fill(child: renderer),
  //            PlaybackWatermark(playback: widget.playback)]),
  //      )
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/keyboard_test.dart test/lab_app_test.dart test/ipad_layout_test.dart`
Expected: PASS.

- [ ] **Step 7: Run the Phase 3 gates**

Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
Expected: 0 issues; exit 0; all pass. No golden changes.

- [ ] **Step 8: Commit**

```bash
git add apps/timeline_lab/lib/shell/lab_shortcuts.dart apps/timeline_lab/lib/lab_app.dart apps/timeline_lab/lib/widgets/filter_panel.dart apps/timeline_lab/test/keyboard_test.dart
git commit -m "feat(lab): keyboard shortcuts for playback, search and selection"
```

---

## Phase 4 — Optional: iOS platform and device measurement (decision D-i3)

### Task 22: Profile on iPad (D-i3 = b: skip the iOS steps; run only the Safari release-web path at the end of this task)

**Files:**
- Create: `ios/` (generated)
- Modify: `analysis_options.yaml`, `README.md`

- [ ] **Step 1: Add the platform**

Run: `flutter create --platforms=ios --org dev.mortang --project-name timeline_lab .`
Expected: `ios/` dir appears, `lib/` untouched.

Then `git status --short`. If `test/widget_test.dart` created, delete; lab has own tests.

- [ ] **Step 2: Exclude it from analysis**

In `analysis_options.yaml`, add `- ios/**` under `analyzer: exclude:`, next to `macos/**`.

Run: `flutter analyze`
Expected: 0 issues.

- [ ] **Step 3: Profile on a device**

Simulator can't run profile mode.
1. Open `ios/Runner.xcworkspace`, set **Signing & Capabilities → Team**.
2. Run:

```sh
flutter devices                         # find the iPad's id
flutter run --profile -d <ipad-id>
```

Each renderer at 120, 1 000, 5 000 stories:
1. Turn on perf overlay (perf control; in design's MenuAnchor if consolidated).
2. 10 s each: scroll/pan, pinch (zoom canvas), playback at 4×.
3. Record worst UI + raster frame times in ms.
4. Also `flutter run --profile` with DevTools → Performance, export one trace per renderer at 5 000 stories.

- [ ] **Step 4: Device checklist** (emulation couldn't show)

- Pencil tap hits dots at precise radius.
- Pencil hover shows hand cursor (M2+ iPad Pro) [UNVERIFIED that Flutter reports Pencil hover].
- Scribble writes into search.
- Trackpad pointer shows hand cursor; two-finger pan works on rail, tree, swimlanes.
- Magic Keyboard: Space, ←/→, ⌘F, Esc.
- Stage Manager: resize window through 320–1366 pt, no overflow.
- VoiceOver reads rail + tree semantics nodes; leaf rects match rows.
- Rotate during playback.
- Real home-indicator inset matches 20 pt in tests.

- [ ] **Step 5: Record the results**

In `README.md` under **Comparison**, replace "Profile-mode frame timings were **not measured**." bullet with "iPad (device, profile)" table: rows = renderers, columns = 120 / 1k / 5k worst UI/raster ms, plus device model + iPadOS version. Observed numbers only; `not measured` for any cell not run.

- [ ] **Step 6: Commit**

```bash
git add apps/timeline_lab/ios apps/timeline_lab/analysis_options.yaml apps/timeline_lab/README.md
git commit -m "feat(lab): iOS runner and iPad profile measurements"
```

**If D-i3 = b (no iOS platform):** run `flutter run --release -d web-server --web-hostname 0.0.0.0 --web-port 8100` from `apps/timeline_lab`, open `http://<mac-lan-ip>:8100` in Safari on iPad. Profile with Safari Web Inspector Timelines from Mac [UNVERIFIED that Flutter's performance overlay renders on web; use Web Inspector numbers]. Record in same README table with "Safari, release web" in header.

### Task 23: README — iPad section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the section** (after **Tests and goldens**)

````markdown
## iPad

The lab is tuned for iPad windows from Slide Over (320 pt) to a 12.9" screen.

- **Layout.**
  - At 900 pt and wider the filters are a sidebar. Below that, a **Filters** button opens them in an end drawer, whose header shows the live match count.
  - Below 600 pt, the scrubber gets its own row and the selected story stacks over a 3-line body. That panel never takes more than 30% of the window height.
  - The bottom bars clear the home indicator, and the software keyboard covers them rather than squeezing the timeline.
- **Touch.**
  - A finger gets a 22 pt hit radius on painted dots and nodes (`LabTarget`); mouse, trackpad and Pencil keep the precise radius.
  - Tree leaves are tappable on their whole row.
  - A tap that covers several stories (a rail stack, a swimlane cell) opens a chooser.
  - A finger tap on a treemap cell smaller than 44 pt opens its group.
- **Pointer.** The mouse can drag-pan every scroll view. Painted targets show a hand cursor on hover; nothing depends on hover.
- **Keyboard.** Space plays/pauses, ←/→ step, ⌘F (Ctrl+F) focuses search, and Esc closes the selected story. Keys only act when no control has focus.

Tests: `flutter test test/ipad_layout_test.dart test/ipad_input_test.dart test/keyboard_test.dart`. They pump the app at 11 iPad sizes with the iOS platform, DPR 2, 24/20 pt insets and a 313/398 pt keyboard.
````

Under **There are two extra sets of goldens**, change "two" → "three" and add:

```markdown
- **iPad** (iOS density, insets): [portrait sliver list](test/goldens/ipad_portrait_sliverList.png), [portrait swimlanes](test/goldens/ipad_portrait_swimlanes.png), [portrait tree](test/goldens/ipad_portrait_treeGraph.png), [portrait zoom](test/goldens/ipad_portrait_zoomCanvas.png), [portrait filters drawer](test/goldens/ipad_portrait_filters.png), [landscape with selection](test/goldens/ipad_landscape_selected.png), [Slide Over](test/goldens/ipad_slideover_sliverList.png).
```

Change narrow-layout bullet text "(700 px, filters collapsed)" → "(700 px, filters in a drawer)".

In **Layout** tree, add `input/ pointer_input.dart (finger radius, mouse drag)`, `shell/ lab_shortcuts.dart`, `widgets/story_chooser.dart`.

- [ ] **Step 2: Run the final gates**

Run: `flutter analyze && dart format --output=none --set-exit-if-changed . && flutter test`
Expected: 0 issues; exit 0; all pass.

- [ ] **Step 3: Commit**

```bash
git add apps/timeline_lab/README.md
git commit -m "docs(lab): iPad section and goldens"
```

---

## Golden changes, summary

| When | Changed | New |
|---|---|---|
| Phase 1 (Task 11) | `sliverList_narrow.png` (`ExpansionTile` → Filters button row) | `ipad_portrait_{sliverList,swimlanes,treeGraph,zoomCanvas,filters}.png`, `ipad_slideover_sliverList.png`, `ipad_landscape_selected.png` |
| Phase 2 (Task 18 gate) | `painterRail_playback.png`, only if rail kept (cursor line runs full renderer height) | — |
| Phase 3 | — | — |

Command: `flutter test --update-goldens test/golden_test.dart`. Open every changed/new PNG with read tool before commit.

## Self-review

**1. Spec coverage**

| Requirement | Where |
|---|---|
| 900 pt breakpoint vs iPad portrait | F3, D-i2, Tasks 1 and 7 |
| Sidebar vs `ExpansionTile` | F3, Task 7 |
| App bar overflow | F1, F11; Coordination (design-owned); covered by Task 2 sweep |
| Playback bar overflow | F1, Task 4 |
| Selected panel height | F2, F4, Task 6 |
| Safe area / home indicator | F10, Task 9 |
| Orientation change mid-playback | F14, Task 10 |
| Split View / Slide Over | F1, F2, Task 2 sweep, Tasks 3–6 |
| Hit-target sizes | F5, Tasks 12–18 |
| Hover-only affordances | F8 (none found), Task 20 |
| Tap vs drag conflicts | F7, Tasks 14 and 15 (full-height pan surfaces); F14 (taps + drags arbitrate correctly) |
| Pinch on zoom canvas | F14 |
| Pencil / trackpad | F8, Task 12 (`isFingerLike`), Task 19, Task 22 checklist |
| Keyboard shortcuts | F9, Task 21 |
| Keyboard occlusion of search | F3, F4, Tasks 7 and 8 |
| Performance unmeasured, how to measure | F16, D-i3, Task 22 |
| Phases 1–4 | Done |
| Widget tests at iPad sizes | `test/ipad_layout_test.dart`, `test/ipad_input_test.dart` |
| Goldens named | Task 11 |
| Decisions | D-i1 … D-i5 |

**2. Placeholder scan.** Code steps have full code. Only `/* unchanged */` markers point at existing code moving verbatim; each names exact block + line at `bdd128d`. Exist because design plan rewrites those blocks first.

**3. Type consistency**
- `LabTarget.min` + `LabTarget.fingerRadius`, `LabBreakpoint.sidebar` + `LabBreakpoint.compact`: Task 1, used Tasks 4, 6, 7, 12–18.
- `hitRadiusFor` + `isFingerLike`: Task 12, used Tasks 14, 15, 18.
- `showStoryChooser(context, globalPosition:, stories:, dataset:)`: Task 13, used Tasks 14, 17.
- `PainterRailGeometry.hitTestAll` / `hitTest(local, {radius})`: Task 14, used Task 20.
- `TreeLayout.hitTest(p, {radius})` / `rectOf(n, {radius})`: Task 15, used Task 20.
- `TreemapCellTile.onSmallTap` + `_CellGrid.onGroup`: Task 18.
- `FilterPanel.searchFocusNode`: Task 21.
- Test helpers `pumpIpad`, `setIpadView`, `showKeyboard`, `collectFlutterErrors`, `rendererRoot`, `ios`, `ipadSizes`, `ipadBottomInset`, `ipadKeyboardPortrait`: Task 2.