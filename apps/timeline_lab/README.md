# Timeline Lab

A scratch Flutter app that renders the same filterable story data with six
renderers (four timelines, a tree graph and a treemap), so they can be
compared before the Serverpod refactor.
The data is synthetic (seeded, deterministic). It has no backend and does not
import from `apps/tell_me_a_story`. The lab copies the models, tokens and
filter semantics it needs.

Strings in this app are scratch copy. They are not subject to the app's UXD
copy rule and are not meant to be ported.

## Run

```sh
just lab                       # Chrome
cd apps/timeline_lab && flutter run -d chrome   # or -d macos
```

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

## Playback

The bar under the timeline replays the history in story-date order
(1925 → 2024), like Obsidian's graph "Animate" but with pause, scrub, speed
and step controls. There are two designs:

- **Sweep** (default for the zoom canvas, swimlanes, tree graph
  and treemap). A time
  cursor moves at 0.6 s per year. Gaps longer than 1.5 s are compressed, and
  stories that share a date are staggered over at most half a year. The
  cursor is drawn as a line (zoom) or a column line (swimlanes), with a
  big year watermark.
- **Steps** (default for the sliver list and RenderBox layout). Story by
  story, with an even dwell of `clamp(60 s / n, 0.6, 2.0)`. Above 500 stories
  a whole year reveals per step. Prev/Next buttons step manually, and the
  caption names the current story.

Shared behaviour:

- **Ghost layout.** Every renderer lays out all entries and fades stories in
  where they already sit, so nothing reflows and scrubbing backwards works.
  Reveal is a pure function of the clock (`PlaybackSchedule`).
- **Filters.** In Dim mode, non-matching stories reveal dimmed when the
  cursor reaches them. In Hide mode only matches play. Changing a filter
  mid-play rebuilds the schedule and keeps the cursor on the same year.
- **Badges never leak the future.** The swimlane `+N` and
  the zoom overflow chip count revealed stories only.
- **Camera follow** keeps the cursor (or current story) in view. Dragging,
  scrolling or zooming turns it off; the target button turns it back on.
- **Ticks don't rebuild the app.** Renderers listen to the
  `PlaybackController` directly: the RenderBox axis only
  repaint, cards rebuild only while their own fade runs, and the zoom canvas
  and swimlane cells rebuild per tick (they already do while panning).
- **Reduced motion.** The clock is a raw `Ticker`, because an
  `AnimationController` runs at 5% of its duration when the platform disables
  animations. With reduce motion (`disableAnimations` or iOS Reduce Motion)
  reveals are instant; playback still only starts when you press Play.
- **Semantics.** The caption is a live region. The tree graph's semantics
  list every node at all times; playback is visual only there.

## Tests and goldens

```sh
just lab-test                    # behaviour tests + golden comparison
just lab-test --update-goldens   # regenerate the PNGs
```

`test/flutter_test_config.dart` loads the SDK's Roboto and Material Icons so
the goldens show real text. The running app uses the brand fonts (Newsreader,
Source Sans 3, Literata) through `google_fonts`. Goldens were generated on
macOS arm64. Other platforms may differ by anti-aliasing, and CI does not run
this package.

The golden scenarios are:

- `all`: no filter.
- `dim` and `hide`: people Ben Morgan + Esther Morgan (`p-1`, `p-4`), era 1950–1999.

Horizontal renderers open scrolled to the newest matched story. The
RenderBox layout opens with that story's card at the top.

| Renderer | all | dim | hide | mid-playback (dim) |
|---|---|---|---|---|
| Sliver list | [png](test/goldens/sliverList_all.png) | [png](test/goldens/sliverList_dim.png) | [png](test/goldens/sliverList_hide.png) | [png](test/goldens/sliverList_playback.png) |
| RenderBox layout | [png](test/goldens/renderBoxLayout_all.png) | [png](test/goldens/renderBoxLayout_dim.png) | [png](test/goldens/renderBoxLayout_hide.png) | [png](test/goldens/renderBoxLayout_playback.png) |
| Zoom canvas | [png](test/goldens/zoomCanvas_all.png) | [png](test/goldens/zoomCanvas_dim.png) | [png](test/goldens/zoomCanvas_hide.png) | [png](test/goldens/zoomCanvas_playback.png) |
| Swimlanes | [png](test/goldens/swimlanes_all.png) | [png](test/goldens/swimlanes_dim.png) | [png](test/goldens/swimlanes_hide.png) | [png](test/goldens/swimlanes_playback.png) |
| Tree graph | [png](test/goldens/treeGraph_all.png) | [png](test/goldens/treeGraph_dim.png) | [png](test/goldens/treeGraph_hide.png) | [png](test/goldens/treeGraph_playback.png) |
| Treemap | [png](test/goldens/treemap_all.png) | [png](test/goldens/treemap_dim.png) | [png](test/goldens/treemap_hide.png) | [png](test/goldens/treemap_playback.png) |

The mid-playback goldens seek to 50% of the default design's duration.

There are two extra sets of goldens:

- **Zoom canvas levels of detail:** [decades (1×)](test/goldens/zoomCanvas_lod_decades.png), [years (3×)](test/goldens/zoomCanvas_lod_years.png), [cards (10×)](test/goldens/zoomCanvas_lod_cards.png).
- **Narrow layout** (700 px, filters collapsed): [sliverList_narrow](test/goldens/sliverList_narrow.png).

## Layout

```
lib/
  model/        lab_models.dart (LabStory, DatePrecision, canonical sort), seed.dart
  filter/       timeline_filter.dart (TimelineFilter, applyFilter, statusLine)
  lab_controller.dart   single ChangeNotifier state owner
  playback/     playback_schedule.dart (pure reveal schedule),
                playback_controller.dart (clock, speed, follow),
                reveal.dart (RevealOpacity, follow helpers)
  renderers/    renderer_contract.dart + one file per renderer;
                tree_graph_layout.dart and treemap_layout.dart hold the pure
                hierarchy/layout code those two renderers test against
  widgets/      story_card.dart, filter_panel.dart, playback_bar.dart
  theme/        lab_theme.dart (token copies of album_theme.dart)
```

Every renderer receives the same `TimelineViewData`: the entries in ascending
order, already filtered in hide mode and flagged `matched` in dim mode, plus
an optional `PlaybackController`. No renderer re-runs the filter.

## Comparison

Notes on the measurements:

- **LOC** is `wc -l` of the renderer file, including its playback code.
- **5k** observations come from:
  - the tests (`zoom_canvas_test.dart`, `swimlanes_test.dart`);
  - a manual smoke in Chromium against `flutter run -d web-server` in **debug** mode.
- Profile-mode frame timings were **not measured**.

| Renderer | Laziness / scale (120 / 1k / 5k) | Text & a11y | Hit testing | True time spacing | Hide vs dim | Playback | LOC | Fit: Decades / Years / Days |
|---|---|---|---|---|---|---|---|---|
| **A. Sliver list** (`CustomScrollView`, pinned decade headers, `SliverList.builder`) | Lazy within each decade group. The smoke covered 120 stories; 1k and 5k were not measured. | Real widgets, so full text, semantics and focus come free. | Framework (`InkWell` per card). | No. The order is right but the spacing is uniform; gaps in time are invisible. | Hide compacts the list. Dim keeps every row, and the header shows `matched of count`. | Steps fit best. Follow must jump to an estimated offset first when the current card isn't built yet (lazy list), then settles on it. | 197 | Decades ✓ via headers. Years ✓. Days only as labels. |
| **C. RenderBox layout** (`MultiChildRenderObjectWidget`, cards at time-proportional y, collision push-down) | **Not lazy**: every card is built and laid out. At 5k, switching to it took ~7 s for the first frame (debug web, observed once). | Real widget cards, so full semantics. | Framework (`defaultHitTestChildren`). | Yes at low density. Colliding cards are pushed down exactly one gap below the previous card on their side. At 5k the spacing is no longer faithful. Sides come from the dataset position, so filters never flip a card. | Hide leaves time gaps on the axis. Dim keeps every card with dimmed text. | Steps. The axis, connectors and cursor repaint per tick; cards sit behind repaint boundaries. | 446 | Decades ✓. Years ✓ at ≤ a few hundred stories. Days ✗. |
| **D. Zoom canvas** (`InteractiveViewer`, semantic zoom, decades → years → cards) | Builds only markers in view, culled on x and on lane y. At the cards level, rows per lane are capped to the lane band and the rest collapse into a `+N` chip. Tests: at 10× on 1k, < 10% of cards are built; at 6× on 1k and 5k every card stays inside its lane band and the world. | Mixed. Decade bubbles and dots are widgets with no labels, and cards are real widgets. | Framework, through the transform. Markers are counter-scaled (`1/scale`) and keyed by story id. | Yes, 40 px per year in world units. | Hide drops markers. Dim fades them, and bubbles show matched counts. | Sweep. Rebuilds the visible markers per tick, the same work as panning. Follow pans x only. | 588 | Decades ✓ (bubbles). Years ✓ (dots). Days ✓ (cards with month ticks). See note 1 below. |
| **E. Swimlanes** (custom `TwoDimensionalScrollView`, year columns × person or family lanes) | Lazy in **both** axes: only visible cells plus the cache extent on every side are built. Test: at 5k the build count is ≤ the visible cell bound and < ¼ of all cells, and cells just left of the view are pre-built. In the smoke (debug web), it scrolled in both axes at 5k with the headers in sync; frame times were not measured. | `LaneCell` is a real widget. Single-entry cells show the title; denser cells show only dots + `+N`. | Framework, per cell. A single-story cell selects on tap. A cell with more stories opens a chooser. | Year buckets only; there is no within-year position. | Hide empties cells. Dim fades dots and titles. A story with k people appears in k lanes. | Sweep. Visible cells rebuild per tick; the cursor line is a separate painter. | 600 | Decades ✗ (too many columns). Years ✓. Days ✗. |
| **F. Tree graph** (one `CustomPainter`, tidy layered tree; toggle **Time**: root → decade → year → story, or **Family**: family → decade → story with each branch hanging off its origin story) | Paints every node. Groups over 6 stories show 5 and a `+N` node; tapping it expands the group, tapping the group collapses it, so the node count stays near 6 per year. Text is laid out once per layout, not per tick. | `semanticsBuilder` adds a node per tree node (stories, groups with counts, `+N`). This is the lab's only `CustomPainterSemantics` renderer since the painter rail was removed (it duplicated the zoom canvas's years level). | Manual: nearest node within 10 px. | No: leaves are evenly spaced in date order; depth carries the time hierarchy. | Hide prunes branches (a branch whose origin is filtered out attaches to its parent family). Dim fades nodes, edges and labels; groups with no matches fade too. | Sweep: the tree grows like Obsidian's graph animation. A node appears with its earliest story but never before its parent, so a branch appears with its origin story. Repaint only. | 719 (367 renderer + 352 layout) | Decades ✓. Years ✓ (time tree). Days only as labels. |
| **G. Treemap** (custom `RenderBox` squarified layout; toggle **Decade** → year, **Family** → decade, or **Person** → decade) | Builds one widget per cell (~100 at the overview), independent of dataset size; drill-down shows a group's cells, then one tile per story. | Real widgets with `Semantics` labels (period, count, matching count). | Framework, per cell. | No: area is story count, not time. | Hide shrinks areas to the matches. Dim keeps full areas and shades each cell by its matched share; headers show `matched/total`. A story with k people counts in k person groups. | Sweep: the layout is fixed and each cell fills bottom-up as its stories reveal. | 683 (467 renderer + 216 layout) | Shows where the archive is dense or thin, not a timeline. |

### Observations

1. **The zoom canvas zooms uniformly in 2-D.** At the cards level (≥ 6×), the family lanes, 120 world units apart, end up more than 700 px apart on screen. Only one lane fits in view, and zooming at the wrong y loses every lane until you pan. If this renderer goes forward, zoom only the x axis, or pin the lane y positions to the screen.
2. **Dimmed text never goes below `#6A6358`.** The dim rule in `docs/ux/80-all-stories.md` sets that floor, so `StoryCard` draws dimmed text in `labDimmedInk` and fades only the borders, pills and markers to 35%. Wrapping the whole card in `Opacity(0.35)` would break the rule.
3. **Hide and dim differ most on time-true renderers (C, D).** There, hide shows real empty stretches of time. On the sliver list, hide just compacts the list.
4. **The current app's rails** (`timeline_page.dart` `_FarRail`, `_MidRail`, `_FullCardRail`) are `ListView`-based. The closest match is A.
5. **Playback suits presentation more than analysis.** Research on Gapminder-style animation (Robertson et al. 2008) found it fastest for presenting and slowest for analysis, and weak beyond about 200 items. Steps switch to one year per step above 500 stories for that reason.
6. **The zoom canvas and playback compound note 1.** Follow pans only on x, so the lane in view stays whatever the user zoomed into, which at the cards level may be an empty lane.
7. **The family tree shows lineage the timelines can't.** Reyes and Okafor hang off the root-family story where each branch began. Because branch stories can predate the origin story within the branch year, playback waits for the origin before showing the branch.
8. **The treemap is the honest density view.** Areas make thin decades and over-represented people obvious at a glance. Hide vs dim differ most here: hide redraws the areas, dim keeps them and shades the matches.
