# Phase 6: Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run tasks in order on `feat/p6-restructure`, branched from `feature/serverpod` (integration branch) after Phase 5 (`2026-11-08-serverpod-phase5-cleanup.md`) merged into it; open one PR into `feature/serverpod`. Each task = one commit (Tasks 17, 18 = several), must leave every gate green. **Task 9 is a stop:** owner answers token questions before Tasks 10–15 run.

**Goal:** Restructure Flutter app, no behaviour change:
- `lib/` gets `app/` composition root + shared `ui/` layer, import rules enforced by test;
- `test/` mirrors `lib/`, no milestone names, shared gateway fakes;
- moved files lose hard-coded colours first;
- `MagicLinkPage` / `AppRoutes.magicLink` → `SignInPage` / `AppRoutes.signIn` (URL stays `/`).

**Architecture:** Feature folders stay for screens; flat `lib/data/` gateway layer stays. Two layers added: `lib/ui/` (widgets shared by several features), `lib/app/` (GoRouter config + app widget). Every move = `git mv` + rewrite of one `package:tell_me_a_story/…` URI (Task 1 enables). `test/architecture/import_boundaries_test.dart` holds import rules. Starts with exact list of today's 58 violations, only shrinks, ends at none. Every step run in scratch copy of tree (Phase 5 state): each compiled, kept `flutter analyze` at 6 issues, all tests passing. Exception: colour fixes in Tasks 10–14, which wait on owner decisions.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13, `flutter_test`, mise, just. No new deps.

**Inputs:**
- Structure proposal + its Decisions section (2026-11-08):
  - fix colours before skip-listed file moves (one file per commit, screenshot check; stop and ask where no token matches);
  - rename MagicLink → SignIn, URL unchanged;
  - shared test fakes in scope;
  - lab apps live in `labs/`, outside this plan.
- `AGENTS.md` and `justfile` gates as Phase 5 left them.

**Verification status of this plan (written 2026-11-08):**
- **Verified in scratch copy** (each step compiled, analyze stayed 6, all tests passed, counts as stated):
  - Task 1 (incl. `main.dart` conditional import);
  - Tasks 2–6 and 8 (allowlist sizes 58 → 31 → 19 → 13 → 13);
  - Task 7's code edit;
  - Task 15's moves (done with skip paths renamed, since colour fixes not done);
  - Task 16;
  - Task 17 (all moves, m13 split, layout guard);
  - Task 18 Step 1 (fakes analyze clean) + `drafts_page_test` migration example.
- **Unverified:**
  - every screenshot check;
  - Tasks 10–14 (blocked on Task 9);
  - Task 18 Step 2 for every file except `drafts_page_test`;
  - Task 19;
  - `just test-live`, e2e, CI runs at any step;
  - `+N` offsets if Phase 5 exit count differs from 686.

---

## Target layout

```
apps/tell_me_a_story/lib/
├── main.dart
├── app/          app.dart, app_router.dart, url_strategy_{stub,web}.dart     may import anything
├── core/         config/env.dart, router/app_routes.dart, server/{app_session,server_client}.dart,
│                 theme/album_theme.dart                                       imports core only
├── data/         gateways + session state (+ auth_refresh.dart, otp_sign_in.dart), server/  imports core, data
├── ui/           album/{album_chrome,album_header,album_modal_frame}.dart
│                 avatar/{profile_avatar,profile_initials}.dart
│                 dialogs/{family_blur_dialog,leave_story_dialog}.dart
│                 family/{family_role,family_tree_order}.dart
│                 navigation/{unsaved_guard,before_unload,before_unload_stub,before_unload_web}.dart
│                 story/{story_date,story_date_picker,photo_frame,story_title}.dart   imports core, data, ui
└── features/<f>/ screens                                      imports core, data, ui, lower-rank features
```

Feature ranks (feature imports only lower rank):
- 0: `auth`, `comments`, `invites`, `people`, `perspectives`, `places`;
- 1: `family`;
- 2: `all_stories`, `drafts`, `search`, `settings`, `stories`, `timeline`.

Only `data/**` and `core/server/**` (and `app`) may import `tell_me_a_story_client` or `serverpod*`. `data/**` may not import `material`, `widgets` or `cupertino`.

`test/` mirrors `lib/`. Test for `lib/<dir>/<name>.dart` is `test/<dir>/<name>_test.dart`, or `<name>_<aspect>_test.dart`. Other folders: `test/architecture/` (guards), `test/live/` (unchanged), `test/support/fakes/` (shared fakes).

---

## Conventions

**Working directory.** Commands run in `apps/tell_me_a_story` unless start with `just` (runs from repo root).

**Gates** (every task before commit):

```bash
mise exec -- just fmt-check
mise exec -- just analyze
mise exec -- just test 2>&1 | tail -n 1
```

Expected:
- `(0 changed)` twice;
- `analyze: 6 issues (ceiling 6)`;
- `All tests passed!` with task's stated `+N`.

`N` assumes Phase 5 exit count 686. If differs, offset every `+N` by same amount. Skipped count stays `~12`.

**Moving a lib file.** Define once per shell (in `apps/tell_me_a_story`, after Task 1):

```bash
mvdart() { # usage: mvdart <old path under lib/> <new path under lib/>
  local old="$1" new="$2"
  mkdir -p "lib/$(dirname "$new")"
  git mv "lib/$old" "lib/$new"
  { grep -rlF "package:tell_me_a_story/$old'" lib test integration_test || true; } | while read -r f; do
    OLD="package:tell_me_a_story/$old'" NEW="package:tell_me_a_story/$new'" perl -0pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
  done
}
```

After Task 1, every importer names lib file by same package URI, incl. conditional import in `main.dart`, so replace is exact. Relative imports remain only in `before_unload.dart`'s `export … if (…) …` (files move together) and in `test/` (test-to-test). IDE "move file" does same; fine for human.

**Import allowlist.** `knownViolations` in `test/architecture/import_boundaries_test.dart` lists today's rule breaks as `'from -> to'`, paths relative to `lib/`. Size never grows. Step removes entries it fixes, renames entries of files it moves. May add entry only where plan names it (Task 8, once). Test fails on any unlisted break and any listed entry no longer occurring (`stale known violation: …`). Each task gives expected size.

**Colour fixes** (Tasks 7, 10–14). Each skip-listed file that moves first loses hard-coded colours, own commit:
- Hit replaced only by existing `album_theme.dart` token with identical ARGB.
- Other values wait for owner's answer in Task 9; never add token on own.
- Then delete file's entry from `temporaryHardcodedColorSkipPaths`, lower `_skipListCeiling` by one.

**Screenshot check** (every colour fix):
1. `mkdir -p /tmp/p6-colours/<file-stem>`.
2. Shell 1: `mise exec -- just server`. Shell 2: `mise exec -- just run`.
3. Chrome at `http://127.0.0.1:3000`, DevTools device toolbar Responsive 1280 × 800. Sign in as `p6-colours@example.com`, code `111111`. First run: create family `Colour Check` with one story + one person; reuse for every check.
4. **Before** edit, open each listed screen. DevTools ▸ Command menu ▸ "Capture screenshot", save as `/tmp/p6-colours/<file-stem>/<screen>-before.png`.
5. Edit, press `R` in shell 2 (hot restart), capture same screens same state as `<screen>-after.png`.
6. Per pair: `magick compare -metric AE <screen>-before.png <screen>-after.png <screen>-diff.png; echo`. Expected `0` for identical-value swap. Other number: open diff. Differences allowed only where Task 9 owner-approved colour drawn. Else stop, report.
7. List screens + AE numbers in commit body.

---

### Task 0: Preconditions and baseline

- [ ] **Step 1:** `git status --short` prints nothing, `git rev-parse --abbrev-ref HEAD` prints `feat/p6-restructure`, roadmap's Phase 5 row says **Landed**. `git branch --list 'feat/*'` should show no unmerged client branch. Every `lib/` move conflicts with open work; if one exists, stop and ask whether to wait.
- [ ] **Step 2:** Run gates. Expected: `+686 ~12` (or Phase 5 exit count; record). Also run `mise exec -- just server-test 2>&1 | tail -n 1`, record count; must not change this phase.

---

### Task 1: Package imports everywhere in `lib/`

**Files:**
- Modify: `apps/tell_me_a_story/analysis_options.yaml`
- Modify: ~71 files under `lib/` (import lines only)

- [ ] **Step 1: Turn on the lint.** In `analysis_options.yaml`, under `linter:` → `rules:`, add `    always_use_package_imports: true` as first rule line (above commented `# avoid_print` line).

- [ ] **Step 2: See it fail.** Run `mise exec -- flutter analyze | tail -n 1`. Expected: several hundred issues, mostly `always_use_package_imports`.

- [ ] **Step 3: Apply the fix.**

```bash
mise exec -- dart fix --apply --code=always_use_package_imports
```

Expected: ~`413 fixes made in 71 files.` `dart fix` also adds `flutter_web_plugins: any` to `pubspec.yaml`, breaks `pub get` (SDK package). Revert: `git checkout pubspec.yaml`.

- [ ] **Step 4: Fix the one conditional import by hand.** `dart fix` leaves conditional part of `main.dart` import relative. Make it:

```dart
import 'package:tell_me_a_story/core/router/url_strategy_stub.dart'
    if (dart.library.html) 'package:tell_me_a_story/core/router/url_strategy_web.dart';
```

Leave `lib/core/navigation/before_unload.dart` (`export 'before_unload_stub.dart' if (…) 'before_unload_web.dart';`) as is. Lint skips exports; three files always move together.

- [ ] **Step 5: Format and check.**

```bash
mise exec -- dart format .
git grep -n -E "^(import|export) '\.\.?/" -- lib
git grep -n -E "^import '[a-z_]+\.dart'" -- lib
```

Expected: `dart format` changes ~4 files; both greps print nothing.

- [ ] **Step 6: Gates.** Expected `+686 ~12`, analyze 6.

- [ ] **Step 7: Commit.** `git commit -am "refactor(client): package imports in lib (always_use_package_imports)"`

---

### Task 2: Architecture guards

**Files:**
- Move: `test/theme/no_hardcoded_colors_test.dart` → `test/architecture/no_hardcoded_colors_test.dart`
- Create: `test/architecture/import_boundaries_test.dart`
- Modify: `AGENTS.md` (colours guard path)

- [ ] **Step 1: Move the colours guard.** `git mv test/theme/no_hardcoded_colors_test.dart test/architecture/no_hardcoded_colors_test.dart && rmdir test/theme`. Test reads `lib/` from working dir; location irrelevant.

- [ ] **Step 2: Add the ceiling.** In that file, insert above `const _albumThemePath = 'core/theme/album_theme.dart';`:

```dart
/// The skip list only shrinks: lower this when a file leaves the list.
const _skipListCeiling = 23;

```

Then insert as first statements inside `void main() {`:

```dart
  test('the hardcoded-color skip list never grows', () {
    expect(
      temporaryHardcodedColorSkipPaths.length,
      lessThanOrEqualTo(_skipListCeiling),
    );
  });

```

- [ ] **Step 3: Write the boundary test with today's 58 violations.** Create `test/architecture/import_boundaries_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Import rules for lib/. Layers: app (main.dart, app/), core, data, ui and
// features/<name>. See AGENTS.md "Layout". Run from apps/tell_me_a_story.
//
// Edges that break a rule today, as 'from -> to' (paths relative to lib/).
// The list only shrinks: a step that fixes an edge removes it, and a step
// that moves a file renames its entries. Never add an edge.
const knownViolations = <String>{
  'core/navigation/leave_story_dialog.dart -> features/family/family_blur_dialog.dart',
  'core/router/app_router.dart -> data/comments_api.dart',
  'core/router/app_router.dart -> data/families_api.dart',
  'core/router/app_router.dart -> data/family_selection.dart',
  'core/router/app_router.dart -> data/invite_api.dart',
  'core/router/app_router.dart -> data/manage_families_api.dart',
  'core/router/app_router.dart -> data/mapbox_search.dart',
  'core/router/app_router.dart -> data/people_api.dart',
  'core/router/app_router.dart -> data/perspectives_api.dart',
  'core/router/app_router.dart -> data/photos_api.dart',
  'core/router/app_router.dart -> data/places_api.dart',
  'core/router/app_router.dart -> data/profile_api.dart',
  'core/router/app_router.dart -> data/search_api.dart',
  'core/router/app_router.dart -> data/stories_api.dart',
  'core/router/app_router.dart -> features/all_stories/all_stories_page.dart',
  'core/router/app_router.dart -> features/auth/invite_sign_in_page.dart',
  'core/router/app_router.dart -> features/auth/magic_link_page.dart',
  'core/router/app_router.dart -> features/drafts/drafts_page.dart',
  'core/router/app_router.dart -> features/family/family_landing_page.dart',
  'core/router/app_router.dart -> features/family/manage_families_page.dart',
  'core/router/app_router.dart -> features/family/manage_family_page.dart',
  'core/router/app_router.dart -> features/perspectives/add_perspective_page.dart',
  'core/router/app_router.dart -> features/search/search_page.dart',
  'core/router/app_router.dart -> features/search/search_recents.dart',
  'core/router/app_router.dart -> features/settings/settings_page.dart',
  'core/router/app_router.dart -> features/stories/new_story_page.dart',
  'core/router/app_router.dart -> features/stories/story_reader_page.dart',
  'core/router/app_router.dart -> features/timeline/timeline_page.dart',
  'core/router/auth_refresh.dart -> data/family_selection.dart',
  'core/router/auth_refresh.dart -> data/profile_session.dart',
  'core/router/auth_refresh.dart -> package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart',
  'core/theme/album_chrome.dart -> features/family/family_blur_dialog.dart',
  'core/theme/album_header.dart -> data/families_api.dart',
  'core/theme/album_header.dart -> data/family_selection.dart',
  'core/theme/album_header.dart -> data/manage_families_api.dart',
  'core/theme/album_header.dart -> data/profile_session.dart',
  'core/theme/album_header.dart -> features/family/family_role.dart',
  'core/theme/album_header.dart -> features/family/family_tree_order.dart',
  'features/all_stories/all_stories_card.dart -> features/stories/story_date.dart',
  'features/auth/invite_sign_in_page.dart -> features/family/family_role.dart',
  'features/auth/otp_sign_in.dart -> package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart',
  'features/auth/otp_sign_in.dart -> package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart',
  'features/auth/otp_sign_in.dart -> package:tell_me_a_story_client/tell_me_a_story_client.dart',
  'features/drafts/drafts_page.dart -> features/stories/story_date.dart',
  'features/family/family_landing_page.dart -> features/stories/story_date.dart',
  'features/family/start_timeline_dialog.dart -> features/timeline/timeline_zoom.dart',
  'features/invites/invite_modal.dart -> features/family/family_blur_dialog.dart',
  'features/people/add_person_modal.dart -> features/family/family_blur_dialog.dart',
  'features/people/edit_person_dialog.dart -> features/family/family_blur_dialog.dart',
  'features/people/person_date_field.dart -> features/stories/story_date.dart',
  'features/people/person_date_field.dart -> features/stories/story_date_picker.dart',
  'features/people/person_profile_dialog.dart -> features/family/family_blur_dialog.dart',
  'features/people/person_profile_dialog.dart -> features/stories/story_date.dart',
  'features/search/search_page.dart -> features/stories/story_date.dart',
  'features/settings/settings_page.dart -> features/stories/story_date.dart',
  'features/timeline/timeline_page.dart -> features/stories/photo_frame.dart',
  'features/timeline/timeline_page.dart -> features/stories/story_date.dart',
  'features/timeline/timeline_zoom.dart -> features/stories/story_date.dart',
};

/// Features may import only features of a lower rank.
const featureRank = <String, int>{
  'auth': 0,
  'comments': 0,
  'invites': 0,
  'people': 0,
  'perspectives': 0,
  'places': 0,
  'family': 1,
  'all_stories': 2,
  'drafts': 2,
  'search': 2,
  'settings': 2,
  'stories': 2,
  'timeline': 2,
};

/// Packages that only core/server/ and data/ may import.
const serverPackages = <String>[
  'package:tell_me_a_story_client/',
  'package:serverpod',
];

/// Flutter UI libraries that data/ may not import.
const uiLibraries = <String>[
  'package:flutter/material.dart',
  'package:flutter/widgets.dart',
  'package:flutter/cupertino.dart',
];

const _appPackage = 'package:tell_me_a_story/';

final _directive = RegExp(
  r"^(?:import|export)\s+'([^']+)'(?:\s+if\s*\([^)]*\)\s*'([^']+)')?",
  multiLine: true,
);

String layerOf(String path) {
  if (path == 'main.dart' || path == 'app.dart' || path.startsWith('app/')) {
    return 'app';
  }
  final parts = path.split('/');
  switch (parts.first) {
    case 'core' || 'data' || 'ui':
      return parts.first;
    case 'features' when parts.length > 2:
      return 'features/${parts[1]}';
  }
  return 'unknown';
}

bool allowed(String from, String to) {
  if (from == to || from == 'app') return true;
  final inShared = to == 'core' || to == 'data' || to == 'ui';
  switch (from) {
    case 'core':
      return to == 'core';
    case 'data':
      return to == 'core' || to == 'data';
    case 'ui':
      return inShared;
  }
  if (inShared) return true;
  if (!to.startsWith('features/')) return false;
  final fromRank = featureRank[from.substring('features/'.length)];
  final toRank = featureRank[to.substring('features/'.length)];
  return fromRank != null && toRank != null && toRank < fromRank;
}

/// Every import/export target of [source], as written.
Iterable<String> targetsOf(String source) sync* {
  for (final match in _directive.allMatches(source)) {
    yield match.group(1)!;
    final conditional = match.group(2);
    if (conditional != null) yield conditional;
  }
}

/// [target] as a path relative to lib/, or null for another package or dart:.
String? libPath(String file, String target) {
  if (target.startsWith(_appPackage)) {
    return target.substring(_appPackage.length);
  }
  if (target.contains(':')) return null;
  return Uri.parse(file).resolve(target).path;
}

void main() {
  test('lib/ imports follow the layer rules', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );

    final found = <String>[];
    final hits = {for (final edge in knownViolations) edge: 0};
    void report(String edge) {
      if (hits.containsKey(edge)) {
        hits[edge] = hits[edge]! + 1;
      } else {
        found.add(edge);
      }
    }

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final file = entity.path.replaceAll('\\', '/').substring('lib/'.length);
      final from = layerOf(file);
      if (from == 'unknown') {
        found.add('$file is outside app/, core/, data/, ui/ and features/');
        continue;
      }
      if (from.startsWith('features/') &&
          !featureRank.containsKey(from.substring('features/'.length))) {
        found.add('$file: add its feature to featureRank');
        continue;
      }
      for (final target in targetsOf(entity.readAsStringSync())) {
        if (serverPackages.any(target.startsWith) &&
            from != 'app' &&
            from != 'data' &&
            !file.startsWith('core/server/')) {
          report('$file -> $target');
          continue;
        }
        if (from == 'data' && uiLibraries.contains(target)) {
          report('$file -> $target');
          continue;
        }
        final path = libPath(file, target);
        if (path == null) continue;
        if (!allowed(from, layerOf(path))) report('$file -> $path');
      }
    }

    final stale = [
      for (final entry in hits.entries)
        if (entry.value == 0) 'stale known violation: ${entry.key}',
    ];
    found.sort();
    final problems = [...stale..sort(), ...found];
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
```

- [ ] **Step 4: Prove the rules bite.** Delete first allowlist entry (`'core/navigation/leave_story_dialog.dart -> features/family/family_blur_dialog.dart',`), run `mise exec -- flutter test test/architecture/import_boundaries_test.dart`. Expected: FAIL, listing exactly that edge. Restore entry. Expected: PASS.

- [ ] **Step 5: AGENTS.md.** Replace `` `test/theme/no_hardcoded_colors_test.dart` `` with `` `test/architecture/no_hardcoded_colors_test.dart` ``. Append to "Code rules" list:

```markdown
- `lib/` imports follow the layer rules in `test/architecture/import_boundaries_test.dart`. Its `knownViolations` list only shrinks during Phase 6; never add an edge.
```

- [ ] **Step 6: Gates.** Expected `+688 ~12` (+2: ceiling and boundary tests).

- [ ] **Step 7: Commit.** `git add -A test/architecture test/theme AGENTS.md && git commit -m "test(client): architecture guards: import rules, colour skip-list ceiling"`

---

### Task 3: `MagicLinkPage` → `SignInPage`, `AppRoutes.magicLink` → `AppRoutes.signIn`

**Files:**
- Modify: `lib/features/auth/magic_link_page.dart` (class names only; file keeps name until Task 15, on colour skip list)
- Modify: `lib/core/router/app_router.dart`
- Modify: `test/router_test.dart`, `test/m13_fit_finish_test.dart`

URL `/` and widget keys (`Key('magic-link-email')`, used by `integration_test/e2e_test.dart` and tests) unchanged.

- [ ] **Step 1: Rename the identifiers.**

```bash
git grep -l -E "MagicLinkPage|AppRoutes\.magicLink|onMagicLink|static const magicLink" -- lib test integration_test \
  | xargs perl -pi -e 's/\b_MagicLinkPageState\b/_SignInPageState/g; s/\bMagicLinkPage\b/SignInPage/g; s/\bAppRoutes\.magicLink\b/AppRoutes.signIn/g; s/\bonMagicLink\b/onSignIn/g; s/static const magicLink = /static const signIn = /'
```

- [ ] **Step 2: Rename the wording.** In `lib/core/router/app_router.dart`:
  - `/// Chrome-lock paths: magic-link entry (signed-out), …` → `/// Chrome-lock paths: sign-in entry (signed-out), …`;
  - `/// Where a signed-in session opens from the magic-link route.` → `/// Where a signed-in session opens from the sign-in route.`

  In `test/router_test.dart`, change four test names `… to magic-link'` → `… to sign-in'`, and `'signed-in user is redirected from magic-link to /family'` → `'signed-in user is redirected from sign-in to /family'`.

- [ ] **Step 3: Check.**

```bash
git grep -n -E "MagicLink|magicLink" -- lib test integration_test
git grep -n "magic-link" -- lib test integration_test | grep -v "Key('magic-link-email')"
```

Expected: both print nothing.

- [ ] **Step 4: Gates.** Expected `+688 ~12`.

- [ ] **Step 5: Commit.** `git commit -am "refactor(client): MagicLinkPage → SignInPage, AppRoutes.magicLink → signIn (URL unchanged)"`

---

### Task 4: Break the router cycle; `lib/app/`

**Files:**
- Create: `lib/core/router/app_routes.dart` (`AppRoutes`, `popOrGoTimeline`)
- Create: `lib/ui/album/album_modal_frame.dart` (`AlbumModalFrame`)
- Modify: `lib/core/router/app_router.dart`, then move to `lib/app/app_router.dart`
- Move: `lib/app.dart` → `lib/app/app.dart`; `lib/core/router/url_strategy_{stub,web}.dart` → `lib/app/`
- Modify: 15 lib importers, 16 test importers, `integration_test/flows.md` (C1, C8, C9), allowlist

`app_router.dart` imports 14 pages; 15 lib files import it back, mostly for `AppRoutes` → 16-file import cycle. After task, pages import only `core/router/app_routes.dart`.

- [ ] **Step 1: Create `lib/core/router/app_routes.dart`.** Move `popOrGoTimeline` and `AppRoutes` class out of `app_router.dart` unchanged. After Task 3 file is:

```dart
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Pops the current route, or opens the timeline when this page is the root.
void popOrGoTimeline(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.timeline);
    }
    return;
  }
  Navigator.of(context).pop();
}

/// Chrome-lock paths: sign-in entry (signed-out), `/family` (signed-in home).
abstract final class AppRoutes {
  static const signIn = '/';
  static const familyLanding = '/family';
  static const timeline = '/timeline';
  static const allStories = '/family/:id/stories';

  static String allStoriesPath(String familyId) => '/family/$familyId/stories';
  static const newStory = '/stories/new';
  static const story = '/stories/:storyId';
  static const storyEdit = '/stories/:storyId/edit';
  static const storyPerspective = '/stories/:storyId/perspective';
  static const invite = '/invite/:token';
  static const drafts = '/drafts';
  static const search = '/search';
  static const settings = '/settings';
  static const manageFamilies = '/manage-families';
  static const manageFamily = '/manage-families/:familyId';

  static String storyPath(String id) => '/stories/$id';

  static String storyEditPath(String id) => '/stories/$id/edit';

  static String invitePath(String token) => '/invite/$token';

  static String manageFamilyPath(String id) => '/manage-families/$id';

  static String storyPerspectivePath(String id) => '/stories/$id/perspective';
}
```

- [ ] **Step 2: Create `lib/ui/album/album_modal_frame.dart`.** Start file with:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

```

Then cut doc comment `/// Card, scrim, and icon label shared by the reader and the capture form.` and whole `class AlbumModalFrame` from `app_router.dart`, paste below imports unchanged.

- [ ] **Step 3: Trim `app_router.dart`.**
  - Delete `import 'dart:ui';` and `import 'package:tell_me_a_story/core/theme/album_theme.dart';`, now unused.
  - Add `import 'package:tell_me_a_story/core/router/app_routes.dart';`.
  - `albumModalPage`, `appStartPath`, `createAppRouter` stay.

- [ ] **Step 4: Repoint the importers.** Run from `apps/tell_me_a_story`. File keeps `app_router.dart` import only if uses `createAppRouter`, `albumModalPage` or `appStartPath`. Gains `app_routes.dart` if uses `AppRoutes` or `popOrGoTimeline`; `album_modal_frame.dart` if uses `AlbumModalFrame`.

```bash
python3 - <<'EOF'
import re, subprocess
old = "import 'package:tell_me_a_story/core/router/app_router.dart';\n"
files = subprocess.run(['git', 'grep', '-l', '-F', old.strip(), '--', 'lib', 'test', 'integration_test'],
                       capture_output=True, text=True).stdout.split()
for f in files:
    s = open(f).read()
    new = ''
    if re.search(r'\b(createAppRouter|albumModalPage|appStartPath)\b', s): new += old
    if re.search(r'\b(AppRoutes|popOrGoTimeline)\b', s): new += "import 'package:tell_me_a_story/core/router/app_routes.dart';\n"
    if re.search(r'\bAlbumModalFrame\b', s): new += "import 'package:tell_me_a_story/ui/album/album_modal_frame.dart';\n"
    open(f, 'w').write(s.replace(old, new, 1))
    print(f)
EOF
```

Expected: 32 files printed (15 lib + 16 test, plus `lib/main.dart`). `new_story_page.dart` and `story_reader_page.dart` gain both new imports.

- [ ] **Step 5: Move to `app/`.**

```bash
mvdart core/router/app_router.dart app/app_router.dart
mvdart app.dart app/app.dart
mvdart core/router/url_strategy_stub.dart app/url_strategy_stub.dart
mvdart core/router/url_strategy_web.dart app/url_strategy_web.dart
mise exec -- dart format lib test integration_test
```

- [ ] **Step 6: Owning paths.** In `integration_test/flows.md`, add `` `app/` `` to three rows:
  - C1 owning paths: `` `features/auth/`, `features/settings/`, `core/server/`, `core/router/`, `app/`, `data/profile_session.dart` ``;
  - C8: `` `features/stories/`, `core/router/`, `app/` ``;
  - C9: `` `core/theme/album_header.dart`, `core/router/`, `app/` ``.

- [ ] **Step 7: Allowlist.** Delete 27 entries starting with `'core/router/app_router.dart -> `. Expected size: **31**.

- [ ] **Step 8: Gates.** Expected `+688 ~12`, analyze 6. If analyze reports `unused_import` in `app/app_router.dart`, delete that import.

- [ ] **Step 9: Commit.** `git add -A lib test integration_test && git commit -m "refactor(client): split AppRoutes and AlbumModalFrame out of the router; router and app widget move to lib/app"`

---

### Task 5: Shared story UI → `lib/ui/story/`

**Files:**
- Move: `lib/features/stories/{story_date,story_date_picker,photo_frame}.dart` → `lib/ui/story/`
- Create: `lib/ui/story/story_title.dart` (`storyTitle` from `features/timeline/timeline_zoom.dart`)
- Modify: `lib/features/timeline/timeline_zoom.dart`, `lib/features/timeline/timeline_page.dart`, `lib/features/family/start_timeline_dialog.dart`, allowlist

`start_timeline_dialog.dart` imported `timeline_zoom.dart` only for `storyTitle` → closed `family` ↔ `timeline` cycle.

- [ ] **Step 1: Move.**

```bash
mvdart features/stories/story_date.dart ui/story/story_date.dart
mvdart features/stories/story_date_picker.dart ui/story/story_date_picker.dart
mvdart features/stories/photo_frame.dart ui/story/photo_frame.dart
```

- [ ] **Step 2: Extract `storyTitle`.** Delete `String storyTitle(Story story) { … }` from `lib/features/timeline/timeline_zoom.dart`, create `lib/ui/story/story_title.dart`:

```dart
import 'package:tell_me_a_story/data/stories_api.dart';

/// [story]'s trimmed title, or 'Untitled'.
String storyTitle(Story story) {
  final title = story.title?.trim() ?? '';
  return title.isEmpty ? 'Untitled' : title;
}
```

- [ ] **Step 3: Imports.**
  - `lib/features/timeline/timeline_zoom.dart`: add `import 'package:tell_me_a_story/ui/story/story_title.dart';`.
  - `lib/features/timeline/timeline_page.dart`: add same import (calls `storyTitle`).
  - `lib/features/family/start_timeline_dialog.dart`: replace `import 'package:tell_me_a_story/features/timeline/timeline_zoom.dart';` with `import 'package:tell_me_a_story/ui/story/story_title.dart';`.

  Then run `mise exec -- dart format lib`.

- [ ] **Step 4: Allowlist.** Delete these 12 entries. Expected size: **19**.

```
'features/all_stories/all_stories_card.dart -> features/stories/story_date.dart',
'features/drafts/drafts_page.dart -> features/stories/story_date.dart',
'features/family/family_landing_page.dart -> features/stories/story_date.dart',
'features/family/start_timeline_dialog.dart -> features/timeline/timeline_zoom.dart',
'features/people/person_date_field.dart -> features/stories/story_date.dart',
'features/people/person_date_field.dart -> features/stories/story_date_picker.dart',
'features/people/person_profile_dialog.dart -> features/stories/story_date.dart',
'features/search/search_page.dart -> features/stories/story_date.dart',
'features/settings/settings_page.dart -> features/stories/story_date.dart',
'features/timeline/timeline_page.dart -> features/stories/photo_frame.dart',
'features/timeline/timeline_page.dart -> features/stories/story_date.dart',
'features/timeline/timeline_zoom.dart -> features/stories/story_date.dart',
```

- [ ] **Step 5: Gates.** Expected `+688 ~12`.

- [ ] **Step 6: Commit.** `git add -A lib test && git commit -m "refactor(client): shared story widgets and storyTitle move to lib/ui/story"`

---

### Task 6: Data seams

**Files:**
- Move: `lib/features/auth/otp_sign_in.dart` → `lib/data/otp_sign_in.dart`; `lib/core/router/auth_refresh.dart` → `lib/data/auth_refresh.dart`
- Modify:
  - `lib/data/app_exception.dart` (gains `StorageFailedException`);
  - `lib/data/photos_api.dart` (loses it);
  - `lib/data/server/server_errors.dart`;
  - tests naming `StorageFailedException`.

`otp_sign_in.dart` is gateway: abstract class + server impl importing generated client. `auth_refresh.dart` binds session state from `data/`. `server_errors.dart` imported `photos_api.dart` only for `StorageFailedException` → two-file cycle.

- [ ] **Step 1: Move.**

```bash
mvdart features/auth/otp_sign_in.dart data/otp_sign_in.dart
mvdart core/router/auth_refresh.dart data/auth_refresh.dart
```

- [ ] **Step 2: Move `StorageFailedException`.** Cut this class from `lib/data/photos_api.dart`:

```dart
class StorageFailedException implements Exception {
  const StorageFailedException({this.code = 'STORAGE_FAILED', this.cause});
  final String code;
  final Object? cause;

  @override
  String toString() => 'StorageFailedException($code)';
}
```

Paste into `lib/data/app_exception.dart` above `/// [AppException.message] for an expected gateway failure, …`, with doc comment:

```dart
/// A blob upload the store refused (`AppErrorCode.storageFailed` on the
/// server, or `FileUploader` returning false).
```

- [ ] **Step 3: Imports.**
  - Add `import 'package:tell_me_a_story/data/app_exception.dart';` to `lib/data/photos_api.dart`, `test/family_covers_test.dart`, `test/new_story_capture_test.dart`, `test/live/photos_api_live_test.dart`.
  - Delete `import 'package:tell_me_a_story/data/photos_api.dart' show StorageFailedException;` directive (two lines) from `lib/data/server/server_errors.dart` and `test/server/server_errors_test.dart`.
  - Delete `import 'package:tell_me_a_story/data/photos_api.dart';` from `test/family_covers_test.dart`.

  Run `mise exec -- dart format lib test` and `mise exec -- flutter analyze | tail -n 1`. Expected: `6 issues found.` New `undefined_identifier` or `unused_import` names file still to fix.

- [ ] **Step 4: Allowlist.** Delete these 6 entries. Expected size: **13**.

```
'core/router/auth_refresh.dart -> data/family_selection.dart',
'core/router/auth_refresh.dart -> data/profile_session.dart',
'core/router/auth_refresh.dart -> package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart',
'features/auth/otp_sign_in.dart -> package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart',
'features/auth/otp_sign_in.dart -> package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart',
'features/auth/otp_sign_in.dart -> package:tell_me_a_story_client/tell_me_a_story_client.dart',
```

- [ ] **Step 5: Gates.** Expected `+688 ~12`. Also run `mise exec -- just server` in one shell, `mise exec -- just test-live 2>&1 | tail -n 1` in another; expected `All tests passed!`.

- [ ] **Step 6: Commit.** `git add -A lib test && git commit -m "refactor(client): otp_sign_in and auth_refresh into data/; StorageFailedException into app_exception"`

---

### Task 7: Colour fix: `features/family/family_role.dart`

**Files:**
- Modify: `lib/features/family/family_role.dart:66`
- Modify: `test/architecture/no_hardcoded_colors_test.dart`

One hit, exact token: `color: owner ? albumTerracotta : Colors.transparent,` → `color: owner ? albumTerracotta : albumBackdropClear,` (`albumBackdropClear` is `Colors.transparent` in `album_theme.dart`).

- [ ] **Step 1: Before screenshots** (see "Screenshot check"), stem `family_role`. Edited branch drawn only by `FamilyRoleChip(role: 'co_owner')` in `transfer_ownership_dialog.dart` (hub + detail role pills are other widgets), so family needs co-owner:
  - `hub`: `/manage-families`;
  - `detail` and `detail-members`: `/manage-families/<id>`, top and scrolled to members list;
  - `transfer-dialog`: `/manage-families/<id>` → Transfer ownership… (shows co-owner chip with transparent fill).
- [ ] **Step 2: Edit** line above.
- [ ] **Step 3: Skip list.** Delete `'features/family/family_role.dart',` from `temporaryHardcodedColorSkipPaths`, set `_skipListCeiling = 22;`.
- [ ] **Step 4: After screenshots and compare.** Expected AE `0` every screen.
- [ ] **Step 5: Gates.** Expected `+688 ~12`.
- [ ] **Step 6: Commit.** `git commit -am "style(client): family_role uses album tokens; leaves the colour skip list"` (body: screens + AE values).

---

### Task 8: Move the unblocked shared widgets → `lib/ui/`

**Files:**
- Move:
  - `lib/features/family/{family_role,family_tree_order}.dart` → `lib/ui/family/`;
  - `lib/core/navigation/leave_story_dialog.dart` → `lib/ui/dialogs/`;
  - `lib/core/navigation/{unsaved_guard,before_unload,before_unload_stub,before_unload_web}.dart` → `lib/ui/navigation/`.
- Modify: allowlist.

- [ ] **Step 1: Move.**

```bash
mvdart features/family/family_role.dart ui/family/family_role.dart
mvdart features/family/family_tree_order.dart ui/family/family_tree_order.dart
mvdart core/navigation/leave_story_dialog.dart ui/dialogs/leave_story_dialog.dart
for f in unsaved_guard before_unload before_unload_stub before_unload_web; do mvdart core/navigation/$f.dart ui/navigation/$f.dart; done
ls lib/core/navigation 2>/dev/null; mise exec -- dart format lib test
```

Expected: `ls` prints nothing (`core/navigation/` gone).

- [ ] **Step 2: Allowlist.** Delete these 4:

```
'core/navigation/leave_story_dialog.dart -> features/family/family_blur_dialog.dart',
'core/theme/album_header.dart -> features/family/family_role.dart',
'core/theme/album_header.dart -> features/family/family_tree_order.dart',
'features/auth/invite_sign_in_page.dart -> features/family/family_role.dart',
```

and add these 4. First three rename moved targets. Last: `album_header` (still in `core/` until Task 15) now importing `ui/`. Task 15 removes all four.

```
'core/theme/album_header.dart -> ui/family/family_role.dart',
'core/theme/album_header.dart -> ui/family/family_tree_order.dart',
'core/theme/album_header.dart -> ui/navigation/unsaved_guard.dart',
'ui/dialogs/leave_story_dialog.dart -> features/family/family_blur_dialog.dart',
```

Expected size: **13**.

- [ ] **Step 3: Gates.** Expected `+688 ~12`.
- [ ] **Step 4: Commit.** `git add -A lib test && git commit -m "refactor(client): family_role, family_tree_order, leave_story_dialog and the unsaved guard move to lib/ui"`

---

### Task 9: STOP: token decisions for the remaining colour fixes

Five files moving in Task 15 still on skip list; six counting `magic_link_page.dart` (becomes `sign_in_page.dart`). Hits below. "Exact token" hits replaced in Tasks 10–14 without asking. Every other row needs owner's answer: existing token (changes pixels) or new token name for `album_theme.dart`. Send whole table to owner (via Main) in one message, wait. Record each answer in "Owner decision" column, commit plan (`docs: Phase 6 token decisions`) before Task 10.

| # | File:line | Today | Exact token | Owner decision |
|---|---|---|---|---|
| 1 | `core/theme/album_chrome.dart:179` | `Colors.white` (plus glyph on non-terracotta `PlusLabel`) | none | new `albumWhite` (`0xFFFFFFFF`) |
| 2 | `core/theme/album_chrome.dart:215` | `Colors.transparent` (dialog `surfaceTintColor`) | `albumBackdropClear` | — |
| 3 | `core/theme/album_chrome.dart:217` | `Color(0x332C2416)` (dialog shadow) | `albumInk.withAlpha(0x33)`: same ARGB, see Q-A | `albumInk.withAlpha(0x33)` (Q-A yes) |
| 4 | `core/theme/album_header.dart:287` | `Color(0xFFFFF6F3)` (Publish button text) | none (`albumDialogSurface` is `0xFFFFF8F6`) | new `albumOnAccent` (`0xFFFFF6F3`) |
| 5 | `core/theme/album_header.dart:787` | `Color(0xFFE6DCD1)` (family menu border) | `albumModalBorder` | — |
| 6 | `core/theme/album_header.dart:938`, `:1025` | `Colors.transparent` (nav underline inactive) | `albumBackdropClear` | — |
| 7 | `core/theme/album_header.dart:1137` | `Color(0xFFFCF9F5)` (avatar menu fill) | none | new `albumMenuSurface` (`0xFFFCF9F5`) |
| 8 | `core/theme/album_header.dart:1140` | `Color(0xFFE6DCD1)` (avatar menu border) | `albumModalBorder` | — |
| 9 | `core/theme/profile_avatar.dart:23` | `Color(0xFFEDE0DC)` (avatar fill) | none | new `albumAvatarFill` (`0xFFEDE0DC`) |
| 10 | `core/theme/profile_avatar.dart:24` | `Color(0xFFD5C7B7)` (avatar border) | none | new `albumAvatarBorder` (`0xFFD5C7B7`) |
| 11 | `features/family/family_blur_dialog.dart:12` | `Color(0x662C2416)` (blur scrim) | `albumInk.withAlpha(0x66)`: same ARGB, see Q-A | `albumInk.withAlpha(0x66)` (Q-A yes) |
| 12 | `features/family/family_blur_dialog.dart:26`, `:62`, `:242` | `Colors.transparent` (barrier) | `albumBackdropClear` | — |
| 13 | `features/family/family_blur_dialog.dart:118` | `Color(0xFFFFF8F6)` (card fill) | `albumDialogSurface` | — |
| 14 | `features/family/family_blur_dialog.dart:122` | `Color(0x1A000000)` (card shadow) | none | new `albumShadow` (`0xFF000000`) `.withAlpha(0x1A)` |
| 15 | `features/family/family_blur_dialog.dart:189` | `Colors.white` (confirm button text) | none | `albumWhite` |
| 16 | `features/family/family_blur_dialog.dart:277`, `:368` | `Color(0xFFE8DFD5)` (send-invite card + row border) | none (`albumModalBorder` is `0xFFE6DCD1`, `albumPillBorder` is `0xFFE7DECE`) | new `albumInviteBorder` (`0xFFE8DFD5`) |
| 17 | `features/family/family_blur_dialog.dart:280` | `Color(0x1A2C2416)` (send-invite shadow) | `albumInk.withAlpha(0x1A)`: same ARGB, see Q-A | `albumInk.withAlpha(0x1A)` (Q-A yes) |
| 18 | `features/family/family_blur_dialog.dart:366` | `Color(0xFFF7F1EA)` (send-invite row fill) | none (`albumPillFill` is `0xFFF6F1EB`) | new `albumInviteNoteFill` (`0xFFF7F1EA`) |
| 19 | `features/family/family_blur_dialog.dart:396` | `Color(0x80E8DFD5)` (divider) | none (follows row 16) | `albumInviteBorder.withAlpha(0x80)` |
| 20 | `features/auth/magic_link_page.dart:11` | `_landingLine = Color(0xFFB9B0AD)` | none | new `albumLandingLine` (`0xFFB9B0AD`) |
| 21 | `features/auth/magic_link_page.dart:13` | `_landingOnPrimary = Color(0xFFFFF6F3)` | none (same value as row 4) | `albumOnAccent` |
| 22 | `features/auth/magic_link_page.dart:249`, `:315` | `Colors.white` (form card fill) | none (same as rows 1, 15) | `albumWhite` |
| 23 | `features/auth/magic_link_page.dart:254`, `:320` | `Color(0x0D000000)` (form card shadow) | none | `albumShadow.withAlpha(0x0D)` |

**Q-A:** Is "existing token with `.withAlpha(n)` yielding identical ARGB" an existing-token match? Rows 3, 11, 17 depend on it. If yes, those hits drop `const` on enclosing expression where needed (e.g. `shadowColor: albumInk.withAlpha(0x33),`).

**Q-B:** `magic_link_page.dart` is sixth skip-listed file that moves (rename to `sign_in_page.dart` in Task 15). Fix-first rule apply too? Plan assumes yes (Task 14). If owner says no, Task 15 renames its skip-list entry 1:1 instead.

If decision adds tokens, add each to `lib/core/theme/album_theme.dart` after `const albumBackdropClear = Colors.transparent;`, as `const <approvedName> = Color(<value>);` with one-line doc comment saying where used. Do in first task that uses it.

- [ ] **Step 1:** Send table + Q-A / Q-B; wait for answers.
- [ ] **Step 2:** Fill "Owner decision" column, commit plan.

**Owner answers (2026-11-07):** no exact token → add one named token per distinct value, today's exact value (pixel-identical); Q-A yes (`token.withAlpha(n)` where ARGB identical, also black shadows via `albumShadow`); Q-B yes (Task 14 runs).

---

### Task 10: Colour fix: `core/theme/album_chrome.dart`

**Files:** `lib/core/theme/album_chrome.dart` (lines 179, 215, 217), `lib/core/theme/album_theme.dart` (only if Task 9 added tokens), `test/architecture/no_hardcoded_colors_test.dart`

- [ ] **Step 1: Before screenshots**, stem `album_chrome`:
  - `manage-members`: `/manage-families/<id>` scrolled down, "Add co-owner" visible (`PlusLabel` with `onTerracotta: false`, draws row 1; header's New story and hub's Start a family use `onTerracotta: true`, don't);
  - `capture-add-person-plus`: `/stories/new` scrolled to People, "Add person" visible;
  - `album-dialog-add-person`: then press "Add person" (add-person modal is `showAlbumDialog` dialog; Rename isn't).
- [ ] **Step 2: Edit.**
  - Line 215: `surfaceTintColor: Colors.transparent,` → `surfaceTintColor: albumBackdropClear,`.
  - Lines 217, 179: apply Task 9 rows 3 and 1.
- [ ] **Step 3: Skip list.** Delete `'core/theme/album_chrome.dart',`, lower `_skipListCeiling` by one (to 21 if Task 7 ran first).
- [ ] **Step 4: After screenshots and compare.** Expected AE `0` every screen unless row-1 or row-3 decision changed value.
- [ ] **Step 5: Gates** (`+688 ~12`) and **commit** `style(client): album_chrome uses album tokens; leaves the colour skip list`.

---

### Task 11: Colour fix: `core/theme/album_header.dart`

**Files:** `lib/core/theme/album_header.dart` (lines 287, 787, 938, 1025, 1137, 1140), `album_theme.dart` (if needed), skip list

- [ ] **Step 1: Before screenshots**, stem `album_header`:
  - `family-nav`: `/family`, header with nav underline;
  - `family-menu`: `/family`, family menu open;
  - `avatar-menu`: `/family`, avatar menu open;
  - `capture-header`: `/stories/new` header with Publish button.
- [ ] **Step 2: Edit.**
  - Lines 787, 1140: `side: const BorderSide(color: Color(0xFFE6DCD1)),` → `side: const BorderSide(color: albumModalBorder),`.
  - Lines 938, 1025: `Colors.transparent` → `albumBackdropClear`.
  - Lines 287, 1137: apply Task 9 rows 4 and 7.
- [ ] **Step 3: Skip list.** Delete `'core/theme/album_header.dart',`; ceiling minus one.
- [ ] **Step 4: After screenshots and compare.**
- [ ] **Step 5: Gates and commit** `style(client): album_header uses album tokens; leaves the colour skip list`.

---

### Task 12: Colour fix: `core/theme/profile_avatar.dart`

**Files:** `lib/core/theme/profile_avatar.dart:23-24`, `album_theme.dart` (if needed), skip list

- [ ] **Step 1: Before screenshots**, stem `profile_avatar`:
  - `header`: `/family` header avatar (account without picture);
  - `settings`: `/settings`;
  - `person-profile`: person profile dialog without picture.
- [ ] **Step 2: Edit** `static const fill` and `static const borderColor` per Task 9 rows 9, 10.
- [ ] **Step 3: Skip list.** Delete `'core/theme/profile_avatar.dart',`; ceiling minus one.
- [ ] **Step 4: After screenshots and compare.**
- [ ] **Step 5: Gates and commit** `style(client): profile_avatar uses album tokens; leaves the colour skip list`.

---

### Task 13: Colour fix: `features/family/family_blur_dialog.dart`

**Files:** `lib/features/family/family_blur_dialog.dart` (lines 12, 26, 62, 118, 122, 189, 242, 277, 280, 366, 368, 396), `album_theme.dart` (if needed), skip list

- [ ] **Step 1: Before screenshots**, stem `family_blur_dialog`:
  - `delete-family`: `/manage-families/<id>` → Delete family confirm;
  - `leave-story`: `/stories/new`, type title, press back → "Leave this story?";
  - `send-invite`: Add person with email → send-invite confirm.
- [ ] **Step 2: Edit.**
  - Lines 26, 62, 242: `barrierColor: Colors.transparent,` → `barrierColor: albumBackdropClear,`.
  - Line 118: `color: const Color(0xFFFFF8F6),` → `color: albumDialogSurface,`.
  - Lines 12, 122, 189, 277, 280, 366, 368, 396: apply Task 9 rows 11, 14, 15, 16, 17, 18, 19.
- [ ] **Step 3: Skip list.** Delete `'features/family/family_blur_dialog.dart',`; ceiling minus one.
- [ ] **Step 4: After screenshots and compare.**
- [ ] **Step 5: Gates and commit** `style(client): family_blur_dialog uses album tokens; leaves the colour skip list`.

---

### Task 14: Colour fix: `features/auth/magic_link_page.dart`

**Files:** `lib/features/auth/magic_link_page.dart` (lines 11, 13, 249, 254, 315, 320), `album_theme.dart` (if needed), skip list

- [ ] **Step 1: Before screenshots** (signed out), stem `sign_in_page`:
  - `landing`: `/`;
  - `code-step`: `/` after "Email me a sign-in code".
- [ ] **Step 2: Edit** per Task 9 rows 20–23.
- [ ] **Step 3: Skip list.** Delete `'features/auth/magic_link_page.dart',`; ceiling minus one.
- [ ] **Step 4: After screenshots and compare.**
- [ ] **Step 5: Gates and commit** `style(client): sign-in page uses album tokens; leaves the colour skip list`.

If owner answered Q-B "no", skip task. Task 15 then renames entry to `'features/auth/sign_in_page.dart',` in same commit as move.

---

### Task 15: Move the colour-fixed files

**Files:**
- Move:
  - `lib/core/theme/{album_chrome,album_header}.dart` → `lib/ui/album/`;
  - `lib/core/theme/{profile_avatar,profile_initials}.dart` → `lib/ui/avatar/`;
  - `lib/features/family/family_blur_dialog.dart` → `lib/ui/dialogs/`;
  - `lib/features/auth/magic_link_page.dart` → `lib/features/auth/sign_in_page.dart`.
- Modify: `integration_test/flows.md` (C9), allowlist

- [ ] **Step 1: Check skip list** no longer names these files. Run: `grep -nE "album_chrome|album_header|profile_avatar|family_blur_dialog|magic_link_page" test/architecture/no_hardcoded_colors_test.dart`. Expected: no output (Q-B "no": only `magic_link_page`).
- [ ] **Step 2: Move.**

```bash
mvdart core/theme/album_chrome.dart ui/album/album_chrome.dart
mvdart core/theme/album_header.dart ui/album/album_header.dart
mvdart core/theme/profile_avatar.dart ui/avatar/profile_avatar.dart
mvdart core/theme/profile_initials.dart ui/avatar/profile_initials.dart
mvdart features/family/family_blur_dialog.dart ui/dialogs/family_blur_dialog.dart
mvdart features/auth/magic_link_page.dart features/auth/sign_in_page.dart
ls lib/core/theme; mise exec -- dart format lib test
```

Expected: `ls` prints only `album_theme.dart`.

- [ ] **Step 3: Owning path.** In `integration_test/flows.md`, C9: replace `` `core/theme/album_header.dart` `` with `` `ui/album/album_header.dart` ``. Also update two `'core/theme/album_header.dart'` fixture strings in `test/new_story_shell_test.dart` (`_pumpStory ignores only an album_header RenderFlex overflow` test; matcher checks only file name).
- [ ] **Step 4: Allowlist.** Delete all 13 remaining entries. Expected size: **0**.
- [ ] **Step 5: Gates.** Expected `+688 ~12`.
- [ ] **Step 6: Commit.** `git add -A lib test integration_test && git commit -m "refactor(client): album chrome, header, avatar and blur dialog move to lib/ui; sign_in_page.dart"`

---

### Task 16: The import rules without an allowlist

**Files:** Replace `test/architecture/import_boundaries_test.dart`

No violations left → allowlist machinery dead code. `app.dart` no longer at `lib/` root.

- [ ] **Step 1: Replace the file** with:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Import rules for lib/. Layers: app (main.dart, app/), core, data, ui and
// features/<name>. See AGENTS.md "Layout". Run from apps/tell_me_a_story.

/// Features may import only features of a lower rank.
const featureRank = <String, int>{
  'auth': 0,
  'comments': 0,
  'invites': 0,
  'people': 0,
  'perspectives': 0,
  'places': 0,
  'family': 1,
  'all_stories': 2,
  'drafts': 2,
  'search': 2,
  'settings': 2,
  'stories': 2,
  'timeline': 2,
};

/// Packages that only core/server/ and data/ may import.
const serverPackages = <String>[
  'package:tell_me_a_story_client/',
  'package:serverpod',
];

/// Flutter UI libraries that data/ may not import.
const uiLibraries = <String>[
  'package:flutter/material.dart',
  'package:flutter/widgets.dart',
  'package:flutter/cupertino.dart',
];

const _appPackage = 'package:tell_me_a_story/';

final _directive = RegExp(
  r"^(?:import|export)\s+'([^']+)'(?:\s+if\s*\([^)]*\)\s*'([^']+)')?",
  multiLine: true,
);

String layerOf(String path) {
  if (path == 'main.dart' || path.startsWith('app/')) return 'app';
  final parts = path.split('/');
  switch (parts.first) {
    case 'core' || 'data' || 'ui':
      return parts.first;
    case 'features' when parts.length > 2:
      return 'features/${parts[1]}';
  }
  return 'unknown';
}

bool allowed(String from, String to) {
  if (from == to || from == 'app') return true;
  final inShared = to == 'core' || to == 'data' || to == 'ui';
  switch (from) {
    case 'core':
      return to == 'core';
    case 'data':
      return to == 'core' || to == 'data';
    case 'ui':
      return inShared;
  }
  if (inShared) return true;
  if (!to.startsWith('features/')) return false;
  final fromRank = featureRank[from.substring('features/'.length)];
  final toRank = featureRank[to.substring('features/'.length)];
  return fromRank != null && toRank != null && toRank < fromRank;
}

/// Every import/export target of [source], as written.
Iterable<String> targetsOf(String source) sync* {
  for (final match in _directive.allMatches(source)) {
    yield match.group(1)!;
    final conditional = match.group(2);
    if (conditional != null) yield conditional;
  }
}

/// [target] as a path relative to lib/, or null for another package or dart:.
String? libPath(String file, String target) {
  if (target.startsWith(_appPackage)) {
    return target.substring(_appPackage.length);
  }
  if (target.contains(':')) return null;
  return Uri.parse(file).resolve(target).path;
}

void main() {
  test('lib/ imports follow the layer rules', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );

    final found = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final file = entity.path.replaceAll('\\', '/').substring('lib/'.length);
      final from = layerOf(file);
      if (from == 'unknown') {
        found.add('$file is outside app/, core/, data/, ui/ and features/');
        continue;
      }
      if (from.startsWith('features/') &&
          !featureRank.containsKey(from.substring('features/'.length))) {
        found.add('$file: add its feature to featureRank');
        continue;
      }
      for (final target in targetsOf(entity.readAsStringSync())) {
        if (serverPackages.any(target.startsWith) &&
            from != 'app' &&
            from != 'data' &&
            !file.startsWith('core/server/')) {
          found.add('$file -> $target');
          continue;
        }
        if (from == 'data' && uiLibraries.contains(target)) {
          found.add('$file -> $target');
          continue;
        }
        final path = libPath(file, target);
        if (path == null) continue;
        if (!allowed(from, layerOf(path))) found.add('$file -> $path');
      }
    }

    found.sort();
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
```

- [ ] **Step 2: Prove it bites.** Add `import 'package:tell_me_a_story/features/family/manage_family_page.dart';` to `lib/ui/story/story_title.dart`, run `mise exec -- flutter test test/architecture/import_boundaries_test.dart`. Expected: FAIL with `ui/story/story_title.dart -> features/family/manage_family_page.dart`. Revert import.
- [ ] **Step 3: AGENTS.md.** Replace Task 2 line with:

```markdown
- `lib/` layers: `app/` (composition root) may import anything; `core/` imports `core/`; `data/` imports `core/` and `data/`; `ui/` imports `core/`, `data/` and `ui/`; `features/<f>/` imports those plus lower-rank features (`featureRank` in `test/architecture/import_boundaries_test.dart`). Only `data/` and `core/server/` import the generated client or `serverpod*`. The test enforces this; change a rank only with the owner's approval.
```

- [ ] **Step 4: Gates and commit.** Expected `+688 ~12`. `git commit -am "test(client): import rules enforced without exceptions"`

---

### Task 17: Tests mirror `lib/`

Three commits (17a, 17b, 17c), each green with same count, then layout guard. Tests already use package imports, shared fakes not yet existing (Task 18), so moving test file = pure rename. Only `test/live/` uses relative imports; doesn't move.

- [ ] **Step 1 (17a): app, core, data and ui tests.**

```bash
while read -r from to; do mkdir -p "test/$(dirname "$to")"; git mv "test/$from" "test/$to"; done <<'EOF'
router_test.dart app/app_router_test.dart
env_test.dart core/config/env_test.dart
app_session_test.dart core/server/app_session_test.dart
album_theme_test.dart core/theme/album_theme_test.dart
app_exception_test.dart data/app_exception_test.dart
comments_api_test.dart data/comments_api_test.dart
families_api_test.dart data/families_api_test.dart
family_covers_test.dart data/family_covers_test.dart
family_selection_test.dart data/family_selection_test.dart
mapbox_search_test.dart data/mapbox_search_test.dart
otp_sign_in_test.dart data/otp_sign_in_test.dart
people_api_test.dart data/people_api_test.dart
perspectives_api_test.dart data/perspectives_api_test.dart
photos_api_test.dart data/photos_api_test.dart
places_api_test.dart data/places_api_test.dart
profile_api_test.dart data/profile_api_test.dart
profile_session_test.dart data/profile_session_test.dart
search_api_test.dart data/search_api_test.dart
stories_api_test.dart data/stories_api_test.dart
timeline_live_test.dart data/timeline_live_test.dart
family_landing_latest_test.dart data/stories_api_latest_test.dart
server/server_errors_test.dart data/server/server_errors_test.dart
server/wire_test.dart data/server/wire_test.dart
album_header_family_switch_test.dart ui/album/album_header_family_switch_test.dart
family_menu_cleanup_test.dart ui/album/album_header_family_menu_test.dart
profile_initials_test.dart ui/avatar/profile_initials_test.dart
leave_story_dialog_test.dart ui/dialogs/leave_story_dialog_test.dart
family_menu_tree_test.dart ui/family/family_tree_order_test.dart
unsaved_guard_test.dart ui/navigation/unsaved_guard_test.dart
story_date_test.dart ui/story/story_date_test.dart
photo_frame_test.dart ui/story/photo_frame_test.dart
EOF
rmdir test/server
```

Gates (`+688 ~12`), then `git commit -m "test(client): app, core, data and ui tests mirror lib"`.

- [ ] **Step 2 (17b): feature tests.**

```bash
while read -r from to; do mkdir -p "test/$(dirname "$to")"; git mv "test/$from" "test/$to"; done <<'EOF'
all_stories_loader_test.dart features/all_stories/all_stories_loader_test.dart
all_stories_logic_test.dart features/all_stories/all_stories_logic_test.dart
all_stories_page_test.dart features/all_stories/all_stories_page_test.dart
comment_composer_test.dart features/comments/comment_composer_test.dart
drafts_page_test.dart features/drafts/drafts_page_test.dart
family_landing_page_test.dart features/family/family_landing_page_test.dart
manage_families_page_test.dart features/family/manage_families_page_test.dart
manage_family_rename_guard_test.dart features/family/manage_family_page_rename_guard_test.dart
start_timeline_test.dart features/family/start_timeline_dialog_test.dart
invite_chrome_test.dart features/invites/invite_modal_test.dart
add_person_modal_test.dart features/people/add_person_modal_test.dart
add_perspective_page_test.dart features/perspectives/add_perspective_page_test.dart
place_picker_modal_test.dart features/places/place_picker_modal_test.dart
search_page_test.dart features/search/search_page_test.dart
settings_page_test.dart features/settings/settings_page_test.dart
settings_guard_test.dart features/settings/settings_page_guard_test.dart
new_story_capture_test.dart features/stories/new_story_page_capture_test.dart
new_story_guard_test.dart features/stories/new_story_page_guard_test.dart
new_story_shell_test.dart features/stories/new_story_page_shell_test.dart
edit_story_guard_test.dart features/stories/new_story_page_edit_guard_test.dart
logout_ordering_test.dart features/stories/new_story_page_logout_test.dart
photo_strip_test.dart features/stories/photo_strip_test.dart
reader_meta_test.dart features/stories/reader_meta_test.dart
story_reader_page_test.dart features/stories/story_reader_page_test.dart
timeline_branching_test.dart features/timeline/timeline_branching_test.dart
timeline_page_test.dart features/timeline/timeline_page_test.dart
EOF
```

Gates (`+688 ~12`), then `git commit -m "test(client): feature tests mirror lib"`.

- [ ] **Step 3 (17c): milestone tests.**

```bash
while read -r from to; do mkdir -p "test/$(dirname "$to")"; git mv "test/$from" "test/$to"; done <<'EOF'
m10_navigation_test.dart ui/album/album_header_manage_entry_test.dart
m14_3_dob_passed_away_test.dart features/people/person_dob_passed_away_test.dart
m14_people_profiles_test.dart features/people/people_profiles_test.dart
EOF
```

Split `test/m13_fit_finish_test.dart` (7 tests, 5 targets). Each new file starts with original's imports and this `main()` preamble:

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
```

Copy tests verbatim, plus only helpers each file uses:

| New file | Tests (by name) | Helpers to copy |
|---|---|---|
| `test/data/invite_api_test.dart` | `buildInviteUrl uses /invite/<token>` | — |
| `test/features/auth/sign_in_page_test.dart` | `landing copy, bad email, send failure, and a different email`; `landing code step: errors, a new code, and sign-in` | `_tapText`, `_enterCode`, `_Otp` |
| `test/features/auth/invite_sign_in_page_test.dart` | `invite page live, dead, null inviter, and signed-in accept`; `signed-in return to an already used invite opens Family Landing`; `signed-in invite that another account used stays dead` | `_tapText`, `_enterCode`, `_Otp`, `_Preview`, `_Invites` |
| `test/ui/dialogs/family_blur_dialog_test.dart` | `listed confirms use a blur shell and not AlertDialog` | `_People` |
| `test/ui/album/album_header_plus_label_test.dart` | `new story header uses a plus circle and invite does not` | — |

Then delete original, prune imports file by file:

```bash
git rm -q test/m13_fit_finish_test.dart
for f in test/data/invite_api_test.dart test/features/auth/sign_in_page_test.dart test/features/auth/invite_sign_in_page_test.dart test/ui/dialogs/family_blur_dialog_test.dart test/ui/album/album_header_plus_label_test.dart; do
  mise exec -- dart fix --apply --code=unused_import,unnecessary_import "$f"
done
mise exec -- dart format test
```

Gates: `+688 ~12`, same count as before split, analyze 6 (no new `unused_import` or `unnecessary_import`). Then `git add -A test && git commit -m "test(client): milestone tests renamed by subject; m13 split by subject"`.

- [ ] **Step 4: The layout guard.** Create `test/architecture/test_layout_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Unit and widget tests mirror lib/: the test for lib/<dir>/<name>.dart is
// test/<dir>/<name>_test.dart (or <name>_<aspect>_test.dart). live/ (tag
// live), architecture/ (guards) and support/ (shared fakes) are the only
// other folders. Run from apps/tell_me_a_story.

const _ownFolders = {'architecture', 'live', 'support'};
final _milestoneName = RegExp(r'^m\d+(_\d+)*_');

void main() {
  test('test files mirror lib/ and are named for their subject', () {
    expect(
      Directory('lib').existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );
    final problems = <String>[];
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/').substring('test/'.length);
      final parts = path.split('/');
      if (_ownFolders.contains(parts.first)) continue;
      final name = parts.last;
      if (!name.endsWith('_test.dart')) {
        problems.add('$path: shared test code goes in test/support/');
        continue;
      }
      if (_milestoneName.hasMatch(name)) {
        problems.add('$path: name the subject, not the milestone');
      }
      if (parts.length == 1) {
        problems.add('$path: move it under the lib/ folder it tests');
        continue;
      }
      final folder = parts.sublist(0, parts.length - 1).join('/');
      if (!Directory('lib/$folder').existsSync()) {
        problems.add('$path: lib/$folder does not exist');
      }
    }
    problems.sort();
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
```

Prove it bites: `printf 'void main() {}\n' > test/m99_demo_test.dart`, run test, expect FAIL with `m99_demo_test.dart: move it under the lib/ folder it tests` and `… name the subject, not the milestone`. Then `rm test/m99_demo_test.dart`.

Gates: `+689 ~12`. Commit: `git add test/architecture && git commit -m "test(client): guard that tests mirror lib and are named by subject"`.

---

### Task 18: Shared gateway fakes

**Files:**
- Create: `test/support/fakes/` with six files below
- Modify: test files in inventory

Each fake = working in-memory impl, records calls, has error hooks. Test uses as is, or subclasses (`class _Stories extends FakeStoriesGateway { … }`) overriding only what's special. Tests import fakes relatively, one `../` per folder level below `test/`: from `test/features/drafts/x_test.dart` it's `import '../../support/fakes/fake_invite_gateway.dart';`, from `test/app/app_router_test.dart` it's `import '../support/fakes/fake_invite_gateway.dart';`.

- [ ] **Step 1: Create the fakes.**

`test/support/fakes/fake_invite_gateway.dart`:

```dart
import 'package:tell_me_a_story/data/invite_api.dart';

/// In-memory [InviteGateway] for widget tests. Records every call. Set an
/// `*Error` field to make that call throw it. Subclass and override a method
/// for anything else.
class FakeInviteGateway implements InviteGateway {
  FakeInviteGateway({
    this.familyId = 'family-1',
    this.createdFamilyId = 'family-created',
    this.acceptedFamilyId = 'family-1',
  });

  /// What [currentFamilyId] returns.
  String? familyId;
  String createdFamilyId;
  String acceptedFamilyId;

  Object? createInviteError;
  Object? sendInviteEmailError;
  Object? acceptInviteError;

  final createdFamilyNames = <String>[];
  final createdInvites =
      <({String familyId, String? email, String? personId})>[];
  final sentInvites = <({String inviteId, String token})>[];
  final acceptedTokens = <String>[];

  @override
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<String> createFamily(String name) async {
    createdFamilyNames.add(name);
    return createdFamilyId;
  }

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    final error = createInviteError;
    if (error != null) throw error;
    createdInvites.add((familyId: familyId, email: email, personId: personId));
    final n = createdInvites.length;
    return CreateInviteResult(
      inviteId: 'invite-$n',
      token: 'token-$n',
      expiresAt: DateTime.utc(2030),
      inviteUrl: buildInviteUrl('token-$n', origin: 'http://127.0.0.1:3000'),
    );
  }

  @override
  Future<void> sendInviteEmail({
    required String inviteId,
    required String token,
  }) async {
    final error = sendInviteEmailError;
    if (error != null) throw error;
    sentInvites.add((inviteId: inviteId, token: token));
  }

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    final error = acceptInviteError;
    if (error != null) throw error;
    acceptedTokens.add(token);
    return AcceptInviteResult(familyId: acceptedFamilyId);
  }
}
```

`test/support/fakes/fake_stories_gateway.dart`:

```dart
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

/// In-memory [StoriesGateway] for widget tests. [stories] is the store,
/// keyed by id; every call is appended to [calls] as its method name. Set
/// [error] to make every call throw it. Subclass and override a method for
/// anything else.
class FakeStoriesGateway implements StoriesGateway {
  FakeStoriesGateway({
    Iterable<Story> stories = const [],
    this.userId = 'user-1',
    DateTime? now,
  }) : now = now ?? DateTime.utc(2026, 11, 1) {
    for (final story in stories) {
      this.stories[story.id] = story;
    }
  }

  /// Author of drafts this fake creates; [listMyDrafts] filters on it.
  final String userId;

  /// Clock for `publishedAt` and [listLatestPublished].
  final DateTime now;

  final stories = <String, Story>{};
  final calls = <String>[];
  final discarded = <String>[];
  final linkedPeople = <({String storyId, String personId})>[];
  Object? error;

  void _record(String call) {
    calls.add(call);
    final thrown = error;
    if (thrown != null) throw thrown;
  }

  Story _require(String storyId) {
    final story = stories[storyId];
    if (story == null) {
      throw const AppException(
        code: AppErrorCode.notFound,
        message: 'Story not found.',
      );
    }
    return story;
  }

  @override
  Future<Story> createDraft({
    String? id,
    required String familyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    bool allowUndated = false,
    List<String> personIds = const [],
  }) async {
    _record('createDraft');
    final story = Story(
      id: id ?? 'story-${stories.length + 1}',
      familyId: familyId,
      authorId: userId,
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: storyDatePrecisionFrom(datePrecision),
      createdAt: now,
      placeId: placeId,
      status: StoryStatus.draft,
      personIds: personIds,
    );
    stories[story.id] = story;
    return story;
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    _record('updateDraft');
    return stories[storyId] = rebuildStory(
      _require(storyId),
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: datePrecision,
      title: title,
      body: body,
      placeId: placeId,
      personIds: personIds,
    );
  }

  @override
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    _record('autosaveDraft');
    final story = stories[storyId];
    if (story == null || story.status != StoryStatus.draft) return false;
    stories[storyId] = rebuildStory(
      story,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: datePrecision,
      title: title,
      body: body,
      placeId: placeId,
      personIds: personIds,
    );
    return true;
  }

  @override
  Future<Story> publish(String storyId) async {
    _record('publish');
    return stories[storyId] = rebuildStory(
      _require(storyId),
      status: StoryStatus.published,
      publishedAt: now,
    );
  }

  @override
  Future<Story> getStory(String storyId) async {
    _record('getStory');
    return _require(storyId);
  }

  @override
  Future<Story?> getPublished(String storyId) async {
    _record('getPublished');
    final story = stories[storyId];
    return story?.status == StoryStatus.published ? story : null;
  }

  @override
  Future<List<Story>> listMyDrafts(String familyId) async {
    _record('listMyDrafts');
    return [
      for (final story in stories.values)
        if (story.familyId == familyId &&
            story.authorId == userId &&
            story.status == StoryStatus.draft)
          story,
    ];
  }

  @override
  Future<List<Story>> listPublished(String familyId) async {
    _record('listPublished');
    return _published(familyId);
  }

  @override
  Future<Story?> getPublishedOrigin(String storyId) async {
    _record('getPublishedOrigin');
    final story = stories[storyId];
    return story?.status == StoryStatus.published ? story : null;
  }

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async {
    _record('listLatestPublished');
    final since = (now ?? this.now).subtract(Duration(days: withinDays));
    final latest = [
      for (final story in _published(familyId))
        if (story.publishedAt != null && story.publishedAt!.isAfter(since))
          story,
    ]..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    return latest.take(limit).toList();
  }

  @override
  Future<void> discard(String storyId) async {
    _record('discard');
    stories.remove(storyId);
    discarded.add(storyId);
  }

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {
    _record('linkPerson');
    linkedPeople.add((storyId: storyId, personId: personId));
    final story = _require(storyId);
    if (!story.personIds.contains(personId)) {
      stories[storyId] = rebuildStory(
        story,
        personIds: [...story.personIds, personId],
      );
    }
  }

  List<Story> _published(String familyId) => [
    for (final story in stories.values)
      if (story.familyId == familyId && story.status == StoryStatus.published)
        story,
  ];
}

/// [story] with the given fields replaced; a null argument keeps the field.
Story rebuildStory(
  Story story, {
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
  String? datePrecision,
  String? title,
  String? body,
  String? placeId,
  List<String>? personIds,
  StoryStatus? status,
  DateTime? publishedAt,
}) {
  return Story(
    id: story.id,
    familyId: story.familyId,
    authorId: story.authorId,
    title: title ?? story.title,
    body: body ?? story.body,
    timeframeStart: timeframeStart ?? story.timeframeStart,
    timeframeEnd: timeframeEnd ?? story.timeframeEnd,
    datePrecision: datePrecision == null
        ? story.datePrecision
        : storyDatePrecisionFrom(datePrecision),
    createdAt: story.createdAt,
    placeId: placeId ?? story.placeId,
    status: status ?? story.status,
    publishedAt: publishedAt ?? story.publishedAt,
    personIds: personIds ?? story.personIds,
    photoCount: story.photoCount,
    placeLabel: story.placeLabel,
    people: story.people,
    personNames: story.personNames,
    authorDisplayName: story.authorDisplayName,
    authorAvatarPath: story.authorAvatarPath,
    commentCount: story.commentCount,
    perspectiveCount: story.perspectiveCount,
    photoPaths: story.photoPaths,
    placeAddress: story.placeAddress,
    personUserIds: story.personUserIds,
  );
}
```

`test/support/fakes/fake_photos_gateway.dart`:

```dart
import 'dart:typed_data';

import 'package:tell_me_a_story/data/photos_api.dart';

/// In-memory [PhotosGateway] for widget tests. [photos] is the store; every
/// call is appended to [calls] as its method name. Set an `*Error` field to
/// make that call throw it. Subclass and override a method for anything else.
class FakePhotosGateway implements PhotosGateway {
  FakePhotosGateway({Iterable<Photo> photos = const [], this.userId = 'user-1'})
    : photos = [...photos];

  /// `uploaderId` of photos this fake uploads.
  final String userId;

  final List<Photo> photos;
  final calls = <String>[];
  final uploadedBytes = <Uint8List>[];
  final deleted = <String>[];
  final heroes = <({String storyId, String photoId})>[];

  /// What [downloadBytes] returns per storage path; missing paths give
  /// empty bytes.
  final bytesByPath = <String, Uint8List>{};

  Object? uploadError;
  Object? downloadError;

  @override
  Future<List<Photo>> listPhotos(String storyId) async {
    calls.add('listPhotos');
    return [
      for (final photo in photos)
        if (photo.storyId == storyId) photo,
    ]..sort(comparePhotoOrder);
  }

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) async {
    calls.add('uploadPhoto');
    final error = uploadError;
    if (error != null) throw error;
    uploadedBytes.add(bytes);
    final id = 'photo-${uploadedBytes.length}';
    final photo = Photo(
      id: id,
      storyId: storyId,
      familyId: familyId,
      uploaderId: userId,
      storagePath: 'photos/$storyId/$id.jpg',
      sortOrder: sortOrder,
    );
    photos.add(photo);
    bytesByPath[photo.storagePath] = bytes;
    return photo;
  }

  @override
  Future<void> deletePhoto(Photo photo) async {
    calls.add('deletePhoto');
    photos.removeWhere((existing) => existing.id == photo.id);
    deleted.add(photo.id);
  }

  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {
    calls.add('setHeroPhoto');
    heroes.add((storyId: storyId, photoId: photoId));
    final ordered = photosWithHeroFirst(await listPhotos(storyId), photoId);
    photos
      ..removeWhere((photo) => photo.storyId == storyId)
      ..addAll(ordered);
  }

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    calls.add('downloadBytes');
    final error = downloadError;
    if (error != null) throw error;
    return bytesByPath[storagePath] ?? Uint8List(0);
  }
}
```

`test/support/fakes/fake_places_gateway.dart`:

```dart
import 'package:tell_me_a_story/data/places_api.dart';

/// In-memory [PlacesGateway] for widget tests. [places] is the store (one
/// tree); every call is appended to [calls] as its method name. Set
/// [createError] to make [createPlace] throw it. Subclass and override a
/// method for anything else.
class FakePlacesGateway implements PlacesGateway {
  FakePlacesGateway({Iterable<Place> places = const [], DateTime? now})
    : places = [...places],
      now = now ?? DateTime.utc(2026, 11, 1);

  final List<Place> places;

  /// `lastUsedAt` that [markUsed] stamps.
  final DateTime now;

  final calls = <String>[];
  Object? createError;

  @override
  Future<List<Place>> listPlaces(String familyId) async {
    calls.add('listPlaces');
    return [...places];
  }

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    calls.add('listFavorites');
    return [
      for (final place in places)
        if (place.isFavorite) place,
    ];
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    calls.add('listRecents');
    final used = [
      for (final place in places)
        if (place.lastUsedAt != null) place,
    ]..sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
    return used.take(limit).toList();
  }

  @override
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  }) async {
    calls.add('createPlace');
    final error = createError;
    if (error != null) throw error;
    final place = Place(
      id: 'place-${places.length + 1}',
      label: label,
      address: address,
      lat: lat,
      lng: lng,
      mapboxPlaceId: mapboxPlaceId,
      isFavorite: isFavorite,
    );
    places.add(place);
    return place;
  }

  @override
  Future<Place> markUsed(String placeId) async {
    calls.add('markUsed');
    return _replace(placeId, lastUsedAt: now);
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
    calls.add('setFavorite');
    return _replace(placeId, isFavorite: isFavorite);
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async {
    calls.add('findByMapboxPlaceId');
    for (final place in places) {
      if (place.mapboxPlaceId == mapboxPlaceId) return place;
    }
    return null;
  }

  @override
  Future<Place?> getPlace(String id) async {
    calls.add('getPlace');
    for (final place in places) {
      if (place.id == id) return place;
    }
    return null;
  }

  Place _replace(String placeId, {DateTime? lastUsedAt, bool? isFavorite}) {
    final index = places.indexWhere((place) => place.id == placeId);
    if (index == -1) throw StateError('no place $placeId');
    final old = places[index];
    return places[index] = Place(
      id: old.id,
      label: old.label,
      address: old.address,
      lat: old.lat,
      lng: old.lng,
      mapboxPlaceId: old.mapboxPlaceId,
      isFavorite: isFavorite ?? old.isFavorite,
      lastUsedAt: lastUsedAt ?? old.lastUsedAt,
    );
  }
}
```

`test/support/fakes/fake_mapbox_search.dart`:

```dart
import 'package:tell_me_a_story/data/mapbox_search.dart';

/// [MapboxSearchGateway] that returns [hits] (at most `limit`) for every
/// query and records the queries. Set [error] to make [search] throw it.
class FakeMapboxSearch implements MapboxSearchGateway {
  FakeMapboxSearch({this.hits = const []});

  List<MapboxSearchHit> hits;
  Object? error;
  final queries = <String>[];

  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async {
    queries.add(query);
    final thrown = error;
    if (thrown != null) throw thrown;
    return hits.take(limit).toList();
  }
}
```

`test/support/fakes/fake_manage_families_gateway.dart`:

```dart
import 'package:tell_me_a_story/data/manage_families_api.dart';

/// [ManageFamiliesGateway] that records every call in [calls] as
/// `method:arg,arg` and succeeds. Set [error] to make every call throw it.
/// Subclass and override a method for anything else.
class FakeManageFamiliesGateway implements ManageFamiliesGateway {
  FakeManageFamiliesGateway({DateTime? resentUntil})
    : resentUntil = resentUntil ?? DateTime.utc(2030);

  /// What [resendInvite] returns.
  final DateTime resentUntil;

  final calls = <String>[];
  Object? error;

  void _record(String call) {
    calls.add(call);
    final thrown = error;
    if (thrown != null) throw thrown;
  }

  @override
  Future<String> createRootFamily(String name) async {
    _record('createRootFamily:$name');
    return 'family-root-${calls.length}';
  }

  @override
  Future<String> createBranchFamily({
    required String parentFamilyId,
    required String originStoryId,
    required String name,
    required int branchYear,
    required String ownerUserId,
    List<String> personIds = const [],
  }) async {
    _record(
      'createBranchFamily:$parentFamilyId,$originStoryId,$name,$branchYear,'
      '$ownerUserId,${personIds.join('+')}',
    );
    return 'family-branch-${calls.length}';
  }

  @override
  Future<void> renameFamily({
    required String familyId,
    required String name,
  }) async => _record('renameFamily:$familyId,$name');

  @override
  Future<void> addCoOwner({
    required String familyId,
    required String userId,
  }) async => _record('addCoOwner:$familyId,$userId');

  @override
  Future<void> removeCoOwner({
    required String familyId,
    required String userId,
  }) async => _record('removeCoOwner:$familyId,$userId');

  @override
  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async => _record('removeMember:$familyId,$userId');

  @override
  Future<void> transferOwnership({
    required String familyId,
    required String newOwnerUserId,
    required String formerOwnerBecomes,
  }) async => _record(
    'transferOwnership:$familyId,$newOwnerUserId,$formerOwnerBecomes',
  );

  @override
  Future<void> softDeleteFamily(String familyId) async =>
      _record('softDeleteFamily:$familyId');

  @override
  Future<void> recoverFamily(String familyId) async =>
      _record('recoverFamily:$familyId');

  @override
  Future<DateTime> resendInvite(String inviteId) async {
    _record('resendInvite:$inviteId');
    return resentUntil;
  }

  @override
  Future<void> revokeInvite(String inviteId) async =>
      _record('revokeInvite:$inviteId');
}
```

Run `mise exec -- dart format test/support && mise exec -- flutter analyze test/support`. Expected: `No issues found!` Commit: `git add test/support && git commit -m "test(client): shared gateway fakes"`.

- [ ] **Step 2: Migrate, one commit per gateway.** For each private fake in inventory below:
  1. If every overridden method equivalent to shared fake's behaviour or throws `UnimplementedError`, delete class, construct shared fake. Pass constructor values old fake returned, e.g. `FakeInviteGateway(familyId: _familyId, createdFamilyId: _familyId, acceptedFamilyId: 'f')`.
  2. Else change `implements XGateway` to `extends FakeXGateway`, delete every override matching shared behaviour, keep rest with its fields.
  3. Run `mise exec -- dart fix --apply --code=unused_import <file>` and file's tests.

  Worked example, already checked in scratch copy: `test/features/drafts/drafts_page_test.dart`:
  - delete `_FakeInviteApi` and `_StubMapboxSearch`;
  - use `FakeInviteGateway(familyId: _familyId, createdFamilyId: _familyId, acceptedFamilyId: 'f')` and `FakeMapboxSearch()`;
  - add two relative imports.

  Result: 11 tests pass, no analyzer issues.

  | Gateway (shared fake) | Files and private fakes (after Task 17) |
  |---|---|
  | `InviteGateway` (`FakeInviteGateway`) | `app/app_router_test` `_StubInviteApi`; `features/auth/invite_sign_in_page_test` `_Invites`; `features/drafts/drafts_page_test` `_FakeInviteApi`; `features/family/manage_families_page_test` `_HubInvite`; `features/family/manage_family_page_rename_guard_test` `_Invite`; `features/family/start_timeline_dialog_test` `_Invite`; `features/invites/invite_modal_test` `_StubInviteApi`; `features/people/people_profiles_test` `_Invites`; `features/people/person_dob_passed_away_test` `_Invites`; `features/search/search_page_test` `_Invite`; `features/settings/settings_page_guard_test` `_Invite`; `features/settings/settings_page_test` `_Invite`; `features/stories/new_story_page_capture_test` `_FakeInviteApi`; `features/stories/new_story_page_edit_guard_test` `_Invite`; `features/stories/new_story_page_guard_test` `_Invite`; `features/stories/new_story_page_logout_test` `_Invite`; `features/stories/new_story_page_shell_test` `_FakeInviteApi`; `features/timeline/timeline_page_test` `_FakeInviteApi`, `_FamilyInvite`; `ui/album/album_header_manage_entry_test` `_Invite` |
  | `StoriesGateway` (`FakeStoriesGateway`) | `app/app_router_test` `_StubStoriesApi`; `features/all_stories/all_stories_loader_test` `_Stories`; `features/all_stories/all_stories_page_test` `_Stories`; `features/drafts/drafts_page_test` `_FakeStoriesApi`; `features/family/start_timeline_dialog_test` `_Stories`, `_ReaderStories`; `features/stories/new_story_page_capture_test` `_FakeStoriesApi`; `features/stories/new_story_page_edit_guard_test` `_Stories`; `features/stories/new_story_page_guard_test` `_Stories`; `features/stories/new_story_page_logout_test` `_Stories`; `features/stories/new_story_page_shell_test` `_AutosaveStories`; `features/stories/story_reader_page_test` `_FakeStoriesApi`; `features/timeline/timeline_page_test` `_FakeStoriesApi` |
  | `PhotosGateway` (`FakePhotosGateway`) | `app/app_router_test` `_StubPhotosApi`; `data/stories_api_test` `_RecordingPhotos`; `features/all_stories/all_stories_page_test` `_Photos`; `features/drafts/drafts_page_test` `_FakePhotosApi`; `features/family/start_timeline_dialog_test` `_Photos`; `features/search/search_page_test` `_Photos`; `features/stories/new_story_page_capture_test` `_FakePhotosApi`; `features/stories/new_story_page_edit_guard_test` `_Photos`; `features/stories/new_story_page_guard_test` `_Photos`; `features/stories/new_story_page_logout_test` `_Photos`; `features/stories/story_reader_page_test` `_FakePhotosApi`; `features/timeline/timeline_page_test` `_FakePhotos` |
  | `PlacesGateway` (`FakePlacesGateway`) | `app/app_router_test` `_StubPlacesApi`; `features/drafts/drafts_page_test` `_StubPlacesApi`; `features/family/start_timeline_dialog_test` `_Places`; `features/places/place_picker_modal_test` `_FakePlacesGateway`; `features/stories/new_story_page_capture_test` `_FakePlacesApi`; `features/stories/new_story_page_edit_guard_test` `_Places`; `features/stories/new_story_page_guard_test` `_Places`; `features/stories/new_story_page_logout_test` `_Places`; `features/stories/new_story_page_shell_test` `_FakePlacesApi`; `features/stories/story_reader_page_test` `_FakePlacesApi` |
  | `MapboxSearchGateway` (`FakeMapboxSearch`) | `app/app_router_test` `_StubMapboxSearch`; `features/drafts/drafts_page_test` `_StubMapboxSearch`; `features/places/place_picker_modal_test` `_FakeSearchGateway`; `features/stories/new_story_page_capture_test` `_FakeMapboxSearch`; `features/stories/new_story_page_edit_guard_test` `_Mapbox`; `features/stories/new_story_page_guard_test` `_Mapbox`; `features/stories/new_story_page_logout_test` `_Mapbox`; `features/stories/new_story_page_shell_test` `_FakeMapboxSearch` |
  | `ManageFamiliesGateway` (`FakeManageFamiliesGateway`) | `features/family/manage_families_page_test` `_Manage`; `features/family/manage_family_page_rename_guard_test` `_Manage`; `features/family/start_timeline_dialog_test` `_Manage`; `features/people/people_profiles_test` `_Manage`; `features/timeline/timeline_page_test` `_FakeManage`; `ui/album/album_header_family_menu_test` `_NoManage`; `ui/album/album_header_manage_entry_test` `_Manage` |

  One commit per row, table order, e.g. `test(client): InviteGateway fakes use FakeInviteGateway`. After each commit:
  - gates pass with `+689 ~12` (same count: migration never deletes or adds test);
  - `grep -rn "implements <Gateway>" test --include=*_test.dart` lists only fakes kept on purpose. Name each kept fake + reason in commit body.

---

### Task 19: Docs, and close Phase 6

**Files:** `AGENTS.md`, `README.md`, roadmap, this plan, `docs/README.md`; move roadmap and Phase 5/6 plans into archive

- [ ] **Step 1: AGENTS.md "Layout".** Replace `apps/tell_me_a_story/` bullet with:

```markdown
- `apps/tell_me_a_story/`: Flutter client (iPad + web).
  - `lib/app`: router and app widget.
  - `lib/core`: config, route paths, server connection, theme tokens.
  - `lib/data`: gateways and session state.
  - `lib/ui`: widgets used by several features.
  - `lib/features/<feature>`: screens.
  - `test/` mirrors `lib/`; `test/architecture` holds the guards; `test/support/fakes` holds the shared gateway fakes; `test/live` (tag `live`); `integration_test/` (e2e).
```

- [ ] **Step 2: README "Layout".** Same replacement for `apps/tell_me_a_story/` bullet.

- [ ] **Step 3: Full gates.**
  - `mise exec -- just check`, `just test-live` against `just server`, e2e run from README (9/9).
  - Server test count unchanged since Task 0.
  - CI green on pushed branch.
  - `git grep -n -E "core/theme/album_header|core/navigation|features/stories/story_date|magic_link_page|MagicLinkPage" -- apps AGENTS.md README.md`: expected no output.

- [ ] **Step 4: Close the migration docs.**
  - Roadmap: append to `| 6. Restructure |` row ` **Landed <date>:** app <N>, server <N>, e2e 9/9.`
  - This plan: append `## As landed` (commits, Task 9 decisions, any fake kept on purpose).
  - Then archive three active migration plans:

```bash
for f in 2026-11-06-serverpod-migration-roadmap.md 2026-11-08-serverpod-phase5-cleanup.md 2026-11-08-serverpod-phase6-restructure.md; do
  git mv "docs/superpowers/plans/$f" "docs/archive/superpowers/plans/$f"
done
```

  - In `docs/README.md`, replace `superpowers/plans/` bullet with `` - `superpowers/plans/`: current plans (new plans go here, via superpowers:writing-plans). The Serverpod migration (Phases 1–6) is complete and archived. ``

- [ ] **Step 5: Commit.** `git add -A docs AGENTS.md README.md && git commit -m "docs: Phase 6 landed; migration plans archived"`

---

## Out of scope
- Splitting large files (`timeline_page.dart` is 3 769 lines). Timeline UI rework after migration decides structure.
- Timeline lab. Merges from own branch into `labs/timeline_lab`, with analyze-only CI job from Phase 5 plan (Task 4, Step 2).
- `docs/` "context folder" reorganisation (later phase).
- Renaming `magic-link-email` widget key (e2e contract; no behaviour change wanted).

## Exit criteria for Phase 6
- `lib/` matches "Target layout". `test/architecture/import_boundaries_test.dart` passes with no allowlist. `test/architecture/test_layout_test.dart` passes.
- Colour skip list lost six moved files, ceiling 17. Q-B "no": lost five, ceiling 18.
- No `MagicLinkPage` or `AppRoutes.magicLink`; `/` still opens sign-in page.
- Every test file under `lib/` folder it tests; no milestone names. Six shared fakes replace private gateway fakes, except ones named on purpose.
- App test count = Phase 5 exit + 3 (`+689 ~12` from 686). Server count unchanged. analyze ≤ 6. `just check`, `test-live`, e2e run, CI green.

## As landed

Landed 2026-11-07 on `feat/p6-restructure` (from `feature/serverpod` at `ddb7732`), not pushed. App `+689 ~12` (686 + 3), server `+425` (unchanged), analyze 6, `just check`, `just test-live` (`+27`), local e2e (9/9) green. CI not yet run (branch not pushed).

Commits (Task 19 docs commit follows):

```
d8f71ce refactor(client): package imports in lib (always_use_package_imports)
8494c9f test(client): architecture guards: import rules, colour skip-list ceiling
4fe5a48 refactor(client): MagicLinkPage → SignInPage, AppRoutes.magicLink → signIn (URL unchanged)
3d051a0 refactor(client): split AppRoutes and AlbumModalFrame out of the router; router and app widget move to lib/app
f2ad404 refactor(client): shared story widgets and storyTitle move to lib/ui/story
6738ae1 refactor(client): otp_sign_in and auth_refresh into data/; StorageFailedException into app_exception
dc3504f style(client): family_role uses album tokens; leaves the colour skip list
1633eec refactor(client): family_role, family_tree_order, leave_story_dialog and the unsaved guard move to lib/ui
d81d198 docs: Phase 6 token decisions
8e7fa20 style(client): album_chrome uses album tokens; leaves the colour skip list
d9f4ef0 style(client): album_header uses album tokens; leaves the colour skip list
b5a153c style(client): profile_avatar uses album tokens; leaves the colour skip list
82f68e8 style(client): family_blur_dialog uses album tokens; leaves the colour skip list
6dfa14f style(client): sign-in page uses album tokens; leaves the colour skip list
dd865e2 refactor(client): album chrome, header, avatar and blur dialog move to lib/ui; sign_in_page.dart
60e66fb test(client): import rules enforced without exceptions
3e6a641 test(client): app, core, data and ui tests mirror lib
6706eef test(client): feature tests mirror lib
275c86e test(client): milestone tests renamed by subject; m13 split by subject
85d558d test(client): guard that tests mirror lib and are named by subject
e89b7bc test(client): shared gateway fakes
35df9fb test(client): InviteGateway fakes use FakeInviteGateway
96540ec test(client): StoriesGateway fakes use FakeStoriesGateway
220282c test(client): PhotosGateway fakes use FakePhotosGateway
97dc2e4 test(client): PlacesGateway fakes use FakePlacesGateway
8cfc326 test(client): MapboxSearchGateway fakes use FakeMapboxSearch
a7c38de test(client): ManageFamiliesGateway fakes use FakeManageFamiliesGateway
```

**Task 9 decisions (owner, 2026-11-07).** Every hit without exact token got new token with today's exact value → every colour fix pixel-identical (AE 0 on every screenshot pair). Q-A yes: `token.withAlpha(n)` where ARGB identical. Q-B yes: sign-in page fixed before rename. New tokens in `core/theme/album_theme.dart`:

| Token | Value | Used by |
|---|---|---|
| `albumWhite` | `0xFFFFFFFF` | `PlusLabel` plus glyph, blur-dialog confirm text, sign-in landing card fills |
| `albumOnAccent` | `0xFFFFF6F3` | Publish story text, sign-in landing button text |
| `albumMenuSurface` | `0xFFFCF9F5` | header avatar menu fill |
| `albumAvatarFill` | `0xFFEDE0DC` | `ProfileAvatar.fill` |
| `albumAvatarBorder` | `0xFFD5C7B7` | `ProfileAvatar.borderColor` |
| `albumInviteBorder` | `0xFFE8DFD5` | send-invite card + note borders; divider via `.withAlpha(0x80)` |
| `albumInviteNoteFill` | `0xFFF7F1EA` | send-invite note fill |
| `albumLandingLine` | `0xFFB9B0AD` | sign-in landing lines (`_landingLine`) |
| `albumShadow` | `0xFF000000` | blur-dialog card shadow `.withAlpha(0x1A)`, sign-in card shadows `.withAlpha(0x0D)` |

Same-ARGB alpha forms: `albumInk.withAlpha(0x33)` (album dialog shadow), `.withAlpha(0x66)` (blur scrim), `.withAlpha(0x1A)` (send-invite shadow). Colour skip list ceiling: 17.

**Screenshot checks** (1280×800, DPR 1.25, e2e owner family; `/tmp/tmas-p6-shots/<stem>/`): `family_role` hub, detail, detail-members, transfer-dialog; `album_chrome` manage-members, capture-add-person-plus, album-dialog-add-person; `album_header` family-nav, family-menu, avatar-menu, capture-header; `profile_avatar` family-nav, settings, manage-members; `family_blur_dialog` remove-confirm, send-invite-confirm, add-co-owner-dialog; `sign_in_page` landing, code-step. All AE 0. Differences from planned screens: Task 7 and Task 10 screens corrected in plan (planned ones never drew edited colour); Task 12 used members list instead of person profile dialog; Task 13 used remove-member confirm + add-co-owner dialog instead of delete-family and leave-story (no data writes).

**Differences from the plan:** `dart fix` (Task 1) adds `flutter_web_plugins: any` to `pubspec.yaml`, reverted; four, not five, "to magic-link" test names (Task 3); `new_story_shell_test.dart` carried two `core/theme/album_header.dart` fixture strings, updated in Task 15.

**Fakes kept on purpose:** none keep `implements <Gateway>`. Private fakes differing from shared behaviour are subclasses (`extends FakeXGateway`) overriding only what differs; each named with reason in its migration commit body (`35df9fb`, `96540ec`, `220282c`, `97dc2e4`, `8cfc326`, `a7c38de`). Test-side changes: assertions read shared fakes' fields (`createdFamilyNames`, `sentInvites`, `queries`, `calls`, `photos`, `places`), and `people_profiles_test` expects shared fake's invite id `invite-1`.