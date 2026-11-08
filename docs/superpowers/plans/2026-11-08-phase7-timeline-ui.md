# Phase 7: Timeline UI — Index

> **For agentic workers:** This is the Phase 7 index. Each slice runs on its own branch off `feature/serverpod` (the integration branch) and lands through one PR into it, after the slices it depends on have merged. 7.0 and 7.1 are written in full below (REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development; steps use `- [ ]`). Every later slice row is the scope contract: its executor writes the full TDD plan at slice start (superpowers:writing-plans) as `docs/superpowers/plans/2026-11-08-phase7-<n>-<name>.md`, verifies its code blocks in a scratch copy of the tree, and links it in "Status". **Stops:** 7.4, 7.5, 7.7 and 7.8 merge only after the owner signs off screenshots (and copy, where listed); 7.8 starts only after the iPad measurement (7.M) passes.

**Goal:** Bring the timeline lab's results into the app as the owner decided on 2026-11-08:
- keep the Decades/Years/Days rails, split out of the 3 770-line `timeline_page.dart` and restyled with the lab's visual system;
- dim-only filters on the timeline;
- two whole-tree views (the treemap overview and the Family-mode tree graph), backed by a new server read and tree-wide live updates;
- the lab itself in the repo as `labs/timeline_lab`;
- macOS-local goldens.

**Architecture:**
- **Shared timeline primitives** (`TimeScale`, markers, canvas labels, hit radius, chooser, empty state, view switch) go to `lib/ui/timeline/`. The rails (`features/timeline`) and the tree views both use them, and `features/` of the same rank can't import each other (`featureRank`, `test/architecture/import_boundaries_test.dart:9-23`).
- **Tokens** go to `lib/core/theme/album_theme.dart`. The lab's `lab_theme.dart` colours are copies of album tokens, so only its tints and scales are new.
- **The whole-tree views** live in `lib/features/timeline/tree/`. That is a folder inside an existing feature, so no new `featureRank` entry is needed (adding one needs the owner).
- **Server:** one new read (`story.listPublishedInTree`, with an index migration) and one new stream (`live.watchTree`). The client refetches on each live event, as today.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13, Serverpod 4.1.1, `flutter_test` goldens, mise, just. No new dependencies.

**Inputs:**
- **Owner decisions (2026-11-08), binding.** They are listed below; this plan cites them as Q1–Q8.
- `docs/archive/migration/timeline-lab-handoff.md`. 7.0 lands it there from the lab branch; until then, read it at `docs/migration/timeline-lab-handoff.md` on `worktree/silver-valley-593f`. It holds the lab's findings and its port list. Its `apps/timeline_lab/…` paths become `labs/timeline_lab/…`.
- The lab's README (renderer table, observations, the iPad section) and its plans `2026-11-07-timeline-lab-{ui-design-review,ipad-review}.md` (moved to `docs/archive/superpowers/plans/` by 7.0).
- `docs/archive/ux/uxd-handoff.md:106, :170-195` and `docs/archive/ux/branch-callout.md` (rev 1.5, LOCKED). The rails' zoom ladder and branch callouts stay as specified; 7.4 changes how they look, not how they behave.
- `AGENTS.md` (gates, the colours guard, import rules, the copy and token approval rules).

| # | Owner decision (2026-11-08) | Where it lands |
|---|---|---|
| Q1 | Keep the Decades/Years/Days rails and restyle them (option 1). No sliver rebuild. | 7.3, 7.4 |
| Q2 | Ship two whole-tree views: the **family tree graph** (Family mode) and the **treemap** overview. This needs G1 `story.listPublishedInTree` plus an index migration, and G2 tree-wide live updates. The entry point is open (owner question O1). Every new string is pending approval. | 7.6S, 7.7, 7.8 |
| Q3 | No playback. | Not ported; `lib/playback/` and every playback hook stay in the lab. |
| Q4 | Filters on the timeline, **dim only** (no hide), reusing the All Stories `matchesSearch` and dim-ink rules. | 7.5 |
| Q5 | Accept the lab's visual system: continuous corners, the marker system and the terracotta selected toggle. Screenshots for owner sign-off before merge. | 7.2, 7.4 |
| Q6 | The owner runs the iPad measurement (lab iPad Task 22) on their own iPad. The tree graph slice is gated on the result. | 7.M gates 7.8 |
| Q7 | The lab comes in as `labs/timeline_lab`, with an analyze-only CI job. Rebase or cherry-pick only the lab commits; never merge the branch. The justfile gets `lab`/`lab-test`. | 7.0 |
| Q8 | macOS-local goldens tagged `golden`, excluded in CI (`--exclude-tags golden`), run with `just test-goldens`, with a scoped `flutter_test_config.dart` for fonts. | 7.1 |

**Baseline at `feature/serverpod` `315852d`** (Phase 6 exit):
- app `+689 ~12` (measured for this plan);
- server `+425`, live `+27`, e2e 9/9 (Phase 6 "As landed");
- analyze 6 (ceiling 6);
- colour skip list 17 entries (ceiling 17).

**Verification status of this plan (written 2026-11-08):**
- **Verified in a scratch copy of the tree at `315852d`:**
  - 7.1 in full: the layout-guard change (red, then green, including the untagged-golden case), the font config, six goldens generated and inspected, `just test` `+689 ~12` with goldens excluded and no tag warning, `just test-goldens` `+6`, `fmt-check` clean, analyze 6;
  - the 7.0 conflict set, simulated with `git merge-tree` (no worktree change).
- **Unverified:**
  - the 7.0 cherry-pick as a whole, and `just lab-test` after the move;
  - every later slice (each is verified by its own slice plan);
  - CI;
  - the iPad numbers (7.M).

---

## Status

| Slice | Plan | Depends on | Status |
|---|---|---|---|
| 7.0 Lab import | this index, §7.0 | — | not started |
| 7.1 Golden harness and rail baselines | this index, §7.1 | — | not started |
| 7.2 Tokens and shared primitives | written at slice start | — (O3 for the two exact-value colour token names) | not started |
| 7.3 Rail split at parity | written at slice start | 7.1, 7.2 | not started |
| 7.4 Rail restyle and iPad | written at slice start | 7.3; owner screenshot sign-off before merge | not started |
| 7.5 Timeline filters (dim only) | written at slice start | 7.4; copy approval (O2) and screenshots before merge | not started |
| 7.6S Server: tree reads (G1, G2) | written at slice start | — | not started |
| 7.M iPad measurement (owner) | this index, §7.M | 7.0 (or the lab branch as it is) | not started |
| 7.7 Whole-tree page and treemap | written at slice start | 7.2, 7.6S; entry point (O1) and copy (O2) answered; screenshots before merge | not started |
| 7.8 Family tree graph | written at slice start | 7.7, **7.M pass** (O4 thresholds); screenshots before merge | not started |
| 7.z Close | this index, §7.z | all | not started |

```
7.0 ──────────────────► 7.M ───────────┐
7.1 ──┐                                │
7.2 ──┼─► 7.3 ─► 7.4 ─► 7.5            │
      └──────┐                         ▼
7.6S ───────┴─► 7.7 ────────────────► 7.8 ─► 7.z
```

7.0, 7.1, 7.2 and 7.6S can start at once. 7.0 and 7.1 both edit `justfile` and `AGENTS.md`: whichever merges second rebases and keeps both sides. 7.7 runs alongside 7.3–7.5. Their only shared files are `test/features/timeline/timeline_page_test.dart` and `test/features/stories/story_reader_page_test.dart` (7.7 adds `watchTree` to the `implements TimelineLive` fakes); keep both sides there.

---

## Conventions

**Working directory.** Commands run in `apps/tell_me_a_story` unless they start with `just` (repo root) or say otherwise. Run tools as `mise exec -- …`.

**Branches.** Each slice uses `feat/p7-<n>-<name>` (for example `feat/p7-1-goldens`), branched from `feature/serverpod` after its dependencies have merged. It lands as one PR into `feature/serverpod` with a merge commit (no squash: 7.0 keeps the lab history). No push to or merge into `main`.

**Gates** (every slice, before each commit and in the PR body):

```bash
mise exec -- just check                         # fmt-check, analyze ≤ 6, test, server-analyze, server-test
mise exec -- just test 2>&1 | tail -n 1         # app count: never fewer than the previous slice
mise exec -- just test-goldens 2>&1 | tail -n 1 # from 7.1 on (macOS)
```

Expected: `(0 changed)` twice, `analyze: 6 issues (ceiling 6)` (lower the ceiling if a slice fixes issues; never raise it), app `+689 ~12` or more, server `+425` or more.
- **Slices that change a gateway or the server** (7.6S, 7.7) also run `just server`, then `mise exec -- just test-live`.
- **Slices that change the header or router** (7.7) and 7.z also run the e2e per README (9/9).

**Colours guard.**
- Every new or split-out file under `lib/` is token-clean: no `Color(0x` and no `Colors.` outside `album_theme.dart`.
- `features/timeline/timeline_page.dart` is on the skip list today (`test/architecture/no_hardcoded_colors_test.dart:21`). 7.3 removes its entry once its last hit is gone, and lowers `_skipListCeiling` from 17 to 16 (the guard fails on a listed file with no hits).
- Never add a skip path. A new token needs the owner's approval. Phase 6's standing rule (owner, 2026-11-07) applies: a hit with no exact token gets one named token with today's exact value, so the swap is pixel-identical, and `token.withAlpha(n)` counts as exact when the ARGB is identical.

**Copy.** No new user-facing string ships without the owner's approval. Every string a slice adds is listed in O2 with its id, marked **pending approval**, and used verbatim once approved. A slice plan may add a string only by adding a row to O2 and getting it approved before merge. Lab copy is scratch copy: never copy it into the app unapproved.

**Goldens** (from 7.1).
- They live in `test/goldens/`, each file starts with `@Tags(['golden'])` (the layout guard checks this), and `test/goldens/flutter_test_config.dart` loads fonts for them alone.
- Generate them on macOS only, with `just test-goldens --update-goldens`. Open every changed PNG with the read tool before committing.
- A slice that should not change pixels (7.3) never regenerates. A slice that changes pixels on purpose (7.4 and later) regenerates and lists every changed PNG in the PR body.
- CI never runs them: `just test` passes `--exclude-tags golden`.

**Screenshot sign-off** (7.4, 7.5, 7.7, 7.8; Q5).
1. Shell 1: `mise exec -- just server`. Shell 2: `mise exec -- just run`.
2. In Chrome at `http://127.0.0.1:3000`, use the DevTools device toolbar at two sizes: 1280 × 800, and 744 × 1133 (iPad mini portrait). Sign in as `p7-shots@example.com` with code `111111`.
3. On the first run, create a root family `Jenkins` with 6 published stories across 1950–1999, then a branch `Bea` from its 1975 story with 2 stories of its own. Reuse that data for every check.
4. Capture the screens the slice lists, before (from `feature/serverpod`) and after. Store them under `/tmp/p7-shots/<slice>/`. Send them to the owner via Main, together with the golden PNG diffs.
5. Merge only after the owner approves. Record the approval (date and any changes asked for) in the slice plan.

**Fakes.** A slice that changes an interface updates every fake of it in `test/`, following the Phase 4 convention:
- 7.7: `StoriesGateway.listPublishedInTree` goes in the shared `test/support/fakes/fake_stories_gateway.dart`. `TimelineLive.watchTree` gets a no-op default in the abstract class, like `watchStory` (`lib/data/timeline_live.dart:24-36`), and is implemented in each `implements TimelineLive` fake: `test/features/timeline/timeline_page_test.dart` (`_FakeLive`) and `test/features/stories/story_reader_page_test.dart`.

**Out of scope:**
- **Playback (Q3).**
- **The sliver rebuild (Q1).**
- **The zoom canvas, swimlanes and RenderBox renderers.**
- **The tree graph's Time mode** (Q2 names Family mode only).
- **The hide mode** (Q4).
- **Tree-wide server search or facets** (G4; it would reopen "cross-family search out").
- **Paging (G5) and kinships (G6).**
- **New `AppErrorCode`s.** None is needed: G1 and G2 refuse with the existing `forbidden`.
- **Colour fixes in other skip-listed files.** The two new exact-value tokens from 7.2 are also used in, for example, `manage_family_page.dart` and `settings_page.dart`, but those files stay as they are.

---

## 7.0 Lab import (Q7)

**Branch:** `feat/p7-0-lab`. **Files:**
- `labs/timeline_lab/**` (from the lab commits, then moved);
- `justfile`;
- `.github/workflows/ci.yml`;
- `AGENTS.md`;
- `docs/archive/migration/timeline-lab-handoff.md`;
- `docs/archive/superpowers/plans/2026-11-07-timeline-lab-{ui-design-review,ipad-review}.md`.

The app (`apps/**`) is untouched.

The lab work is the 52 linear commits `bdd128d^..6302bfe` on `worktree/silver-valley-593f` (no merges; the objects are in this repository). The branch's first two commits (`2c3aca2`, `d9729f7`) are already in our history, and the branch is 140+ commits behind. Merging it would revert the Phase 3–6 docs, so cherry-pick only the lab range.

- [ ] **Step 1: Preconditions.** `git status --short` prints nothing. `git rev-parse --abbrev-ref HEAD` prints `feat/p7-0-lab`. `git cat-file -t 6302bfe` prints `commit`. `git rev-list --count bdd128d^..6302bfe` prints `52`.

- [ ] **Step 2: Cherry-pick the lab range.**

```bash
git cherry-pick -x bdd128d^..6302bfe
```

Expected: two stops, both predicted with `git merge-tree`. Any other conflict: `git cherry-pick --abort` and report.

1. **At `bdd128d` (`justfile`).** The lab's context lines (`db-test`, `functions-serve`) no longer exist. Keep our `justfile` and add the lab's two recipes directly after `test-live`, as the lab wrote them:

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
   - The roadmap is a modify/delete conflict, because the roadmap was archived. Drop the lab's line: `git rm docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md`.
   - The handoff is a file-location conflict, because `docs/migration/` was renamed. Accept git's suggestion: `git add docs/archive/migration/timeline-lab-handoff.md`, and make sure no `docs/migration/` directory is left (`git status --short docs`).
   - Then `git cherry-pick --continue`.

Check: `git diff feature/serverpod --stat -- apps docs/archive/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` lists only `apps/timeline_lab/**`.

- [ ] **Step 3: Move the lab to `labs/` and finish the wiring** (one commit).

```bash
mkdir -p labs
git mv apps/timeline_lab labs/timeline_lab
git mv docs/superpowers/plans/2026-11-07-timeline-lab-ui-design-review.md docs/superpowers/plans/2026-11-07-timeline-lab-ipad-review.md docs/archive/superpowers/plans/
git grep -l "apps/timeline_lab" -- labs/timeline_lab
```

- In each file the grep lists (the lab README; nothing in `lib/` or `test/`), replace `apps/timeline_lab` with `labs/timeline_lab`.
- Leave the archived handoff and lab plans unchanged: they are history.
- In `justfile`, change both recipes to `cd labs/timeline_lab && …`.
- In `.github/workflows/ci.yml`, append the analyze-only job from the Phase 5 plan (`docs/archive/superpowers/plans/2026-11-08-serverpod-phase5-cleanup.md`, Task 4 Step 2):

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

      - name: flutter pub get
        run: flutter pub get --enforce-lockfile

      - name: flutter analyze
        run: flutter analyze
```

- In `AGENTS.md` "Layout", add after the `packages/…` bullet:

```markdown
- `labs/timeline_lab/`: the timeline lab, a dev-only Flutter bench (synthetic data, macOS goldens). Nothing in `apps/` imports it. `just lab`, `just lab-test`; CI runs `flutter analyze` on it only.
```

Commit: `chore(lab): timeline lab moves to labs/timeline_lab; lab recipes and analyze-only CI job`.

- [ ] **Step 4: Gates.**
  - `mise exec -- just lab-test 2>&1 | tail -n 1` → `+272: All tests passed!` on macOS. The 36 goldens are macOS arm64. A golden that differs only in glyph antialiasing on another Mac: report it; don't regenerate.
  - `(cd labs/timeline_lab && mise exec -- flutter analyze)` → `No issues found!`.
  - `actionlint .github/workflows/ci.yml && echo actionlint-ok`.
  - `mise exec -- just check`: app `+689 ~12`, server `+425`, unchanged.
  - `git diff feature/serverpod --stat -- apps` prints nothing.
- [ ] **Step 5: PR** `chore: timeline lab in labs/timeline_lab (Phase 7.0)`, merged with a merge commit. The CI `lab` job must be green.

---

## 7.1 Golden harness and rail baselines (Q8)

**Branch:** `feat/p7-1-goldens`. **Files:**
- Create: `apps/tell_me_a_story/test/goldens/flutter_test_config.dart`, `apps/tell_me_a_story/test/goldens/timeline_rails_golden_test.dart`, `apps/tell_me_a_story/test/goldens/timeline/*.png` (6).
- Modify: `apps/tell_me_a_story/test/architecture/test_layout_test.dart`, `apps/tell_me_a_story/dart_test.yaml`, `justfile`, `AGENTS.md`.

**Why first:** 7.3 splits `timeline_page.dart` and must prove it changed no pixels. These six goldens are taken now, before any timeline code moves.

**Fonts:**
- `google_fonts` asks for families named `<Family>_<variant>` (`Newsreader_500`, `Literata_italic`, `SourceSans3_regular`; `google_fonts_base.dart:112`), and tests can't fetch fonts.
- Registering under the fallback names (`Newsreader`, …) does **not** work in the test engine; the scratch run rendered boxes.
- So the config registers the SDK's Roboto under every variant name of the three families the app uses, which gives real glyphs. The brand faces themselves are checked in the browser screenshots.
- `google_fonts` still prints `unable to load font …` lines during golden runs. That is expected: it looks for asset files, but the families are already registered.

### Task 1: The layout guard accepts tagged goldens

- [ ] **Step 1: Write the golden test** `test/goldens/timeline_rails_golden_test.dart`:

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

- [ ] **Step 2: See the guard fail.** Run `mise exec -- flutter test test/architecture/test_layout_test.dart`. Expected failure: `goldens/timeline_rails_golden_test.dart: lib/goldens does not exist`.

- [ ] **Step 3: Teach the guard about `test/goldens/`.** In `test/architecture/test_layout_test.dart`, replace the header comment and `_ownFolders` (lines 5–11) with:

```dart
// Unit and widget tests mirror lib/'s folders: every test file outside live/
// (tag live), goldens/ (tag golden, macOS only), architecture/ (guards) and
// support/ (shared fakes) ends in _test.dart, sits in a folder that also
// exists under lib/, and is not named for a milestone (m<N>_...). File names
// are not matched to lib/ files. Run from apps/tell_me_a_story.

const _ownFolders = {'architecture', 'goldens', 'live', 'support'};
```

and insert directly after `final parts = path.split('/');` (line 25):

```dart
      if (parts.first == 'goldens' &&
          path.endsWith('_test.dart') &&
          !entity.readAsStringSync().startsWith("@Tags(['golden'])")) {
        problems.add("$path: a golden test starts with @Tags(['golden'])");
      }
```

- [ ] **Step 4: Green, and check the tag rule.** Re-run the guard: it passes. Then:
  1. `printf "void main() {}\n" > test/goldens/untagged_test.dart`, and re-run. Expected failure: `goldens/untagged_test.dart: a golden test starts with @Tags(['golden'])`.
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

If a later slice adds a `GoogleFonts.<family>(` call for a new family, add that family's google_fonts name to `_googleFamilies`.

- [ ] **Step 2: Declare the tag.** Append to `apps/tell_me_a_story/dart_test.yaml`, under `tags:`, after the `live` entry:

```yaml
  golden:
```

- [ ] **Step 3: Recipes.** In `justfile`, replace the `test` recipe and add `test-goldens` after `test-live`:

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

CI's `app` job runs `just test`, so it now excludes goldens with no change to `ci.yml`.

- [ ] **Step 4: See them fail.** Run `mise exec -- just test-goldens 2>&1 | tail -n 3`. Expected: `-6`, and each failure says `Could not be compared against non-existent file: "timeline/<zoom>_<size>.png"`.

- [ ] **Step 5: Generate and inspect.**
  1. Run `mise exec -- just test-goldens --update-goldens`.
  2. Open all six PNGs in `test/goldens/timeline/` with the read tool. Expected: real glyphs, not boxes. The header shows `Tell Me a Story`, `Jenkins`, `Stories / Timeline / Draft Stories`. The zoom pill has the selected segment in terracotta.
  3. In `decades_desktop`, the 1970s row holds `2 stories preserved` and the moss `Bea Branch` callout. `years_*` shows the hanging Bea callout on the 1975 node, and `days_*` shows full cards.
  4. At 744 pt the header shows `Tell …` and hides the family name. That is today's behaviour; record it, don't fix it here.
- [ ] **Step 6: Green.** `mise exec -- just test-goldens 2>&1 | tail -n 1` → `+6: All tests passed!`.
- [ ] **Step 7: The rest is unchanged.**
  - `mise exec -- just test 2>&1 | tail -n 1` → `+689 ~12: All tests passed!`. Goldens are excluded, and there is no "undeclared tag" warning.
  - `mise exec -- just fmt-check` shows `(0 changed)` twice.
  - `mise exec -- just analyze` shows `analyze: 6 issues (ceiling 6)`.

### Task 3: Document and commit

- [ ] **Step 1: `AGENTS.md`.**
  - In "Layout", in the `test/` bullet, after `` `test/live` (tag `live`); `` insert `` `test/goldens` (tag `golden`, macOS only, own `flutter_test_config.dart`); ``.
  - In the gates table, after the "Live client tests" row, add: `| Goldens (macOS) | \`just test-goldens\` | all passing; regenerate only on purpose (\`just test-goldens --update-goldens\`) and open every changed PNG |`.
- [ ] **Step 2: Commit** `test(client): golden harness (tag golden, macOS only) and timeline rail baselines`. The body lists the six PNGs.
- [ ] **Step 3: PR** `test: golden harness and timeline rail baselines (Phase 7.1)`. Paste the gates and `just test-goldens` output.

---

## 7.2 Tokens and shared primitives (Q5)

**Owns:**
- `lib/core/theme/album_theme.dart`;
- new `lib/ui/timeline/`: `time_scale.dart`, `time_axis_painter.dart`, `canvas_label.dart`, `story_marker.dart`, `pointer_input.dart`, `story_chooser.dart`, `empty_timeline.dart`, `view_switch.dart`;
- tests `test/core/theme/album_theme_test.dart` and `test/ui/timeline/*_test.dart`;
- `test/support/contrast.dart` (from the lab).

**Change:**
- **Tokens** (port `labs/timeline_lab/lib/theme/lab_theme.dart`; names pending O3):
  - scales `AlbumSpace` (4/8/12/16/24), `AlbumRadius` (tile 4, group 8, card 12, sheet 16, pill 20), `AlbumStroke` (1/1.5/2), `AlbumMarker` (dot 10, small 8, gap 2, ring 2, hollow 1.5), `AlbumTarget` (min 44, finger radius 22), `AlbumBreakpoint` (sidebar 900, compact 600);
  - text roles `AlbumText.axis/count/lane/group`; `badge` waits for 7.8;
  - tints `albumRule` (`albumInk` at 0x33), `albumRuleStrong` (0x99), `albumWatermark` (0x1F), `albumSageTint` (`albumSage` at 0x59), `albumSageLine` (0x73);
  - `albumDimInk = Color(0xFF6A6358)`;
  - `albumContainerShape(radius, {side})` (`RoundedSuperellipseBorder`), `AlbumFieldBorder`, and a `segmentedButtonTheme` in `albumTheme()` (terracotta selected, parchment label, 5.18:1).
- **Exact-value colour tokens for `timeline_page.dart`'s hits without one** (Phase 6 rule; names pending O3): `0xFFF5DED6` (focused-dot halo, focused-card glow, filled chip) and `0xFFF5ECE9` (unfilled chip). Each gets a one-line doc comment naming its users.
- **Primitives** ported from the lab with `LabStory`/`LabFamily` replaced by `Story`/`TreeFamily`:
  - `fractionalYear(DateTime)` lives in `time_scale.dart` (it divides by the year's real day count), not on `Story`;
  - `StoryChooser` lists titles with `story_date.dart`'s label;
  - `ViewSwitch` is a `SegmentedButton` on the new theme;
  - nothing in `lib/` uses the primitives yet.
- No pixel change on any existing screen: `albumTheme()` gains only a theme for widgets the app doesn't use yet (`SegmentedButton`).

**Tests:**
- Port `time_scale_test`, `time_axis_painter_test`, `canvas_label_test`, `story_marker_test`, `pointer_input_test`, `story_chooser_test`, `field_border_test`, and the contrast cases of `lab_theme_test` (with `support/contrast.dart`), each red first.
- Add a test that `allStoriesDimInk().toARGB32() == albumDimInk.toARGB32()`, so 7.5's swap is pixel-identical.
- `just test-goldens` is unchanged (no regeneration).

**Done when:** the gates are green with the new tests, goldens are unchanged, and there are no colour-guard hits in `lib/ui/timeline/`.

## 7.3 Rail split at parity

**Owns:**
- `lib/features/timeline/timeline_page.dart`;
- new `lib/features/timeline/rails/{rail_scaffold,far_rail,mid_rail,full_card_rail}.dart`, `lib/features/timeline/{zoom_switch,origin_banner}.dart`;
- the colour skip list.

`timeline_branching.dart` and `timeline_zoom.dart` change only where an import moves.

**Today** (`timeline_page.dart` at `315852d`):
- page state `:57-775`; `scrollDialStep` `:776`; `_ArrowKeys` `:804`;
- `_FarRail` `:852` with `_EmptyTap`, `_FarDecadeRow`, `_CenterOnDot`, `_OriginDot` and `_FarDot` (to `:1524`);
- `_MidRail` `:1525` with `_DialFade`, `_DialSubheader`, `_DialRow` and `_HangParentCallout` (to `:2497`), with `_ZoomSwitch` `:1787-1978` in the middle;
- `_RailGutter` `:2498`; `_FullCardRail` `:2526` with `_DaysCard*`, `_FullCardRow`, `_FullCardDot`, `_FullCard`, `_FullChip` and `_CardPhotos` (to `:3694`); `_OriginBanner` `:3695`.
- The three rail `State`s repeat the centre/measure/step/opacity code (`:882-1105`, `:1559-1747`, `:2562-2792`).

**Change** (three commits; the gates and `just test-goldens` must pass **without regenerating** after each):
1. **Move.** Move each rail with its private helpers into its own library. Classes used across files lose their underscore; nothing else changes.
2. **Scaffold.** `RailScaffold` (a mixin or helper on the rail `State`s) takes over the shared centre, measure, step, arrow-key, empty-tap and fade code.
3. **Colours.** Replace the 12 hits with exact tokens:

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

   Then delete `'features/timeline/timeline_page.dart'` from `temporaryHardcodedColorSkipPaths` and set `_skipListCeiling = 16`.

**Tests:** `timeline_page_test.dart` and `timeline_branching_test.dart` pass **unedited** (`git diff --stat -- test` shows only the guard file).

**Done when:**
- `timeline_page.dart` holds only the page;
- the colours guard passes with ceiling 16;
- the six goldens match without regeneration;
- app count unchanged, analyze ≤ 6.

## 7.4 Rail restyle and iPad (Q5)

**Owns:**
- `lib/features/timeline/**`;
- `test/features/timeline/**`;
- `test/goldens/timeline_*` and its PNGs;
- `test/support/ipad.dart` (from the lab);
- the chip-label fix in the five chip screens, if it reproduces (below).

**Change:**
- **Markers.**
  - Far, mid and days dots use `StoryDot` / `paintStoryMarker`: filled = match, hollow = dimmed (used from 7.5), terracotta outer ring = focused/selected, moss ring = branch origin.
  - Branch callouts keep `branch-callout.md` geometry and copy.
- **Corners.** Cards and banners use `albumContainerShape(AlbumRadius.card)`; chips and pills stay stadium-shaped.
- **One spine.** One spine look (`paintTimeAxis` or one `RailSpine` widget) replaces the three spines (`:1076-1083`, `_RailGutter`, `:2711-2717`).
- **Touch.**
  - Dots use `hitRadiusFor(pointer kind)`, so a finger gets 22 pt.
  - Where a finger tap covers several stories (a stacked year on Years), `StoryChooser` lists them; its title string goes in O2.
- **Insets.** The bottom footer clears `viewPadding.bottom`, and the soft keyboard doesn't squeeze the rail (`resizeToAvoidBottomInset: false` where it applies).
- **iPad.** An iPad no-overflow sweep for the timeline at the lab's 11 sizes and three zooms (`test/features/timeline/timeline_page_ipad_test.dart` with `test/support/ipad.dart`).
- **Chip label fade (handoff §2.1, unverified in the app).**
  1. Reproduce first on web in `drafts_page`, `start_timeline_dialog`, `invite_modal`, `search_page` and `new_story_page` (screenshots).
  2. Only if it reproduces, add `maxLines: 1, overflow: TextOverflow.ellipsis` to those chip labels.
  3. Otherwise record "not reproduced" and change nothing.

**Tests:**
- Targeted updates in `timeline_page_test` (`_expectMossCard`, `_mossRingOn` and the colour/geometry asserts); each changed assert is named in the PR body.
- New marker-state and chooser widget tests, and the iPad sweep.
- Goldens regenerated on purpose, plus `days`/`decades` at the iPad mini landscape size (1133 × 744).

**Stop:** the screenshot sign-off (Decades, Years, Days, the branch callout and the chooser, at both sizes) before merge.

## 7.5 Timeline filters, dim only (Q4)

**Owns:**
- new `lib/ui/story/story_search.dart` (`matchesSearch`, `nameMatches` and their `_contains`, moved from `features/all_stories/all_stories_logic.dart:324-352`; All Stories imports them from here);
- `features/all_stories/all_stories_card.dart` (`allStoriesDimInk()` returns `albumDimInk`; its callers stay);
- new `lib/features/timeline/filter/{timeline_filter,filter_panel}.dart`;
- the rails, for the dim state.

**Change:**
- **The filter.** `TimelineFilter {personIds, placeIds, fromDecade, toDecade, query}`: OR within a category, AND across categories. The text match is `matchesSearch` (title, body, person names; never the place). People and places chips come from the loaded stories (`personIds`/`personNames`, `placeId`/`placeLabel`). There is no family filter, because a rail is one family.
- **Dim, never hide.**
  - Unmatched rows keep their slot and use `albumDimInk` text with a hollow marker.
  - Counts read "matched of total" (copy in O2).
  - With no matches, the rails stay mounted, with the empty state and a clear action.
- **Placement.** A persistent sidebar at ≥ 900 pt (`AlbumBreakpoint.sidebar`); below that, an end drawer opened from a button beside the zoom switch.
- **Scope of the state.** The filter survives zoom changes and resets on a family switch.

**Tests:**
- Port the `filter_test` cases (without hide or families).
- `all_stories_logic_test` follows the move; its `matchesSearch` cases now run against the new import.
- Widget tests:
  - dim keeps the same row count;
  - unmatched ink is `0xFF6A6358`;
  - the rails stay mounted on no match;
  - sidebar vs drawer at 899/900 pt;
  - the iPad sweep with the filters open.
- Goldens `timeline_filtered_{desktop,ipad_mini_portrait}`.

**Stop:** O2 copy approved, and screenshots signed off.

## 7.6S Server: tree reads (G1, G2)

**Owns:**
- `apps/server/lib/src/endpoints/story_endpoint.dart`, `live_endpoint.dart`, `lib/src/live/live_events.dart`, and the three `postLiveEvent` callers (`story_endpoint.dart:280`, `photo_endpoint.dart:238`, `note_endpoint.dart:167`);
- `lib/src/models/story.spy.yaml`;
- a new migration;
- `test/integration/{story_endpoint,live_endpoint}_test.dart`;
- the regenerated `packages/tell_me_a_story_client` (`just server-generate`). The app compiles unchanged, because the change only adds things.

**G1 `story.listPublishedInTree(UuidValue familyId) → List<StoryDto>`.**
- **Authorization:** the existing `_requireFamilyReader` (`isTreeReadable`: the family is live, and the caller is a live member of some family in its tree), otherwise `forbidden`.
- **Rows:** stories with `treeId = family.treeId`, `status = published`, and `familyId` in the tree's **live** families (D6b; a deleted middle family hides only its own stories, D8). Ordered by `_timelineOrder` (`story_endpoint.dart:504-509`), built with `storyDtos`, as `listForPerson` does at `:399-427`.
- **Index:** add to `story.spy.yaml` `indexes:`:

```yaml
  ### Tree timeline (listPublishedInTree): same column order as
  ### stories_family_order_idx, led by treeId.
  stories_tree_order_idx:
    fields: treeId, status, dateStart, datePrecision, createdAt, id
```

then `mise exec -- just server-generate` and `mise exec -- just server-migration tree-timeline` (a new migration; never edit `20261107133050788-init`).

**G2: `live.watchTree(UuidValue familyId)`, chosen over N `watchFamily` subscriptions.**
- **Branches created later are covered.** `LiveKind` has only `story|photo|note`, so no event announces a new family. With N subscriptions, the client would miss a branch created after it subscribed until the next full reload. One tree channel covers it with no client bookkeeping.
- **One subscription.** That means one authorization check (`isTreeReadable`, the same rule as G1), one retry/backoff loop in `ServerTimelineLive`, and one permanent-refusal path. N subscriptions mean N of each, plus resubscribing whenever the tree's family list changes.
- **Small change.** `treeChannel(treeId) => 'tree:$treeId'`. `postLiveEvent(session, event, {required UuidValue treeId})` also posts to the tree channel. Every caller already holds the `Story`, so it passes `story.treeId`. There is no model change: `LiveEventDto` keeps `familyId`, so the client can tell which family changed.
- **Same trust model as `watchFamily`.** Authorization happens once, at subscribe (`live_endpoint.dart:9-21`). Events are only hints; the refetch through G1 re-checks access. Writes to soft-deleted families are refused (D6b), so no event comes from one.
- **Cost of the alternative.** It needs no server change. But it carries the bookkeeping above, and it still can't see a new branch without a family event, which would be a new `LiveKind` anyway.

**Tests** (each red first; they extend the business-rules cases):
1. A member of root R reads the published stories of R and its live branch B, interleaved in timeline order; their own drafts are absent.
2. A member of B only reads R's stories through `listPublishedInTree(B)`.
3. Given R → M (soft-deleted) → C, a member of R sees R and C, not M (D8).
4. A caller outside the tree gets `forbidden`. An anonymous caller is refused. A soft-deleted `familyId` gets `forbidden`.
5. Another tree's stories are never returned.
6. The migration creates `stories_tree_order_idx` (a `pg_indexes` query, as `constraints_test` does).
7. `watchTree(R)`: a publish in B delivers an event with `familyId = B`.
8. An edit to a draft in B delivers nothing.
9. An event in another tree is not delivered.
10. `watchTree` by a non-member gets `forbidden`; an anonymous caller is refused.
11. `watchFamily` behaviour is unchanged (the existing cases stay green).

**Done when:** `just check` passes with server `+425` plus the new cases, `just server-analyze` is clean, and the generated client is committed.

## 7.M iPad measurement (Q6; owner, on their iPad)

This is not a PR. It measures the lab's whole-tree renderers on real hardware before 7.8 commits to the tree graph, which paints every node.
- **Who:** the owner runs it. An agent prepares the build and records the numbers in this plan's "As landed".
- **When:** any time; it doesn't wait for other slices. It runs on `labs/timeline_lab` after 7.0, or on the lab worktree as it is.

**Setup:**
1. **Mac:** Safari ▸ Settings ▸ Advanced ▸ "Show features for web developers".
2. **iPad:** Settings ▸ Apps ▸ Safari ▸ Advanced ▸ Web Inspector **on**. Connect the iPad to the Mac with a cable and trust the Mac.
3. **Build and serve the release web build** (run in `labs/timeline_lab`):

   ```bash
   mise exec -- flutter build web --release
   python3 -m http.server 8100 --bind 0.0.0.0 --directory build/web
   ipconfig getifaddr en0          # the Mac's LAN address
   ```

4. On the iPad, in Safari, open `http://<mac-lan-ip>:8100`. Close other tabs and apps; keep the iPad plugged in with Low Power Mode off.
5. On the Mac, choose Safari ▸ Develop ▸ *<iPad name>* ▸ the lab page, then open the **Timelines** tab. Enable **Rendering Frames** and **JavaScript & Events**; leave the others off.

**Screens** (landscape full screen, then the tree graph again in portrait). For each, set the bench menu's dataset to **1 000**, then repeat at **5 000**:

| # | Screen in the lab | Action recorded (10 s each) |
|---|---|---|
| S1 | Tree graph, **Family** mode | Continuous one-finger panning down, across and back over the whole tree (the graph scrolls on both axes; it has no pinch). |
| S2 | Treemap, Family grouping (the overview) | Tap into a family, then a decade, then back out; repeat three times. |
| S3 | Sliver list (the control) | Fling scroll top to bottom and back. |
| S4 | Switch from the sliver list to the tree graph | One tap on the renderer switch. Record the longest frame (time to the first full frame). |

**Method:**
1. Press record in Timelines, do the action, then stop.
2. In **Rendering Frames**, read the frame count, the number of frames over **16.7 ms** (the 60 fps line), and the longest frame in ms. Safari on iPad renders at 60 Hz by default.
3. Export each recording (Timelines ▸ Export) to `~/p7-ipad/<screen>-<size>.json`.
4. Record the device model, iPadOS version and Safari version.
5. Note the device checklist from lab Task 22, Step 4, as observations only (they don't gate):
   - Pencil tap;
   - the trackpad hand cursor;
   - Magic Keyboard;
   - Stage Manager 320–1366 pt;
   - VoiceOver on the tree nodes;
   - the home-indicator inset.

**Pass thresholds** (proposed; confirm in O4). The gate is the **1 000-story** run:
- S1 and S2: at least 90% of frames ≤ 16.7 ms, and no frame over 50 ms during the gesture.
- S4: the longest frame is ≤ 500 ms.
- S3 is the reference: if S3 also fails, the build or device setup is suspect; re-check before judging S1/S2.
- The 5 000-story numbers are recorded but don't gate. If they fail, 7.8 keeps the lab's `+N` collapse for groups over 6, and the slice plan adds a node cap.

**Outcome:**
- **Pass:** 7.8 may start.
- **Fail:** stop and report to the owner through Main. The options are: ship the treemap only (7.7) and keep the tree graph in the lab; or rework the graph to cull off-screen nodes and measure again.

## 7.7 Whole-tree page and treemap (Q2)

**Owns:**
- `lib/data/stories_api.dart` (`StoriesGateway.listPublishedInTree`, `StoriesApi` via `_client.story.listPublishedInTree`);
- `lib/data/timeline_live.dart` (`TimelineLive.watchTree` with a no-op default, `ServerTimelineLive` on `live.watchTree` with the same 200 ms debounce and backoff, and `treeEventMatters`, which drops non-published story events and has no family filter);
- `lib/core/router/app_routes.dart` (`familyTree = '/family/:id/tree'`, `familyTreePath(id)`);
- `lib/app/app_router.dart` (the route, beside `allStories` at `:183`);
- `lib/ui/album/album_header.dart` (`AlbumHeaderPage.familyTree` and the entry point per O1);
- new `lib/features/timeline/tree/{family_tree_page,tree_timeline_loader,treemap_layout,treemap_view}.dart`;
- the fakes listed in Conventions.

**Change:**
- **Load.** The page loads `listFamilyTree(familyId)` and `listPublishedInTree(familyId)`, and refetches on `watchTree`.
- **Treemap.** Port `treemap_layout.dart` and `treemap_renderer.dart`:
  - squarified;
  - groupings per O5 (default: Family → decade, plus Decade → year and Person → decade);
  - drill-down;
  - a finger tap on a cell under 44 pt opens its group;
  - quiet by default;
  - no playback and no filter (O6).
- **Taps.**
  - A story tile pushes `AppRoutes.storyPath(id)` (the reader, as `timeline_page.dart:537-543` does).
  - A family cell's title remembers the family (`FamilySelection.remember`) and goes to `AppRoutes.timeline`.
- **The view switch** appears only when 7.8 lands. Until then the page shows the treemap alone.

**Tests:**
- Port `treemap_test` (199 lines; layout and hit tests on `Story`/`TreeFamily`).
- Page widget tests with fakes: load, live refresh, tile → reader route, family → timeline, the empty tree.
- The router test for `/family/:id/tree`, the header entry test, and the iPad sweep.
- Live: `listPublishedInTree` returns a branch's story, and `watchTree` fires on a branch publish (`test/live/stories_live_test.dart`, `server_timeline_live_test.dart`).
- Goldens `family_tree_treemap_{desktop,ipad_mini_portrait}`.

**Stop:** O1 and O2 answered before the slice starts; screenshots signed off before merge. Gates include `test-live` and e2e.

## 7.8 Family tree graph (Q2; gated on 7.M)

**Owns:** new `lib/features/timeline/tree/{tree_graph_layout,tree_graph_view}.dart`, `family_tree_page.dart` (the view switch), tests and goldens.

**Change:**
- **Port Family mode only** from `tree_graph_layout.dart` and `tree_graph_renderer.dart`: family → decade → story, with each branch hanging off its origin story (`TreeFamily.parentFamilyId`, `originStoryId`).
- **Drop** Time mode, playback and the filter flags.
- **Keep:**
  - groups over 6 collapse to `+N`;
  - calm edges;
  - label knockouts;
  - the finger hit radius with nearest-node hit testing;
  - full-height pan;
  - the `semanticsBuilder` nodes.
- **The page's `ViewSwitch`** (terracotta selected toggle): tree graph | treemap, with labels in O2.
- **Taps.** A story node opens the reader; a family node opens its timeline.
- **Performance.** The S1/S4 thresholds from 7.M hold on the real tree sizes the slice tests at (1 000 synthetic stories in a widget benchmark, as a sanity check; the iPad numbers decide).

**Tests:**
- Port `tree_graph_test` (273 lines) for Family mode.
- Widget tests: node tap → route, family tap, `+N`, and semantics labels.
- The iPad sweep.
- Goldens `family_tree_graph_{desktop,ipad_mini_portrait}`.

**Stop:** screenshots signed off before merge.

## 7.z Close

- Gates on `feature/serverpod` after the last merge: `just check`, `just test-live`, `just test-goldens`, the e2e (9/9), and CI green, including the `lab` job.
- Fill "As landed" below: commits per slice, the counts, the iPad table, and the owner's answers to O1–O6.
- `AGENTS.md`: check that the layout, gates and `test/goldens` lines match what landed.
- Move this plan and the slice plans to `docs/archive/superpowers/plans/` (the `docs/superpowers/plans/README.md` rule).
- Ask the owner whether `labs/timeline_lab` stays as the bench or is deleted (O7).

---

## Owner questions

Send these through Main. Each answer is recorded here before the slice that depends on it starts.

**O1. Where the whole-tree views live (blocks 7.7).** Recommended: **(A)** a row in the family menu (`album_header.dart` `_menuItems`, `:693-764`), between the family list divider and "Invite…". It opens `/family/:id/tree` for the current family; the header handles the navigation itself, as its "Stories" item does (`:171-177`).
- It fits the menu's existing family-level actions (invite, add a branch, manage).
- It needs no change to the locked zoom ladder.
- It leaves the header's width budget alone: at 744 pt the header already hides the family name (7.1 golden).

Alternatives:
- **(B)** A fourth segment in the timeline zoom pill. It mixes "zoom" with "another view" and changes the locked R3/M13 ladder.
- **(C)** A fourth header nav item. That means less room for the family name on iPad.

**O2. Copy (all pending approval).**

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

**O3. Token names (blocks 7.2).**
- Confirm the names in 7.2 for the lab's scales and tints. The values are the lab's, accepted under Q5.
- Name the two exact-value tokens. Proposed: `albumBlush` = `0xFFF5DED6`, `albumBlushPale` = `0xFFF5ECE9`.

**O4. iPad thresholds (blocks the 7.M verdict).** Confirm the following, or give other numbers:
- the gate is the 1 000-story run;
- S1/S2: at least 90% of frames ≤ 16.7 ms and none over 50 ms during the gesture;
- S4: the first full frame is ≤ 500 ms;
- 5 000 stories is recorded only.

**O5. Treemap groupings (7.7).** All three of the lab's (family, decade, person), or by family only? Recommended: all three, since they need no extra data.

**O6. Filters on the whole-tree views?** Q4 covers the timeline. Recommended: no for now; the tree views show every story undimmed.

**O7. After Phase 7 (7.z):** keep `labs/timeline_lab` as the bench, or delete it?

---

## Exit criteria for Phase 7

- The rails look as the owner signed off (Q5), split out of `timeline_page.dart`. `timeline_page.dart` is off the colour skip list (ceiling 16).
- The timeline has dim-only filters (Q4) with approved copy.
- The family tree graph (7.M pass) and the treemap read the whole tree through `story.listPublishedInTree` and update through `live.watchTree`. They are reached from the approved entry point.
- `labs/timeline_lab` is in the repo with `just lab`/`just lab-test` and an analyze-only CI job.
- Goldens run with `just test-goldens`, and CI excludes them.
- `just check`, `just test-live`, `just test-goldens`, the e2e (9/9) and CI are green. The app count is at least `+689 ~12` plus the new tests; the server count is `+425` plus the 7.6S cases; analyze ≤ 6.

## As landed

(Filled in by 7.z.)
