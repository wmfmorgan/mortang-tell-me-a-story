# Phase 7: Timeline UI — Index

> **For agentic workers:** Phase 7 index. Each slice runs on own branch off `feature/serverpod` (integration branch), lands via one PR into it after dependency slices merge. 7.0 and 7.1 written in full below (REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development; steps use `- [ ]`). Every later slice row = scope contract: executor writes full TDD plan at slice start (superpowers:writing-plans) as `docs/superpowers/plans/2026-11-08-phase7-<n>-<name>.md`, verifies code blocks in scratch copy of tree, links it in "Status". **Stops:** 7.4, 7.5, 7.7, 7.8 merge only after owner signs off screenshots (and copy, where listed); 7.8 starts only after iPad measurement (7.M) passes.

**Goal:** Bring timeline lab results into app per owner decisions 2026-11-08:
- keep Decades/Years/Days rails, split out of 3 770-line `timeline_page.dart`, restyled with lab visual system;
- dim-only filters on timeline;
- two whole-tree views (treemap overview, Family-mode tree graph), backed by new server read + tree-wide live updates;
- lab itself in repo as `labs/timeline_lab`;
- macOS-local goldens.

**Architecture:**
- **Shared timeline primitives** (`TimeScale`, markers, canvas labels, hit radius, chooser, empty state, view switch) go to `lib/ui/timeline/`. Rails (`features/timeline`) and tree views both use them; same-rank `features/` can't import each other (`featureRank`, `test/architecture/import_boundaries_test.dart:9-23`).
- **Tokens** go to `lib/core/theme/album_theme.dart`. Lab's `lab_theme.dart` colours = copies of album tokens; only tints and scales new.
- **Whole-tree views** live in `lib/features/timeline/tree/`. Folder inside existing feature → no new `featureRank` entry (adding one needs owner).
- **Server:** one new read (`story.listPublishedInTree`, with index migration), one new stream (`live.watchTree`). Client refetches on each live event, as today.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13, Serverpod 4.1.1, `flutter_test` goldens, mise, just. No new deps.

**Inputs:**
- **Owner decisions (2026-11-08), binding.** Listed below; cited as Q1–Q8.
- `docs/archive/migration/timeline-lab-handoff.md`. 7.0 lands it there from lab branch; until then read at `docs/migration/timeline-lab-handoff.md` on `worktree/silver-valley-593f`. Holds lab findings + port list. Its `apps/timeline_lab/…` paths become `labs/timeline_lab/…`.
- Lab README (renderer table, observations, iPad section) and plans `2026-11-07-timeline-lab-{ui-design-review,ipad-review}.md` (moved to `docs/archive/superpowers/plans/` by 7.0).
- `docs/archive/ux/uxd-handoff.md:106, :170-195` and `docs/archive/ux/branch-callout.md` (rev 1.5, LOCKED). Rails' zoom ladder + branch callouts stay as specified; 7.4 changes look, not behaviour.
- `AGENTS.md` (gates, colours guard, import rules, copy + token approval rules).

| # | Owner decision (2026-11-08) | Where it lands |
|---|---|---|
| Q1 | Keep Decades/Years/Days rails, restyle (option 1). No sliver rebuild. | 7.3, 7.4 |
| Q2 | Ship two whole-tree views: **family tree graph** (Family mode) + **treemap** overview. Needs G1 `story.listPublishedInTree` + index migration, G2 tree-wide live updates. Entry point = family menu row (O1). Every new string needs approval (C1–C18 approved, O2). | 7.6S, 7.7, 7.8 |
| Q3 | No playback. | Not ported; `lib/playback/` and every playback hook stay in lab. |
| Q4 | Filters on timeline, **dim only** (no hide), reusing All Stories `matchesSearch` + dim-ink rules. | 7.5 |
| Q5 | Accept lab visual system: continuous corners, marker system, terracotta selected toggle. Screenshots for owner sign-off before merge. | 7.2, 7.4 |
| Q6 | Owner runs iPad measurement (lab iPad Task 22) on own iPad. Tree graph slice gated on result. | 7.M gates 7.8 |
| Q7 | Lab comes in as `labs/timeline_lab`, analyze-only CI job. Rebase or cherry-pick only lab commits; never merge branch. Justfile gets `lab`/`lab-test`. | 7.0 |
| Q8 | macOS-local goldens tagged `golden`, excluded in CI (`--exclude-tags golden`), run with `just test-goldens`, scoped `flutter_test_config.dart` for fonts. | 7.1 |

**Baseline at `feature/serverpod` `315852d`** (Phase 6 exit):
- app `+689 ~12` (measured for this plan);
- server `+425`, live `+27`, e2e 9/9 (Phase 6 "As landed");
- analyze 6 (ceiling 6);
- colour skip list 17 entries (ceiling 17).

**Verification status of this plan (written 2026-11-08):**
- **Verified in scratch copy of tree at `315852d`:**
  - 7.1 in full: layout-guard change (red, then green, incl. untagged-golden case), font config, six goldens generated + inspected, `just test` `+689 ~12` with goldens excluded and no tag warning, `just test-goldens` `+6`, `fmt-check` clean, analyze 6;
  - 7.0 conflict set, simulated with `git merge-tree` (no worktree change).
- **Unverified:**
  - 7.0 cherry-pick as whole, and `just lab-test` after move;
  - every later slice (each verified by own slice plan);
  - CI;
  - iPad numbers (7.M).

---

## Status

| Slice | Plan | Depends on | Status |
|---|---|---|---|
| 7.0 Lab import | this index, §7.0 | — | done (#181; lab-test `+272`) |
| 7.1 Golden harness and rail baselines | this index, §7.1 | — | done (`feat/p7-1-goldens`) |
| 7.2 Tokens and shared primitives | this index, §7.2 | — (O3 answered 2026-11-08) | done (`feat/p7-2-tokens`; app `+741 ~12`) |
| 7.3 Rail split at parity | this index, §7.3 | 7.1, 7.2 | done (`feat/p7-3-rail-split`; app `+741 ~12`, goldens unchanged) |
| 7.4 Rail restyle and iPad | this index, §7.4 "TDD plan" | 7.3; owner screenshot sign-off before merge | done; owner signed off 2026-11-08 with one change (finger misses on Decades zoom out) (`feat/p7-4-restyle`; app `+817 ~12`, 6 goldens regenerated + 2 new) |
| 7.5 Timeline filters (dim only) | this index, §7.5 "TDD plan" | 7.4; copy approved (O2, 2026-11-08); screenshots before merge | done; owner signed off 2026-11-08 with two changes (sidebar toggles + starts closed; no-match card pinned above rows) (`feat/p7-5-filters`; app `+888 ~12`, 8 goldens regenerated for button + 2 new) |
| 7.6S Server: tree reads (G1, G2) | this index, §7.6S | — | done (#183); server `+447`, live `+29` |
| 7.M iPad measurement (owner) | this index, §7.M | 7.0 (or lab branch as is) | **passed** 2026-11-08 (owner verdict vs O4 thresholds; no numeric exports, see §7.M "Outcome" and "As landed") |
| 7.7 Whole-tree page and treemap | this index, §7.7 | 7.2, 7.6S (O1, O2, O5, O6 answered 2026-11-08); screenshots before merge | built; owner signed off v2 + C19 on 2026-11-08, colour key added after (`feat/p7-7-treemap`; app `+802 ~12`, goldens `+8`); ready to merge |
| 7.8 Family tree graph | this index, §7.8 "TDD plan" | 7.7, **7.M pass** (passed 2026-11-08); screenshots before merge | done; owner signed off 2026-11-08 with one change (family name chip selects family) (`feat/p7-8-tree-graph`; app `+973 ~12`, goldens `+14`: 2 new, 2 treemap PNGs regenerated for view switch, approved) |
| 7.z Close | this index, §7.z | all | done (`chore/p7-z-close`; lab deleted per O7, plan archived) |

```
7.0 ──────────────────► 7.M ───────────┐
7.1 ──┐                                │
7.2 ──┼─► 7.3 ─► 7.4 ─► 7.5            │
      └──────┐                         ▼
7.6S ───────┴─► 7.7 ────────────────► 7.8 ─► 7.z
```

7.0, 7.1, 7.2, 7.6S can start at once. 7.0 and 7.1 both edit `justfile` and `AGENTS.md`: second to merge rebases, keeps both sides. 7.7 runs alongside 7.3–7.5. 7.6S adds no-op `watchTree` to `implements TimelineLive` fakes in `test/features/timeline/timeline_page_test.dart` and `test/features/stories/story_reader_page_test.dart`, which 7.3–7.5 also edit; keep both sides.

---

## Conventions

**Working directory.** Commands run in `apps/tell_me_a_story` unless start with `just` (repo root) or say otherwise. Run tools as `mise exec -- …`.

**Branches.** Each slice uses `feat/p7-<n>-<name>` (e.g. `feat/p7-1-goldens`), branched from `feature/serverpod` after deps merged. Lands as one PR into `feature/serverpod` with merge commit (no squash: 7.0 keeps lab history). No push to or merge into `main`.

**Gates** (every slice, before each commit and in PR body):

```bash
mise exec -- just check                         # fmt-check, analyze ≤ 6, test, server-analyze, server-test
mise exec -- just test 2>&1 | tail -n 1         # app count: never fewer than the previous slice
mise exec -- just test-goldens 2>&1 | tail -n 1 # from 7.1 on (macOS)
```

Expected: `(0 changed)` twice, `analyze: 6 issues (ceiling 6)` (lower ceiling if slice fixes issues; never raise), app `+689 ~12` or more, server `+425` or more.
- **Slices changing gateway or server** (7.6S, 7.7) also run `just server`, then `mise exec -- just test-live`.
- **Slices changing header or router** (7.7) and 7.z also run e2e per README (9/9).

**Colours guard.**
- Every new or split-out file under `lib/` token-clean: no `Color(0x`, no `Colors.` outside `album_theme.dart`.
- `features/timeline/timeline_page.dart` on skip list today (`test/architecture/no_hardcoded_colors_test.dart:21`). 7.3 removes entry once last hit gone, lowers `_skipListCeiling` 17 → 16 (guard fails on listed file with no hits).
- Never add skip path. New token needs owner approval. Phase 6 standing rule (owner, 2026-11-07): hit with no exact token gets one named token with today's exact value, so swap pixel-identical; `token.withAlpha(n)` counts as exact when ARGB identical.

**Copy.** No new user-facing string ships without owner approval. Every string slice adds listed in O2 with id, marked **pending approval**, used verbatim once approved. Slice plan may add string only by adding O2 row + getting approval before merge. Lab copy = scratch copy: never copy into app unapproved.

**Goldens** (from 7.1).
- Live in `test/goldens/`; each file starts `@Tags(['golden'])` (layout guard checks); `test/goldens/flutter_test_config.dart` loads fonts for them alone.
- Generate on macOS only, `just test-goldens --update-goldens`. Open every changed PNG with read tool before commit.
- Slice that shouldn't change pixels (7.3) never regenerates. Slice changing pixels on purpose (7.4+) regenerates, lists every changed PNG in PR body.
- CI never runs them: `just test` passes `--exclude-tags golden`.

**Screenshot sign-off** (7.4, 7.5, 7.7, 7.8; Q5).
1. Shell 1: `mise exec -- just server`. Shell 2: `mise exec -- just run`.
2. Chrome at `http://127.0.0.1:3000`, DevTools device toolbar at two sizes: 1280 × 800, and 744 × 1133 (iPad mini portrait). Sign in as `p7-shots@example.com` code `111111`.
3. First run: create root family `Jenkins` with 6 published stories across 1950–1999, then branch `Bea` from its 1975 story with 2 own stories. Reuse data for every check.
4. Capture slice's listed screens, before (from `feature/serverpod`) and after. Store under `/tmp/p7-shots/<slice>/`. Send to owner via Main with golden PNG diffs.
5. Merge only after owner approves. Record approval (date + requested changes) in slice plan.

**Fakes.** Slice changing interface updates every fake of it in `test/`, per Phase 4 convention:
- 7.6S: `StoriesGateway.listPublishedInTree` goes in shared `test/support/fakes/fake_stories_gateway.dart`. `TimelineLive.watchTree` gets no-op default in abstract class, like `watchStory` (`lib/data/timeline_live.dart:24-36`), implemented in each `implements TimelineLive` fake: `test/features/timeline/timeline_page_test.dart` (`_FakeLive`), `test/features/stories/story_reader_page_test.dart` (`_StoryReload`), `test/goldens/timeline_rails_golden_test.dart` (`_Live`). 7.7 overrides only where test needs.

**Out of scope:**
- **Playback (Q3).**
- **Sliver rebuild (Q1).**
- **Zoom canvas, swimlanes, RenderBox renderers.**
- **Tree graph Time mode** (Q2 names Family mode only).
- **Hide mode** (Q4).
- **Tree-wide server search or facets** (G4; would reopen "cross-family search out").
- **Paging (G5), kinships (G6).**
- **New `AppErrorCode`s.** None needed: G1, G2 refuse with existing `forbidden`.
- **Colour fixes in other skip-listed files.** Two new exact-value tokens from 7.2 also used in e.g. `manage_family_page.dart`, `settings_page.dart`, but those files stay as is.

---

## 7.0 Lab import (Q7)

**Branch:** `feat/p7-0-lab-import`. **Files:**
- `labs/timeline_lab/**` (from lab commits, then moved);
- `justfile`;
- `.github/workflows/ci.yml`;
- `AGENTS.md`;
- `docs/archive/migration/timeline-lab-handoff.md`;
- `docs/archive/superpowers/plans/2026-11-07-timeline-lab-{ui-design-review,ipad-review}.md`.

App (`apps/**`) untouched.

Lab work = 52 linear commits `bdd128d^..6302bfe` on `worktree/silver-valley-593f` (no merges; objects in this repo). Branch's first two commits (`2c3aca2`, `d9729f7`) already in our history; branch 140+ commits behind. Merging would revert Phase 3–6 docs, so cherry-pick only lab range.

- [ ] **Step 1: Preconditions.** `git status --short` prints nothing. `git rev-parse --abbrev-ref HEAD` prints `feat/p7-0-lab-import`. `git cat-file -t 6302bfe` prints `commit`. `git rev-list --count bdd128d^..6302bfe` prints `52`.

- [ ] **Step 2: Cherry-pick lab range.**

```bash
git cherry-pick -x bdd128d^..6302bfe
```

Expected: two stops, both predicted with `git merge-tree`. Any other conflict: `git cherry-pick --abort` and report.

1. **At `bdd128d` (`justfile`).** Lab's context lines (`db-test`, `functions-serve`) gone. Keep our `justfile`, add lab's two recipes right after `test-live`, as lab wrote them:

   ```just
   # Timeline lab in Chrome
   lab:
       cd apps/timeline_lab && flutter run -d chrome

   # Timeline lab tests (pass --update-goldens to regenerate PNGs)
   lab-test *args:
       cd apps/timeline_lab && flutter test {{args}}
   ```

   Then `git add justfile && git cherry-pick --continue`.
2. **At `6302bfe` (docs).**
   - Roadmap = modify/delete conflict (roadmap archived). Drop lab's line: `git rm docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md`.
   - Handoff = file-location conflict (`docs/migration/` renamed). Accept git suggestion: `git add docs/archive/migration/timeline-lab-handoff.md`, ensure no `docs/migration/` dir left (`git status --short docs`).
   - Then `git cherry-pick --continue`.

Check: `git diff feature/serverpod --stat -- apps docs/archive/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` lists only `apps/timeline_lab/**`.

- [ ] **Step 3: Move lab to `labs/`, finish wiring** (one commit).

```bash
mkdir -p labs
git mv apps/timeline_lab labs/timeline_lab
git mv docs/superpowers/plans/2026-11-07-timeline-lab-ui-design-review.md docs/superpowers/plans/2026-11-07-timeline-lab-ipad-review.md docs/archive/superpowers/plans/
git grep -l "apps/timeline_lab" -- labs/timeline_lab
```

- In each file grep lists (lab README; nothing in `lib/` or `test/`), replace `apps/timeline_lab` with `labs/timeline_lab`.
- Leave archived handoff + lab plans unchanged: history.
- In `justfile`, change both recipes to `cd labs/timeline_lab && …`.
- In `.github/workflows/ci.yml`, append analyze-only job from Phase 5 plan (`docs/archive/superpowers/plans/2026-11-08-serverpod-phase5-cleanup.md`, Task 4 Step 2), with `install_args` line every other job has (postdates Phase 5 plan, `9491e43`):

```yaml
  lab:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    defaults:
      run:
        shell: bash
        working-directory: labs/timeline_lab
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          persist-credentials: false

      - uses: jdx/mise-action@b44d12e7d0d8ee7461bb893e1b1993500433185b # v5.2.7
        with:
          install_args: flutter # terraform is for deploys only

      - name: flutter pub get
        run: flutter pub get --enforce-lockfile

      - name: flutter analyze
        run: flutter analyze
```

- In `AGENTS.md` "Layout", add after `packages/…` bullet:

```markdown
- `labs/timeline_lab/`: the timeline lab, a dev-only Flutter bench (synthetic data, macOS goldens). Nothing in `apps/` imports it. `just lab`, `just lab-test`; CI runs `flutter analyze` on it only.
```

Commit: `chore(lab): timeline lab moves to labs/timeline_lab; lab recipes and analyze-only CI job`.

- [ ] **Step 4: Gates.**
  - `mise exec -- just lab-test 2>&1 | tail -n 1` → `+272: All tests passed!` on macOS. 36 goldens = macOS arm64. Golden differing only in glyph antialiasing on another Mac: report; don't regenerate.
  - `(cd labs/timeline_lab && mise exec -- flutter analyze)` → `No issues found!`.
  - `actionlint .github/workflows/ci.yml && echo actionlint-ok`.
  - `mise exec -- just check`: app + server counts unchanged from `feature/serverpod` base (`+689 ~12` and `+425` at `315852d`; `+694 ~12` and `+432` at `49c0585`, where 7.0 cut).
  - `git diff feature/serverpod --stat -- apps` prints nothing.
- [ ] **Step 5: PR** `chore: timeline lab in labs/timeline_lab (Phase 7.0)`, merged with merge commit. CI `lab` job must be green.

---

## 7.1 Golden harness and rail baselines (Q8)

**Branch:** `feat/p7-1-goldens`. **Files:**
- Create: `apps/tell_me_a_story/test/goldens/flutter_test_config.dart`, `apps/tell_me_a_story/test/goldens/timeline_rails_golden_test.dart`, `apps/tell_me_a_story/test/goldens/timeline/*.png` (6).
- Modify: `apps/tell_me_a_story/test/architecture/test_layout_test.dart`, `apps/tell_me_a_story/dart_test.yaml`, `justfile`, `AGENTS.md`.

**Why first:** 7.3 splits `timeline_page.dart`, must prove no pixel change. Six goldens taken now, before timeline code moves.

**Fonts:**
- `google_fonts` asks for families named `<Family>_<variant>` (`Newsreader_500`, `Literata_italic`, `SourceSans3_regular`; `google_fonts_base.dart:112`); tests can't fetch fonts.
- Registering under fallback names (`Newsreader`, …) does **not** work in test engine; scratch run rendered boxes.
- So config registers SDK's Roboto under every variant name of app's three families → real glyphs. Brand faces checked in browser screenshots.
- `google_fonts` still prints `unable to load font …` during golden runs. Expected: looks for asset files, but families already registered.

### Task 1: The layout guard accepts tagged goldens

- [ ] **Step 1: Write golden test** `test/goldens/timeline_rails_golden_test.dart`:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

import '../support/fakes/fake_invite_gateway.dart';
import '../support/fakes/fake_stories_gateway.dart';

// The three timeline rails as they look today. Phase 7 splits
// timeline_page.dart against these unchanged (7.3), then restyles them on
// purpose (7.4). macOS only: `just test-goldens`.

const _jenkins = '00000000-0000-0000-0000-000000000001';
const _bea = '00000000-0000-0000-0000-0000000000be';

const _sizes = <String, Size>{
  'desktop': Size(1280, 800),
  'ipad_mini_portrait': Size(744, 1133),
};

const _zooms = <String, String?>{
  'decades': null,
  'years': 'timeline-zoom-mid',
  'days': 'timeline-zoom-full',
};

Story _story(String id, String title, DateTime start, {List<String>? people}) {
  return Story(
    id: id,
    familyId: _jenkins,
    authorId: 'u1',
    title: title,
    body: 'Told at the kitchen table.',
    timeframeStart: start,
    timeframeEnd: start,
    placeId: 'pl',
    placeLabel: 'Harbour Street',
    status: StoryStatus.published,
    personIds: const ['p'],
    personNames: people ?? const ['Ada Jenkins'],
    publishedAt: DateTime.utc(2026, 9, 27),
    createdAt: DateTime.utc(2026, 9, 27),
  );
}

final _published = <Story>[
  _story('s1952', 'The flood year', DateTime(1952, 3, 14)),
  _story('s1961', 'First car', DateTime(1961, 6, 2)),
  _story('s1975', 'Bea moves north', DateTime(1975, 8, 9)),
  _story('s1978', 'Summer at the lake', DateTime(1978, 7, 1)),
  _story('s1984', 'The new kitchen', DateTime(1984, 1, 20)),
  _story('s1999', 'Millennium eve', DateTime(1999, 12, 31)),
];

class _Stories extends FakeStoriesGateway {
  @override
  Future<List<Story>> listPublished(String familyId) async =>
      _published.where((s) => s.familyId == familyId).toList();

  @override
  Future<Story?> getPublished(String storyId) async {
    for (final s in _published) {
      if (s.id == storyId) return s;
    }
    return null;
  }
}

class _Families extends FamiliesGateway {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(id: _jenkins, name: 'Jenkins', createdAt: DateTime.utc(2020)),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async => const [
    TreeFamily(id: _jenkins, name: 'Jenkins'),
    TreeFamily(
      id: _bea,
      name: 'Bea',
      parentFamilyId: _jenkins,
      originStoryId: 's1975',
      branchYear: 1975,
    ),
  ];
}

class _Live implements TimelineLive {
  @override
  void watch({required String familyId, required void Function() onChange}) {}

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  @override
  void dispose() {}
}

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final MapEntry(key: zoomName, value: zoomKey) in _zooms.entries) {
      testWidgets('timeline $zoomName $sizeName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: albumTheme(),
            home: TimelinePage(
              api: FakeInviteGateway(familyId: _jenkins),
              storiesApi: _Stories(),
              familiesApi: _Families(),
              live: _Live(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (zoomKey != null) {
          await tester.tap(find.byKey(Key(zoomKey)));
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(TimelinePage),
          matchesGoldenFile('timeline/${zoomName}_$sizeName.png'),
        );
      });
    }
  }
}
```

- [ ] **Step 2: See guard fail.** Run `mise exec -- flutter test test/architecture/test_layout_test.dart`. Expected failure: `goldens/timeline_rails_golden_test.dart: lib/goldens does not exist`.

- [ ] **Step 3: Teach guard about `test/goldens/`.** In `test/architecture/test_layout_test.dart`, replace header comment and `_ownFolders` (lines 5–11) with:

```dart
// Unit and widget tests mirror lib/'s folders: every test file outside live/
// (tag live), goldens/ (tag golden, macOS only), architecture/ (guards) and
// support/ (shared fakes) ends in _test.dart, sits in a folder that also
// exists under lib/, and is not named for a milestone (m<N>_...). File names
// are not matched to lib/ files. Run from apps/tell_me_a_story.

const _ownFolders = {'architecture', 'goldens', 'live', 'support'};
```

and insert right after `final parts = path.split('/');` (line 25):

```dart
      if (parts.first == 'goldens' &&
          path.endsWith('_test.dart') &&
          !entity.readAsStringSync().startsWith("@Tags(['golden'])")) {
        problems.add("$path: a golden test starts with @Tags(['golden'])");
      }
```

- [ ] **Step 4: Green, check tag rule.** Re-run guard: passes. Then:
  1. `printf "void main() {}\n" > test/goldens/untagged_test.dart`, re-run. Expected failure: `goldens/untagged_test.dart: a golden test starts with @Tags(['golden'])`.
  2. `rm test/goldens/untagged_test.dart`.

### Task 2: Fonts, tag and recipes; generate the baselines

- [ ] **Step 1: Font config** `test/goldens/flutter_test_config.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Golden tests only (this file applies to test/goldens/ and below).
///
/// google_fonts names each variant `<Family>_<variant>` (`Newsreader_500`,
/// `Literata_italic`) and tests can't fetch fonts, so text would render in
/// the test font's boxes. This registers the Flutter SDK's Roboto under every
/// variant name the album theme can ask for, plus Material Icons. Goldens
/// then show real glyphs (Roboto shapes, not the brand faces). macOS only:
/// `just test-goldens`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadFonts();
  await testMain();
}

const _googleFamilies = ['Newsreader', 'Literata', 'SourceSans3'];

Directory _materialFontsDir() {
  const rel = 'bin/cache/artifacts/material_fonts';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && Directory('$root/$rel').existsSync()) {
    return Directory('$root/$rel');
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final candidate = Directory('${dir.path}/$rel');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'Flutter SDK material_fonts not found; run flutter precache',
  );
}

/// google_fonts' variant suffix: `regular`, `italic`, `500`, `500italic`.
String _variant(int weight, {required bool italic}) {
  if (weight == 400) return italic ? 'italic' : 'regular';
  return italic ? '${weight}italic' : '$weight';
}

String _robotoFile(int weight, {required bool italic}) {
  final bold = weight >= 600;
  if (italic) return bold ? 'Roboto-BoldItalic.ttf' : 'Roboto-Italic.ttf';
  if (bold) return 'Roboto-Bold.ttf';
  return weight == 500 ? 'Roboto-Medium.ttf' : 'Roboto-Regular.ttf';
}

Future<void> _loadFonts() async {
  final dir = _materialFontsDir();
  final cache = <String, Future<ByteData>>{};
  Future<ByteData> bytes(String name) => cache.putIfAbsent(
    name,
    () async =>
        ByteData.sublistView(await File('${dir.path}/$name').readAsBytes()),
  );

  final loaders = <FontLoader>[
    for (final family in _googleFamilies)
      for (var weight = 100; weight <= 900; weight += 100)
        for (final italic in [false, true])
          FontLoader('${family}_${_variant(weight, italic: italic)}')
            ..addFont(bytes(_robotoFile(weight, italic: italic))),
    FontLoader('MaterialIcons')..addFont(bytes('MaterialIcons-Regular.otf')),
  ];
  await Future.wait([for (final loader in loaders) loader.load()]);
}
```

If later slice adds `GoogleFonts.<family>(` call for new family, add that family's google_fonts name to `_googleFamilies`.

- [ ] **Step 2: Declare tag.** Append to `apps/tell_me_a_story/dart_test.yaml`, under `tags:`, after `live` entry:

```yaml
  golden:
```

- [ ] **Step 3: Recipes.** In `justfile`, replace `test` recipe, add `test-goldens` after `test-live`:

```just
# flutter test in apps/tell_me_a_story (goldens excluded: they are macOS-only)
test:
    cd apps/tell_me_a_story && flutter test --exclude-tags golden
```

```just
# Golden tests, macOS only (just test-goldens --update-goldens to regenerate)
test-goldens *args:
    cd apps/tell_me_a_story && flutter test --tags golden {{args}} test/goldens
```

CI `app` job runs `just test`, so now excludes goldens with no `ci.yml` change.

- [ ] **Step 4: See them fail.** Run `mise exec -- just test-goldens 2>&1 | tail -n 3`. Expected: `-6`, each failure says `Could not be compared against non-existent file: "timeline/<zoom>_<size>.png"`.

- [ ] **Step 5: Generate and inspect.**
  1. Run `mise exec -- just test-goldens --update-goldens`.
  2. Open all six PNGs in `test/goldens/timeline/` with read tool. Expected: real glyphs, not boxes. Header shows `Tell Me a Story`, `Jenkins`, `Stories / Timeline / Draft Stories`. Zoom pill selected segment terracotta.
  3. In `decades_desktop`, 1970s row holds `2 stories preserved` and moss `Bea Branch` callout. `years_*` and `days_*` open on 1999 story: `years_ipad_mini_portrait` shows hanging Bea callout on 1975 node, but in `years_desktop` only faded stub at bottom edge (as landed). `days_*` shows full cards.
  4. At 744 pt header shows `Tell …`, hides family name. Today's behaviour; record, don't fix here.
- [ ] **Step 6: Green.** `mise exec -- just test-goldens 2>&1 | tail -n 1` → `+6: All tests passed!`.
- [ ] **Step 7: Rest unchanged.**
  - `mise exec -- just test 2>&1 | tail -n 1` → `+694 ~12: All tests passed!` (count at `feature/serverpod` 49c0585; earlier `+689` stale). Goldens excluded, no "undeclared tag" warning.
  - `mise exec -- just fmt-check` shows `(0 changed)` twice.
  - `mise exec -- just analyze` shows `analyze: 6 issues (ceiling 6)`.

### Task 3: Document and commit

- [ ] **Step 1: `AGENTS.md`.**
  - In "Layout", `test/` bullet, after `` `test/live` (tag `live`); `` insert `` `test/goldens` (tag `golden`, macOS only, own `flutter_test_config.dart`); ``.
  - In gates table, after "Live client tests" row, add: `| Goldens (macOS) | \`just test-goldens\` | all passing; regenerate only on purpose (\`just test-goldens --update-goldens\`) and open every changed PNG |`.
- [ ] **Step 2: Commit** `test(client): golden harness (tag golden, macOS only) and timeline rail baselines`. Body lists six PNGs.
- [ ] **Step 3: PR** `test: golden harness and timeline rail baselines (Phase 7.1)`. Paste gates + `just test-goldens` output.

---

## 7.2 Tokens and shared primitives (Q5)

**Branch:** `feat/p7-2-tokens`. **Files:**
- Modify: `lib/core/theme/album_theme.dart`, `lib/features/all_stories/all_stories_card.dart` (`allStoriesDimInk()` only), `test/core/theme/album_theme_test.dart`.
- Create `lib/ui/timeline/`:
  - `time_scale.dart`, with `fractionalYear`;
  - `time_axis_painter.dart`;
  - `canvas_label.dart`;
  - `story_marker.dart`, with `isOrigin`;
  - `pointer_input.dart`;
  - `timeline_entry.dart`;
  - `story_chooser.dart`;
  - `empty_timeline.dart`;
  - `view_switch.dart`.
- Create tests:
  - `test/core/theme/{album_contrast,album_field_border}_test.dart`;
  - `test/features/all_stories/all_stories_card_test.dart`;
  - `test/ui/timeline/{time_scale,time_axis_painter,canvas_label,story_marker,pointer_input,timeline_entry,story_chooser,empty_timeline,view_switch}_test.dart`;
  - `test/support/contrast.dart` (copied from lab unchanged).

**Names** (O3, approved 2026-11-08). Lab `Lab*`/`lab*` names → `Album*`/`album*`. Three exceptions:
- `labDimmedInk` → `albumDimInk`;
- `labMoss` → existing `branchMoss`;
- `labSurface`, `labBorder` and other colour copies → existing album tokens.

No pixel changes anywhere:
- `albumTheme()` gains only `segmentedButtonTheme`; `lib/` has no `SegmentedButton` today;
- `inputDecorationTheme` keeps `OutlineInputBorder`;
- nothing in `lib/` uses new primitives yet;
- `allStoriesDimInk()` swap ARGB-identical (Task 1, Step 1 proves before swap).

**Dropped from lab port (out of scope):**
- `LabText.badge` (waits for 7.8), `labDimOpacity`, lab theme's chip, menu, drawer, slider themes;
- `familyLaneOrder` (swimlanes + zoom canvas only);
- `reveal` playback param of `paintStoryMarker` (Q3).

### Task 1: Tokens

- [ ] **Step 1: Red tests.**
  - In `album_theme_test.dart`, add cases:
    - tints equal `albumInk.withAlpha(0x33 / 0x99 / 0x1F)` and `albumSage.withAlpha(0x59 / 0x73)`;
    - `albumDimInk`, `albumBlush`, `albumBlushPale` keep hex values;
    - every scale value matches table below;
    - `AlbumText` roles build on theme (`axis` w600 with tabular figures, `count` is `albumDimInk`, `lane` w600, `group` is `titleSmall`);
    - `albumContainerShape(12, side:)` is `RoundedSuperellipseBorder` with that radius + side;
    - segmented theme resolves selected → terracotta/parchment, unselected → `albumPillFill`/`albumInk`.
  - `album_contrast_test.dart`: lab's `lab_theme_test` contrast cases with album tokens:
    - six text pairs ≥ 4.5:1;
    - selected-segment label 5.18:1 (±0.01);
    - terracotta + moss markers ≥ 3:1 on parchment.
  - `album_field_border_test.dart`: lab's `field_border_test` with `AlbumFieldBorder`. Fourth case (lab theme text field uses border) not ported: app input theme keeps `OutlineInputBorder`.
  - `all_stories_card_test.dart`: `expect(allStoriesDimInk().toARGB32(), albumDimInk.toARGB32())`.
  - Run `mise exec -- flutter test test/core/theme test/features/all_stories/all_stories_card_test.dart`. Expected: compile errors (`albumDimInk`, `AlbumSpace`, … undefined).
- [ ] **Step 2: Green.** In `album_theme.dart`, after `albumCardRadius`, add tokens below (doc comments as lab), import `dart:ui show lerpDouble` for `AlbumFieldBorder`. Add lab's `segmentedButtonTheme` to `albumTheme()`, text style `GoogleFonts.sourceSans3(fontWeight: FontWeight.w600, fontSize: 14)`. Re-run Step 1 tests: pass, incl. dim-ink case against *old* `alphaBlend` body → proves swap pixel-identical.

  | Token | Value |
  |---|---|
  | `albumDimInk` | `Color(0xFF6A6358)` |
  | `albumBlush` | `Color(0xFFF5DED6)`: timeline focused-dot halo, focused-card glow, filled chip |
  | `albumBlushPale` | `Color(0xFFF5ECE9)`: timeline unfilled chip |
  | `albumRuleStrong` / `albumRule` / `albumWatermark` | `Color(0x992C2416)` / `Color(0x332C2416)` / `Color(0x1F2C2416)` |
  | `albumSageTint` / `albumSageLine` | `Color(0x597A8B74)` / `Color(0x737A8B74)` |
  | `AlbumSpace` | `xs 4, s 8, m 12, l 16, xl 24` |
  | `AlbumRadius` | `tile 4, group 8, card 12, sheet 16, pill 20` |
  | `AlbumStroke` | `hairline 1, rule 1.5, mark 2` |
  | `AlbumMarker` | `dot 10, small 8, gap 2, ring 2, hollow 1.5` |
  | `AlbumTarget` | `min 44, fingerRadius 22` |
  | `AlbumBreakpoint` | `sidebar 900, compact 600` |
  | `AlbumText` | `axis`, `count`, `lane`, `group` |
  | `albumContainerShape(radius, {side})` | `RoundedSuperellipseBorder` |
  | `AlbumFieldBorder({borderSide, radius = AlbumRadius.card})` | lab's `LabFieldBorder` |

- [ ] **Step 3: Point dim ink at token.** In `all_stories_card.dart`:

```dart
/// Ink at 70% on parchment: the #6A6358 dim floor ([albumDimInk]).
Color allStoriesDimInk() => albumDimInk;
```

- [ ] **Step 4: Gates.**
  - `mise exec -- just check` passes (app count up by Task 1 tests).
  - `mise exec -- just test-goldens 2>&1 | tail -n 1` gives `+6`, `git status --short apps/tell_me_a_story/test/goldens` empty.
- [ ] **Step 5: Commit** `feat(client): timeline tokens in album_theme (O3) and albumDimInk for All Stories`.

### Task 2: Shared primitives in `lib/ui/timeline/`

- [ ] **Step 1: Red tests.**
  - Copy `time_scale_test`, `time_axis_painter_test`, `canvas_label_test`, `pointer_input_test` from `labs/timeline_lab/test/`, changing only imports (`package:tell_me_a_story/ui/timeline/…`, `core/theme/album_theme.dart`) and `LabTarget` → `AlbumTarget`.
  - `time_scale_test` also gains `fractionalYear` cases:
    - `DateTime(1987)` → `1987`;
    - `DateTime(2000, 7, 2)` → `2000.5` (leap year);
    - `DateTime(1987, 7, 2)` → `1987 + 182 / 365`;
    - Dec 31 in `(y + 0.99, y + 1)`;
    - local 23:30 time equals UTC calendar day.
  - Port `story_marker_test` with `AlbumMarker`. Add `isOrigin` case: `TreeFamily(originStoryId: 's1975')` makes `s1975` origin, `s1952` not.
  - Port `story_chooser_test` with three app `Story`s at year, month, day precision, one blank title. Also asserts rows `The flood year · 1952`, `First car · June 1952`, `Untitled · June 2, 1952`.
  - New `timeline_entry_test`:
    - entry's `id` and `year` (`fractionalYear(publishedStart)`);
    - `timelineEntries(stories, matches:)` keeps order, flags matches;
    - no `matches` → every entry matches.
  - New `empty_timeline_test`, using C17 and C9:
    - message + `empty-action` button call `onAction`;
    - no action → message alone.
  - New `view_switch_test`:
    - `SegmentedButton` under `switchKey` reports tapped value, hides check icon;
    - at 200 pt wide, long labels scroll, no overflow.
  - Run `mise exec -- flutter test test/ui/timeline`. Expected: compile errors (missing libs).
- [ ] **Step 2: Green: port lab files.**
  - **Same API as lab:**
    - `time_scale.dart`: lab file, plus:

      ```dart
      double fractionalYear(DateTime date) {
        final day = DateTime.utc(date.year, date.month, date.day);
        final start = DateTime.utc(date.year);
        final days = DateTime.utc(date.year + 1).difference(start).inDays;
        return date.year + day.difference(start).inDays / days;
      }
      ```

    - `canvas_label.dart`: unchanged.
    - `time_axis_painter.dart`: lab tokens → album tokens.
    - `pointer_input.dart`: `LabTarget` → `AlbumTarget`.
  - **`story_marker.dart`:**
    - `isOrigin(Story story, Iterable<TreeFamily> families)`;
    - `MarkerSpec`, `paintStoryMarker(canvas, c, spec)`, `StoryDot`, with `albumTerracotta` and `branchMoss`. No `reveal` param.
  - **`timeline_entry.dart`** (adapter from lab's `TimelineEntry`):
    - `TimelineEntry({required Story story, required bool matched})`, getters `id`, `year`;
    - `timelineEntries(Iterable<Story>, {bool Function(Story)? matches})`.
  - **`story_chooser.dart`:** `showStoryChooser(context, {globalPosition, required List<Story> stories})`. Rows read `'${storyTitle(s)} · ${storyDateLabelFor(s)}'`, keyed `chooser-<id>`. C10 title = 7.4's job.
  - **`empty_timeline.dart`:**
    - `EmptyTimeline({required String message, String? actionLabel, VoidCallback? onAction})`, asserts label + callback come together;
    - keys `empty-timeline`, `empty-action`;
    - callers pass approved copy (C9, or C17 with `Clear filters`).
  - **`view_switch.dart`:** lab widget, padding `AlbumSpace.l`/`s`, gap `AlbumSpace.m`, label in `AlbumText.lane`.
- [ ] **Step 3: Gates.** Same as Task 1, Step 4. Import guard passes (`ui/` imports only `core/`, `data/`, `ui/`), layout guard passes (`test/ui/timeline` mirrors `lib/ui/timeline`), colours guard passes with no hits in `lib/ui/timeline/`, skip list unchanged.
- [ ] **Step 4: Commit** `feat(client): shared timeline primitives in lib/ui/timeline (TimeScale, markers, labels, hit radius, chooser, empty state, view switch, TimelineEntry)`.

### Task 3: Plan bookkeeping

- [ ] Set Status row done, add 7.2 "As landed" notes. Commit `docs(plan): Phase 7.2 status and as-landed notes`.

**Done when:**
- gates green with new tests;
- goldens unchanged;
- no colour-guard hits in `lib/ui/timeline/`.

## 7.3 Rail split at parity

**Owns:**
- `lib/features/timeline/timeline_page.dart`;
- new `lib/features/timeline/rails/{rail_scaffold,far_rail,mid_rail,full_card_rail}.dart`, `lib/features/timeline/{zoom_switch,origin_banner}.dart`;
- colour skip list.

`timeline_branching.dart` and `timeline_zoom.dart` change only where import moves.

**Today** (`timeline_page.dart` at `315852d`):
- page state `:57-775`; `scrollDialStep` `:776`; `_ArrowKeys` `:804`;
- `_FarRail` `:852` with `_EmptyTap`, `_FarDecadeRow`, `_CenterOnDot`, `_OriginDot`, `_FarDot` (to `:1524`);
- `_MidRail` `:1525` with `_DialFade`, `_DialSubheader`, `_DialRow`, `_HangParentCallout` (to `:2497`), `_ZoomSwitch` `:1787-1978` in middle;
- `_RailGutter` `:2498`; `_FullCardRail` `:2526` with `_DaysCard*`, `_FullCardRow`, `_FullCardDot`, `_FullCard`, `_FullChip`, `_CardPhotos` (to `:3694`); `_OriginBanner` `:3695`.
- Three rail `State`s repeat centre/measure/step/opacity code (`:882-1105`, `:1559-1747`, `:2562-2792`).

**Change** (three commits; gates + `just test-goldens` must pass **without regenerating** after each):
1. **Move.** Each rail + private helpers into own library. Cross-file classes lose underscore; nothing else changes.
2. **Scaffold.** `RailScaffold` (mixin or helper on rail `State`s) takes shared centre, measure, step, arrow-key, empty-tap, fade code.
3. **Colours.** Replace 12 hits with exact tokens:

   | Line | Today | Token |
   |---|---|---|
   | 1082 | `Color(0x332C2416)` | `albumRule` |
   | 1273, 2077, 2188 | `Color(0xFFFFF8F6)` | `albumDialogSurface` |
   | 1882 | `Color(0xB32C2416)` | `albumInk.withAlpha(0xB3)` (`const` → `final`) |
   | 1961 | `Colors.transparent` | `albumBackdropClear` |
   | 2771, 2772 | `Color(0x00FBF7F2)` | `albumParchment.withAlpha(0)` |
   | 3342, 3416, 3563 (filled) | `Color(0xFFF5DED6)` | 7.2's token for that value |
   | 3563 (unfilled) | `Color(0xFFF5ECE9)` | 7.2's token for that value |
   | 3386 | `Colors.white` | `albumWhite` |

   Then delete `'features/timeline/timeline_page.dart'` from `temporaryHardcodedColorSkipPaths`, set `_skipListCeiling = 16`.

**Tests:** `timeline_page_test.dart` and `timeline_branching_test.dart` pass **unedited** (`git diff --stat -- test` shows only guard file).

**Done when:**
- `timeline_page.dart` holds only page;
- colours guard passes ceiling 16;
- six goldens match without regeneration;
- app count unchanged, analyze ≤ 6.

## 7.4 Rail restyle and iPad (Q5)

**Owns:**
- `lib/features/timeline/**`;
- `test/features/timeline/**`;
- `test/goldens/timeline_*` and PNGs;
- `test/support/ipad.dart` (from lab);
- chip-label fix in five chip screens, if reproduces (below).

**Change:**
- **Markers.**
  - Far, mid, days dots use `StoryDot` / `paintStoryMarker`: filled = match, hollow = dimmed (used from 7.5), terracotta outer ring = focused/selected, moss ring = branch origin.
  - Branch callouts keep `branch-callout.md` geometry + copy.
- **Corners.** Cards + banners use `albumContainerShape(AlbumRadius.card)`; chips + pills stay stadium.
- **One spine.** One spine look (`paintTimeAxis` or one `RailSpine` widget) replaces three spines (`:1076-1083`, `_RailGutter`, `:2711-2717`).
- **Touch.**
  - Dots use `hitRadiusFor(pointer kind)` → finger gets 22 pt.
  - Where finger tap covers several stories (stacked year on Years), `StoryChooser` lists them; title string in O2.
- **Insets.** Bottom footer clears `viewPadding.bottom`; soft keyboard doesn't squeeze rail (`resizeToAvoidBottomInset: false` where applies).
- **iPad.** iPad no-overflow sweep for timeline at lab's 11 sizes × three zooms (`test/features/timeline/timeline_page_ipad_test.dart` with `test/support/ipad.dart`).
- **Chip label fade (handoff §2.1, unverified in app).**
  1. Reproduce first on web in `drafts_page`, `start_timeline_dialog`, `invite_modal`, `search_page`, `new_story_page` (screenshots).
  2. Only if reproduces, add `maxLines: 1, overflow: TextOverflow.ellipsis` to those chip labels.
  3. Else record "not reproduced", change nothing.

**Tests:**
- Targeted updates in `timeline_page_test` (`_expectMossCard`, `_mossRingOn`, colour/geometry asserts); each changed assert named in PR body.
- New marker-state + chooser widget tests, iPad sweep.
- Goldens regenerated on purpose, plus `days`/`decades` at iPad mini landscape (1133 × 744).

**Stop:** screenshot sign-off (Decades, Years, Days, branch callout, chooser, both sizes) before merge.

### 7.4 TDD plan (written at slice start, 2026-11-08)

Branch `feat/p7-4-restyle` from `feat/p7-3-rail-split` `26230d4` (7.3 merging into `feature/serverpod`; its review clean-ups ride along only on lines this slice touches). Each task: failing test first, red, implement, green, gates, commit. Copy = C10 only.

**Plan fixes found at slice start:**
- Years shows one row per story, ≥ 64 pt apart → finger never covers two Years nodes. Stacked year finger can cover = Decades dot cluster (three 1962 stories 20 pt apart, inside 22 pt finger radius). Chooser goes there.
- Narrow Days draws spine at x = 14, plain dots at x = 22, branch dot at x = 30 (visible in `days_ipad_mini_portrait.png`). One spine fixes: spine, plain dots, narrow branch dot share x = 22.

#### Task 1: Chooser title (C10)
- **Test** (`test/ui/timeline/story_chooser_test.dart`): menu shows `Stories here` (key `chooser-title`) above rows; title not selectable (tap keeps menu open, resolves nothing).
- **Change** (`lib/ui/timeline/story_chooser.dart`): disabled first `PopupMenuItem` with C10 text in `AlbumText.count`-weight ink.

#### Task 2: Markers
- **Tests** (`test/features/timeline/rail_markers_test.dart`, new):
  - Decades, Years, Days story dots are `StoryDot`s: matched (filled); focused/highlighted plain story `selected: true`; others `selected: false`.
  - Branch story dot (child callout or parent origin) never `selected` (moss callout ring only ring; branch-callout.md Rule 1, "nothing covers the green ring"), no `boxShadow` anywhere on it.
  - Origin dot with no callout on Decades = `StoryDot` with `origin: true` (moss ring, Rule 8 "An origin dot with no callout … still gets the moss ring").
- **Change:** `_FarDot`, Years `mark`, `_FullCardDot` paint `StoryDot(reserveRings: false)` at existing diameters; `_OriginDot` goes (its ring = marker origin ring: same 2 pt gap, 2 pt stroke as callout ring). Days blush halo + Years pale disc go: focus = terracotta selected ring. Branch callout ring, leader, label unchanged (`placeBranchCallout`, `parentCalloutOverlay`).
- **`timeline_page_test` updates:** `_mossRingOn` also accepts `StoryDot` whose spec has `origin: true` centred on dot.

#### Task 3: Corners
- **Tests** (in `rail_markers_test.dart`): Years focused + branch cards, Days card, origin banner use `albumContainerShape(AlbumRadius.card)` (`RoundedSuperellipseBorder` radius 12); Years date chip + Days person/place chips keep shapes.
- **Change:** `ShapeDecoration`/`Material.shape` with `albumContainerShape`; `InkWell.customBorder` follows shape.
- **`timeline_page_test` updates:** `_expectMossCard` (both branches) and focused-card asserts reading `BoxDecoration.borderRadius`/`RoundedRectangleBorder` read superellipse shape instead. Every changed assert listed in "As landed".

#### Task 4: One spine
- **Tests:** each rail has exactly one `RailSpine` (key `timeline-spine`), 2 pt wide in `albumRule`, centred on viewport on Decades, Years, wide Days; at x = 22 from rail left edge on narrow Days, through centre of every plain + branch dot (±1).
- **Change:** new `rails/rail_spine.dart` (`RailSpine({double? left})`); `_RailGutter` + two inline spines go.

#### Task 5: Touch and the chooser
- **Tests** (`test/features/timeline/rail_touch_test.dart`, new):
  - touch tap 18 pt from lone Decades dot opens story; mouse click same point doesn't;
  - touch tap between two 1962 dots on Decades opens chooser (C10 title + one row per covered story), picking row opens that story;
  - touch tap 18 pt from Years node opens Days on it; mouse keeps 8 pt slop.
- **Change:** Decades dots answer mouse, trackpad, stylus only; touch-only detector over row's dot area collects dots within `hitRadiusFor(kind, precise: radius)` of tap: one → opens, several → `showStoryChooser`. Years plain node gets touch-only 44 pt target around mouse target.

#### Task 6: Insets
- **Tests:** `viewPadding.bottom = 20` → Decades footer text bottom ≥ 20 pt above window bottom; 313 pt keyboard inset → rail viewport keeps height (Scaffold sets `resizeToAvoidBottomInset: false`).
- **Change:** `timeline_page.dart` footer padding adds `MediaQuery.viewPaddingOf(context).bottom`; `Scaffold(resizeToAvoidBottomInset: false)`.

#### Task 7: iPad sweep
- `test/support/ipad.dart` (lab sizes, insets, `setIpadView`, `showKeyboard`, `collectFlutterErrors`, minus lab-only renderer helpers) and `test/features/timeline/timeline_page_ipad_test.dart`: each of 11 sizes × Decades/Years/Days pumps `TimelinePage` with golden fixture (6 stories + Bea branch), on `TargetPlatform.iOS`, no FlutterError (overflows incl.); plus each size with keyboard shown.

#### Task 8: Chip-label fade
- Reproduce first on web (`flutter run -d web-server`, DPR 1.25) in `drafts_page`, `start_timeline_dialog`, `invite_modal`, `search_page`, `new_story_page`, crops saved beside sign-off screenshots. Change only if reproduces.

#### Task 9: Goldens and sign-off
- Add `mini_landscape` (1133 × 744) to golden sizes for `decades` and `days`; regenerate every timeline golden with `just test-goldens --update-goldens`; open each PNG.
- BEFORE (`26230d4`) + AFTER screenshots at 1280 × 800 and 744 × 1133: Decades, Years, Days, branch callout, chooser on 1962 cluster (touch tap). Server from this worktree on :8280 with own data dir; web on :3100.
- Status row + "As landed".

## 7.5 Timeline filters, dim only (Q4)

**Owns:**
- new `lib/ui/story/story_search.dart` (`matchesSearch`, `nameMatches`, their `_contains`, moved from `features/all_stories/all_stories_logic.dart:324-352`; All Stories imports from here);
- new `lib/features/timeline/filter/{timeline_filter,filter_panel}.dart`;
- rails, for dim state.

**Change:**
- **Filter.** `TimelineFilter {personIds, placeIds, fromDecade, toDecade, query}`: OR within category, AND across. Text match = `matchesSearch` (title, body, person names; never place). People + places chips from loaded stories (`personIds`/`personNames`, `placeId`/`placeLabel`). No family filter: rail = one family.
- **Dim, never hide.**
  - Unmatched rows keep slot, use `albumDimInk` text + hollow marker.
  - Counts read "matched of total" (copy in O2).
  - No matches → rails stay mounted, empty state + clear action pinned at top of rail, above first row, covering no row (owner, 2026-11-08 sign-off).
- **Placement.** `Filters` button beside zoom switch at every width. At ≥ 900 pt (`AlbumBreakpoint.sidebar`) toggles docked, non-modal sidebar, starts closed, stays open across zoom changes until closed; below, opens end drawer. (Owner decision, 2026-11-08 sign-off; replaces "a persistent sidebar at ≥ 900 pt", so sidebar closed → rail full width.)
- **State scope.** Filter survives zoom changes, resets on family switch.

**Tests:**
- Port `filter_test` cases (minus hide, families).
- `all_stories_logic_test` follows move; `matchesSearch` cases run against new import.
- Widget tests:
  - dim keeps same row count;
  - unmatched ink `0xFF6A6358`;
  - rails stay mounted on no match;
  - sidebar vs drawer at 899/900 pt;
  - iPad sweep with filters open.
- Goldens `timeline_filtered_{desktop,ipad_mini_portrait}`.

**Stop:** O2 copy approved, screenshots signed off.

### 7.5 TDD plan (written at slice start, 2026-11-08)

Branch `feat/p7-5-filters` from `feat/p7-4-restyle` `7b19f98`. Each task: failing test first, red, implement, green, gates, commit. Copy = C11–C18 only, verbatim.

**Plan fixes found at slice start:**
- Decade bounds use story start decade (`decadeStartYear(publishedStart)`), same key as its Decades row → decade header C18 count always agrees with dots. Lab's era overlap on story span would let 1949–1952 story match 1950s filter while sitting in 1940s row.
- Goldens: Filters button on screen at every width → 8 baselines change with empty filter, by button only. (Before owner sign-off sidebar always shown at ≥ 900 pt, also changed 5 desktop + landscape baselines; see "As landed".)
- No new strings beyond C11–C18: sidebar + drawer have no close label (drawer closes on scrim), Filters button shows no count, panel clear action reuses C17 `Clear filters`. C16 shows only while filter active.

#### Task 1: Move `matchesSearch`
- **Test:** `all_stories_logic_test` U-14 imports `ui/story/story_search.dart`; red until file exists.
- **Change:** new `lib/ui/story/story_search.dart` with `matchesSearch`, `nameMatches`, `_contains`; `all_stories_logic.dart` and `all_stories_card.dart` import it; no re-export.

#### Task 2: `TimelineFilter`
- **Tests** (`test/features/timeline/filter/timeline_filter_test.dart`, ported from lab `filter_test` minus hide, families): people OR within; people AND decades across; decade bounds by start decade; place fails story without place; query matches person names not place; inactive filter (blank query) matches all; `copyWith` clears decade bounds; `filterOptions` lists people, places, decades from loaded stories (sorted, deduped); C16 + C18 strings.
- **Change:** `lib/features/timeline/filter/timeline_filter.dart`: `TimelineFilter {personIds, placeIds, fromDecade, toDecade, query}`, `isActive`, `copyWith`, `matches(Story)` (text via `matchesSearch`), `filterOptions(stories)`, `filterStatusLine` (C16), `decadeMatchCount` (C18).

#### Task 3: Dim on the rails
- **Tests** (`test/features/timeline/filter/timeline_filter_page_test.dart`): person filter → each rail keeps same row/dot count; unmatched dots `StoryDot`s with `matched: false`, matched `matched: true`; unmatched Years/Days title uses `0xFF6A6358`; Decades count reads `{matched} of {total}` (C18) while filtering, `N stories` without; empty filter → every dot matched, no text uses dim ink.
- **Change:** each rail takes `dimmed` (unmatched story ids) + `filtering`; dots + nodes pass `matched`; Years + Days texts use `albumDimInk` when dimmed; Decades row with no match dims label + count.

#### Task 4: Panel, sidebar and drawer
- **Tests:** at 900 pt sidebar (`timeline-filter-sidebar`) starts closed, rail full width; `Filters` button (C11, key `timeline-filters-open`) beside zoom switch docks it (360 pt, left of rail, no drawer), stays open across Decades → Years → Days, button closes it; at 899 pt button opens end drawer (`timeline-filter-drawer`, titled `Filters`); panel shows `People`, `Places`, `Years` (C12–C14), search hint (C15), C16 while active; typing query dims non-matches; filter survives Decades → Years → Days; resets on family switch; no match → rails stay mounted under C17, `Clear filters` clears.
- **Change:** `lib/features/timeline/filter/filter_panel.dart` (`FilterPanel`); `TimelinePage` keeps `_filter` + `_sidebarOpen`, builds docked sidebar (360 pt, `AlbumBreakpoint.sidebar`) or end drawer, passes button (`filterAction`) + C17 `EmptyTimeline` card (`notice`) to rails, where `buildRail` puts button beside zoom switch, pins card between zoom switch and rows.

#### Task 5: iPad sweep with the filters open
- `timeline_page_ipad_test`: each of 11 sizes with filter active + filters opened from button (docked sidebar ≥ 900, drawer below), on iOS, no FlutterError; plus keyboard up with search focused.

#### Task 6: Goldens and sign-off
- New `timeline_filtered_{desktop,ipad_mini_portrait}` (person filter on Decades; portrait with drawer open). Regenerate 8 baselines; open every PNG.
- Screenshots under `/tmp/tmas-p7-5-shots/`: desktop with sidebar (no filter, person filter, query, no matches); each zoom with filter; iPad mini portrait drawer open + closed.
- Status row + "As landed".

## 7.6S Server: tree reads (G1, G2)

**Branch:** `feat/p7-6s-tree-reads`, from `feature/serverpod` `920cc17`. **Owns:**
- server: `lib/src/endpoints/{story,live,family}_endpoint.dart`, `lib/src/live/live_events.dart`, three `postLiveEvent` callers (`story_endpoint.dart:280`, `photo_endpoint.dart:238`, `note_endpoint.dart:167`), `lib/src/models/story.spy.yaml`, `lib/src/models/dto/{live_kind,live_event_dto}.spy.yaml`, new migration, `test/integration/{story_endpoint,live_endpoint}_test.dart`;
- regenerated `packages/tell_me_a_story_client` (`just server-generate`);
- client plumbing (moved here from 7.7; no UI): `lib/data/stories_api.dart` (`StoriesGateway.listPublishedInTree`), `lib/data/timeline_live.dart` (`TimelineLive.watchTree`, `treeEventMatters`), `test/support/fakes/fake_stories_gateway.dart`, no-op `watchTree` in three `implements TimelineLive` fakes (`test/features/timeline/timeline_page_test.dart` `_FakeLive`, `test/features/stories/story_reader_page_test.dart` `_StoryReload`, `test/goldens/timeline_rails_golden_test.dart` `_Live`; no pixel change), `test/data/{stories_api,timeline_live}_test.dart`, `test/live/{stories_live,server_timeline_live}_test.dart`.

**G1 `story.listPublishedInTree(UuidValue familyId) → List<StoryDto>`.**
- **Authz:** existing `_requireFamilyReader` (`Authz.isTreeReadable`: family live, caller live member of some live family with same `treeId`), else `forbidden`. Same rule `listPublished` + `watchFamily` use for tree readers. Anonymous never reach it (`requireLogin`).
- **Rows:** stories with `treeId = family.treeId`, `status = published`, `familyId` in tree's **live** families (D6b; deleted middle family hides only own stories, parent + children stay one tree, D8). Ordered by `_timelineOrder` (`story_endpoint.dart:504-509`), built with `storyDtos`, as `listForPerson` at `:399-427`.
- **Index:** add to `story.spy.yaml` `indexes:`:

```yaml
  ### Tree timeline (listPublishedInTree): same column order as
  ### stories_family_order_idx, led by treeId.
  stories_tree_order_idx:
    fields: treeId, status, dateStart, datePrecision, createdAt, id
```

then `mise exec -- just server-generate` and `mise exec -- just server-migration tree-timeline` (new migration; never edit `20261107133050788-init`).

**G2: `live.watchTree(UuidValue familyId) → Stream<LiveEventDto>`, chosen over N `watchFamily` subscriptions.**
- **One subscription.** One authz check (`isTreeReadable`, same rule as G1 and `watchFamily` tree-reader branch; live member always passes), one retry/backoff loop in `ServerTimelineLive`, one permanent-refusal path. N subscriptions = N of each, plus resubscribe whenever tree family list changes.
- **Channel.** `treeChannel(treeId) => 'tree:$treeId'`. `postLiveEvent(session, event, {required UuidValue treeId})` also posts to tree channel, after family + story channels. Every caller holds `Story`, passes `story.treeId`. `LiveEventDto` keeps `familyId` so client knows which family changed.
- **Family events (new `LiveKind.family`).** Tree's live-family set changes on `family.createBranch`, `family.softDelete`, `family.recover`; each posts, after commit and **only to tree channel**, `LiveEventDto(familyId: <that family>, kind: family, deleted: <true for softDelete>)` via `postFamilyEvent(session, family, deleted:)`. Family channel never carries it → today's `timelineEventMatters` untouched. Repeated `softDelete` (no-op path) posts nothing. `LiveKind` = DTO enum, no column → model change without migration.
- **Same trust model as `watchFamily`.** Authz once, at subscribe (`live_endpoint.dart:9-21`), same `forbidden('member only')`. Events = hints only; G1 refetch re-checks access. Writes to soft-deleted families refused (D6b) → no story event from one.
- **Alternative cost.** N subscriptions need no server change but carry bookkeeping above, still can't see new branch without family event.

**Client plumbing (no UI).**
- `StoriesGateway.listPublishedInTree(String familyId) → Future<List<Story>>`; `StoriesApi` calls `_client.story.listPublishedInTree` via `_stories` (server errors mapped as `listPublished`). `FakeStoriesGateway.listPublishedInTree` records call, returns every published story in store, sorted with `compareStories` (fake store = one tree).
- `TimelineLive.watchTree({required String familyId, required void Function() onChange})`, no-op default like `watchStory`. `ServerTimelineLive` opens third `_LiveFeed` on `live.watchTree` (same 200 ms debounce, 1 s → 30 s backoff, permanent refusal on `AppException`/unauthorized/forbidden; one stream per family id; `dispose` closes).
- `treeEventMatters(event)`: like `timelineEventMatters` minus family filter. Story event not deleted + not published dropped; every other event (published/deleted stories, photos, notes, family events) refreshes.

### Task 1: G1 tree read and its index
- [x] **Step 1 (red):** in `story_endpoint_test.dart`, group `tree timeline`:
  1. Given R → B1 → C and R → B2, B1 member reads published stories of R (parent), B2 (sibling), C (child), B1, interleaved in timeline order; drafts in R and B1 (own incl.) and other tree's stories absent.
  2. Given R → M (soft-deleted) → C, members of R and C both read R's and C's stories, not M's (D6b, D8).
  3. Stories sharing start across families come year, month, day, then createdAt: result equals `timelineOrder` over union of each family's `listPublished`.
  4. Stranger + other-tree member get `forbidden`; soft-deleted-family member asking for it gets `forbidden`; anonymous refused (`ServerpodUnauthenticatedException`).
  5. `pg_indexes` has `stories_tree_order_idx` on `("treeId", status, "dateStart", "datePrecision", "createdAt", id)`.

  Run `mise exec -- dart test test/integration/story_endpoint_test.dart` in `apps/server`: fails to compile (no `listPublishedInTree`).
- [x] **Step 2 (green):** endpoint method + index, `just server-generate`, `just server-migration tree-timeline`. Rerun: green.
- [x] **Step 3:** `mise exec -- just server-analyze`, `just fmt-check`; commit `feat(server): story.listPublishedInTree with a tree timeline index (7.6S G1)`.

### Task 2: G2 tree channel and family events
- [x] **Step 1 (red):** in `live_endpoint_test.dart`, group `watchTree`:
  1. R member watching `watchTree(R)` gets event of real publish in branch B (`story.publish`), `familyId = B`.
  2. Comment on published story in B arrives on tree channel (note caller passes `treeId`).
  3. Draft edit in B delivers nothing.
  4. Comment in other tree delivers nothing (comment in R, same window, does).
  5. R member watching `watchTree(R)` hears `createBranch` under R (`kind = family`, new id, `deleted = false`), then `softDelete` of branch (`deleted = true`), then `recover` (`deleted = false`). Repeated `softDelete` posts nothing.
  6. Stranger + soft-deleted-family member get `forbidden('member only')`; anonymous refused.
  7. Existing `watchFamily` cases stay green; family event never reaches `family:<id>`.

  Red: no `watchTree`, no `LiveKind.family`.
- [x] **Step 2 (green):** `LiveKind.family`, `treeChannel`, `postLiveEvent(..., treeId:)` at three callers, `postFamilyEvent` in `createBranch`/`softDelete`/`recover`, `LiveEndpoint.watchTree`; `just server-generate`. Rerun: green; `story,note,photo,family` endpoint tests stay green.
- [x] **Step 3:** analyze, format; commit `feat(server): live.watchTree on a tree channel with family events (7.6S G2)`.

### Task 3: client plumbing
- [x] **Step 1 (red):** `test/data/stories_api_test.dart`: `listPublishedInTree` calls `story.listPublishedInTree` with family uuid, maps each `StoryDto`, server order; server `AppException` comes out mapped. `test/data/timeline_live_test.dart`: `treeEventMatters` (other families refresh; draft story doesn't; deleted stories, photos, notes, family events do); `watchTree` subscribes to `live.watchTree`, debounces, reopens with backoff, stops on refusal, `dispose` closes. Live (`test/live`): `stories_live_test` — root member reads branch story via `listPublishedInTree`; `server_timeline_live_test` — `watchTree(root)` fires on branch publish.
- [x] **Step 2 (green):** gateway method, fake, `TimelineLive.watchTree`, `ServerTimelineLive`, `treeEventMatters`, three no-op fakes. `mise exec -- just test`, `mise exec -- just test-goldens` (unchanged).
- [x] **Step 3:** commit `feat(app): tree read and tree live plumbing (7.6S)`.

### Task 4: close
- [x] `mise exec -- just check`; live suite against server built from this branch (`LIVE_SERVER_URL`, see "As landed"); fill "As landed" + Status row; commit `docs(plan): 7.6S as landed`.

**Done when:** `just check` passes with server count up by new cases, `just test-goldens` unchanged, migration new + tool-named, generated client committed, `git status --short` clean.

**As landed (7.6S, 2026-11-08, `feat/p7-6s-tree-reads`):**
- **Commits:** `ef49b1e` plan; `11a2d07` G1 (`story.listPublishedInTree`, index, migration); `ed48c4c` G2 (`live.watchTree`, tree channel, `LiveKind.family`); `47e97d2` client plumbing; then this "As landed" commit.
- **Endpoints:** `StoryEndpoint.listPublishedInTree(Session, UuidValue familyId) → Future<List<StoryDto>>`; `LiveEndpoint.watchTree(Session, UuidValue familyId) → Stream<LiveEventDto>`. Client: `client.story.listPublishedInTree(familyId)`, `client.live.watchTree(familyId)`.
- **Authz:** `Authz.isTreeReadable(familyId)` for both (family live, caller live member of some live family with same `treeId`); G1 refuses via `_requireFamilyReader` with bare `forbidden`, G2 with `forbidden('member only')`, as `watchFamily`. No new `AppErrorCode`.
- **Migration:** `20261108073545682-tree-timeline` (tool-named): `CREATE INDEX "stories_tree_order_idx" ON "stories" USING btree ("treeId", "status", "dateStart", "datePrecision", "createdAt", "id")`. `20261107133050788-init` untouched.
- **Family events:** `createBranch`, `softDelete` (not repeat), `recover` post `LiveKind.family` to `tree:<treeId>` only. `recover` included: changes tree's live-family set like `softDelete`; `rename`, `setOrigin`, membership changes, purge post nothing.
- **Gates:** `just check` passes: `fmt-check` `(0 changed)` ×2; `analyze: 6 issues (ceiling 6)`; app `+704 ~12` (10 new: 2 `stories_api`, 3 `treeEventMatters`, 5 `watchTree`); `server-analyze` no issues; server `+447` (15 new: 7 story, 8 live, incl. review's deleted-family-member + exact-order cases). `just test-goldens` `+6`, no PNG changed.
- **Live:** `just server` on :8080 runs main checkout's older server, so live suite ran against server started from this worktree on other ports with own data dir: `SERVERPOD_DATABASE_DATA_PATH=.serverpod/p76s/pgdata SERVERPOD_API_SERVER_PORT=8180 SERVERPOD_API_SERVER_PUBLIC_PORT=8180 SERVERPOD_INSIGHTS_SERVER_PORT=8181 SERVERPOD_INSIGHTS_SERVER_PUBLIC_PORT=8181 SERVERPOD_WEB_SERVER_PORT=8182 SERVERPOD_WEB_SERVER_PUBLIC_PORT=8182 SERVERPOD_DATABASE_PORT=8190 dart run bin/main.dart --apply-migrations` in `apps/server`, then `flutter test --tags live --run-skipped --dart-define=LIVE_SERVER_URL=http://127.0.0.1:8180 test/live`: `+29` (was `+27`; +2). Worktree's copied `.serverpod/development/pgdata` points at main checkout's postmaster → separate data path.

## 7.M iPad measurement (Q6; owner, on their iPad)

Not a PR. Measures lab whole-tree renderers on real hardware before 7.8 commits to tree graph (paints every node).
- **Who:** owner runs. Agent prepares build, records numbers in plan "As landed".
- **When:** any time; doesn't wait for other slices. Runs on `labs/timeline_lab` after 7.0, or on lab worktree as is.

**Setup:**
1. **Mac:** Safari ▸ Settings ▸ Advanced ▸ "Show features for web developers".
2. **iPad:** Settings ▸ Apps ▸ Safari ▸ Advanced ▸ Web Inspector **on**. Cable iPad to Mac, trust Mac.
3. **Build + serve release web build** (in `labs/timeline_lab`):

   ```bash
   mise exec -- flutter build web --release
   python3 -m http.server 8100 --bind 0.0.0.0 --directory build/web
   ipconfig getifaddr en0          # the Mac's LAN address
   ```

4. On iPad Safari, open `http://<mac-lan-ip>:8100`. Close other tabs/apps; keep iPad plugged in, Low Power Mode off.
5. On Mac, Safari ▸ Develop ▸ *<iPad name>* ▸ lab page, open **Timelines** tab. Enable **Rendering Frames** + **JavaScript & Events**; others off.

**Screens** (landscape full screen, then tree graph again in portrait). Each: bench menu dataset **1 000**, then repeat at **5 000**:

| # | Screen in the lab | Action recorded (10 s each) |
|---|---|---|
| S1 | Tree graph, **Family** mode | Continuous one-finger pan down, across, back over whole tree (graph scrolls both axes; no pinch). |
| S2 | Treemap, Family grouping (overview) | Tap into family, then decade, then back out; repeat 3×. |
| S3 | Sliver list (control) | Fling scroll top to bottom and back. |
| S4 | Switch from sliver list to tree graph | One tap on renderer switch. Record longest frame (time to first full frame). |

**Method:**
1. Record in Timelines, do action, stop.
2. In **Rendering Frames**, read frame count, frames over **16.7 ms** (60 fps line), longest frame ms. iPad Safari renders 60 Hz default.
3. Export each recording (Timelines ▸ Export) to `~/p7-ipad/<screen>-<size>.json`.
4. Record device model, iPadOS + Safari versions.
5. Note device checklist from lab Task 22, Step 4, observations only (don't gate):
   - Pencil tap;
   - trackpad hand cursor;
   - Magic Keyboard;
   - Stage Manager 320–1366 pt;
   - VoiceOver on tree nodes;
   - home-indicator inset.

**Pass thresholds** (approved, O4). Gate = **1 000-story** run:
- S1, S2: ≥ 90% frames ≤ 16.7 ms, no frame over 50 ms during gesture.
- S4: longest frame ≤ 500 ms.
- S3 = reference: if S3 also fails, build or device setup suspect; re-check before judging S1/S2.
- 5 000-story numbers recorded, don't gate. If fail, 7.8 keeps lab `+N` collapse for groups over 6, slice plan adds node cap.

**Outcome:**
- **Pass:** 7.8 may start.
- **Fail:** stop, report to owner via Main. Options: ship treemap only (7.7), keep tree graph in lab; or rework graph to cull off-screen nodes, measure again.

**Outcome (2026-11-08): pass.** Owner ran measurement on own iPad 2026-11-08, reports fine vs approved O4 thresholds. Owner's verdict only: no Timelines exports or per-screen numbers (frames, frames over 16.7 ms, longest frame) recorded for S1–S4. 7.8 may start; keeps `+N` collapse for groups over 6 (no node cap).

## 7.7 Whole-tree page and treemap (Q2)

**Branch:** `feat/p7-7-treemap`, from `feature/serverpod` `fd00bd4` (7.0, 7.1, 7.2, 7.6S merged; app `+751 ~12`). **Owns:**
- uses 7.6S plumbing as landed, unchanged: `StoriesGateway.listPublishedInTree`, `TimelineLive.watchTree`, `treeEventMatters` (`lib/data/stories_api.dart`, `lib/data/timeline_live.dart`). No new gateway call → no new live test;
- `lib/core/router/app_routes.dart` (`familyTree = '/family/:id/tree'`, `familyTreePath(id)`);
- `lib/app/app_router.dart` (route, beside `allStories`);
- `lib/ui/album/album_header.dart` (`AlbumHeaderPage.familyTree` + O1 menu row);
- `lib/ui/timeline/view_switch.dart` (`label` optional: C5–C7, and 7.8's C3/C4, have no approved "Group by"-style label);
- new `lib/features/timeline/tree/{family_tree_page,tree_timeline_loader,treemap_layout,treemap_view}.dart`;
- tests: `test/features/timeline/tree/{tree_timeline_loader,treemap_layout,treemap_view,family_tree_page}_test.dart`, `test/app/app_router_test.dart`, `test/ui/album/album_header_family_menu_test.dart`, `test/ui/timeline/view_switch_test.dart`, `test/goldens/family_tree_treemap_golden_test.dart` + two PNGs.

**Not touched:** `timeline_page.dart` and `features/timeline/rails/` (7.3 owns), server, generated client, every fake in Conventions (shared `FakeStoriesGateway.listPublishedInTree` already returns store as one tree).

**Copy.** Only approved strings (O2), verbatim:
- C1 `See the whole family tree` (menu row), C2 `{Family} family tree` (page heading; `{Family}` = tree's root family, live row with no live parent, fallback current family), C5–C7 `By family` · `By decade` · `By person` (grouping switch, that order, `By family` selected first), C9 `No stories in this family tree yet.` (empty tree).
- Reused app strings, no new copy: `Couldn't load stories.` + `Retry` (All Stories load error), `No one tagged` (All Stories person grouping, stories with no tagged person), `1 story` / `{n} stories` (All Stories `groupCountLabel`, in cell semantics), `Untitled` (`storyTitle`), story date labels (`storyDateLabelFor`), `{decade}s` and years.
- Dropped lab copy: `Group by` label (switch has none), `All` crumb (C2 heading = root crumb), `›` separator (`chevron_right` icon), dim-mode `matched/total` counts (O6).
- C8 (`{n} more stories`) belongs to graph's `+N` chip, stays with 7.8; treemap has no `+N`.
- C19 `Open {Family} timeline` (owner feedback, 2026-11-08): **approved 2026-11-08**, one constant (`openFamilyTimelineLabel`).
- Family colour key (owner, after v2 sign-off) adds no copy: family names only.

**Change:**
- **Route.** `/family/:id/tree` → `FamilyTreePage(familyId:, storiesApi:, familiesApi:)` from `createAppRouter`, beside `allStories`. Router's existing auth redirect covers it.
- **Entry (O1 A).** `_FamilyMenu` gets row `family-menu-tree` (C1, `Icons.forest_outlined`), right after `family-menu-divider`, before `family-menu-invite`, shown when `currentFamilyId` set, except on new-story page (Invite hidden too) and tree page itself (owner feedback). Selecting calls `GoRouter.of(context).go(AppRoutes.familyTreePath(currentFamilyId))`, as Stories item. No header nav item active on tree page.
- **Load.** `TreeTimelineLoader.load(familyId)` runs `listFamilyTree(familyId)` + `listPublishedInTree(familyId)` in parallel, rethrows gateway's own error (`ParallelWaitError` unwrap from `AllStoriesLoader`). Page shows spinner, then treemap; failure shows `Couldn't load stories.` with `Retry`. Header chrome (`listMine`/`listStewarded`) = same best-effort read as All Stories. `FamilySelection.remember(familyId)` on open.
- **Live.** `initState` calls `live.watchTree(familyId, onChange: reload)`; reload keeps treemap on screen (no spinner), generation counter drops stale results. `live` defaults as `TimelinePage`'s: injected one, none when only `storiesApi` injected (tests), else owned `ServerTimelineLive` closed by `dispose`.
- **Treemap** (`treemap_layout.dart`, pure; `treemap_view.dart`, widgets), ported from lab:
  - `squarify` unchanged; `TreemapCell`/`TreemapGroup` hold `TimelineEntry`s (7.2) instead of lab entries;
  - `buildTreemap(List<TimelineEntry>, List<TreeFamily>, TreemapBy)`: `family` → decade cells (group label = family name), `decade` → year cells (`1950s` → `1952`), `person` → decade cells over `Story.people` (story counts once per tagged person; untagged → `No one tagged`); groups + cells sorted by count desc, ties timeline order;
  - `TreemapLayout`/`TreemapSlot`/`RenderTreemapLayout` unchanged;
  - visual weight (owner feedback): every cell + story tile tinted by family, cycling `albumSageTint`, `albumBlush`, `albumBlushPale`, `albumPillFill` in tree order (four families never share tint; family keeps tint across groupings). In `By decade` and `By person` cell takes **dominant family's** tint (most stories; tie → earliest story's family). Group frames `albumRuleStrong`; cells keep `albumModalBorder`. Count uses `AlbumText.count` in `albumInk` (style's `albumDimInk` is 3.8:1 on sage tint), sized fifth of cell's shorter side between base size and 32; label w600, `AlbumText.group` size in cells ≥ 96 pt. Ink ≥ 4.5:1 on every tint (tested). No new tokens. Shapes `albumContainerShape(AlbumRadius.group/tile)`;
  - family colour key (`treemap-family-key`) under grouping switch in all three groupings: per family, tree order, 14 pt swatch with cell tint (`albumRuleStrong` hairline so `albumPillFill` shows) + family name; wraps on narrow, ellipsizes name wider than row;
  - drill-down: overview (groups of cells) → tap group header → group's cells, large → tap cell → one tile per story, date order. Crumb row = C2 heading (`treemap-crumb-root`, tappable once drilled) › group (`treemap-crumb-group`) › cell;
  - **finger** tap on overview cell under `AlbumTarget.min` (44 pt) either axis opens its group instead (`isFingerLike`); mouse, trackpad, pencil open cell;
  - switching grouping returns to overview;
  - removed from lab: playback (`RevealOpacity`, fill rise; Q3), dim shading + matched counts (O6), `selectedId`.
- **Taps.**
  - Story tile pushes `AppRoutes.storyPath(id)` (reader), reloads quietly on return, as All Stories.
  - Every group header drills in, every grouping (owner feedback). In `By family`, drilled view (group or cell level) shows terracotta `Open {Family} timeline` action (C19, `treemap-open-family`) after crumbs: calls `FamilySelection.remember(id)`, goes to `AppRoutes.timeline`.
- **Empty tree.** No published story in tree: heading + `EmptyTimeline(message: C9)`, no switch.
- **No view switch** until 7.8; page shows treemap alone.

### Task 1: Treemap layout (pure)
- [x] **Step 1 (red):** `test/features/timeline/tree/treemap_layout_test.dart`, ported from lab `treemap_test` (`squarify` group unchanged) with app `Story`/`TreeFamily` fixtures (Jenkins root, branches Bea + Cal, stories 1950–1999, one untagged):
  1. `squarify`: lab's four proportional/no-overlap cases, no-sliver case, zero-total case.
  2. `By decade`: groups + cells sum to story count, sort desc, each entry in its decade group + year cell.
  3. `By family`: group ids = exactly families with stories, labels = tree names, cells `{decade}s`.
  4. `By person`: story counts once per tagged person; untagged form `No one tagged`.
  5. Ties keep timeline order (two equal-count groups keep first-story order).
  6. Ink on strongest fill (`0.18` terracotta over parchment) ≥ 4.5:1 (`test/support/contrast.dart`).

  Run `mise exec -- flutter test test/features/timeline/tree`: compile errors (no lib).
- [x] **Step 2 (green):** `lib/features/timeline/tree/treemap_layout.dart`. Rerun: green.

### Task 2: Treemap view
- [x] **Step 1 (red):** `treemap_view_test.dart` (1280 × 800, `albumTheme()`):
  1. Overview shows one `treemap-group-<id>` per family + C2 heading; switch reads `By family` · `By decade` · `By person`, `By family` selected, no label.
  2. `By decade`: tap group header → `treemap-crumb-group` appears; tap cell → one `treemap-story-<id>` per story; tap tile → `onStory(id)`; tap `treemap-crumb-root` → back to overview.
  3. `By family`: tap group header → drills in, `onFamily` not called; drilled view shows `Open Bea timeline`, calls `onFamily(id)`; absent in `By decade`.
  4. Finger tap on sub-44 pt overview cell opens its group; mouse tap same cell opens cell.
  5. Switching grouping while drilled → overview.
  6. Cell semantics read `{label}, {n} stories` / `1 story`.
  7. No stories: C9 (`empty-timeline`), no switch.

  `test/ui/timeline/view_switch_test.dart`: no `label` → only `SegmentedButton`.
- [x] **Step 2 (green):** `treemap_view.dart` (`TreemapView({title, stories, tree, onStory, onFamily})`), optional `ViewSwitch.label`. Rerun: green.

### Task 3: Loader, page, route, header row
- [x] **Step 1 (red):**
  - `tree_timeline_loader_test.dart`: both calls run with family id; failing `listPublishedInTree` rethrows gateway's `AppException`, not `ParallelWaitError`.
  - `family_tree_page_test.dart` (fakes: `FakeStoriesGateway`, `FamiliesGateway` with three-family tree, recording `TimelineLive`):
    1. load: spinner, then `Jenkins family tree` + treemap; `listPublishedInTree` called once; `watchTree` subscribed with family id; `FamilySelection.id` = family;
    2. live refresh: new published story in store, then `onChange()` → new story's group count shows, no spinner between;
    3. tile → reader: drill + tap story → router at `AppRoutes.storyPath(id)`;
    4. family → timeline: drill into family, tap `Open Cal timeline` → `FamilySelection.id` = that family, router at `AppRoutes.timeline`;
    5. empty tree → C9;
    6. error → `Couldn't load stories.`; `Retry` loads again;
    7. iPad sweep: 744 × 1133, 1133 × 744, 1024 × 1366, 1366 × 1024, 320 × 568 render without layout exception, treemap fills space under switch.
  - `app_router_test.dart`: signed-in `/family/<id>/tree` shows `FamilyTreePage`; signed-out redirected to sign-in.
  - `album_header_family_menu_test.dart`: dropdown order becomes families, divider, tree row, invite, branch, Manage, with C1 text; row shows without write access; picking from Drafts goes to `/family/<current>/tree`.
- [x] **Step 2 (green):** routes, page, loader, `AlbumHeaderPage.familyTree`, row. `mise exec -- just test`.

### Task 4: Goldens
- [x] `test/goldens/family_tree_treemap_golden_test.dart` (`@Tags(['golden'])`): `FamilyTreePage` with Task 3 fakes (Jenkins, Bea, Cal; stories 1950–1999) at `desktop` 1280 × 800 and `ipad_mini_portrait` 744 × 1133, overview, `By family`. `mise exec -- just test-goldens --update-goldens`, open both PNGs, then `just test-goldens`: `+8`, six rail PNGs unchanged (`git status --short test/goldens/timeline` empty).

### Task 5: Gates, live, e2e, screenshots
- [x] `mise exec -- just check`; live suite against server from this worktree (7.6S "As landed" env, own data dir); e2e per README (9/9).
- [x] Screenshots (Conventions sign-off, own server + web-server): family menu with row; overview each grouping; one drill-down; iPad mini portrait. To `/tmp/tmas-p7-7-shots/`.
- [x] Status row + "As landed"; commit.

**Stop:** screenshots signed off before merge (O1, O2, O5, O6 answered). Gates incl. `test-live` + e2e.

**Done when:** `just check` passes with new tests, `just test-goldens` `+8` with six rail PNGs unchanged, live suite passes vs this branch's server, `git status --short` clean.

## 7.8 Family tree graph (Q2; gated on 7.M)

**Owns:** new `lib/features/timeline/tree/{tree_graph_layout,tree_graph_view}.dart`, `family_tree_page.dart` (view switch), tests, goldens.

**Change:**
- **Port Family mode only** from `tree_graph_layout.dart` and `tree_graph_renderer.dart`: family → decade → story, each branch hanging off origin story (`TreeFamily.parentFamilyId`, `originStoryId`).
- **Drop** Time mode, playback, filter flags.
- **Keep:**
  - groups over 6 collapse to `+N`;
  - calm edges;
  - label knockouts;
  - finger hit radius with nearest-node hit testing;
  - full-height pan;
  - `semanticsBuilder` nodes.
- **Page `ViewSwitch`** (terracotta selected toggle): tree graph | treemap, labels in O2.
- **Taps.** Story node opens reader; family node opens its timeline.
- **Performance.** 7.M S1/S4 thresholds hold on real tree sizes slice tests (1 000 synthetic stories in widget benchmark, sanity check; iPad numbers decide).

**Tests:**
- Port `tree_graph_test` (273 lines) for Family mode.
- Widget tests: node tap → route, family tap, `+N`, semantics labels.
- iPad sweep.
- Goldens `family_tree_graph_{desktop,ipad_mini_portrait}`.

**Stop:** screenshots signed off before merge.

### 7.8 TDD plan (written at slice start, 2026-11-08)

Branch `feat/p7-8-tree-graph` from `feature/serverpod` `1954671` (7.0–7.7 merged; 7.M passed). Each task: failing test first, red, implement, green, gates, commit.

**Owns (as planned, made exact):**
- new `lib/features/timeline/tree/{tree_graph_layout,tree_graph_view}.dart`;
- `lib/features/timeline/tree/family_tree_page.dart` (view switch + which view shows);
- `lib/features/timeline/tree/treemap_view.dart`: only optional `viewSwitch` slot before grouping switch, and C2 heading as shared `TreeHeading` widget (graph shows same heading);
- `lib/ui/timeline/view_switch.dart`: optional `leading` list before segments, so page switch + treemap grouping switch share one row;
- `lib/core/theme/album_theme.dart`: `AlbumText.badge` (lab's `LabText.badge`, deferred to 7.8 by 7.2: `labelSmall` w700 in `albumParchment`). Text style, not colour token;
- tests: `test/features/timeline/tree/{tree_graph_layout,tree_graph_view}_test.dart` (new), `family_tree_page_test.dart`, `test/ui/timeline/view_switch_test.dart`, `test/core/theme/album_theme_test.dart`, `test/support/tree_fixture.dart` (crowded 1960s for `+N`), `test/goldens/family_tree_graph_golden_test.dart` + two PNGs, and `family_tree_treemap_golden_test.dart` (now selects `Overview` first).

**Not touched:** server, generated client, gateways + fakes, router, header, rails.

**Copy.** Only approved strings, verbatim:
- C3 · C4 `Family tree` · `Overview` (page view switch, that order, no label; `Family tree` selected on open, since menu row C1 says "See the whole family tree").
- C8 `{n} more stories`: semantics label of `+N` node. Painted chip shows `+N` only (number, no words).
- C19 `Open {Family} timeline`: action shown after family node tapped (7.7 pattern: family title drills/selects, C19 navigates).
- Reused, no new copy: C2 (heading, and root node label when tree has >1 root family), `Untitled` (`storyTitle`), story date labels (`storyDateLabelFor`), `{decade}s`, `1 story` / `{n} stories` (group semantics, All Stories wording), family names, branch year as data (`Bea (1975)`, as lab).
- Dropped lab copy: `Tree` (switch label), `Time`/`Family` (modes), `Families` (lab multi-root label; C2 replaces), `+N more` (chip shows `+N`).

**Change:**
- **Layout** (`tree_graph_layout.dart`, pure): `TreeNode {id, kind, label, storyId, familyId, hiddenStoryIds, children, parent, storyCount, depth}`; kinds `root`, `family`, `decade`, `story`, `overflow`. `buildFamilyTree(List<Story> stories, List<TreeFamily> tree, {required String rootLabel, Set<String> expanded, int maxLeaves = 6})`: stories in timeline order; family whose parent not in tree (null or soft-deleted, D8) = root; one root = graph root, several hang from `root` node labelled `rootLabel`; family with neither stories nor branches left out; decades date order; > `maxLeaves` stories in decade show `maxLeaves - 1` + one overflow node (`+N`, latest stories), except branch origins, never collapse; branch hangs off origin leaf, or off parent family when origin unpublished; `expanded` (decade node ids) shows every story. `TreeLayout` unchanged from lab (depth on x, leaves stacked on y, parents centred on first + last child, `hitTest(p, radius:)` nearest node, labels not targets, `storyNodes`).
- **View** (`tree_graph_view.dart`): `TreeGraphView({title, stories, tree, onStory, onFamily, viewSwitch})`. C2 heading (`TreeHeading`), then view switch row, then graph in vertical + horizontal scroll view, ≥ viewport tall (full-height pan). One `CustomPainter`:
  - edges: cubic curves in `albumRule`, `AlbumStroke.rule` wide (calm);
  - story nodes: `paintStoryMarker` (`AlbumMarker.small`, matched, moss ring on branch origin), label right of dot in `labelSmall` `albumInk`;
  - decade + root nodes: `albumInk` dot, label above-right on `albumParchment` knockout (edges pass under);
  - family nodes: `albumInk` dot, label above-right on chip in family's 7.7 tint (`treemapFamilyTints`, cycling `albumSageTint`, `albumBlush`, `albumBlushPale`, `albumPillFill` in tree order, over parchment), `albumRuleStrong` hairline, ink ≥ 4.5:1 on every tint; selected family gets `albumTerracotta` ring around chip;
  - overflow: `albumInk` pill holding `+N` in `AlbumText.badge` (parchment, ≥ 4.5:1).
- **Taps** (nearest node within `hitRadiusFor(kind, precise: 10)`, finger reaches 22 pt): story → `onStory(id)`; `+N` → decade expands; expanded decade → collapses; family → selected, heading row shows C19 action (`tree-graph-open-family`), calls `onFamily(id)`; root does nothing. Cursor = hand over node.
- **Semantics** (`semanticsBuilder`): story `{title}, {date}` (button, tap opens); `+N` C8 (button, tap expands); family `{name}, {n} stories` (button, tap selects); decade + root `{label}, {n} stories`.
- **Page.** `FamilyTreePage` keeps `_view` (`FamilyTreeView.graph` first). Builds C3/C4 `SegmentedButton` (key `family-tree-view`, `ViewSwitch` style, no selected icon), hands to whichever view shows: graph puts it in own switch row; treemap puts it before grouping switch (`ViewSwitch.leading`), so same place in both. Switching keeps loaded data; live reload keeps view. Treemap 7.7 behaviour unchanged.
- **Empty tree.** C9 no switch, as 7.7.

#### Task 1: Layout (pure)
- **Test** `tree_graph_layout_test.dart`, ported from lab `tree_graph_test` "family tree" + "layout" groups + finger-radius case, with `TreeFixture` (Jenkins → Bea from 1975, Cal from 1984) and 1 000-story synthetic tree:
  1. Jenkins root; Bea + Cal hang off `s1975` and `s1984` leaves; every story shown once (leaves + `hiddenStoryIds`); root `storyCount` = story count.
  2. Decade with 8 stories shows 5 + `+3` (latest three, date order); decade in `expanded` → all 8; branch origin in crowded decade never collapsed.
  3. Origin story unpublished → branch hangs off parent family.
  4. Family whose parent not in tree = root; two roots hang from `root` node labelled `rootLabel`; family with no stories + no branches absent; no stories → null.
  5. Layout: parents centred on children, depth on x, leaves one `leafGap` apart, every story in `storyNodes`.
  6. Hit testing: label not target; 12 pt below dot misses with precise radius, hits with `AlbumTarget.fingerRadius`.
  7. Ink on each family tint over parchment + parchment on `+N` ink pill ≥ 4.5:1 (`test/support/contrast.dart`).
  8. 1 000 stories over five families: built + laid out, every story reachable (benchmark sanity check; frame in Task 2).

#### Task 2: View
- **Test** `tree_graph_view_test.dart` (1280 × 800, `albumTheme()`):
  1. C2 heading + one painter; tap `s1952` dot (mouse) calls `onStory('s1952')`; finger 12 pt off dot does too, mouse there nothing.
  2. `+N`: crowded decade shows `+3`; tap shows all its stories; tap decade collapses.
  3. Family tap selects: C19 `Open Bea timeline` shows, tap calls `onFamily(bea)`; tapping root family (`Jenkins`) shows `Open Jenkins timeline` instead.
  4. Semantics: story node reads `{title}, {date}`, is button; `+3` reads `3 more stories`; family reads `Bea (1975), 3 stories`; tapping story semantics node calls `onStory`.
  5. Graph pans both axes, ≥ viewport tall.
  6. 1 000 stories: first frame builds without error (sanity; logs time).
  - `album_theme_test`: `AlbumText.badge` is `labelSmall` w700 in `albumParchment`.

#### Task 3: Page and the view switch
- **Tests** (`family_tree_page_test.dart`):
  1. Page opens on `Family tree`: switch (`family-tree-view`) reads `Family tree` · `Overview`, `Family tree` selected, no label; `TreeGraphView` shows, `TreemapView` doesn't.
  2. Tap `Overview` → treemap with same switch in grouping row (same top-left as graph, ±1); tap `Family tree` → back.
  3. Live reload keeps selected view.
  4. Graph story tap opens reader; graph family tap then C19 → timeline with that family selected.
  5. 7.7 treemap cases select `Overview` first; assertions unchanged.
  6. iPad sweep: 11 `ipadSizes`, iOS with insets, both views: no FlutterError; graph viewport starts below switch, reaches window bottom; treemap keeps 7.7 floor.
  - `view_switch_test`: `leading` widgets before segments.

#### Task 4: Goldens
- `test/goldens/family_tree_graph_golden_test.dart` (`@Tags(['golden'])`): page on `Family tree` with crowded fixture (`+N` on Jenkins' 1960s) at `desktop` 1280 × 800 and `ipad_mini_portrait` 744 × 1133. `family_tree_treemap_golden_test` taps `Overview` first; its two PNGs regenerated on purpose (switch row now leads with C3/C4), 10 rail PNGs unchanged (`git status --short test/goldens/timeline` empty). Open every changed PNG.

#### Task 5: Gates, live, e2e, screenshots
- `mise exec -- just check`; `just test-goldens` (`+14`); live suite + e2e (9/9) vs server from this worktree (own ports + data dir).
- Screenshots to `/tmp/tmas-p7-8-shots/` (own server + web-server, seeded as 7.7): graph at 1280 × 800 and 744 × 1133, `+N` collapsed + expanded, selected family with C19, view switch on both views.
- Status row + "As landed"; commit.

**Stop:** screenshots signed off before merge.

**Done when:** `just check` passes with new tests, `just test-goldens` `+14` with 10 rail PNGs unchanged, live suite + e2e pass vs this branch's server, `git status --short` clean.

## 7.z Close

- Gates on `feature/serverpod` after last merge: `just check`, `just test-live`, `just test-goldens`, e2e (9/9), CI green (`lab` job went with lab, O7).
- Fill "As landed" below: commits per slice, counts, iPad table, owner answers O1–O6.
- `AGENTS.md`: check layout, gates, `test/goldens` lines match what landed.
- Move this plan + slice plans to `docs/archive/superpowers/plans/` (`docs/superpowers/plans/README.md` rule).
- Ask owner whether `labs/timeline_lab` stays as bench or deleted (O7).

---

## Owner questions

Send via Main. Each answer recorded here before dependent slice starts.

**Answers (owner, 2026-11-08):**

| # | Answer |
|---|---|
| O1 | **(A)**: family menu row opening `/family/:id/tree`. |
| O2 | All 18 strings (C1–C18) approved as proposed; use verbatim. C19 (`Open {Family} timeline`, 7.7 owner feedback) approved 2026-11-08. |
| O3 | Proposed 7.2 token names approved, incl. `albumBlush` = `0xFFF5DED6` and `albumBlushPale` = `0xFFF5ECE9`. |
| O4 | Proposed thresholds approved. |
| O5 | All three treemap groupings (family, decade, person). |
| O6 | No filters on tree views for now. |
| O7 | **Delete** lab (owner, 2026-11-08). 7.z removes `labs/timeline_lab`, `lab`/`lab-test` recipes, CI `lab` job. |

**O1. Where the whole-tree views live (blocks 7.7).** Recommended: **(A)** row in family menu (`album_header.dart` `_menuItems`, `:693-764`), between family list divider and "Invite…". Opens `/family/:id/tree` for current family; header handles navigation itself, as "Stories" item (`:171-177`).
- Fits menu's existing family-level actions (invite, add branch, manage).
- No change to locked zoom ladder.
- Leaves header width budget alone: at 744 pt header already hides family name (7.1 golden).

Alternatives:
- **(B)** Fourth segment in timeline zoom pill. Mixes "zoom" with "another view", changes locked R3/M13 ladder.
- **(C)** Fourth header nav item. Less room for family name on iPad.

**O2. Copy (approved 2026-11-08 as proposed).**

| Id | Where | Proposed text |
|---|---|---|
| C1 | Family menu row (O1 A) | `See the whole family tree` |
| C2 | Whole-tree page title | `{Family} family tree` |
| C3, C4 | View switch (7.8) | `Family tree` · `Overview` |
| C5–C7 | Treemap groupings (O5) | `By family` · `By decade` · `By person` |
| C8 | Treemap/graph `+N` chip semantics | `{n} more stories` |
| C9 | Empty tree | `No stories in this family tree yet.` |
| C10 | Story chooser title (7.4) | `Stories here` |
| C11 | Filters button / drawer title (7.5) | `Filters` |
| C12–C14 | Filter sections | `People` · `Places` · `Years` |
| C15 | Filter search hint | `Search titles, stories and people` |
| C16 | Status line | `{matched} of {total} stories match` |
| C17 | No-match state + action | `No stories match these filters.` · `Clear filters` |
| C18 | Decade header count while filtering | `{matched} of {total}` |
| C19 | Treemap, drilled-in family action (7.7 owner feedback) | `Open {Family} timeline` (approved 2026-11-08) |

**O3. Token names (blocks 7.2).**
- Confirm 7.2 names for lab scales + tints. Values = lab's, accepted under Q5.
- Name two exact-value tokens. Proposed: `albumBlush` = `0xFFF5DED6`, `albumBlushPale` = `0xFFF5ECE9`.

**O4. iPad thresholds (blocks the 7.M verdict).** Confirm, or give other numbers:
- gate = 1 000-story run;
- S1/S2: ≥ 90% frames ≤ 16.7 ms, none over 50 ms during gesture;
- S4: first full frame ≤ 500 ms;
- 5 000 stories recorded only.

**O5. Treemap groupings (7.7).** All three of lab's (family, decade, person), or family only? Recommended: all three, need no extra data.

**O6. Filters on the whole-tree views?** Q4 covers timeline. Recommended: no for now; tree views show every story undimmed.

**O7. After Phase 7 (7.z):** keep `labs/timeline_lab` as bench, or delete?

---

## Exit criteria for Phase 7

- Rails look as owner signed off (Q5), split out of `timeline_page.dart`. `timeline_page.dart` off colour skip list (ceiling 16).
- Timeline has dim-only filters (Q4) with approved copy.
- Family tree graph (7.M pass) + treemap read whole tree via `story.listPublishedInTree`, update via `live.watchTree`. Reached from approved entry point.
- `labs/timeline_lab` came in with 7.0 (`just lab`/`just lab-test`, analyze-only CI job), deleted at 7.z (O7).
- Goldens run with `just test-goldens`; CI excludes them.
- `just check`, `just test-live`, `just test-goldens`, e2e (9/9), CI green. App count ≥ `+689 ~12` plus new tests; server `+425` plus 7.6S cases; analyze ≤ 6.

## As landed

**Phase 7 summary (7.z, 2026-11-08):**
- **PRs and merge commits** into `feature/serverpod`:

| Slice | PR | Merge |
|---|---|---|
| 7.0 Lab import | #181 | `659f82a` |
| 7.1 Golden harness | #182 | `920cc17` |
| 7.6S Server tree reads | #183 | `0ee6780` |
| 7.2 Tokens and primitives | #184 | `fd00bd4` |
| 7.3 Rail split | #185 | `2c21572` |
| 7.7 Whole-tree page and treemap | #187 | `a8ead54` |
| 7.4 Rail restyle and iPad | #188 | `53967c3` |
| Build robustness (no libsqlite3 download; CI caches embedded Postgres) | #189 | `5c4ba8a` |
| 7.5 Timeline filters | #190 | `1954671` |
| 7.8 Family tree graph | #191 | `3429aff` |

- **Counts** (at `feat/p7-8-tree-graph` `83fe9bb`): app `+973 ~12` (Phase 6: `+689 ~12`), server `+447` (was `+425`), live `+29` (was `+27`), e2e 9/9, `just test-goldens` `+14`, `analyze: 6 issues (ceiling 6)`, colour skip list 17 → 16 (`timeline_page.dart` off).
- **7.M:** passed 2026-11-08 on owner verdict vs O4 thresholds. No numeric exports → no iPad table (see "7.M iPad measurement" below).
- **Owner answers O1–O7** ("Owner questions" → "Answers"): O1 (A) family menu row; O2 C1–C18 approved, C19 added; O3 token names approved; O4 thresholds approved; O5 all three groupings; O6 no filters on tree views; O7 delete lab.
- **7.z** (`chore/p7-z-close`): lab deleted; this summary + roadmap row; `AGENTS.md` checked; plan archived to `docs/archive/superpowers/plans/`.

**7.2 Tokens and shared primitives** (`feat/p7-2-tokens`, from `feature/serverpod` `920cc17`):
- **Commits:**
  - `d94a41b`: owner answers O1–O7;
  - `9f5fd86`: §7.2 plan;
  - `256accb`: tokens + `albumDimInk` (+19 tests);
  - `3f98657`: primitives (+28 tests).
- **Gates:**
  - `just check` passes: fmt `(0 changed)` twice, `analyze: 6 issues (ceiling 6)` (all six pre-existing), app `+741 ~12` (from `+694 ~12`, +47), server `+432`;
  - import, layout, colours guards pass, skip list unchanged at 17;
  - `just test-goldens` `+6`, no PNG changed.
- **Plan fixes:**
  - Index 7.2 row said 7.5 would point `allStoriesDimInk()` at token. 7.2 did it; 7.5 "Owns" line for it gone. Dim-ink test passed vs old `alphaBlend` body before swap → ARGB-identical.
  - Lab `EmptyTimeline` was Hide-mode empty state with fixed copy. Hide mode out of scope (Q4), so now takes `message` + optional `actionLabel`/`onAction`. Callers pass C9, or C17 with `Clear filters`.
  - Added `TimelineEntry` adapter (`timeline_entry.dart`: `Story` + `matched`, `year` = `fractionalYear(publishedStart)`, `timelineEntries(…, matches:)`). Replaces lab `TimelineEntry` + `LabStory.fractionalYear`.
  - `fractionalYear` uses UTC calendar day → local `DateTime` near DST change maps to own day.
  - `isOrigin` takes `Iterable<TreeFamily>`, not lab dataset.
  - Not ported:
    - `familyLaneOrder` (swimlanes + zoom canvas only);
    - `reveal` param of `paintStoryMarker` (playback, Q3);
    - `LabText.badge` (7.8) and `labDimOpacity`;
    - lab theme chip, input, menu, drawer, slider themes (would change pixels);
    - lab fourth field-border case (theme text field uses border).
  - `albumCardRadius` (12) and `AlbumRadius.card` (12) both exist; merge left to later slice.
  - C10 chooser title stays with 7.4 → `showStoryChooser` no title row yet.
  - `just check` needs `dart pub get` in `apps/server` in fresh worktree; else `server-analyze` reports missing `serverpod_cloud_storage_gcp`.

**7.7 Whole-tree page and treemap** (`feat/p7-7-treemap`, from `feature/serverpod` `fd00bd4`; owner signed off v2 screenshots + approved C19 on 2026-11-08):
- **Commits:**
  - `ae4f404`: §7.7 plan;
  - `6c14334`: treemap layout + view, optional `ViewSwitch.label` (+23 tests);
  - `36758f7`: loader, page, route, header row (+18 tests);
  - `2b84b0e`: two goldens;
  - then this "As landed" commit.
- **Gates:**
  - `just check` passes: fmt `(0 changed)` twice, `analyze: 6 issues (ceiling 6)`, app `+792 ~12` (from `+751 ~12`, +41), `server-analyze` no issues, server `+447` (unchanged);
  - import, layout, colours guards pass; no colour hit in `lib/features/timeline/tree/`, skip list unchanged at 17;
  - `just test-goldens` `+8`: six rail PNGs unchanged, plus `family_tree_treemap_{desktop,ipad_mini_portrait}.png` (both opened + checked);
  - live `+29` vs server from this worktree (7.6S env with ports 8380–8382, DB port 8390, `SERVERPOD_DATABASE_DATA_PATH=.serverpod/p77/pgdata`);
  - e2e 9/9 (`flutter drive … -d web-server --web-port=3700 --driver-port=4544 --dart-define=SERVER_URL=http://127.0.0.1:8380`, chromedriver 157.0.8103.38 fetched by `npx @puppeteer/browsers install chromedriver@157.0.8103.38` into `/tmp`; none on PATH).
- **Screenshots** (`/tmp/tmas-p7-7-shots/`, seeded via API as `p7-shots@example.com`: Jenkins 8 stories 1952–1999, branches Bea (from 1975, 3 stories) + Cal (from 1984, 2 stories)): `01-family-menu-desktop`, `02-treemap-by-family-desktop`, `03-treemap-by-decade-desktop`, `04-treemap-by-person-desktop`, `05-drill-group-1970s-desktop`, `06-drill-stories-jenkins-1950s-desktop`, `07-treemap-by-family-ipad-mini-portrait`, `08-family-menu-ipad-mini-portrait`. Also checked live: story tile opens reader, `Bea · 3` title opens Bea's timeline.
- **Plan fixes:**
  - Also owns `test/support/tree_fixture.dart` (shared Jenkins/Bea/Cal tree for layout, view, page, golden tests).
  - Server refuses publishing story with no person (`person required`), so `No one tagged` in `By person` only shows for stories whose people all lack name; kept since `Story.people` drops unnamed people.
  - Owner feedback (2026-11-08), one commit each: `012bda7` family tints, `albumRuleStrong` group frames, scaled counts (+3 layout tests net, +4 view; both treemap goldens regenerated on purpose + re-inspected); `abe6212` family header drills in, with `Open {Family} timeline` action (C19); `ce98cd3` tree row hidden on new-story + tree pages (+1 test). Page title stays root family. v2 screenshots: `/tmp/tmas-p7-7-shots/v2/`.
  - **Sign-off (owner, 2026-11-08):** v2 screenshots approved; C19 approved; one addition, family colour key: `6de01a9` (+2 view tests: every family with tint in all three groupings, wrapping without overflow at 744 × 1133 and 320 × 568; both treemap goldens regenerated on purpose + re-inspected; screenshot `/tmp/tmas-p7-7-shots/v2/11-colour-key-desktop.png`). Page sweep height floor became half on iPad, third at 320 pt, since key row ~26 pt. Gates after: `just check` passes (fmt 0 changed ×2, analyze 6, app `+802 ~12`, server `+447`), `just test-goldens` `+8` with six rail PNGs unchanged.
  - `just check` in fresh worktree also needs `just server-passwords` (git-ignored `apps/server/config/passwords.yaml`); without it `server-test` stops after unit tests.

**7.3 Rail split at parity** (`feat/p7-3-rail-split`, from `feat/p7-2-tokens` `ac9bee0`):
- **Commits** (Colours moved first, agreed with Main 2026-11-08):
  - `7b7a39c`: Colours. 12 hits in `timeline_page.dart` became `albumRule`, `albumDialogSurface` (×3), `albumInk.withAlpha(0xB3)`, `albumBackdropClear`, `albumParchment.withAlpha(0)` (×2), `albumBlush` (×3, incl. `.withValues(alpha: 0.3)`), `albumBlushPale`, `albumWhite`. Days gradient `const Positioned.fill` lost `const`. Page left skip list, ceiling now 16. Throwaway test checked every token ARGB vs replaced literal before commit; all nine pairs matched.
  - `fcd824f`: Move. Code moved into `rails/{far_rail,mid_rail,full_card_rail,rail_scaffold}.dart`, `zoom_switch.dart` (`_ZoomSwitch` + `DialSubheader`), `origin_banner.dart`. Cross-file classes lost underscore (`FarRail`, `MidRail`, `FullCardRail`, `OriginBanner`, `DialSubheader`, `HangParentParentData`), gained `super.key` (`use_key_in_widget_constructors` requires). Nothing else changed.
  - `3290998`: Scaffold. `RailScaffold<W, K>` = mixin on rail `State`s, keyed by row: decade start year on Decades, story id on Years + Days. Owns viewport key, scroll controller, centre row, opacities, first-frame centring, `followFocus`, arrow-key `step`, `measure`, opacity tolerance check, `buildRail` (zoom switch, arrow keys, empty tap, scroll-driven re-measure). Each rail supplies hooks: `rowKeys`, `rowContext`, `initialCenterKey`, `fallbackCenterKey`, `stepFallbackKey`, `measureWithoutTarget`, `opacityTolerance`, `fadeFor`, `focusIdFor`, `focusedStoryId`, `onCenterStory`. `edgeFade` shared by Decades (`farEdgeOpacity`) + Days (`fullCardOpacity`). `ArrowKeys` + `EmptyTap` private to scaffold again.
- **Line counts:** `timeline_page.dart` 771 (was 3770), `rails/full_card_rail.dart` 1076, `rails/mid_rail.dart` 681, `rails/far_rail.dart` 548, `rails/rail_scaffold.dart` 342, `zoom_switch.dart` 247, `origin_banner.dart` 81.
- **Gates** (after each of three commits): `just check` passes, fmt `(0 changed)` twice, `analyze: 6 issues (ceiling 6)`, app `+741 ~12`, server `+432`. `just test-goldens` `+6` without regenerating. `timeline_page_test.dart` + `timeline_branching_test.dart` unedited; `git diff --stat ac9bee0 -- apps/tell_me_a_story/test` shows only colours guard.
- **Left per rail** (sharing would change behaviour or pixels):
  - Edge gradients: Years two 120-pt bands (stops 0.15/0.45/1), Days one full-height band (0/18/82/100%), Decades none.
  - Spines: Decades 2-pt `albumRule` line, Years `_RailGutter`, Days keyed, width-aware `timeline-spine`. 7.4 unifies.
  - Years centre measuring uses `localToGlobal(Offset(0, h/2))`, not top + h/2 → Years keeps own `fadeFor`.
  - Days doesn't re-centre on focus change; only updates centre row → keeps own `didUpdateWidget`, no `followFocus`.
  - Unmeasured-row opacity: Decades falls back to 1; Years passes 0.35 to `opacityOf`, Days 0.4.
  - Opacity tolerance: 0.01 Decades, 0.02 Years + Days.
  - Years + Days repeat same eight short story-id hooks; widgets share no type.
- **Fresh worktree:** `just server-test` also needs `apps/server/config/passwords.yaml` (gitignored) copied from main checkout; without it integration suites stop silently after `+47`.

**7.4 Rail restyle and iPad** (`feat/p7-4-restyle`, from `feat/p7-3-rail-split` `26230d4`):
- **Commits:** `8d94a0a` plan; `a0058d6` C10 chooser title; `fe469ba` markers, corners, one spine (`rails/rail_spine.dart`, shared `test/support/timeline_fixture.dart`); `c025012` finger hit radius + stacked-year chooser (`fingerDevices`/`preciseDevices` in `pointer_input.dart`); `31525f1` insets, narrow decade rows, iPad sweep (`test/support/ipad.dart`); `a79ed93` spine fills viewport + goldens; `c9a6814` unused imports.
- **Gates:** `just check` passes: fmt `(0 changed)` ×2, `analyze: 6 issues (ceiling 6)`, app `+815 ~12` (from `+741`), server `+447`; colours guard ceiling 16, no skip path added. `just test-goldens` `+8`.
- **Goldens:** all six regenerated (`{decades,years,days}_{desktop,ipad_mini_portrait}`), plus new `decades_ipad_mini_landscape` + `days_ipad_mini_landscape`. Golden test now reads shared fixture (same data).
- **Changed `timeline_page_test` assertions:** `_mossRingOn` (also accepts `StoryDot` with `origin`); `_expectMossCard` (both branches read `RoundedSuperellipseBorder`/`ShapeDecoration` radius `AlbumRadius.card`); "a decade branch dot stays on the line and comes last" (branch `StoryDot` not `selected`, no shadow, instead of `Container` `BoxDecoration.boxShadow == null`); "a focused parent origin card has a moss border and does not scale" (Years reads `ShapeDecoration` side/shadows, Days reads `RoundedSuperellipseBorder.side` + `ShapeDecoration.shadows`).
- **Fixes found:** old Decades spine (and first `RailSpine`) had zero height → Decades never showed line; narrow Days drew spine at x = 14, off dots (now x = 22 for spine, plain + branch dots; branch card stays under label). Decades at Split View/Slide Over overflowed (count row + branch callout); count ellipsizes, branch label shortens to dots column.
- **Plan fix:** stacked-year chooser lives on Decades (finger covers neighbouring dots 20 pt apart); Years rows too far apart for finger to cover two.
- **Dots:** mid 12/14 and full 12/14 pt (were 16/22 and 14/20); far unchanged 12/14.
- **Chip-label fade:** not reproduced on web (DPR 1.25) in `drafts_page`, `start_timeline_dialog`, `invite_modal`, `search_page` (incl. selected chip), `new_story_page`; nothing changed.
- **Not folded:** 7.3 review's `scrollDialStep`/`HangParentParentData` moves (lines untouched); far rail now uses `opacityOf(…, unmeasured: 1)`, matching scaffold comment.
- **Owner sign-off (2026-11-08):** approved, one change: keep zoom-out. On Decades finger tap in dots area reaching no dot (> 22 pt from every dot) = empty tap, calls rail `onEmpty` (`_zoomOut`), as other empty taps; only taps within finger radius of dot open story or chooser. Fixed test-first in `rail_touch_test.dart` ("a finger far from every dot zooms out", "a finger near stacked dots opens the chooser, not zoom-out"); app `+817 ~12`, goldens unchanged.

**7.5 Timeline filters, dim only** (`feat/p7-5-filters`, from `feat/p7-4-restyle` `7b19f98`):
- **Commits:** `ff66802` plan; `cb0aeb4` `matchesSearch`/`nameMatches` move to `lib/ui/story/story_search.dart` (All Stories imports there, no re-export; `all_stories_logic_test` U-14 runs vs new import); `d148a70` `TimelineFilter` (+9 tests, lab `filter_test` minus hide, families); `95dc93b` dim on rails, `FilterPanel`, sidebar + drawer, iPad sweep (+15 page tests, +44 iPad cases); `50a42fb` goldens. Tasks 3 + 4 landed in one commit: dim tests drive filter via panel.
- **Gates:** `just check` passes: fmt `(0 changed)` ×2, `analyze: 6 issues (ceiling 6)` (all six pre-existing), app `+885 ~12` (from `+817`, +68), server `+447`; colours guard unchanged (no skip path, ceiling 16). `just test-goldens` `+10`.
- **Copy:** C11–C18 verbatim: `Filters` (button + panel title), `People`, `Places`, `Years`, `Search titles, stories and people`, `{matched} of {total} stories match` (only while filter active), `No stories match these filters.` with `Clear filters` (also panel clear action), `{matched} of {total}` on each Decades row while filtering. Decade range shows bounds as data (`1950s – 1990s`), no words.
- **Behaviour:**
  - `TimelineFilter {personIds, placeIds, fromDecade, toDecade, query}`; OR within, AND across; text via `matchesSearch` (never place). Chips from loaded stories (`Story.people`; `placeId` with `placeLabel`, else address). Decade range = `RangeSlider` over loaded decades; thumb at either end = open bound.
  - Dim, never hide: every rail keeps rows + dots; unmatched marker hollow (`MarkerSpec.matched: false`), texts `albumDimInk` (Years: date chip, place, photos, origin tag, title; Days: date, chips, origin tag, title, footer). Dimmed focused row keeps ring + border, not terracotta inks. Decades row with no match dims label + count.
  - No match: rail stays mounted; `EmptyTimeline` card (C17, key `timeline-no-match`) whose action clears filter pinned between zoom switch and rows (`buildRail`'s `notice`), covers no row on any zoom. (Before owner sign-off centred over rail, could cover decade.)
  - Placement: `Filters` button beside zoom switch every width. ≥ 900 pt (`AlbumBreakpoint.sidebar`) toggles docked, non-modal 360 pt sidebar left of rail, closed default; `_sidebarOpen` page state, stays open across zooms until button closes. Below 900 pt button opens 360 pt (≤ 90% wide) end drawer. Both only once rail has stories. 360 pt = narrowest width tried showing whole C15 hint (300, 340 ellipsized).
  - Scope: page state → survives zoom changes, opening story, breakpoint; `_selectFamily` resets.
- **Goldens:** new `timeline_filtered_desktop` (sidebar docked from button, Tom filter on Decades) + `timeline_filtered_ipad_mini_portrait` (drawer open). All 8 baselines regenerated on purpose for Filters button: RGB-compared with 7.4 PNGs (`7b19f98`), each differs only in 64 × 14 pt box just left of zoom switch (x 963–1027 desktop, 816–880 landscape, 427–491 portrait; y 109–123); every rail pixel matches 7.4.
- **Changed assertion:** none left. Interim `rail_markers_test` spine change (rail centre after sidebar) reverted to 7.4 window-centre check now sidebar starts closed.
- **Fixture:** `test/support/timeline_fixture.dart` gains optional `people`/`place` on `fixtureStory` (defaults unchanged) and `fixtureVaried` (same six stories with Ada, Tom, Bea, three places).
- **Screenshots** (`/tmp/tmas-p7-5-shots/`; own server :8580 with `.serverpod/p75`, web :3500; seeded via API as `p7-5-shots@example.com`: Jenkins, 9 stories 1952–1999, Ada, Tom, Bea, Clara, 4 places): `01-desktop-sidebar-no-filter`, `02-desktop-person-filter-tom`, `03-desktop-text-query-summer`, `04-desktop-no-match-clear-filters`, `05-decades-filter-ada`, `05b-decades-filter-ada-after-zooms`, `06-years-filter-ada`, `06b-years-filter-ada-centred-on-a-match`, `07-days-filter-ada`, `07b-days-filter-ada-centred-on-a-match`, `08-ipad-mini-portrait-drawer-closed`, `09-ipad-mini-portrait-drawer-open`. Also checked live: filter survives opening story + coming back, and 1280 → 744 resize.
- **Fresh worktree:** `server-test` failed in build hook: `sqlite3` dylib download returned 92-byte error body (hash mismatch); copying verified `libsqlite3.dylib` (sha256 `38c4a60b…`) from another worktree's `.dart_tool/hooks_runner/shared/sqlite3/build/download-38c4a60b/` fixed it.
- **Owner sign-off (2026-11-08):** approved, two changes, each test-first in own commit:
  - `946e624`: sidebar toggles + starts closed. `Filters` button beside zoom switch every width; ≥ 900 pt docks non-modal 360 pt sidebar staying open across zooms until button closes (`_sidebarOpen`, page state); below 900 pt opens end drawer as before. Closed → rail full width, so 5 desktop + landscape baselines back to 7.4 plus button (RGB diff vs `7b19f98` confined to button; see "Goldens"); 3 portrait unchanged from `50a42fb`; `timeline_filtered_desktop` regenerated (sidebar opened from button). Tests: placement test now covers closed at 900 pt (rail 0–900), docking, staying open across Decades → Years → Days, closing; panel tests open sidebar first (`_pumpWithFilters`); iPad sweep opens filters from button every size. `rail_markers_test` back to 7.4 form.
  - `f93b697`: no-match card (C17, same card + copy) pinned at rail top, between zoom switch and rows (`buildRail`'s new `notice` slot, passed by each rail), covers no row. +3 tests (Decades, Years, Days): card under zoom switch, ends above rows list, overlaps no story dot.
  - Gates after both: `just check` passes (fmt `(0 changed)` ×2, `analyze: 6 issues (ceiling 6)`, app `+888 ~12`, server `+447`); `just test-goldens` `+10`; iPad sweep (`timeline_page_ipad_test`) `+90`.
  - v2 screenshots (`/tmp/tmas-p7-5-shots/v2/`, same server, data, ports): `01-desktop-sidebar-closed`, `02-desktop-sidebar-open`, `03-desktop-sidebar-open-person-filter-tom`, `04-desktop-no-match-pinned-decades`, `05-desktop-no-match-pinned-years`, `06-desktop-no-match-pinned-years-sidebar-closed`, `07-ipad-mini-portrait-no-match-pinned`.

**7.M iPad measurement** (owner, 2026-11-08):
- **Result: pass**, owner verdict. Owner ran §7.M on own iPad, reports fine vs approved O4 thresholds.
- **No numbers:** no Timelines exports (`~/p7-ipad/*.json`), no per-screen frame counts, no device, iPadOS or Safari versions on record. Device checklist (Pencil, trackpad cursor, Magic Keyboard, Stage Manager, VoiceOver, home indicator) not reported.
- **Effect on 7.8:** gate open; `+N` collapse for groups over 6 stays, no node cap.

**7.8 Family tree graph** (`feat/p7-8-tree-graph`, from `feature/serverpod` `1954671`; owner signed off 2026-11-08 with one change, see "Owner sign-off"):
- **Commits:**
  - `48d1777`: 7.M passed (owner verdict) + §7.8 TDD plan;
  - `ef179bd`: tree graph layout, Family mode (`tree_graph_layout.dart`; +10 tests, `tree_graph_layout_test`);
  - `1fbbc04`: tree graph view + `Family tree` · `Overview` switch (`tree_graph_view.dart`, `family_tree_page.dart`, `ViewSwitch.leading`, `TreeHeading` + `OpenFamilyTimelineAction` shared from `treemap_view.dart`, `AlbumText.badge`; +9 view tests, +1 view-switch test, +12 page tests);
  - `eb2e2b8`: goldens;
  - `a62fcfc`: whole `+N` pill is target (found on screenshot run: mouse click on pill middle, 9–13 pt from anchor, missed; +1 test);
  - then this "As landed" commit.
- **Gates** (at `a62fcfc`):
  - `just check` passes: fmt `(0 changed)` ×2, `analyze: 6 issues (ceiling 6)`, app `+971 ~12` (from `+939 ~12` at `1954671`, +32), `server-analyze` no issues, server `+447` (unchanged);
  - import, layout, colours guards pass; no colour hit in new files, skip list unchanged at 16, no token added (`AlbumText.badge` = text style);
  - `just test-goldens` `+14`: 10 rail PNGs unchanged (`git status --short test/goldens/timeline` empty); new `family_tree_graph_{desktop,ipad_mini_portrait}.png`; `family_tree_treemap_{desktop,ipad_mini_portrait}.png` regenerated on purpose since C3/C4 switch now leads grouping row. All four opened + checked;
  - live `+29` + e2e 9/9 vs server from this worktree (7.6S env with ports 8880–8882, DB port 8890, `SERVERPOD_DATABASE_DATA_PATH=.serverpod/p78/pgdata`; e2e on `--web-port=3800 --driver-port=4844` with chromedriver 157 from 7.7 at `/tmp/p77-chromedriver/chromedriver/mac_arm-157.0.8103.38/chromedriver-mac-arm64/chromedriver`). Both stopped after, data dir removed.
- **Behaviour:**
  - Page opens on `Family tree` (C3); `Overview` (C4) shows 7.7 treemap unchanged. Switch (`family-tree-view`) same place in both views: own row in graph, leading grouping switch row in treemap (`ViewSwitch.leading`). View = page state, live reload keeps it; switching views rebuilds graph → `+N` expansions + family selection reset.
  - Graph: family → decade → story; branches hang off origin leaf (moss ring), or off parent family when origin unpublished; family whose parent not in tree = root (several roots hang from hub labelled C2). Decades over 6 show 5 + `+N` (latest stories; origins never collapse); `+N` expands, expanded decade's dot collapses. Family names on chips in 7.7 treemap tint (`treemapFamilyTints`), `albumRuleStrong` hairline; decade labels knock edges out on parchment; edges `albumRule` curves.
  - Taps: `+N` pill or family name chip under pointer (whole box), else nearest node within 10 pt (mouse, pencil, trackpad) or 22 pt (finger); other labels not targets. Story opens reader (reloads quietly on return, as treemap); family (dot or chip) selected (terracotta ring around chip), heading row shows C19, opens that family's timeline, as treemap drilled family. Cursor hand over target.
  - Semantics: story `{title}, {date}` (button), `+N` C8 `{n} more stories` (button, on pill rect), family `{name (year)}, {n} stories` (one button per family, rect covers dot + chip, selected state), decade + hub `{label}, {n} stories`.
  - Performance sanity: 1 000 synthetic stories over five families build + lay out under 500 ms in layout test, pump first frame under 3 s in debug widget test; 7.M = real gate.
- **Copy:** C3, C4, C8, C19 verbatim; `+N` chip shows only number; branch year as data (`Bea (1975)`). No new string.
- **Plan fixes:**
  - Graph goldens live in 7.7 golden file, renamed `family_tree_golden_test.dart` (one set of fakes for both views), not new file. Treemap cases tap `Overview` first.
  - `test/support/tree_fixture.dart` gained `crowded` (six more Jenkins stories in 1960s, for `+3`) and `synthetic(count)` (1 000-story tree).
  - 7.7 page tests exercising treemap tap `Overview` first; assertions unchanged. 7.7 five-size sweep became 11 `ipadSizes` on iOS with insets, both views.
  - `ViewSwitch` placement on treemap changed two treemap goldens; assignment's "existing 12 unchanged" couldn't hold for them (reported to Main).
- **Screenshots** (`/tmp/tmas-p7-8-shots/`; own server + web-server :3800, seeded via API as `p7-8-shots@example.com`: Jenkins 14 stories 1952–1999, eight in 1960s, branches Bea from 1975 (3 stories) + Cal from 1984 (2 stories)): `01-graph-desktop`, `02-graph-ipad-mini-portrait`, `03-plus-n-collapsed-desktop` (crop), `04-plus-n-expanded-desktop`, `05-family-selected-c19-desktop`, `06-view-switch-overview-desktop`, `07-view-switch-overview-ipad-mini-portrait`, `08-graph-ipad-mini-portrait-panned`. Also checked live: story dot opens reader; Bea's node then `Open Bea timeline` opens Bea's timeline.
- **Owner sign-off (2026-11-08):** approved, incl. regenerated treemap goldens, opening on `Family tree`, reset of `+N` expansions + family selection on view switch. Kept as built: family node selects, C19 navigates (two steps, as treemap). One change, test-first:
  - `acd1721`: family name chip selects family too, as dot does. Whole chip box = target for every pointer (`TreeGraphPainter.familyChipRect`, `targetBox`; box under pointer wins over nearest dot); VoiceOver keeps one node per family, rect = chip + dot. +2 tests (`tree_graph_view_test`): chip's four corners + middle select Bea with mouse + finger, point 4 pt right of chip doesn't; Bea has one semantics node with union rect, tap selects her.
  - Gates after: `just check` passes (fmt `(0 changed)` ×2, `analyze: 6 issues (ceiling 6)`, app `+973 ~12`, server `+447`); `just test-goldens` `+14`, no PNG changed.