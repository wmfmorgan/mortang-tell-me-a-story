# Phase 4f: e2e and CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The e2e flows (C1–C9) sign in with the 6-digit email code against a local `just server`, and the CI `e2e` job runs them against that server instead of the Supabase stack.

**Architecture:** Slice row "4f e2e and CI" of `2026-11-07-serverpod-phase4-client-cutover.md`. The e2e entry keeps its flows and helpers; only sign-in, mounting, the prod guard and the reset helper change. Sign-in types the dev code `111111` into the code step that 4a builds (keys `magic-link-email`, `invite-email`, `sign-in-code`, `sign-in-code-submit`). The app is mounted by `app.main()` once; later flows remount the exact `TellMeAStoryApp` widget `main()` built, so the e2e never copies `main.dart`'s wiring and needs no knowledge of `AuthRefresh`'s constructor. The magic-link relay (`e2e/relay.ts`, `support/relay_client.dart`) goes away.

**Tech Stack:** Flutter 3.47.7 `integration_test` + `flutter drive` (web-server, ChromeDriver), Serverpod 4.1.1 client (`serverClient.auth`), bash, GitHub Actions, just.

**Verification on this branch:** `bash e2e/check_flows.sh` and `flutter analyze` (integration_test clean; total ≤ 23). The full `flutter drive` run needs every gateway switched (4a–4e) and happens in 4z.

---

## File map

| File | Change |
|---|---|
| `apps/tell_me_a_story/integration_test/flows.md` | C1 renamed "C1 email-code sign-in lands on timeline"; owning path `core/supabase/` → `core/server/`. |
| `apps/tell_me_a_story/integration_test/e2e_test.dart` | Code sign-in (`_signIn`, C1, C6); `_mountApp` reuses `main()`'s widget; Supabase/relay code removed; `place.familyId` → `FavoritePlace.familyId`. |
| `apps/tell_me_a_story/integration_test/support/prod_guard.dart` | `assertLocalServer()`: `Env.serverUrl` must be `http://127.0.0.1:8080` or `http://localhost:8080`. |
| `apps/tell_me_a_story/integration_test/support/preconditions.dart` | `resetAppState()` signs out through `serverClient.auth`; `createFavoritePlace` returns `({String familyId, String label})`. |
| `apps/tell_me_a_story/integration_test/support/relay_client.dart` | Deleted. |
| `e2e/relay.ts` | Deleted (`check_flows.sh` stays). |
| `.github/workflows/ci.yml` | `e2e` job only: `just server` instead of `supabase start`; Deno, relay and Supabase CLI steps dropped; `flutter drive --dart-define=SERVER_URL=http://127.0.0.1:8080`. |
| `justfile` | `run` recipe adds `--dart-define=SERVER_URL=http://127.0.0.1:8080` (Supabase defines stay until 4z). |

No `lib/` or `test/` file changes, so no gateway fakes are touched.

---

### Task 1: Rename C1 (manifest first)

**Files:**
- Modify: `apps/tell_me_a_story/integration_test/flows.md` (C1 row)
- Modify: `apps/tell_me_a_story/integration_test/e2e_test.dart` (C1 `testWidgets` name)

- [ ] **Step 1: Failing check — change the manifest row**

```markdown
| C1 | `C1 email-code sign-in lands on timeline` | §8 sign-in; M1; M8; `m08-profile.md`; §14 Automated #4 | `features/auth/`, `features/settings/`, `core/server/`, `core/router/`, `data/profile_session.dart` |
```

- [ ] **Step 2: Run it, expect FAIL**

Run: `bash e2e/check_flows.sh`
Expected: exit 1, `check_flows: flows.md and e2e_test.dart disagree:` with a diff showing `C1 email-code …` vs `C1 magic-link …`.

- [ ] **Step 3: Rename the test**

```dart
  testWidgets('C1 email-code sign-in lands on timeline', (tester) async {
```

- [ ] **Step 4: Run it, expect PASS**

Run: `bash e2e/check_flows.sh`
Expected: `check_flows: 9 flows match (…flows.md <-> …e2e_test.dart)`

- [ ] **Step 5: Commit** — `test(client): rename C1 to email-code sign-in`

### Task 2: Support files on the server client

**Files:**
- Modify: `apps/tell_me_a_story/integration_test/support/prod_guard.dart`
- Modify: `apps/tell_me_a_story/integration_test/support/preconditions.dart`
- Delete: `apps/tell_me_a_story/integration_test/support/relay_client.dart`, `e2e/relay.ts`
- Modify: `apps/tell_me_a_story/integration_test/e2e_test.dart` (imports, `setUpAll`, the two `place.familyId` reads)

- [ ] **Step 1: Failing check**

Run: `rg -n "supabase|Supabase|relay|magicLink" apps/tell_me_a_story/integration_test e2e`
Expected: hits in `prod_guard.dart`, `preconditions.dart`, `relay_client.dart`, `e2e_test.dart`, `e2e/relay.ts`.

- [ ] **Step 2: `prod_guard.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/config/env.dart';

const _localServers = {'http://127.0.0.1:8080', 'http://localhost:8080'};

/// The e2e flows create users and families, so they run only against a local
/// `just server`.
void assertLocalServer() {
  final url = Env.serverUrl;
  final origin = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  if (!_localServers.contains(origin)) {
    fail('SERVER_URL "$url" is not the local just server (http://127.0.0.1:8080)');
  }
}
```

- [ ] **Step 3: `preconditions.dart`**

```dart
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';

/// Signs the carried-over session out and drops the in-memory family and
/// profile.
Future<void> resetAppState() async {
  final auth = serverClient.auth;
  if (auth.isAuthenticated) await auth.signOutDevice();
  FamilySelection.clear();
  ProfileSession.instance.clear();
}

/// The family a favorite was created in, and the label the picker shows.
typedef FavoritePlace = ({String familyId, String label});

/// Favorite on the signed-in user's current family. No Mapbox id.
Future<FavoritePlace> createFavoritePlace({
  required String label,
  required String address,
}) async {
  final familyId = FamilySelection.id ?? await InviteApi().currentFamilyId();
  if (familyId == null) {
    throw StateError('no family for favorite place');
  }
  final place = await PlacesApi().createPlace(
    familyId: familyId,
    label: label,
    address: address,
    lat: 30.2672,
    lng: -97.7431,
    isFavorite: true,
  );
  return (familyId: familyId, label: place.label);
}
```

`Place` loses `familyId` in 4d, so the flows read the family from `FavoritePlace` instead (`_untilDraftReady(familyId: place.familyId …)` and `_publishedStory(familyId: place.familyId …)` keep compiling unchanged because the record has the same field name).

- [ ] **Step 4: Delete the relay**

```bash
git rm e2e/relay.ts apps/tell_me_a_story/integration_test/support/relay_client.dart
```

- [ ] **Step 5:** `e2e_test.dart`: `setUpAll(assertLocalServer);`, drop the `supabase_flutter`, `supabase_init`, `relay_client`, `auth_refresh`, `app_router`, `families_api`, `invite_api`, `people_api`, `profile_api`, `profile_session` imports (Task 3 removes their last uses).

### Task 3: Code sign-in and mounting in `e2e_test.dart`

**Files:** Modify `apps/tell_me_a_story/integration_test/e2e_test.dart`

- [ ] **Step 1: Mount once, then remount `main()`'s widget**

```dart
TellMeAStoryApp? _mounted;

// app.main() sets the URL strategy and starts the server client, so it runs
// once. The test binding replaces the tree between flows; later flows sign
// the carried-over session out and remount the widget main() built.
Future<void> _mountApp(WidgetTester tester) async {
  final mounted = _mounted;
  if (mounted == null) {
    await app.main();
    await pumpUntilFound(tester, find.byType(TellMeAStoryApp));
    _mounted = _app(tester);
    return;
  }
  await resetAppState();
  await tester.pumpWidget(mounted);
}
```

- [ ] **Step 2: Code step helpers**

```dart
/// The fixed code a local `just server` accepts (apps/server auth_config.dart).
const _devLoginCode = '111111';

/// Copy the sign-in pages show when a code request or check fails.
const _signInErrors = [
  'That code isn’t right. Check it and try again.',
  'That code has expired. Send a new one.',
  'Too many tries. Wait a few minutes, then send a new code.',
  'Request failed',
];

void _failOnSignInError() {
  for (final error in _signInErrors) {
    if (find.textContaining(error).evaluate().isNotEmpty) {
      fail('sign-in error: $error');
    }
  }
}

/// Types [email] into [field], asks for a code and waits for the code step.
Future<void> _requestCode(WidgetTester tester, Key field, String email) async {
  await tester.enterText(find.byKey(field), email);
  await tester.pump();
  final send = find.text('Email me a sign-in code');
  await tester.ensureVisible(send);
  await tester.tap(send);
  final code = find.byKey(const Key('sign-in-code'));
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (code.evaluate().isNotEmpty) return;
    _failOnSignInError();
  }
  throw TestFailure('$code not found within 30s (url: ${Uri.base})');
}

/// Enters the dev code and waits until [landed] shows.
Future<void> _enterCode(WidgetTester tester, Finder landed) async {
  await tester.enterText(find.byKey(const Key('sign-in-code')), _devLoginCode);
  await tester.pump();
  final submit = find.byKey(const Key('sign-in-code-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  final deadline = DateTime.now().add(const Duration(seconds: 45));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (landed.evaluate().isNotEmpty) return;
    _failOnSignInError();
  }
  throw TestFailure('$landed not found within 45s (url: ${Uri.base})');
}
```

- [ ] **Step 3: `_signIn`**

```dart
Future<void> _signIn(WidgetTester tester, String flow, String email) async {
  await _step(flow, 'boot', () async {
    await _mountApp(tester);
    await pumpUntilFound(tester, find.byKey(const Key('magic-link-email')));
  });
  await _step(flow, 'send-code', () async {
    await _requestCode(tester, const Key('magic-link-email'), email);
  });
  await _step(flow, 'enter-code', () async {
    await _enterCode(tester, find.byKey(const Key('family-menu')));
  });
}
```

- [ ] **Step 4: C1** — `boot` calls `_mountApp(tester)`; `send-link`/`magic-link`/`recover-session`/`avatar` become:

```dart
    await _c1Step('send-code', () async {
      await _requestCode(tester, const Key('magic-link-email'), email);
    });
    await _c1Step('enter-code', () async {
      await _enterCode(tester, find.byKey(const Key('header-avatar')));
    });
```

- [ ] **Step 5: C6** — the guest asks for a code on the invite page and enters it there:

```dart
    await _step('C6', 'send-code', () async {
      await _requestCode(tester, const Key('invite-email'), guest);
    });
    await _step('C6', 'enter-code', () async {
      await _enterCode(tester, find.byKey(const Key('family-landing')));
    });
    await _step('C6', 'joined-timeline', () async {
      await pumpUntilFound(tester, find.text(family));
      …unchanged…
```

- [ ] **Step 6: Delete** `_handOff`, `_untilLinkSent`, `_supabaseReady`.

- [ ] **Step 7: Verify**

Run: `rg -n "supabase|Supabase|relay|magicLink|recoverSession" apps/tell_me_a_story/integration_test e2e` → nothing.
Run: `cd apps/tell_me_a_story && mise exec -- flutter analyze` → no issue under `integration_test/`, total ≤ 23.
Run: `bash e2e/check_flows.sh` → `9 flows match`.

- [ ] **Step 8: Commit** — `test(client): e2e signs in with the email code on just server`

### Task 4: CI e2e job on `just server`

**Files:** Modify `.github/workflows/ci.yml` (job `e2e` only)

- [ ] **Step 1:** Replace the Supabase CLI env/steps, Deno, relay and "await supabase start" steps. New step order:
  1. checkout; `e2e flow manifest` (`bash e2e/check_flows.sh`);
  2. `subosito/flutter-action` (3.47.7) — its Dart runs the server;
  3. `extractions/setup-just@53165ef7e734c5c07cb06b3c8e7b647c5aa16db3 # v4.0.0` with `just-version: "1.46.0"` (mise.toml);
  4. `server packages and passwords`: `(cd apps/server && dart pub get --enforce-lockfile)`, `(cd packages/tell_me_a_story_client && dart pub get --enforce-lockfile)`, `just server-passwords`;
  5. `just server (background)`: `just server > "$RUNNER_TEMP/server.log" 2>&1 &` and save the pid;
  6. `flutter pub get --enforce-lockfile` in the app;
  7. ChromeDriver step unchanged;
  8. `await just server`: poll `http://127.0.0.1:8080/` up to 300 s with `curl -s -o /dev/null` (any HTTP answer counts; connection refused does not), fail early if the server pid exits;
  9. `flutter drive … --dart-define=SERVER_URL=http://127.0.0.1:8080`;
  10. `e2e logs (server, chromedriver)` with `if: always()`.
- [ ] **Step 2: Verify** — `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` parses; `rg -n "supabase|deno|relay" .github/workflows/ci.yml` hits only the other jobs (lines before `e2e:`).
- [ ] **Step 3: Commit** — `ci: e2e job runs against just server`

### Task 5: `just run` passes `SERVER_URL`

**Files:** Modify `justfile` (`run` recipe)

- [ ] **Step 1:** after `--dart-define=SUPABASE_ANON_KEY="$anon_key" \` add `--dart-define=SERVER_URL=http://127.0.0.1:8080 \`.
- [ ] **Step 2: Verify** — `just --dry-run run` (or `just --show run`) prints the new define.
- [ ] **Step 3: Commit** — `chore: just run passes SERVER_URL`

### Task 6: Gate

- [ ] `mise exec -- dart format --output=none --set-exit-if-changed apps/tell_me_a_story/lib apps/tell_me_a_story/test apps/tell_me_a_story/integration_test` → 0 changed
- [ ] `flutter analyze` ≤ 23, none in `integration_test/`
- [ ] `flutter test`, `just test-live` pass (no app code changed)
- [ ] `bash e2e/check_flows.sh` passes
- [ ] Commit the plan as landed: `docs: Phase 4f plan as landed`

## Notes for 4z
- `flutter drive` can only pass once 4a–4e are merged: on this branch `main()` still starts Supabase, so `serverClient` is never initialised.
- The e2e depends on 4a for: `app.main()` calling `initServer`, the keys `magic-link-email`, `invite-email`, `sign-in-code`, `sign-in-code-submit`, the send button text "Email me a sign-in code" on both pages, and `AuthRefresh` reacting to `serverClient.auth` sign-out.
