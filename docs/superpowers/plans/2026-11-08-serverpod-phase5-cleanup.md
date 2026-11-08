# Phase 5: Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Run the tasks in order on `feat/p5-cleanup`, branched from `feature/serverpod` (the integration branch) once Phase 4 has merged into it; open one PR into `feature/serverpod`. Each task ends in one commit and must leave every gate green.

**Goal:** Remove the Supabase era from the repo. That means deleting the backend, its CI and tooling; moving the e2e flow check into `flutter test`; running CI on mise + just with a server job; archiving every existing doc; and rewriting `AGENTS.md`, the README and the hosting notes for the Serverpod stack.

**Architecture:** Deletions and tooling only. No file under `apps/tell_me_a_story/lib` moves; that is Phase 6 (`2026-11-08-serverpod-phase6-restructure.md`).
- `just` becomes the single entry point for every gate, and CI calls the same recipes.
- Every doc moves as-is into `docs/archive/`, keeping its path below `docs/`. Only three active files stay outside it: the roadmap and the Phase 5 and 6 plans.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13, Serverpod 4.1.1, mise 2026.11, just 1.46.0, GitHub Actions (`jdx/mise-action` v5.2.7).

**Inputs:**
- Roadmap Phase 5 row: `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md`.
- Structure proposal decisions of 2026-11-08 (Decisions section of the proposal handed over with this plan):
  - archive all docs (no deletes, no renames);
  - port `check_flows` to a Dart test;
  - the lab goes to `labs/` with an analyze-only CI job;
  - the restructure is Phase 6.

**Verification status of this plan (written 2026-11-08):**
- **Verified:**
  - Task 1: the test passes on the tree and fails on drift (scratch copy).
  - Task 3: the recipes were run in a scratch copy.
  - Task 4: the workflow passes `actionlint`; the mise-action pin was resolved from `refs/tags/v5.2.7`.
  - The baseline numbers: format 0 changed, app analyze 6, server analyze clean, app tests `+685 ~12`.
- **Unverified:**
  - the `just server-test` count;
  - Task 2's deletions and grep;
  - Task 4's first CI run (mise installing Flutter on `ubuntu-latest`; embedded Postgres in the `server` job);
  - Task 5's local e2e run;
  - Task 6's archive script and its expected count (86);
  - Tasks 7–9 (text only; `netlify.toml` parsed by nobody yet);
  - Task 10.

  Treat each "Expected" in those tasks as unverified until the step runs.

---

## Decisions this plan applies

| # | Decision | Where |
|---|---|---|
| P5-1 | `e2e/check_flows.sh` becomes `apps/tell_me_a_story/test/architecture/e2e_flow_manifest_test.dart` and runs inside `just test`. `e2e/` is deleted. | Task 1 |
| P5-2 | `supabase/`, `scripts/advisors/`, `advisors-prod.yml`, the `deno`/`pgtap` CI jobs, the supabase `just` recipes and the Supabase CLI in `mise.toml` are deleted. | Task 2 |
| P5-3 | New recipes `fmt-check`, `analyze` (ceiling 6), `server-analyze` and `check`. | Task 3 |
| P5-4 | CI uses `jdx/mise-action` (tool versions come only from `mise.toml`) and just recipes, and gains a `server` job. If `labs/timeline_lab` exists by then, it gets an analyze-only `lab` job. | Task 4 |
| P5-5 | The e2e signs in with the fixed dev code `111111`, which `just server` uses on a local server (`apps/server/lib/src/auth/auth_config.dart` `devLoginCode`). This landed in 4f; Phase 5 only verifies it. | Task 5 |
| P5-6 | All tracked files under `docs/` and `r1-shots/` move to `docs/archive/<same subpath>`, except the roadmap and the Phase 5/6 plans. Links that break are fixed. | Task 6 |
| P5-7 | `netlify.toml` stays the web host config; server hosting is not chosen yet. | Task 7 |
| P5-8 | `README.md`, `apps/tell_me_a_story/README.md` and `AGENTS.md` are rewritten for the Serverpod stack. | Tasks 8 and 9 |

**Out of scope:**
- Any move under `lib/` or `test/` (Phase 6).
- Production server hosting.
- Netlify UI settings (owner action; see Task 7).
- The timeline lab merge (its own branch).

---

## File map

| Path | Change | Task |
|---|---|---|
| `apps/tell_me_a_story/test/architecture/e2e_flow_manifest_test.dart` | Create | 1 |
| `apps/tell_me_a_story/integration_test/flows.md` | Modify line 3 | 1, 6 |
| `e2e/check_flows.sh` | Delete | 1 |
| `supabase/` (95 files), `scripts/advisors/` (12), `.github/workflows/advisors-prod.yml` | Delete | 2 |
| `.gitignore`, `mise.toml` | Modify | 2 |
| `justfile` | Modify | 2, 3 |
| `.github/workflows/ci.yml` | Modify (Task 1), rewrite (Task 4) | 1, 2, 4 |
| `docs/**` (77 tracked files) and `r1-shots/` (10) | Move to `docs/archive/` (except 3 active plans) | 6 |
| `docs/README.md` | Create | 6 |
| `apps/tell_me_a_story/lib/data/app_exception.dart` | Comment path | 6 |
| `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` | Rows and links | 0, 6, 10 |
| `netlify.toml` | Rewrite | 7 |
| `README.md`, `apps/tell_me_a_story/README.md` | Rewrite | 8 |
| `AGENTS.md` | Rewrite | 9 |

---

### Task 0: Preconditions and baseline

**Files:**
- Modify: `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` (Phase 5 row, new Phase 6 row)

- [ ] **Step 1: Check the branch and tree**

Run: `git status --short && git rev-parse --abbrev-ref HEAD` (in the checkout or worktree that holds `feat/p5-cleanup`)
Expected: nothing, then `feat/p5-cleanup`. Anything else is the owner's work: stop and ask.

- [ ] **Step 2: Record the baseline** (all from the repo root)

```bash
mise exec -- just server-setup
(cd apps/tell_me_a_story && mise exec -- flutter pub get --enforce-lockfile)
(cd apps/tell_me_a_story && mise exec -- dart format --output=none --set-exit-if-changed .)
(cd apps/server && mise exec -- dart format --output=none --set-exit-if-changed .)
(cd apps/tell_me_a_story && mise exec -- flutter analyze --no-fatal-infos --no-fatal-warnings | tail -n 1)
(cd apps/server && mise exec -- dart analyze --fatal-infos | tail -n 1)
mise exec -- just test 2>&1 | tail -n 1
mise exec -- just server-test 2>&1 | tail -n 1
bash e2e/check_flows.sh
```

Expected:
- Both format runs: `(0 changed)`.
- App analyze: `6 issues found.`
- Server analyze: `No issues found!`
- `just test`: `+685 ~12: All tests passed!` (this count was measured at `de30ef5`; if yours differs, write yours down and use it below).
- `just server-test`: `All tests passed!`; write down the `+N` count (measured `+425` at `501910b`).
- `check_flows: 9 flows match (…)`.

Every later "test count unchanged" check compares against these numbers.

- [ ] **Step 3: Point the roadmap at the plans**

In `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md`, replace the last cell of the `| 5. Cleanup |` row, `written at Phase 4 close`, with `` `2026-11-08-serverpod-phase5-cleanup.md` ``. Add this row after it (already applied in `501910b`, together with both plans; then this step and Step 4 have nothing to add beyond these plan-text fixes):

```markdown
| 6. Restructure | `lib/` gets `app/` and `ui/` layers with enforced import rules; `test/` mirrors `lib/`; hard-coded colours in the moved files become tokens; `MagicLinkPage` → `SignInPage`; shared test fakes | `2026-11-08-serverpod-phase6-restructure.md` |
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-11-08-serverpod-phase5-cleanup.md docs/superpowers/plans/2026-11-08-serverpod-phase6-restructure.md docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md
git commit -m "docs: Phase 5 and Phase 6 plans"
```

---

### Task 1: The e2e flow check becomes a Dart test

**Files:**
- Create: `apps/tell_me_a_story/test/architecture/e2e_flow_manifest_test.dart`
- Modify: `apps/tell_me_a_story/integration_test/flows.md:3`
- Modify: `.github/workflows/ci.yml` (drop the `e2e flow manifest` step)
- Delete: `e2e/check_flows.sh`

The test is a line-by-line port of `e2e/check_flows.sh`. It checks:
- rows `| C<n> |`;
- unique ids;
- at most 10 flows;
- names start with the id and match `^C[0-9]+ [a-z0-9 ,/-]+$`;
- names are at most 64 characters;
- every backticked owning path exists under `lib/`;
- the sorted names equal the quoted `'C<n> …'` names in `e2e_test.dart`;
- the `testWidgets(` count equals the row count;
- there is no `testWidgets(` under `integration_test/support`.

This code was run against the current tree in a scratch copy: it passes, and it fails with a diff when a flow name is changed.

- [ ] **Step 1: Write the test**

Create `apps/tell_me_a_story/test/architecture/e2e_flow_manifest_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The e2e flow manifest check: integration_test/flows.md and the
// testWidgets names in integration_test/e2e_test.dart must agree, and every
// owning path must exist under lib/. Reads files only. Run from
// apps/tell_me_a_story (flutter test does).

const _manifestPath = 'integration_test/flows.md';
const _entryPath = 'integration_test/e2e_test.dart';
const _supportPath = 'integration_test/support';
const _flowBudget = 10;
const _maxNameLength = 64;

final _rowPattern = RegExp(r'^\| C[0-9]+ \|');
final _namePattern = RegExp(r'^C[0-9]+ [a-z0-9 ,/-]+$');
final _quotedName = RegExp(r"'(C[0-9]+ [^'\n]*)'");
final _backticked = RegExp(r'`([^`]+)`');

class _Flow {
  const _Flow(this.id, this.name, this.paths);

  final String id;
  final String name;
  final List<String> paths;
}

List<_Flow> _readFlows(String manifest) {
  final flows = <_Flow>[];
  for (final line in manifest.split('\n')) {
    if (!_rowPattern.hasMatch(line)) continue;
    // | Flow | Test name | Spec source | Owning paths |
    final cells = line.split('|');
    flows.add(
      _Flow(cells[1].trim(), cells[2].trim().replaceAll('`', ''), [
        for (final match in _backticked.allMatches(cells[4])) match.group(1)!,
      ]),
    );
  }
  return flows;
}

void main() {
  test('flows.md and e2e_test.dart agree', () {
    final manifestFile = File(_manifestPath);
    final entryFile = File(_entryPath);
    expect(
      manifestFile.existsSync(),
      isTrue,
      reason: 'missing $_manifestPath; run from apps/tell_me_a_story',
    );
    expect(entryFile.existsSync(), isTrue, reason: 'missing $_entryPath');

    final flows = _readFlows(manifestFile.readAsStringSync());
    expect(flows, isNotEmpty, reason: 'no flow rows in $_manifestPath');

    final errors = <String>[];
    final seen = <String>{};
    final duplicates = <String>{};
    for (final flow in flows) {
      if (!seen.add(flow.id)) duplicates.add(flow.id);
    }
    if (duplicates.isNotEmpty) {
      errors.add('duplicate flow ids: ${duplicates.join(' ')}');
    }
    if (flows.length > _flowBudget) {
      errors.add('${flows.length} flows is over the U4 budget of $_flowBudget');
    }

    for (final flow in flows) {
      if (!flow.name.startsWith('${flow.id} ')) {
        errors.add(
          "${flow.id}: test name '${flow.name}' does not start with "
          "'${flow.id} '",
        );
      }
      if (!_namePattern.hasMatch(flow.name)) {
        errors.add(
          "${flow.id}: test name '${flow.name}' has characters outside "
          '[a-z0-9 ,/-]',
        );
      }
      if (flow.name.length > _maxNameLength) {
        errors.add('${flow.id}: test name is over $_maxNameLength characters');
      }
      for (final path in flow.paths) {
        if (FileSystemEntity.typeSync('lib/$path') ==
            FileSystemEntityType.notFound) {
          errors.add('${flow.id}: owning path lib/$path does not exist');
        }
      }
    }

    final entry = entryFile.readAsStringSync();
    final tests = [
      for (final match in _quotedName.allMatches(entry)) match.group(1)!,
    ].where(_namePattern.hasMatch).toList()..sort();
    final want = [for (final flow in flows) flow.name]..sort();
    if (tests.join('\n') != want.join('\n')) {
      errors.add(
        'flows.md and e2e_test.dart disagree:\n'
        '  only in flows.md: ${want.where((n) => !tests.contains(n)).toList()}\n'
        '  only in e2e_test.dart: ${tests.where((n) => !want.contains(n)).toList()}',
      );
    }

    final calls = 'testWidgets('.allMatches(entry).length;
    if (calls != flows.length) {
      errors.add(
        'e2e_test.dart has $calls testWidgets calls; '
        'flows.md has ${flows.length} rows',
      );
    }

    final support = Directory(_supportPath);
    if (support.existsSync()) {
      for (final entity in support.listSync(recursive: true)) {
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            entity.readAsStringSync().contains('testWidgets(')) {
          errors.add(
            'testWidgets( found in ${entity.path}; '
            'tests live only in e2e_test.dart',
          );
        }
      }
    }

    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
```

- [ ] **Step 2: Run it on the real manifest**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/architecture/e2e_flow_manifest_test.dart`
Expected: `+1: All tests passed!`

- [ ] **Step 3: Prove it catches a drift**

In `integration_test/flows.md`, change the C3 test name `` `C3 capture and publish shows the card on the timeline` `` to `` `C3 capture and publish shows the card` ``, then run the same command.
Expected: FAIL, with `flows.md and e2e_test.dart disagree:` followed by `only in flows.md: [C3 capture and publish shows the card]` and `only in e2e_test.dart: [C3 capture and publish shows the card on the timeline]`.
Restore the file: `git checkout -- apps/tell_me_a_story/integration_test/flows.md`. Run it again; expected PASS.

- [ ] **Step 4: Update the manifest header**

In `apps/tell_me_a_story/integration_test/flows.md`, replace line 3:

```markdown
Lock: `docs/design-doc/e2e.md` (U1) and `docs/design-doc/e2e-addendum-a.md`. `test/architecture/e2e_flow_manifest_test.dart` checks this file in `flutter test`. One row per flow. The test name is the exact `testWidgets` description in `e2e_test.dart`. Owning paths are relative to `apps/tell_me_a_story/lib/`.
```

(Task 6 changes the two `docs/design-doc/` paths to their archive paths.)

- [ ] **Step 5: Delete the script and its CI step**

```bash
git rm e2e/check_flows.sh
```

In `.github/workflows/ci.yml`, job `e2e`, delete these lines (with the blank line after them):

```yaml
      - name: e2e flow manifest
        run: bash e2e/check_flows.sh
```

Run: `git grep -n "check_flows" -- . ':!docs'`
Expected: no output.

- [ ] **Step 6: Gates**

```bash
cd apps/tell_me_a_story
mise exec -- dart format --output=none --set-exit-if-changed .
mise exec -- flutter analyze --no-fatal-infos --no-fatal-warnings | tail -n 1
mise exec -- flutter test 2>&1 | tail -n 1
```

Expected:
- format `(0 changed)`;
- analyze `6 issues found.`;
- tests `+686 ~12: All tests passed!`, the baseline + 1.

- [ ] **Step 7: Commit**

```bash
git add -A apps/tell_me_a_story/test/architecture apps/tell_me_a_story/integration_test/flows.md .github/workflows/ci.yml
git commit -m "test(client): e2e flow manifest check runs in flutter test; drop e2e/check_flows.sh"
```

---

### Task 2: Delete the Supabase backend and its tooling

**Files:**
- Delete: `supabase/`, `scripts/advisors/`, `.github/workflows/advisors-prod.yml`
- Modify: `.github/workflows/ci.yml` (delete jobs `deno` and `pgtap`), `justfile`, `mise.toml`, `.gitignore`

- [ ] **Step 1: Delete the directories and the prod workflow**

```bash
git rm -r -q supabase scripts/advisors .github/workflows/advisors-prod.yml
ls scripts 2>/dev/null || echo "scripts/ gone"
```

Expected: `scripts/ gone`. If `scripts/` still lists anything, it is untracked: stop and ask.

- [ ] **Step 2: Delete the `deno` and `pgtap` jobs**

In `.github/workflows/ci.yml`, delete everything from the line `  deno:` down to the line before `  e2e:`. That removes both jobs and leaves `flutter` and `e2e`. Leave the top-level `env:` block (`ANALYZE_CEILING: 27`); Task 4 replaces the whole file.

- [ ] **Step 3: Delete the Supabase recipes**

In `justfile`, delete these recipes with their comment lines: `supabase-start`, `db-reset`, `db-test` and `functions-serve` (the blocks from `# supabase start` through `supabase test db`, and from `# supabase functions serve …` through `supabase functions serve --env-file supabase/.env.local`).

- [ ] **Step 4: Drop the Supabase CLI from mise**

Replace `mise.toml` with:

```toml
# Tool versions for local dev and CI. CI installs exactly these through
# jdx/mise-action; this file is the only place they are pinned.
[tools]
flutter = "3.47.7"
just = "1.46.0"
```

- [ ] **Step 5: Drop the Supabase ignores**

In `.gitignore`, delete the block:

```gitignore
# Supabase local
supabase/.branches
supabase/.temp
```

(keep the blank-line structure: one blank line between the remaining blocks).

- [ ] **Step 6: Check that nothing outside docs still points at the old backend**

Run: `git grep -n -i -E "supabase|deno|pgtap|splinter|advisors" -- . ':!docs'`
Expected: matches only in `AGENTS.md`, `README.md` (Tasks 8 and 9 rewrite them) and `netlify.toml` line 3 (Task 7).

- [ ] **Step 7: Gates**

```bash
mise exec -- just --list
mise exec -- just test 2>&1 | tail -n 1
```

Expected: `just --list` shows no `supabase-start`, `db-reset`, `db-test` or `functions-serve`. Tests: `+686 ~12: All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add -A .github justfile mise.toml .gitignore   # the git rm in Step 1 already staged supabase/ and scripts/; naming them here fails with "pathspec did not match"
git commit -m "chore: remove Supabase backend, advisors and their CI, recipes and CLI"
```

---

### Task 3: `just` gate recipes

**Files:**
- Modify: `justfile` (append four recipes)

`analyze` ports the CI ceiling script:
- any `error •` line fails;
- otherwise the issue count must be at most the ceiling.

The ceiling is 6 (the count at Phase 4 close). It is only ever lowered. `fmt-check` needs `pub get` to have run in both packages: `just server-setup`, plus `flutter pub get` in the app. These recipes were run in a scratch copy of the repo: `fmt-check` reported 0 changed, `analyze` reported `analyze: 6 issues (ceiling 6)`, `analyze 5` failed, and `server-analyze` reported `No issues found!`.

- [ ] **Step 1: Append the recipes**

Append to `justfile`:

```just

# dart format check: app and server (the generated client package is not checked)
fmt-check:
    cd apps/tell_me_a_story && dart format --output=none --set-exit-if-changed .
    cd apps/server && dart format --output=none --set-exit-if-changed .

# flutter analyze in apps/tell_me_a_story: any error fails, and at most `ceiling` other issues
analyze ceiling="6":
    #!/usr/bin/env bash
    set -uo pipefail
    cd apps/tell_me_a_story
    out="$(mktemp)"
    trap 'rm -f "$out"' EXIT
    flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee "$out"
    rc=${PIPESTATUS[0]}
    if grep -qF 'error •' "$out"; then
        echo "analyze: errors found (exit $rc)" >&2
        exit 1
    fi
    if grep -qF 'No issues found!' "$out"; then
        count=0
    else
        count=$( { grep -vF '•' "$out" | grep -Eo '[0-9]+ issues? found\.' | tail -n 1 | grep -Eo '^[0-9]+'; } || true )
    fi
    if [ -z "$count" ]; then
        echo "analyze: no issue count in the output (exit $rc)" >&2
        exit 1
    fi
    echo "analyze: $count issues (ceiling {{ceiling}})"
    if [ "$count" -gt {{ceiling}} ]; then
        echo "analyze: $count issues is over the ceiling of {{ceiling}}" >&2
        exit 1
    fi
    if [ "$rc" -ne 0 ]; then
        echo "analyze: exit $rc with no error lines" >&2
        exit 1
    fi

# dart analyze in apps/server; any issue fails
server-analyze:
    cd apps/server && dart analyze --fatal-infos

# Every local gate: format, analyze, app tests, server analyze and server tests
check: fmt-check analyze test server-analyze server-test
```

- [ ] **Step 2: Run each recipe**

```bash
mise exec -- just fmt-check
mise exec -- just analyze | tail -n 1
mise exec -- just analyze 5; echo "exit=$?"
mise exec -- just server-analyze
mise exec -- just check 2>&1 | tail -n 3
```

Expected:
- `fmt-check`: `(0 changed)` twice.
- `analyze`: `analyze: 6 issues (ceiling 6)`.
- `analyze 5`: `analyze: 6 issues is over the ceiling of 5`, then `exit=1`.
- `server-analyze`: `No issues found!`.
- `check` ends with the server test summary `All tests passed!`.

- [ ] **Step 3: Commit**

```bash
git add justfile
git commit -m "chore(just): fmt-check, analyze (ceiling 6), server-analyze and check recipes"
```

---

### Task 4: CI on mise + just, with a server job

**Files:**
- Rewrite: `.github/workflows/ci.yml`

`jdx/mise-action` installs Flutter (mise backend `http:flutter`) and just from `mise.toml`, so CI and local runs use the same pins. The action pin below is the commit of tag `v5.2.7` (`refs/tags/v5.2.7` → `b44d12e7d0d8ee7461bb893e1b1993500433185b`, a lightweight tag on a commit).

**Owner approval:** this adds a new third-party action and drops `subosito/flutter-action` and `extractions/setup-just`. Name that in the PR body.

- [ ] **Step 1: Replace `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

permissions:
  contents: read

jobs:
  app:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    defaults:
      run:
        shell: bash
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          persist-credentials: false

      - uses: jdx/mise-action@b44d12e7d0d8ee7461bb893e1b1993500433185b # v5.2.7

      - name: tool versions
        run: |
          flutter --version
          just --version

      - name: pub get (app and server)
        run: |
          (cd apps/tell_me_a_story && flutter pub get --enforce-lockfile)
          (cd apps/server && dart pub get --enforce-lockfile)

      - name: just fmt-check
        run: just fmt-check

      - name: just analyze
        run: just analyze

      - name: just test
        run: just test

  server:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    defaults:
      run:
        shell: bash
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          persist-credentials: false

      - uses: jdx/mise-action@b44d12e7d0d8ee7461bb893e1b1993500433185b # v5.2.7

      - name: server packages and passwords
        run: |
          (cd apps/server && dart pub get --enforce-lockfile)
          just server-passwords

      - name: just server-analyze
        run: just server-analyze

      - name: just server-test
        run: just server-test

  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 25
    defaults:
      run:
        shell: bash
    env:
      SERVER_URL: "http://127.0.0.1:8080"
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
        with:
          persist-credentials: false

      - uses: jdx/mise-action@b44d12e7d0d8ee7461bb893e1b1993500433185b # v5.2.7

      - name: server packages and passwords
        run: |
          (cd apps/server && dart pub get --enforce-lockfile)
          just server-passwords

      - name: just server (background)
        run: |
          just server > "$RUNNER_TEMP/server.log" 2>&1 &
          echo $! > "$RUNNER_TEMP/server.pid"

      - name: flutter pub get
        working-directory: apps/tell_me_a_story
        run: flutter pub get --enforce-lockfile

      - name: chrome and chromedriver (preinstalled, versions must match)
        run: |
          chrome="$(command -v google-chrome)"
          driver="${CHROMEWEBDRIVER:?CHROMEWEBDRIVER is not set}/chromedriver"
          test -x "$driver"
          cv="$("$chrome" --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
          dv="$("$driver" --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
          echo "chrome ${cv} (${chrome})"
          echo "chromedriver ${dv} (${driver})"
          if [ -z "$cv" ] || [ -z "$dv" ] || [ "${cv%.*}" != "${dv%.*}" ]; then
            echo "e2e: chromedriver ${dv} does not match Chrome ${cv} (MAJOR.MINOR.BUILD)" >&2
            exit 1
          fi
          "$driver" --port=4444 > "$RUNNER_TEMP/chromedriver.log" 2>&1 &
          curl -fsS --retry 20 --retry-connrefused --retry-max-time 30 http://127.0.0.1:4444/status > /dev/null
          echo "chromedriver listening on 127.0.0.1:4444"

      - name: await just server
        run: |
          pid="$(cat "$RUNNER_TEMP/server.pid")"
          deadline=$((SECONDS + 300))
          until [ "$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' "$SERVER_URL/")" != 000 ]; do
            if ! kill -0 "$pid" 2>/dev/null; then
              echo "e2e: just server exited before listening on $SERVER_URL" >&2
              exit 1
            fi
            if [ "$SECONDS" -ge "$deadline" ]; then
              echo "e2e: just server did not listen on $SERVER_URL within 300 s" >&2
              exit 1
            fi
            sleep 2
          done
          echo "just server listening on $SERVER_URL"

      - name: flutter drive (e2e)
        working-directory: apps/tell_me_a_story
        run: |
          flutter drive \
            --driver=test_driver/integration_test.dart \
            --target=integration_test/e2e_test.dart \
            -d web-server --web-port=3000 --web-hostname=127.0.0.1 \
            --browser-name=chrome --driver-port=4444 --headless \
            --chrome-binary="$(command -v google-chrome)" \
            --dart-define=SERVER_URL="$SERVER_URL"

      - name: e2e logs (server, chromedriver)
        if: always()
        run: |
          for f in server.log chromedriver.log; do
            if [ -f "$RUNNER_TEMP/$f" ]; then
              echo "== $f"
              cat "$RUNNER_TEMP/$f"
            fi
          done
```

- [ ] **Step 2 (only if `labs/timeline_lab/` exists on the branch): add the analyze-only lab job**

Append under `jobs:`:

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

If the lab is not on the branch yet, skip this step. The lab's own merge adds this job.

- [ ] **Step 3: Lint the workflow locally**

Run: `actionlint .github/workflows/ci.yml && echo actionlint-ok` (`brew install actionlint` if missing; the workflow above, with the lab job appended, was checked with actionlint 1.x and passes).
Expected: `actionlint-ok`.
Run: `git grep -n -E "subosito|setup-just|ANALYZE_CEILING|deno|supabase" -- .github`
Expected: no output.

- [ ] **Step 4: Commit and push; watch the first run**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: mise + just; app, server and e2e jobs"
git push
```

Expected on the PR checks:
- `app`, `server` and `e2e` are green;
- the `server` log shows the same `+N` as the Task 0 baseline.

Two failure modes have known causes:
- **mise cannot install Flutter on `ubuntu-latest`:** the mise backend `http:flutter` is unexercised in CI. Fix it in one commit by restoring `subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0` (with `flutter-version: "3.47.7"`) before the mise step in each job, and setting `MISE_DISABLE_TOOLS: flutter` in the job `env`. Report this in the PR.
- **Embedded Postgres in `server`:** 4f noted that its first CI start was unexercised. If it fails, attach the `server-test` log and stop.

---

### Task 5: The e2e signs in with the dev code

**Files:** none (verification only)

The roadmap's "e2e reads the dev OTP code" landed in 4f. A local server (`isLocalPod`: run mode development or test with an embedded Postgres) generates the fixed code `devLoginCode = '111111'` (`apps/server/lib/src/auth/auth_config.dart`). The e2e types `_devLoginCode = '111111'` (`apps/tell_me_a_story/integration_test/e2e_test.dart`).

- [ ] **Step 1: Check the three copies of the code agree**

Run: `git grep -n -E "(_)?devLoginCode = " -- apps`
Expected: three lines, all `'111111'`:
- `apps/server/lib/src/auth/auth_config.dart`;
- `apps/tell_me_a_story/integration_test/e2e_test.dart`;
- `apps/tell_me_a_story/test/live/support/live_server.dart`.

- [ ] **Step 2: Run the e2e locally**

```bash
# shell 1 (repo root)
mise exec -- just server
# shell 2: chromedriver matching your Chrome major.minor.build
chromedriver --port=4444
# shell 3
cd apps/tell_me_a_story
mise exec -- flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/e2e_test.dart \
  -d web-server --web-port=3000 --web-hostname=127.0.0.1 \
  --browser-name=chrome --driver-port=4444 \
  --dart-define=SERVER_URL=http://127.0.0.1:8080
```

Expected: `All tests passed!` with the 9 flows C1–C9. No commit.

---

### Task 6: Archive every doc and fix the links that break

**Files:**
- Move: every tracked file under `docs/` (77) and `r1-shots/` (10), except the roadmap and the Phase 5/6 plans, to `docs/archive/`
- Create: `docs/README.md`
- Modify:
  - `apps/tell_me_a_story/integration_test/flows.md:3`;
  - `apps/tell_me_a_story/lib/data/app_exception.dart:4`;
  - `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` (links);
  - `docs/superpowers/plans/2026-11-08-serverpod-phase6-restructure.md` (none: it already uses archive paths).

Path rule: `docs/<x>` → `docs/archive/<x>`; `r1-shots/<x>` → `docs/archive/r1-shots/<x>`. File names are kept, so relative links between archived docs keep working (they only link to siblings, e.g. `[82-family-switch.md](82-family-switch.md)`). Server and generated-client comments that cite bare file names (`business-rules.md §3.4`, `schema-design.md §4.2`) stay valid and are not edited. Only path citations change.

- [ ] **Step 1: Check that nothing under `docs/` is untracked**

Run: `git status --short docs r1-shots`
Expected: no output. An untracked file belongs to the owner: stop and ask before moving anything.

- [ ] **Step 2: Move**

```bash
keep='^docs/superpowers/plans/(2026-11-06-serverpod-migration-roadmap|2026-11-08-serverpod-phase5-cleanup|2026-11-08-serverpod-phase6-restructure)\.md$'
git ls-files docs r1-shots | grep -Ev "$keep" | while read -r f; do
  case "$f" in
    docs/*) dest="docs/archive/${f#docs/}" ;;
    *) dest="docs/archive/$f" ;;
  esac
  mkdir -p "$(dirname "$dest")"
  git mv "$f" "$dest"
done
git status --short | grep -c '^R'
git ls-files docs | grep -v '^docs/archive/'
```

Expected:
- the rename count is `86`;
- the last command prints exactly the three kept plan files.

- [ ] **Step 3: Write `docs/README.md`**

```markdown
# Docs

- `superpowers/plans/`: current plans. Today that is the Serverpod migration roadmap and the Phase 5 and Phase 6 plans. New plans go here (superpowers:writing-plans).
- `archive/`: every doc written before 2026-11-08, moved unchanged: `docs/<path>` became `docs/archive/<path>`, and the root `r1-shots/` became `docs/archive/r1-shots/`. It holds the Supabase-era impl spec, design doc and UX notes, the migration specs (`archive/migration/business-rules.md`, `endpoint-contract.md`, `schema-design.md`, `serverpod-notes.md`) and all earlier plans. Treat it as history: a current plan wins over anything in it. A later phase reorganises the docs into a context folder.
```

- [ ] **Step 4: Fix the path citations**

1. `apps/tell_me_a_story/integration_test/flows.md` line 3: replace `` `docs/design-doc/e2e.md` `` with `` `docs/archive/design-doc/e2e.md` ``, and `` `docs/design-doc/e2e-addendum-a.md` `` with `` `docs/archive/design-doc/e2e-addendum-a.md` ``.
2. `apps/tell_me_a_story/lib/data/app_exception.dart` line 4: replace `/// docs/migration/endpoint-contract.md §2.1. [unauthenticated] corresponds` with `/// docs/archive/migration/endpoint-contract.md §2.1. [unauthenticated] corresponds`. Run `dart format` on the file; if the line passes 80 columns, reflow the comment so the meaning is unchanged.
3. In the roadmap:
   - replace each `` `docs/migration/ `` with `` `docs/archive/migration/ `` in the "Reference inputs" list;
   - add this sentence after the "Detailed plan" table: `Plans for Phases 1–4 are in \`docs/archive/superpowers/plans/\`.`

- [ ] **Step 5: Check that no live link is left**

Run: `git grep -n -E "docs/(design-doc|impl-spec|m14-review|migration|plans|ux)/|r1-shots/" -- . ':!docs/archive' ':!README.md' ':!AGENTS.md'`
Expected: no output (`README.md` and `AGENTS.md` are rewritten in Tasks 8 and 9).

- [ ] **Step 6: Gates**

```bash
mise exec -- just fmt-check
mise exec -- just test 2>&1 | tail -n 1
```

Expected: `(0 changed)` twice; `+686 ~12: All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add -A docs r1-shots apps/tell_me_a_story/integration_test/flows.md apps/tell_me_a_story/lib/data/app_exception.dart
git commit -m "docs: archive every existing doc under docs/archive; fix live links"
```

---

### Task 7: Hosting notes (`netlify.toml`)

**Files:**
- Rewrite: `netlify.toml`

Netlify builds the web app from settings in the Netlify UI, which are not in the repo. The app now needs `--dart-define=SERVER_URL=<absolute server URL>`; `Env.validate()` throws at startup without it. No production server exists yet. Changing the Netlify UI build command and choosing a server host are owner actions (AGENTS: no hosted config changes). This task only fixes the repo side:
- the build-skip rule must also rebuild when the generated client changes, because the app depends on it by path;
- the stale Supabase comment goes.

- [ ] **Step 1: Replace `netlify.toml`**

```toml
# Netlify hosts the Flutter web app (apps/tell_me_a_story). The build command
# lives in the Netlify UI and must pass the defines the app reads:
#   --dart-define=SERVER_URL=<absolute Serverpod URL>   (required; the app
#     refuses to start without it)
#   --dart-define=INVITE_APP_ORIGIN=<this site's origin>
#   --dart-define=MAPBOX_ACCESS_TOKEN=<public token>    (optional)
# The Serverpod server is hosted elsewhere (not chosen yet).

# Skip the build when neither the app, its generated client package nor this
# file changed. Exit 0 = cancel build; exit 1 = continue.
# Docs-, CI-, server- and lab-only commits are skipped.
# https://docs.netlify.com/build/configure-builds/ignore-builds/

[build]
  ignore = """
if [ -z "$CACHED_COMMIT_REF" ]; then
  exit 1
fi
git diff --quiet "$CACHED_COMMIT_REF" "$COMMIT_REF" -- \
  apps/tell_me_a_story/ \
  packages/tell_me_a_story_client/ \
  netlify.toml
"""

# Path URLs (no hash) need a rewrite so a refresh of /timeline or
# /invite/:token serves the Flutter app. Existing files still win.
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

- [ ] **Step 2: Check the TOML parses**

Run: `python3 -c 'import tomllib;tomllib.load(open("netlify.toml","rb"));print("toml ok")'`
Expected: `toml ok`.

- [ ] **Step 3: Commit, and record the owner action**

```bash
git add netlify.toml
git commit -m "chore(netlify): document the Serverpod defines; rebuild on client package changes"
```

PR body: **Owner action.** Update the Netlify build command to pass `SERVER_URL` (and `INVITE_APP_ORIGIN`), and choose the server host. The deployed site will not start until `SERVER_URL` is set.

---

### Task 8: README rewrite

**Files:**
- Rewrite: `README.md`
- Rewrite: `apps/tell_me_a_story/README.md` (currently the Flutter template)

- [ ] **Step 1: Replace `README.md`**

````markdown
# Tell Me a Story

Private family storytelling app (Mortang): a Flutter client for iPad and web on a Serverpod (Dart) server with PostgreSQL.

## Layout

- `apps/tell_me_a_story/`: Flutter client.
  - `lib/core`: config, server connection, router, theme tokens.
  - `lib/data`: one gateway per backend area (models, `XGateway`, `XApi` on the generated client).
  - `lib/features/<feature>`: screens.
  - Tests: `test/` (unit and widget), `test/live` (needs `just server`), `integration_test/` (e2e).
- `apps/server/`: Serverpod 4.1.1 server.
  - Endpoints: `lib/src/endpoints`.
  - Rules: `lib/src/<domain>`.
  - Models: `lib/src/models/*.spy.yaml`.
  - Migrations: `migrations/`.
  - Tests: `test/unit`, `test/integration`.
- `packages/tell_me_a_story_client/`: generated client (`just server-generate`); never edit by hand.
- `docs/`: `superpowers/plans/` holds current plans; `archive/` holds history.

## Setup

Needs [mise](https://mise.jdx.dev). From the repo root:

```bash
mise install            # Flutter 3.47.7 and just 1.46.0 from mise.toml
just server-setup       # serverpod_cli 4.1.1, server and client packages, local passwords
(cd apps/tell_me_a_story && flutter pub get)
```

`just server-passwords` writes `apps/server/config/passwords.yaml` with random local secrets. It is git-ignored; never commit it.

## Run locally

```bash
just server   # API on http://127.0.0.1:8080; embedded Postgres; migrations applied
just run      # web app on http://127.0.0.1:3000 (alias: just web)
```

Sign in with any email. A local server does not send mail: the sign-in code is always `111111`. For the map and place search, pass a public Mapbox token: `MAPBOX_ACCESS_TOKEN=pk... just run`.

App defines (`--dart-define`): `SERVER_URL` (required), `INVITE_APP_ORIGIN` (default `http://127.0.0.1:3000`), `MAPBOX_ACCESS_TOKEN` (optional).

## Tests and gates

```bash
just check       # fmt-check, analyze (ceiling 6), test, server-analyze, server-test
just test        # app unit and widget tests (includes the e2e flow manifest check)
just server-test # server unit and integration tests (embedded Postgres)
just test-live   # app gateways against a running `just server`
```

End-to-end tests: start `just server`, start a `chromedriver --port=4444` that matches your Chrome, then:

```bash
cd apps/tell_me_a_story
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/e2e_test.dart \
  -d web-server --web-port=3000 --web-hostname=127.0.0.1 \
  --browser-name=chrome --driver-port=4444 \
  --dart-define=SERVER_URL=http://127.0.0.1:8080
```

`integration_test/flows.md` lists the flows. `just test` fails if it and `e2e_test.dart` disagree.

## Server changes

Edit models in `apps/server/lib/src/models/*.spy.yaml` or endpoints, then:

```bash
just server-generate          # regenerates server protocol, client package, test tools
just server-migration <tag>   # only when the database schema changed
```

Never edit a migration that already exists.

## Hosting

Netlify builds the web app (`netlify.toml`). The Serverpod server's production host is not chosen yet.
````

- [ ] **Step 2: Replace `apps/tell_me_a_story/README.md`**

```markdown
# tell_me_a_story (Flutter client)

The iPad and web client. Setup, run and test commands are in the repo root `README.md`; run them from the repo root with `just`.
```

- [ ] **Step 3: Check every command in the README exists**

Run: `mise exec -- just --list | grep -E "^\s+(check|test|test-live|server|server-setup|server-passwords|server-generate|server-migration|server-test|run|fmt-check|analyze|server-analyze)\b" | wc -l`
Expected: `13`.

- [ ] **Step 4: Commit**

```bash
git add README.md apps/tell_me_a_story/README.md
git commit -m "docs: README for the Serverpod stack"
```

---

### Task 9: `AGENTS.md` rewrite

**Files:**
- Rewrite: `AGENTS.md` (`.cursor/rules/mortang-contract.mdc` already points here; unchanged)

The rules below keep every code-quality rule of the old contract that still applies:
- no swallowed errors;
- colour tokens, with the guard and a skip list that only shrinks;
- no new copy without approval;
- no new dependencies without approval;
- no secrets;
- no hosted config changes.

They drop everything Supabase, Notion and §15 specific. **The owner reviews the wording in the PR.**

- [ ] **Step 1: Replace `AGENTS.md`**

```markdown
# AGENTS.md: Mortang · Tell Me a Story

Rules for any coding agent working in this repo. `.cursor/rules/mortang-contract.mdc` points here.

## What governs a task
1. The task's plan in `docs/superpowers/plans/` and the product decisions it cites (roadmap, "Product decisions").
2. This file: layout, gates and code rules.
3. `docs/archive/` is history (the old impl spec, design doc, UX notes, migration specs and earlier plans). Read it for background; a current plan wins.

If the code and the plan disagree, stop and report the difference; don't reconcile silently. Chat is never a lock.

## Layout
- `apps/tell_me_a_story/`: Flutter client (iPad + web).
  - `lib/core`: config, server connection, router, theme tokens.
  - `lib/data`: gateways (models, `XGateway`, `XApi` on the generated client).
  - `lib/features/<feature>`: screens.
  - Tests: `test/`, `test/live` (tag `live`), `integration_test/`.
- `apps/server/`: Serverpod 4.1.1 server. Endpoints are in `lib/src/endpoints`, rules in `lib/src/<domain>`, models in `lib/src/models/*.spy.yaml`, migrations in `migrations/`.
- `packages/tell_me_a_story_client/`: generated; never edit by hand.

## Work rules
- Build only what the plan lists. Don't add or remove a feature, screen, endpoint, table or dependency on your own; if it's unclear, stop and ask.
- No direct push to `main`. Don't merge into `main`.
- TDD: write the failing test, make it pass, then refactor with the tests green.
- Server models change only in `*.spy.yaml`, followed by `just server-generate`. A schema change gets a new migration (`just server-migration <tag>`). Never edit an existing migration.

## Gates
Run from the repo root and paste the output in the PR body.

| Gate | Command | Baseline |
|---|---|---|
| All local gates | `just check` | passes |
| …format | `just fmt-check` | 0 changed |
| …app analyze | `just analyze` | ≤ 6 issues, no errors |
| …app tests | `just test` | all passing; never fewer tests |
| …server analyze | `just server-analyze` | no issues |
| …server tests | `just server-test` | all passing |
| Live client tests | `just server`, then `just test-live` | all passing |
| e2e | `flutter drive` per README | 9/9 flows |

- `just test` includes `test/architecture/e2e_flow_manifest_test.dart`, which fails if `integration_test/flows.md` and `e2e_test.dart` disagree.
- The analyze ceiling lives in `justfile` (`analyze ceiling="6"`). Lower it when you fix issues; never raise it.
- CI runs the same recipes (`app`, `server` and `e2e` jobs).

## Code rules
- No swallowed errors. Every catch shows or returns a mapped message, or rethrows.
- Server errors are `AppException` with an `AppErrorCode` (`apps/server/lib/src/models/app_error_code.spy.yaml`; shorthands in `apps/server/lib/src/errors.dart`). Messages are user-facing copy; never put raw database text in them. The client maps them in `lib/data/server/server_errors.dart`. A new code needs the owner's approval.
- UI uses only `lib/core/theme/album_theme.dart` tokens. `test/theme/no_hardcoded_colors_test.dart` fails on `Color(0x` or `Colors.` anywhere else in `lib/`. Its skip list names files by exact path from `lib/` and only shrinks: never add a path. A new token needs the owner's approval.
- No new user-facing copy without the owner's approval.
- No new dependencies without approval. Pin majors; no drive-by upgrades.

## Off limits
- No secrets in code, docs or chat. `apps/server/config/passwords.yaml` comes from `just server-passwords` and is git-ignored.
- No production or hosted config changes (Netlify settings, server hosting, DNS, mail provider keys).
```

- [ ] **Step 2: Check that nothing stale is left**

Run: `git grep -n -i -E "supabase|deno|pgtap|notion|§15|impl spec|mapRpcError" -- AGENTS.md README.md .cursor`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md for the Serverpod stack"
```

---

### Task 10: Close Phase 5

**Files:**
- Modify: `docs/superpowers/plans/2026-11-06-serverpod-migration-roadmap.md` (Phase 5 row)
- Modify: this plan (append "As landed")

- [ ] **Step 1: Full gates**

```bash
mise exec -- just check 2>&1 | tail -n 3
mise exec -- just server &   # then, in another shell:
mise exec -- just test-live 2>&1 | tail -n 1
```

Then run the Task 5 e2e and check the CI run of the pushed branch.

Expected:
- `just check` passes;
- the app count equals the baseline + 1;
- the server count equals the baseline;
- `test-live` passes;
- e2e 9/9;
- CI jobs `app`, `server` and `e2e` are green.

- [ ] **Step 2: Check nothing old is left**

Run: `git grep -n -i -E "supabase|deno|pgtap|splinter|check_flows" -- . ':!docs'`
Expected: no output. (Docs are excluded: the archive is history, and the active plans name what was deleted.)

- [ ] **Step 3: Update the roadmap and this plan**

- Roadmap `| 5. Cleanup |` row: append ` **Landed <date>:** app <N>, server <N>, e2e 9/9; CI on mise + just.` with the measured counts.
- Append an `## As landed` section to this plan listing the commits (`git log --oneline <Task 0 commit>..HEAD`) and anything that differed from the plan (for example a CI fallback from Task 4).

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans
git commit -m "docs: Phase 5 landed"
```

---

## Exit criteria for Phase 5
- `supabase/`, `scripts/`, `e2e/` and `r1-shots/` are gone. The Supabase CLI is not in `mise.toml`. CI has no Deno, pgTAP or advisors.
- The e2e flow manifest is checked by `just test`. `just check` exists and passes. CI runs `app`, `server` and `e2e` through mise + just.
- Every pre-2026-11-08 doc is under `docs/archive/` with its old subpath. Outside the archive, no file links to an old `docs/…` path.
- `AGENTS.md`, `README.md`, `apps/tell_me_a_story/README.md` and `netlify.toml` describe the Serverpod stack. The Netlify UI change is listed as an owner action.
- `lib/` and `test/` are unchanged except the new `test/architecture/e2e_flow_manifest_test.dart` and one comment path in `app_exception.dart`.
