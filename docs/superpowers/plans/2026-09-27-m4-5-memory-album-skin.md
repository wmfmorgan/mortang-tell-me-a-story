# M4.5 Memory Album visual skin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` after human approval. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Gate:** Plan-only until human approves. Do not write application code until approval.
>
> **On approval:** Copy this plan to `docs/superpowers/plans/2026-09-27-m4-5-memory-album-skin.md` in the first commit. Isolated worktree: `.worktrees/feat-m04-5-memory-album-skin` on `feat/m04-5-memory-album-skin` from **latest `main`**.

**Goal:** Skin existing Flutter chrome to **Memory Album** tokens on the four IN surfaces only. No new features, routes, schema, Edge, Realtime, or Storage. Exit = **Mugatu PASS vs Stitch** + **Bill local smoke**. Open PR; do not merge unless Bill says merge.

**Architecture:** Add a locked `AlbumTheme` (`ColorScheme` + `TextTheme` + component themes). Apply it to the four IN surfaces so parchment/terracotta/sage/ink/fonts/roundness match UXD DESIGN.md. Existing widgets keep their structure and locked EN copy. Timeline published rows become **soft album cards** (not Far/Mid/Near zoom).

**Tech Stack:** Flutter 3.x, `google_fonts` (Newsreader, Literata, Source Sans 3). No new backend.

**M5:** Stopped. Do not start Reader / comments / perspectives in this PR.

## Sources (do not invent past these)

- Impl Spec §15 M4.5 playbook (Accepted, 2026-09-27): https://app.notion.com/p/3e0c4bcef238814f9686d1d956b1f3f8
- UXD handoff DESIGN.md: https://app.notion.com/p/3e0c4bcef238818dba09d617a2127cd4
- Stitch project `12192342757314667328` · design system `assets/18104844965535020843`
- Chrome/copy locks: https://app.notion.com/p/3e0c4bcef23881e59430d4f904bc59a3
- Design Doc: no schema work this MS

## Approaches (locked recommendation)

1. **Recommended — token theme + card chrome on IN surfaces (Approach A).** One `albumTheme` `ThemeData`. Wrap Timeline / New Story / Drafts (Add Person + Place picker inherit from capture). Soft `Card` around published rows and draft rows. Keep field order, routes, copy, Mapbox, invite **behavior**.
2. **Global `MaterialApp.theme` only, no card/layout pass.** Tokens would leak to magic-link; timeline would stay a flat list. Fail Mugatu “soft story cards.”
3. **Rebuild screens from Stitch HTML.** Out of scope — skin existing chrome; do not redesign capture order or invent copy.

Pick **Approach A**. Apply theme on `MaterialApp.router` **and** assert IN surfaces; **do not** change Invite modal tabs/copy/layout (Invite polish is OUT). Magic-link inheriting parchment is incidental token application, not a new screen.

## Locked tokens (must-match)

| Token | Hex / value | Use |
|-------|-------------|-----|
| Parchment BG | `#FBF7F2` | Scaffold / canvas. Stitch may read `#FFF8F6` — either warm album. **Never** Material white `#FFFFFF` as product chrome. |
| Terracotta primary | `#8B5E4B` | Publish / filled primary buttons / selected decade |
| Muted sage | `#7A8B74` | Chips, status, secondary accents **only** — **not** primary buttons |
| Ink brown | `#2C2416` | Body and headline text |
| Forbidden sage stand-in | `#665D5A` | Stitch Material `ColorScheme.secondary` — **do not** use as sage |
| Headlines | Newsreader | AppBar titles, section titles |
| Body | Literata | Story text, list previews, empty copy |
| Labels | Source Sans 3 | Buttons, chips, form labels |
| Roundness | 8–12px | Cards, inputs, chips |
| Actions | Save draft **secondary**; Publish **primary** | Already in capture; keep |

## Screens IN (only these)

1. `/timeline` — parchment album chrome + **soft story cards**. **Not** Far/Mid/Near pinch (M6). Stitch zoom screens are **reference for card feel**, not zoom chrome.
2. `/stories/new` — capture form: decade chips, people, place+map, text, photo strip. Field **order unchanged**.
3. `/drafts` — album list + missing-field chips. EN from chrome locks.
4. People / Places **from capture** — Add Person + Place picker sheets only.

**Stitch visual refs (IN):**

| Stitch title | Screen id |
|--------------|-----------|
| New Story — Tell Me a Story | `30237cf012c74948b863c02cb860223a` |
| Drafts List — Tell Me a Story | `2ef8fbb308b24783a9b7d385f7d8d7a2` |
| Add Person Modal — Choose or Create New | `c2cde0060dec47e0b5cf9b2afbfdf788` |
| Add Person Modal — Create New Person Active | `a634b51aa7524889969ba984b5496a16` |
| Choose Place Modal — Modern Google Maps Street Map | `149c60693c4a447e8a475d36ccf5868d` |
| Family Timeline (Near Zoom) — card feel only | `b50f9265a875446abc4025d1cf84b8a3` |

## FORBIDDEN / OUT

- Reader, Add Perspective, Search, Invite polish, timeline zoom
- Year/month/day pickers
- Schema/migrations, Edge, Realtime, public Storage URLs
- Redesigning capture field order or inventing EN copy
- Starting M5 in this PR
- Purple AppBar / cold white product chrome / freestyle palette
- Pixel-perfect claim without Mugatu PASS

## Fail criteria (Mugatu)

Still Material debug chrome; wrong fonts; purple AppBar / cold white as product chrome; freestyle palette; sage = `#665D5A`.

## Current code (plan-time)

- `TellMeAStoryApp` has **no** `theme:` — default Material 3.
- Capture already hardcodes terracotta `#8B5E4B` for publish highlight / selected decade.
- Timeline published rows are a bare `Column` (no Card).
- Drafts rows are not album cards.
- No Newsreader / Literata / Source Sans 3.

## Files to touch

### Create

| Path | Responsibility |
|------|----------------|
| `apps/tell_me_a_story/lib/core/theme/album_theme.dart` | Locked hex constants + `ThemeData albumTheme()` |
| `apps/tell_me_a_story/test/album_theme_test.dart` | Exact hex, sage ≠ `#665D5A`, primary is terracotta |

### Modify

| Path | Change |
|------|--------|
| `pubspec.yaml` | Pin `google_fonts` |
| `lib/app.dart` | `theme: albumTheme()`, `colorSchemeSeed` forbidden |
| `lib/features/timeline/timeline_page.dart` | Parchment scaffold; AppBar ink/parchment; published row → rounded Card (8–12px), ink text; keep tap → no new routes beyond existing M4 reader no-op **or** existing `/stories/:id` if already on main (reader is OUT — **do not add reader**). Timeline tap already no-op on main until M5. |
| `lib/features/stories/new_story_page.dart` | Use theme tokens instead of ad-hoc colors where possible; section titles Newsreader; body Literata; Save draft outlined/secondary; Publish filled terracotta |
| `lib/features/stories/timeframe_chips.dart` | Selected = terracotta; unselected sage border/text optional |
| `lib/features/stories/photo_strip.dart` | 8–12px tiles; parchment/sage surfaces not `surfaceContainerHighest` gray |
| `lib/features/drafts/drafts_page.dart` | Album cards; missing-field chips sage; locked empty/loading copy unchanged |
| `lib/features/people/add_person_modal.dart` | Inherit theme; parchment sheet; no copy changes |
| `lib/features/places/place_picker_modal.dart` | Inherit theme; parchment sheet; Mapbox failure copy unchanged |
| Widget tests that assume default Material colors | Update only if they assert chrome colors; **do not** weaken copy assertions |
| `README.md` | M4.5 smoke: visual check of four IN surfaces |

### Explicitly do not modify

- Invite modal layout/tabs/copy (`invite_modal.dart` behavior)
- Router paths, stories/photos APIs, supabase/
- Capture field order, publish validation rules

---

### Task 1: Worktree + plan copy

```bash
cd /Users/jabroni/Projects/mortang-tell-me-a-story
git fetch origin
git checkout main
git pull --ff-only origin main
git worktree add .worktrees/feat-m04-5-memory-album-skin -b feat/m04-5-memory-album-skin origin/main
```

Write `docs/superpowers/plans/2026-09-27-m4-5-memory-album-skin.md` from this plan.

```
docs(m04.5): add Memory Album visual skin implementation plan
```

---

### Task 2: `AlbumTheme` tokens + tests

**Produces:**

```dart
const albumParchment = Color(0xFFFBF7F2);
const albumTerracotta = Color(0xFF8B5E4B);
const albumSage = Color(0xFF7A8B74);
const albumInk = Color(0xFF2C2416);

ThemeData albumTheme() { ... }
```

`ColorScheme` from parchment + terracotta primary + sage as **tertiary** (not `secondary: Color(0xFF665D5A)`). `onSurface` / `onPrimary` ink or parchment as appropriate.

`TextTheme`: headline* Newsreader, body* Literata, label* Source Sans 3 via `google_fonts`.

`cardTheme`: radius 12, soft border (`albumSage` or ink at low opacity).

`filledButtonTheme`: terracotta; `textButtonTheme` / outlined: secondary Save draft.

- [ ] Tests:

```dart
test('locked hex values', () {
  expect(albumParchment, const Color(0xFFFBF7F2));
  expect(albumTerracotta, const Color(0xFF8B5E4B));
  expect(albumSage, const Color(0xFF7A8B74));
  expect(albumInk, const Color(0xFF2C2416));
  expect(albumSage, isNot(const Color(0xFF665D5A)));
});

test('theme primary is terracotta not sage', () {
  final t = albumTheme();
  expect(t.colorScheme.primary, albumTerracotta);
  expect(t.scaffoldBackgroundColor, albumParchment);
});
```

Widget tests: set `GoogleFonts.config.allowRuntimeFetching = false` in `setUpAll` if fetch flakes.

Pin `google_fonts` in pubspec. Commit:

```
feat(m04.5): add Memory Album ThemeData tokens
```

---

### Task 3: Apply theme on app + IN AppBars/scaffolds

Wire `theme: albumTheme()` on `MaterialApp.router`.

Smoke widget: pump `TellMeAStoryApp` or `MaterialApp(theme: albumTheme(), home: TimelinePage(...))` and expect scaffold background parchment (read `Theme.of(context).scaffoldBackgroundColor` or `Container` color).

Do **not** restyle Invite controls beyond inherited colors.

Commit:

```
feat(m04.5): apply Memory Album theme to the app
```

---

### Task 4: Timeline soft story cards

Replace bare `_PublishedRow` `Column` with a `Card` (radius 8–12, padding, ink title + Literata preview). Empty copy **unchanged**: `No stories yet. Capture the first one for this family.`

No zoom buttons, no decade-dot ladder.

Update `timeline_page_test` if it looks for a raw Column; keep empty-copy and AppBar label tests.

Commit:

```
feat(m04.5): album cards on timeline smoke list
```

---

### Task 5: Capture + people/place sheets

- Section titles use headline style (Newsreader).
- Story field body Literata.
- Selected decade chip terracotta fill; unselected sage/ink outline.
- Publish `FilledButton` terracotta; Save draft `TextButton` / outlined.
- Photo strip tiles 8–12px, parchment/sage, not M3 gray `surfaceContainerHighest`.
- Add Person / Place picker: parchment modal background via theme; **no new strings**.

Keep terracotta highlight `#8B5E4B` for blocked publish (already locked).

Capture tests that find `Save draft` / `Publish story` / banner copy must still pass.

Commit:

```
feat(m04.5): skin capture form and people/place sheets
```

---

### Task 6: Drafts album list

Draft rows → same card language as timeline. Filter / missing-field chips use sage (not terracotta primary). Empty/loading copy **verbatim**.

Commit:

```
feat(m04.5): skin drafts list as album cards
```

---

### Task 7: README + verification + PR

README M4.5 smoke:

1. Magic-link → `/timeline`: parchment, ink title, cards (or empty copy).
2. New story: fonts + Save draft secondary / Publish primary + chips.
3. Drafts: cards + sage missing chips + locked empty copy.
4. Add person / Choose place sheets: parchment, not cold white.

```bash
cd apps/tell_me_a_story && flutter test
```

Report pass/fail with output.

**Screenshots for Mugatu** (after local run): Timeline, New story, Drafts, Add Person, Place picker — vs Stitch refs above. Agent captures if Flutter web is up; otherwise Bill/Mugatu.

**PR title:** `feat(m04.5): Memory Album visual skin`

PR body:

- §15 M4.5 playbook IN/OUT
- Locked hex table (sage `#7A8B74`, not `#665D5A`)
- `flutter test` output
- Screenshot list / paths
- Non-goals: M5 reader, zoom, Invite polish, schema
- Do not claim Mugatu PASS or Bill smoke until they sign

Open PR; **do not merge** unless Bill says merge.

---

## Self-review

| Playbook item | Task |
|---------------|------|
| Tokens hex/fonts/roundness | 2 |
| `/timeline` album + cards, no zoom | 3, 4 |
| `/stories/new` capture skin | 5 |
| `/drafts` album + chips | 6 |
| People/Places from capture | 5 |
| No M5 / no Invite polish / no schema | Global |
| `flutter test` + screenshots | 7 |

**Placeholder scan:** Mugatu PASS and Bill smoke remain named exits, not agent-closed.

## Execution handoff (after approval)

1. **Subagent-Driven (recommended)**
2. **Inline Execution**

Which approach?
