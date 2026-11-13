# Serverpod Phase 2: Client Seams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put every Supabase detail that feature and core code can see behind client-owned seams while the app still runs on Supabase. After this plan, the Serverpod cutover only rewrites `lib/data/*_api.dart` bodies plus bootstrap (`main.dart`, `lib/core/supabase/`, `AuthRefresh`, auth pages).

**Architecture:** This is Phase A from `docs/migration/endpoint-contract.md` §5, steps 1–4. Step 5 (OTP login UI) is deferred.
- **Session seam.** A new `AppSession` (`lib/core/server/app_session.dart`) is the single source for the signed-in user id and for sign-out. It follows the existing `ProfileSession.instance` pattern: there is a static `AppSession.instance`, the default is Supabase-backed, and tests swap it. Per-widget injection does not change; the existing `currentUserId`, `signedInUserId` and `onLogout` constructor parameters still win.
- **Error seam.** One client error type, `AppException{AppErrorCode code, String message}`, lives in `lib/data/app_exception.dart`. Supabase-specific translation lives in `lib/data/supabase_errors.dart`, and Phase C deletes that file. Gateways translate catalog errors (`NOT_FOUND:` / `FORBIDDEN:` / `VALIDATION:` / `INVITE_INVALID:` RPC messages and edge-function `{code, message}` envelopes) into `AppException`. Features only see `AppException` or opaque errors, which get generic copy.
- **Moved logic.** Duplicate-key handling and photo cleanup on discard move into `StoriesApi`. Picture URLs become bytes. The perspective page reads the user's name from `ProfileSession`.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13 via mise, `supabase_flutter` (postgrest 2.9.1, functions_client 2.7.1, storage_client 2.8.0), `flutter_test`, `http` (test stubs), `image` (test PNGs).

---

## Scope decisions

| Item | Decision | Why |
|---|---|---|
| `AppSession` + route every `auth.currentUser` read in `lib/features/**` / `lib/core/**` | **In** (Tasks 1–3) | Contract §5 A.1 |
| Direct `profiles` query in `add_perspective_page.dart` | **In** (Task 4), replaced with `ProfileSession` | Contract §3 row `add_perspective_page.dart`, §5 A.4 |
| `signOut` in `album_header.dart` | **In** (Task 3) | Contract §5 A.1 |
| One `AppException`; delete `rpc_error.dart`, `InviteApiException`, `ManageFamiliesException`, `OriginRpcException`, `PersonProfileNotFound`; delete feature-level `PostgrestException` catches | **In** (Tasks 5–9) | Contract §5 A.2–A.3; audit "3 different error-mapping paths" |
| Idempotent `createDraft` / `linkPerson`; fold `deleteAllForStory` into `StoriesApi.discard` | **In** (Tasks 9–10) | Contract §5 A.3 |
| Image URL → bytes (`pictureBytes`, `thumbBytes`, `Image.memory`) | **In** (Task 11) | Contract §5 A.4 requires it |
| Wire all 14 gateways from `main.dart` (composition root) | **Skipped** | Contract §5 Phase A has no DI step. §3 changes `main.dart` only in Phase C. Note: roadmap row 2 lists "gateways injected from `main.dart`", so Main should decide whether to amend the contract or the roadmap |
| Shared `test/support/fakes.dart` | **Skipped** | Contract §4: "Gateway fakes in widget tests implement the unchanged interfaces, so they don't change." It does not recommend consolidating them |
| Email-code (OTP) login UI | **Deferred** to cutover | Assignment exclusion (contract §5 A.5) |
| `AuthRefresh`, `main.dart`, `lib/core/supabase/*`, auth pages, Supabase uses inside `lib/data/*` | Unchanged | Contract §5 A.1 leaves these for Phase C |
| `AppErrorCode.conflict / photoCap / storageFailed` | Not added yet | Nothing on Supabase produces them through a gateway today. `StorageFailedException` and `StateError('PHOTO_CAP')` stay until Phase C maps the server codes (contract §3 `dto_mapping.dart`) |

**Which gateway methods get `withAppErrors`.** It wraps every method whose errors reach a call site that shows catalog copy. That is:
- `PeopleApi.listTreePeople/createPerson/personProfile/updatePerson/markPassedAway`
- `StoriesApi.listPublished/linkPerson`
- `FamiliesApi.setCoverPhoto/clearCoverPhoto`
- the origin RPCs, which use their own catalog sentences

Every other gateway method's errors already render as generic copy whatever their type, so translating them would change nothing a user sees. In Phase C the generated client throws the server `AppException` for every method anyway.

**UI copy invariant.** Every message shown before is shown after. The call sites are audited in each task. Two edge paths need explicit code to keep their copy:
- add-person invite failures keep the generic save sentence (Task 7);
- a hidden linked profile inside `listTreePeople` keeps the generic load failure (Task 8).

## Conventions for the engineer

- Line numbers refer to commit `2c3aca2` (current `HEAD`). Earlier tasks shift lines in shared files. **Find each edit by the quoted code**, not only by the number.
- Run every `flutter` command from `apps/tell_me_a_story`. Run every `git` command from the repo root.
- Imports: keep the file's existing order (dart, package, then relative, alphabetical within each group).
- Never add `Color(0x…)` or `Colors.` outside `lib/core/theme/album_theme.dart`. `test/theme/no_hardcoded_colors_test.dart` runs in `just test`.
- Never write the token `timeframeStart!` in `lib/`. `test/stories_api_test.dart:140` greps for it.

## File map

| File | Responsibility | Tasks |
|---|---|---|
| `lib/core/server/app_session.dart` (new) | `AppSession` seam + `SupabaseAppSession` | 1 |
| `lib/data/app_exception.dart` (new) | `AppErrorCode`, `AppException`, `appErrorMessage` (backend-neutral) | 5 |
| `lib/data/supabase_errors.dart` (new) | PostgREST catalog + edge-function envelope → `AppException` (deleted in Phase C) | 5, 7 |
| `lib/data/rpc_error.dart` | **deleted** (replaced by `appErrorMessage`) | 6 |
| `lib/core/router/app_router.dart` | user id via `AppSession`; drop `photosApi` from `DraftsPage` | 2, 10 |
| `lib/core/theme/album_header.dart` | logout via `AppSession` | 3 |
| `lib/features/drafts/drafts_page.dart` | user id via `AppSession`; discard no longer calls photos | 2, 10 |
| `lib/features/family/manage_families_page.dart`, `manage_family_page.dart`, `start_family_dialog.dart`, `start_timeline_dialog.dart` | user id via `AppSession`; catch `AppException` | 2, 7 |
| `lib/features/family/start_timeline_host.dart`, `family_landing_page.dart` | drop `signedInUserId()`; `appErrorMessage` | 2, 6 |
| `lib/features/people/person_profile_dialog.dart` | user id via `AppSession`; `appErrorMessage`; bytes | 2, 6, 8, 11 |
| `lib/features/people/add_person_modal.dart` | `appErrorMessage`; invite-step copy | 6, 7 |
| `lib/features/people/edit_person_dialog.dart` | bytes | 11 |
| `lib/features/invites/invite_modal.dart` | `appErrorMessage`; catch `AppException` | 6, 7 |
| `lib/features/perspectives/add_perspective_page.dart` | name via `ProfileSession` | 4 |
| `lib/features/settings/settings_page.dart`, `timeline/timeline_page.dart` | user id via `AppSession` | 2 |
| `lib/features/stories/story_reader_page.dart` | user id via `AppSession`; origin `AppException` | 2, 8 |
| `lib/features/stories/new_story_page.dart` | drop `PostgrestException` catches | 9 |
| `lib/data/people_api.dart` | guards; `PersonProfileNotFound` gone; `pictureBytes` | 6, 8, 11 |
| `lib/data/stories_api.dart` | guards; idempotent create/link; discard cleans photos; `thumbBytes` | 6, 9, 10, 11 |
| `lib/data/families_api.dart` | guards; `OriginRpcException` gone | 6, 8 |
| `lib/data/invite_api.dart`, `manage_families_api.dart` | envelopes → `AppException` | 7 |
| `lib/data/photos_api.dart` | `deleteAllForStory` leaves the `PhotosGateway` interface | 10 |
| `test/app_session_test.dart` (new) | session seam + header logout | 1, 3 |
| `test/supabase_errors_test.dart` (new) | translation helpers | 5, 7 |
| `test/gateway_errors_test.dart` (new) | real `*Api` classes over a stubbed HTTP client | 6–10 |
| existing tests | listed per task | 2–11 |

---

### Task 0: Baseline

**Files:** none.

- [ ] **Step 1: Record the green baseline**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test
mise exec -- flutter analyze > /tmp/phase2-analyze-before.txt; echo "analyze exit $?"
```
Expected: `All tests passed!` with `+677`. Keep the analyze output; Task 12 compares against it.

---

### Task 1: `AppSession` seam

**Files:**
- Create: `apps/tell_me_a_story/lib/core/server/app_session.dart`
- Test: `apps/tell_me_a_story/test/app_session_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `apps/tell_me_a_story/test/app_session_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';

void main() {
  tearDown(() => AppSession.instance = const SupabaseAppSession());

  test('the default session is Supabase-backed', () {
    expect(AppSession.instance, isA<SupabaseAppSession>());
  });

  test('the Supabase session has no user before Supabase starts', () {
    expect(const SupabaseAppSession().currentUserId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/app_session_test.dart`
Expected: FAIL to compile: `Error when reading 'lib/core/server/app_session.dart': No such file or directory`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/tell_me_a_story/lib/core/server/app_session.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who is signed in, for code outside `lib/data`.
///
/// Widgets that take a `currentUserId` / `signedInUserId` / `onLogout`
/// argument still prefer it; this is the fallback. The Serverpod cutover swaps
/// [instance] for a `client.auth`-backed session.
abstract class AppSession {
  const AppSession();

  /// App-wide session. Tests replace it and restore
  /// `const SupabaseAppSession()` in tearDown.
  static AppSession instance = const SupabaseAppSession();

  /// Signed-in user id, or null when signed out or auth has not started.
  String? get currentUserId;

  Future<void> signOut();
}

/// [AppSession] over Supabase auth.
class SupabaseAppSession extends AppSession {
  const SupabaseAppSession();

  @override
  String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase is not initialized (widget tests).
      return null;
    }
  }

  @override
  Future<void> signOut() => Supabase.instance.client.auth.signOut();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/app_session_test.dart`
Expected: PASS (`+2: All tests passed!`).

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/core/server/app_session.dart apps/tell_me_a_story/test/app_session_test.dart
git commit -m "refactor(client): add AppSession seam over Supabase auth"
```

---

### Task 2: Route every user-id read through `AppSession`

Today there are ten reads of `Supabase.instance.client.auth.currentUser` outside `lib/data`, `main.dart` and the auth pages:

| File:line | Today | After |
|---|---|---|
| `lib/core/router/app_router.dart:471-477` (`_signedInUserId`, used at `:454`) | try/catch Supabase | `AppSession.instance.currentUserId` |
| `lib/features/drafts/drafts_page.dart:164-170` | `_sessionUserId()` | one-liner |
| `lib/features/family/manage_families_page.dart:130-136` | `_sessionUserId()` | one-liner |
| `lib/features/family/manage_family_page.dart:166-174` | `widget.currentUserId` else Supabase | `widget.currentUserId ?? AppSession…` |
| `lib/features/family/start_timeline_host.dart:12-20` (`signedInUserId`, used at `family_landing_page.dart:211`) | public helper | **deleted**; caller reads `AppSession` |
| `lib/features/people/person_profile_dialog.dart:79-85` (used at `:72`) | `_sessionUserId()` | **deleted**; `AppSession` at `:72` |
| `lib/features/settings/settings_page.dart:199-205` | `_sessionUserId()` | one-liner |
| `lib/features/stories/story_reader_page.dart:199-206` | `_currentUserId` getter | `widget.currentUserId ?? AppSession…` |
| `lib/features/timeline/timeline_page.dart:223-230` | `_sessionUserId()` | `widget.currentUserId ?? AppSession…` |
| `lib/features/perspectives/add_perspective_page.dart:149-150` | inside the direct query | removed in Task 4 |

**Files:**
- Modify: the nine `lib/` files in the table (all rows except add_perspective)
- Test: `apps/tell_me_a_story/test/m14_3_dob_passed_away_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/m14_3_dob_passed_away_test.dart`:

1. After line 6 (`import 'package:supabase_flutter/supabase_flutter.dart';`), insert:
```dart
import 'package:tell_me_a_story/core/server/app_session.dart';
```
2. In `_openProfile` (line 450), change `required String signedInUserId,` to:
```dart
  String? signedInUserId,
```
3. After the test that ends at line 200 (`'a failed mark shows the mapped error and stays put'`), insert:
```dart

  testWidgets('with no injected id the profile asks AppSession who is signed in', (
    tester,
  ) async {
    AppSession.instance = const _Session('member');
    addTearDown(() => AppSession.instance = const SupabaseAppSession());
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: true,
      )
      ..editor = const Person(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        userId: 'member',
      )
      ..steward = true;
    await _openProfile(tester, people);

    // The signed-in user is Ada herself, so the steward check never runs.
    expect(find.text('Mark as passed away'), findsNothing);
  });
```
4. At the end of the file, append:
```dart

class _Session extends AppSession {
  const _Session(this.currentUserId);

  @override
  final String? currentUserId;

  @override
  Future<void> signOut() async {}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/m14_3_dob_passed_away_test.dart`
Expected: FAIL on the new test: `Expected: no matching candidates  Actual: _TextWidgetFinder:<Found 1 widget with text "Mark as passed away"`. The dialog still asks Supabase, gets null, and runs the steward check.

- [ ] **Step 3: Write minimal implementation**

`lib/core/router/app_router.dart`
- Delete line 5: `import 'package:supabase_flutter/supabase_flutter.dart';`
- Before line 35 (`import '../theme/album_theme.dart';`), insert `import '../server/app_session.dart';`
- Line 454: `currentUserId: _signedInUserId(),` → `currentUserId: AppSession.instance.currentUserId,`
- Delete lines 470–477, the blank line plus:
```dart
String? _signedInUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}
```

`lib/features/drafts/drafts_page.dart`
- Delete line 3 (`supabase_flutter` import). After line 5 (`import '../../core/router/app_router.dart';`), insert `import '../../core/server/app_session.dart';`
- Replace lines 164–170 (`String? _sessionUserId() { try { … } catch (_) { return null; } }`) with:
```dart
  String? _sessionUserId() => AppSession.instance.currentUserId;
```

`lib/features/family/manage_families_page.dart`
- Delete line 4 (`supabase_flutter` import). After line 6 (`'../../core/router/app_router.dart'`), insert `import '../../core/server/app_session.dart';`
- Replace lines 130–136 with:
```dart
  String? _sessionUserId() => AppSession.instance.currentUserId;
```

`lib/features/family/manage_family_page.dart`
- Delete line 4 (`supabase_flutter` import). After line 7 (`'../../core/router/app_router.dart'`), insert `import '../../core/server/app_session.dart';`
- Replace lines 166–174 with:
```dart
  String? _sessionUserId() =>
      widget.currentUserId ?? AppSession.instance.currentUserId;
```

`lib/features/family/start_timeline_host.dart`
- Delete line 3 (`supabase_flutter` import).
- Delete lines 12–21 (the doc comment, `signedInUserId({String? override})` and the blank line after it). The file then starts its declarations at `/// Branch dialog shared by signed-in hosts.`

`lib/features/family/family_landing_page.dart`
- After line 8 (`import '../../core/router/app_router.dart';`), insert `import '../../core/server/app_session.dart';`
- Line 211: `final userId = signedInUserId();` → `final userId = AppSession.instance.currentUserId;`

`lib/features/people/person_profile_dialog.dart`
- Delete line 3 (`supabase_flutter` import). After line 5 (`'../../core/router/app_router.dart'`), insert `import '../../core/server/app_session.dart';`
- Line 72: `signedInUserId: signedInUserId ?? _sessionUserId(),` → `signedInUserId: signedInUserId ?? AppSession.instance.currentUserId,`
- Delete lines 78–85 (the blank line plus the top-level `String? _sessionUserId() { … }`).

`lib/features/settings/settings_page.dart`
- Delete line 7 (`supabase_flutter` import). After line 10 (`'../../core/router/app_router.dart'`), insert `import '../../core/server/app_session.dart';`
- Replace lines 199–205 with:
```dart
  String? _sessionUserId() => AppSession.instance.currentUserId;
```

`lib/features/stories/story_reader_page.dart`
- Delete line 7 (`supabase_flutter` import). After line 9 (`'../../core/router/app_router.dart'`), insert `import '../../core/server/app_session.dart';`
- Replace lines 199–206 (`String? get _currentUserId { … }`) with:
```dart
  String? get _currentUserId =>
      widget.currentUserId ?? AppSession.instance.currentUserId;
```

`lib/features/timeline/timeline_page.dart`
- Delete line 7 (`supabase_flutter` import). After line 9 (`'../../core/router/app_router.dart'`), insert `import '../../core/server/app_session.dart';`
- Replace lines 223–230 with:
```dart
  String? _sessionUserId() =>
      widget.currentUserId ?? AppSession.instance.currentUserId;
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/m14_3_dob_passed_away_test.dart test/m14_people_profiles_test.dart test/drafts_page_test.dart test/settings_page_test.dart test/start_timeline_test.dart test/story_reader_page_test.dart test/timeline_page_test.dart test/router_test.dart
mise exec -- flutter test
```
Expected: PASS, 0 failures (the full suite is now 677 + 3 new tests from Tasks 1–2).

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/core/router/app_router.dart apps/tell_me_a_story/lib/features/drafts/drafts_page.dart apps/tell_me_a_story/lib/features/family/manage_families_page.dart apps/tell_me_a_story/lib/features/family/manage_family_page.dart apps/tell_me_a_story/lib/features/family/start_timeline_host.dart apps/tell_me_a_story/lib/features/family/family_landing_page.dart apps/tell_me_a_story/lib/features/people/person_profile_dialog.dart apps/tell_me_a_story/lib/features/settings/settings_page.dart apps/tell_me_a_story/lib/features/stories/story_reader_page.dart apps/tell_me_a_story/lib/features/timeline/timeline_page.dart apps/tell_me_a_story/test/m14_3_dob_passed_away_test.dart
git commit -m "refactor(client): read the signed-in user id through AppSession"
```

---

### Task 3: Logout goes through `AppSession`

**Files:**
- Modify: `apps/tell_me_a_story/lib/core/theme/album_header.dart:6,15,1115`
- Test: `apps/tell_me_a_story/test/app_session_test.dart`

- [ ] **Step 1: Write the failing test**

Replace `test/app_session_test.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDown(() => AppSession.instance = const SupabaseAppSession());

  test('the default session is Supabase-backed', () {
    expect(AppSession.instance, isA<SupabaseAppSession>());
  });

  test('the Supabase session has no user before Supabase starts', () {
    expect(const SupabaseAppSession().currentUserId, isNull);
  });

  testWidgets('header Logout without onLogout signs out through AppSession', (
    tester,
  ) async {
    final session = _FakeSession('u1');
    AppSession.instance = session;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: 'Morgan',
            families: const [],
            currentFamilyId: null,
            onFamilySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-menu-logout')));
    await tester.pumpAndSettle();

    expect(session.signOutCalls, 1);
  });
}

class _FakeSession extends AppSession {
  _FakeSession(this.currentUserId);

  @override
  final String? currentUserId;

  var signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/app_session_test.dart`
Expected: FAIL. The new test reports `You must initialize the supabase instance before calling Supabase.instance`, thrown from `_HeaderAvatarState._logout`.

- [ ] **Step 3: Write minimal implementation**

In `lib/core/theme/album_header.dart`:
- Delete line 6: `import 'package:supabase_flutter/supabase_flutter.dart';`
- After line 15 (`import '../router/app_router.dart';`), insert `import '../server/app_session.dart';`
- Line 1115: `await Supabase.instance.client.auth.signOut();` → `await AppSession.instance.signOut();`

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/app_session_test.dart test/settings_page_test.dart test/settings_guard_test.dart test/logout_ordering_test.dart test/m10_navigation_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/core/theme/album_header.dart apps/tell_me_a_story/test/app_session_test.dart
git commit -m "refactor(client): sign out through AppSession"
```

---

### Task 4: Perspective page reads the name from `ProfileSession`

`add_perspective_page.dart:147-163` queries `profiles.display_name` directly. `ProfileSession` (`lib/data/profile_session.dart`) already holds that name. It is loaded once per user through `ProfileGateway.loadOwn`, and `main.dart:23-25` wires it. The page now listens to `ProfileSession`, the same way `_HeaderAvatarState` does (`album_header.dart:1074-1089`).

**Files:**
- Modify: `apps/tell_me_a_story/lib/features/perspectives/add_perspective_page.dart:3,7-8,40,135-169`
- Test: `apps/tell_me_a_story/test/add_perspective_page_test.dart`

- [ ] **Step 1: Write the failing test**

In `test/add_perspective_page_test.dart`:
1. After line 7 (`import 'package:tell_me_a_story/data/perspectives_api.dart';`), insert:
```dart
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';
```
2. After the test that ends at line 173 (`'posting as shows the name and Author when ids match'`), insert:
```dart

  testWidgets('with no postingAs the page shows the signed-in profile name', (
    tester,
  ) async {
    ProfileSession.loadOwn = () async =>
        const OwnProfile(id: 'u1', displayName: 'Sarah Morgan');
    addTearDown(() {
      ProfileSession.loadOwn = null;
      ProfileSession.instance.clear();
    });

    await _pumpOverlay(tester, api: _FakePerspectivesApi());

    expect(find.text('Posting as'), findsOneWidget);
    expect(find.text('Sarah Morgan'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/add_perspective_page_test.dart`
Expected: FAIL on the new test: `Expected: exactly one matching candidate  Actual: _TextWidgetFinder:<Found 0 widgets with text "Posting as"`. The page still asks Supabase, which throws and is swallowed.

- [ ] **Step 3: Write minimal implementation**

In `lib/features/perspectives/add_perspective_page.dart`:
- Delete line 3: `import 'package:supabase_flutter/supabase_flutter.dart';`
- Between line 7 (`'../../data/perspectives_api.dart'`) and line 8 (`'../../data/stories_api.dart'`), insert `import '../../data/profile_session.dart';`
- After `_perspectiveInitials` (ends at line 40), insert:
```dart

String? _nonEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
```
- Replace lines 135–169 (`initState`, `_loadPostingAs`, `dispose`) with:
```dart
  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) _body.text = existing.body;
    _postingAs = _nonEmpty(widget.postingAs);
    if (_postingAs == null) {
      final session = ProfileSession.instance;
      _postingAs = _nonEmpty(session.displayName);
      session.addListener(_onProfile);
      session.ensureLoaded();
    }
  }

  /// Signed-in name from [ProfileSession]. Tests and signed-out sessions have none.
  void _onProfile() {
    final name = _nonEmpty(ProfileSession.instance.displayName);
    if (!mounted || name == null || name == _postingAs) return;
    setState(() => _postingAs = name);
  }

  @override
  void dispose() {
    ProfileSession.instance.removeListener(_onProfile);
    _body.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/add_perspective_page_test.dart test/story_reader_page_test.dart`
Expected: PASS. The existing test `'shows locked Add Perspective copy and no title field'` still finds no `Posting as`, because `ProfileSession.loadOwn` is null there.

Then confirm the session seam is complete:
```bash
git grep -n "Supabase.instance" -- apps/tell_me_a_story/lib/features apps/tell_me_a_story/lib/core
```
Expected: only `lib/core/supabase/supabase_init.dart`, `lib/features/auth/invite_sign_in_page.dart` and `lib/features/auth/magic_link_page.dart`.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/features/perspectives/add_perspective_page.dart apps/tell_me_a_story/test/add_perspective_page_test.dart
git commit -m "refactor(client): perspective page reads the poster name from ProfileSession"
```

---

### Task 5: `AppException` and PostgREST catalog translation

**Files:**
- Create: `apps/tell_me_a_story/lib/data/app_exception.dart`
- Create: `apps/tell_me_a_story/lib/data/supabase_errors.dart`
- Test: `apps/tell_me_a_story/test/supabase_errors_test.dart` (new)

- [ ] **Step 1: Write the failing test**

Create `apps/tell_me_a_story/test/supabase_errors_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/supabase_errors.dart';

void main() {
  group('appExceptionFromPostgrest', () {
    test('maps each catalog prefix to its code and detail', () {
      final cases = <String, (AppErrorCode, String)>{
        'NOT_FOUND: story': (AppErrorCode.notFound, 'story'),
        'FORBIDDEN: not a steward': (AppErrorCode.forbidden, 'not a steward'),
        'VALIDATION: Already on this story': (
          AppErrorCode.validation,
          'Already on this story',
        ),
        'INVITE_INVALID: Invite link expired': (
          AppErrorCode.inviteInvalid,
          'Invite link expired',
        ),
      };
      for (final entry in cases.entries) {
        final mapped = appExceptionFromPostgrest(
          PostgrestException(message: entry.key),
        );
        expect(mapped?.code, entry.value.$1, reason: entry.key);
        expect(mapped?.message, entry.value.$2, reason: entry.key);
      }
    });

    test('keeps the trimmed message when the detail is empty', () {
      final mapped = appExceptionFromPostgrest(
        const PostgrestException(message: ' VALIDATION: '),
      );
      expect(mapped?.message, 'VALIDATION:');
    });

    test('returns null for an uncatalogued message', () {
      expect(
        appExceptionFromPostgrest(
          const PostgrestException(
            message: 'duplicate key value violates unique constraint',
            code: '23505',
          ),
        ),
        isNull,
      );
    });
  });

  group('withAppErrors', () {
    test('returns the call result', () async {
      expect(await withAppErrors(() async => 3), 3);
    });

    test('rethrows a catalog error as AppException', () async {
      await expectLater(
        withAppErrors<void>(
          () async => throw const PostgrestException(message: 'FORBIDDEN: no'),
        ),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having((e) => e.message, 'message', 'no'),
        ),
      );
    });

    test('leaves other errors untouched', () async {
      const raw = PostgrestException(message: 'permission denied', code: '42501');
      await expectLater(
        withAppErrors<void>(() async => throw raw),
        throwsA(same(raw)),
      );
      final state = StateError('network');
      await expectLater(
        withAppErrors<void>(() async => throw state),
        throwsA(same(state)),
      );
    });
  });

  test('appErrorMessage reads only AppException', () {
    expect(
      appErrorMessage(
        const AppException(
          code: AppErrorCode.validation,
          message: 'Already linked',
        ),
      ),
      'Already linked',
    );
    expect(appErrorMessage(StateError('x')), isNull);
    expect(
      appErrorMessage(const PostgrestException(message: 'VALIDATION: raw')),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/supabase_errors_test.dart`
Expected: FAIL to compile: `Error when reading 'lib/data/app_exception.dart': No such file or directory`.

- [ ] **Step 3: Write minimal implementation**

Create `apps/tell_me_a_story/lib/data/app_exception.dart`:
```dart
/// Expected gateway failures. Mirrors the server `AppErrorCode`
/// (docs/migration/endpoint-contract.md §2.1) for the codes the Supabase
/// backend produces today, plus [unauthenticated] for calls made without a
/// session.
enum AppErrorCode { notFound, forbidden, validation, inviteInvalid, unauthenticated }

/// An expected failure whose [message] is user-facing copy.
class AppException implements Exception {
  const AppException({required this.code, required this.message});

  final AppErrorCode code;
  final String message;

  @override
  String toString() => 'AppException(${code.name}: $message)';
}

/// [AppException.message] for an expected gateway failure, or null for any
/// other error (callers show their generic sentence).
String? appErrorMessage(Object error) =>
    error is AppException ? error.message : null;
```

Create `apps/tell_me_a_story/lib/data/supabase_errors.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// SQL raises catalog errors as `PREFIX: detail` (§12 error catalog).
const _catalogPrefixes = <String, AppErrorCode>{
  'NOT_FOUND:': AppErrorCode.notFound,
  'FORBIDDEN:': AppErrorCode.forbidden,
  'VALIDATION:': AppErrorCode.validation,
  'INVITE_INVALID:': AppErrorCode.inviteInvalid,
};

/// A catalog [error] as an [AppException]; null for any other message.
AppException? appExceptionFromPostgrest(PostgrestException error) {
  final trimmed = error.message.trim();
  for (final entry in _catalogPrefixes.entries) {
    if (!trimmed.startsWith(entry.key)) continue;
    final detail = trimmed.substring(entry.key.length).trim();
    return AppException(
      code: entry.value,
      message: detail.isEmpty ? trimmed : detail,
    );
  }
  return null;
}

/// Runs a PostgREST [call]. Catalog errors are rethrown as [AppException];
/// every other error is rethrown unchanged.
Future<T> withAppErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PostgrestException catch (error) {
    final mapped = appExceptionFromPostgrest(error);
    if (mapped == null) rethrow;
    throw mapped;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/supabase_errors_test.dart`
Expected: PASS (`+7: All tests passed!`).

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/data/app_exception.dart apps/tell_me_a_story/lib/data/supabase_errors.dart apps/tell_me_a_story/test/supabase_errors_test.dart
git commit -m "feat(client): add AppException and PostgREST catalog translation"
```

---

### Task 6: Catalog RPC errors reach features as `AppException`

This replaces `mapRpcError` (`lib/data/rpc_error.dart:4-19`) with `appErrorMessage` at its five call sites. It also wraps the gateway methods whose errors reach those call sites, so each site sees the same copy it showed before:

| Call site | Gateway calls feeding it | Wrapped in this task |
|---|---|---|
| `family_landing_page.dart:219` | `StoriesGateway.listPublished` | `StoriesApi.listPublished` |
| `family_landing_page.dart:279` | `FamiliesGateway.setCoverPhoto/clearCoverPhoto` | both |
| `invite_modal.dart:221` | `PeopleGateway.updatePerson` | yes |
| `add_person_modal.dart:128` | `listTreePeople`, `createPerson`, `linkPerson`, invites (Task 7) | `PeopleApi.listTreePeople/createPerson`, `StoriesApi.linkPerson` |
| `person_profile_dialog.dart:230` | `PeopleGateway.markPassedAway` | yes |

**Files:**
- Delete: `apps/tell_me_a_story/lib/data/rpc_error.dart`
- Modify: `lib/features/family/family_landing_page.dart:12,19,219,279`; `lib/features/invites/invite_modal.dart:7,9,221`; `lib/features/people/add_person_modal.dart:8,10,128`; `lib/features/people/person_profile_dialog.dart:7,9,230`
- Modify: `lib/data/people_api.dart:6,245-254,290-321,378-388,405-414`; `lib/data/stories_api.dart:5,671-683,736-745`; `lib/data/families_api.dart:6,358-389`
- Test: `test/add_person_modal_test.dart`, `test/invite_chrome_test.dart`, `test/m14_3_dob_passed_away_test.dart`, `test/gateway_errors_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

(a) `test/add_person_modal_test.dart`: delete line 6 (`supabase_flutter` import). After line 7 (`'package:tell_me_a_story/core/theme/album_theme.dart'`), insert `import 'package:tell_me_a_story/data/app_exception.dart';`. Then replace the five fake throws:
- lines 436–438 (8-space indent):
```dart
        throw const AppException(
          code: AppErrorCode.validation,
          message: 'Already on this story',
        );
```
- lines 496–498 (10-space indent):
```dart
          throw const AppException(
            code: AppErrorCode.validation,
            message: 'Already on this story',
          );
```
- line 533 (8-space indent):
```dart
        throw const AppException(
          code: AppErrorCode.validation,
          message: 'Already linked',
        );
```
- lines 862–864 (18-space indent):
```dart
                  throw const AppException(
                    code: AppErrorCode.validation,
                    message: 'Already on this story',
                  );
```
- lines 946–948 (16-space indent):
```dart
                throw const AppException(
                  code: AppErrorCode.validation,
                  message: 'Already on this story',
                );
```

(b) `test/invite_chrome_test.dart`: delete line 4 (`supabase_flutter` import). After line 5 (`'package:tell_me_a_story/core/config/env.dart'`), insert `import 'package:tell_me_a_story/data/app_exception.dart';`. Then:
- lines 263–266 →
```dart
        ..updateError = const AppException(
          code: AppErrorCode.validation,
          message: 'That email is already used',
        );
```
- lines 299–302 →
```dart
        ..updateError = Exception(
          'duplicate key value violates unique constraint',
        );
```
- lines 333–336 →
```dart
      ..updateError = Exception(
        'duplicate key value violates unique constraint',
      );
```

(c) `test/m14_3_dob_passed_away_test.dart`: delete line 6 (`supabase_flutter` import). After the `core/server/app_session.dart` import added in Task 2, insert `import 'package:tell_me_a_story/data/app_exception.dart';`. Replace lines 187–189 with:
```dart
      ..markError = const AppException(
        code: AppErrorCode.forbidden,
        message: 'not a steward',
      );
```

(d) Create `apps/tell_me_a_story/test/gateway_errors_test.dart`:
```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

typedef _Reply = ({int status, Object body});

/// Answers each request from [reply] and records `METHOD /path`.
class _Http extends http.BaseClient {
  _Http(this.reply);

  final _Reply Function(http.BaseRequest request) reply;
  final calls = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add('${request.method} ${request.url.path}');
    final answer = reply(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(answer.body))),
      answer.status,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

SupabaseClient _client(_Http transport) =>
    SupabaseClient('http://localhost', 'test-anon-key', httpClient: transport);

_Reply _error(int status, String code, String message) =>
    (status: status, body: {'code': code, 'message': message});

void main() {
  group('catalog RPC errors', () {
    test('PeopleApi.markPassedAway reports FORBIDDEN as AppException', () async {
      final api = PeopleApi(
        client: _client(
          _Http((_) => _error(400, 'P0001', 'FORBIDDEN: not a steward')),
        ),
      );
      await expectLater(
        api.markPassedAway(personId: 'p1', value: true),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having((e) => e.message, 'message', 'not a steward'),
        ),
      );
    });

    test('PeopleApi.markPassedAway leaves an uncatalogued error alone', () async {
      final api = PeopleApi(
        client: _client(_Http((_) => _error(500, 'XX000', 'boom'))),
      );
      await expectLater(
        api.markPassedAway(personId: 'p1', value: true),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('StoriesApi.linkPerson reports VALIDATION as AppException', () async {
      final api = StoriesApi(
        client: _client(
          _Http(
            (_) => _error(400, 'P0001', 'VALIDATION: Already on this story'),
          ),
        ),
      );
      await expectLater(
        api.linkPerson(storyId: 's1', personId: 'p1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.validation)
              .having((e) => e.message, 'message', 'Already on this story'),
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/add_person_modal_test.dart test/invite_chrome_test.dart test/m14_3_dob_passed_away_test.dart test/gateway_errors_test.dart`
Expected: FAIL. Examples:
- `add_person_modal_test`: `Found 0 widgets with text "Already on this story"` (the snackbar shows `Couldn’t save person. Try again.`).
- `invite_chrome_test` "mapped error": `Found 0 widgets with text "That email is already used"`.
- `m14_3`: `Found 0 widgets with text "not a steward"`.
- `gateway_errors_test`: `Expected: <Instance of 'AppException'> … Actual: PostgrestException`.

- [ ] **Step 3: Write minimal implementation**

Delete the old mapper:
```bash
git rm apps/tell_me_a_story/lib/data/rpc_error.dart
```

`lib/features/family/family_landing_page.dart`
- Delete line 19 (`import '../../data/rpc_error.dart';`). Before line 12 (`import '../../data/families_api.dart';`), insert `import '../../data/app_exception.dart';`
- Line 219: `_snack(mapRpcError(error) ?? 'Try again');` → `_snack(appErrorMessage(error) ?? 'Try again');`
- Line 279: `: mapRpcError(error) ??` → `: appErrorMessage(error) ??`

`lib/features/invites/invite_modal.dart`
- Delete line 9 (`rpc_error.dart` import). Before line 7 (`import '../../data/invite_api.dart';`), insert `import '../../data/app_exception.dart';`
- Line 221: `_rowError[person.id] = mapRpcError(error) ?? 'Try again';` → `_rowError[person.id] = appErrorMessage(error) ?? 'Try again';`

`lib/features/people/add_person_modal.dart`
- Delete line 10 (`rpc_error.dart` import). Before line 8 (`import '../../data/invite_api.dart';`), insert `import '../../data/app_exception.dart';`
- Line 128: `final message = mapRpcError(error) ?? 'Couldn’t save person. Try again.';` → `final message = appErrorMessage(error) ?? 'Couldn’t save person. Try again.';`

`lib/features/people/person_profile_dialog.dart`
- Delete line 9 (`rpc_error.dart` import). Before line 7 (`import '../../data/invite_api.dart';`), insert `import '../../data/app_exception.dart';`
- Line 230: `SnackBar(content: Text(mapRpcError(error) ?? 'Try again')),` → `SnackBar(content: Text(appErrorMessage(error) ?? 'Try again')),`

`lib/data/people_api.dart`
- After line 6 (`import 'photos_api.dart';`), insert `import 'supabase_errors.dart';`
- Replace `listTreePeople` (lines 245–254) with:
```dart
  @override
  Future<List<Person>> listTreePeople(String familyId) {
    return withAppErrors(() async {
      final familyIds = await _treeFamilyIds(familyId);
      final rows = await _client
          .from('people')
          .select(_treeSelect)
          .inFilter('family_id', familyIds)
          .order('name');
      return Future.wait(rows.map(_treePerson));
    });
  }
```
- In `createPerson`, replace lines 302–320 (from `final uid = _client.auth.currentUser!.id;` through `return person;`) with:
```dart
    return withAppErrors(() async {
      final uid = _client.auth.currentUser!.id;
      final row = await _client
          .from('people')
          .insert({
            'family_id': familyId,
            'name': name.trim(),
            'relationship': null,
            'email': ?trimmedEmail,
            'passed_away': passedAway,
            'about': ?trimmedAbout,
            'created_by': uid,
          })
          .select(_rowSelect)
          .single();
      var person = Person.fromJson(row);
      if (pictureBytes != null && pictureBytes.isNotEmpty) {
        person = await _uploadPersonPicture(person, pictureBytes);
      }
      return person;
    });
```
- In `updatePerson`, replace lines 378–388 (from `final row = await _client` through `return person;`) with:
```dart
    return withAppErrors(() async {
      final row = await _client
          .from('people')
          .update(patch)
          .eq('id', personId)
          .select(_rowSelect)
          .single();
      var person = Person.fromJson(row);
      if (pictureBytes != null && pictureBytes.isNotEmpty) {
        person = await _uploadPersonPicture(person, pictureBytes);
      }
      return person;
    });
```
- Replace `markPassedAway` (lines 405–414) with:
```dart
  @override
  Future<void> markPassedAway({
    required String personId,
    required bool value,
  }) {
    return withAppErrors(() async {
      await _client.rpc(
        'mark_passed_away',
        params: {'p_person_id': personId, 'p_value': value},
      );
    });
  }
```

`lib/data/stories_api.dart`
- After line 5 (`import 'photos_api.dart';`), insert `import 'supabase_errors.dart';`
- Replace `listPublished` (lines 671–683) with:
```dart
  @override
  Future<List<Story>> listPublished(String familyId) {
    return withAppErrors(() async {
      final rows = await _client
          .from('stories')
          .select(_publishedSelect)
          .eq('family_id', familyId)
          .eq('status', 'published')
          .order('timeframe_start')
          .order('date_precision')
          .order('created_at')
          .order('id');
      return rows.map(Story.fromJson).toList();
    });
  }
```
- Replace `linkPerson` (lines 736–745) with:
```dart
  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) {
    return withAppErrors(() async {
      await _client.from('story_people').insert({
        'story_id': storyId,
        'person_id': personId,
      });
    });
  }
```

`lib/data/families_api.dart`
- After line 6 (`import 'recovery_window.dart';`), insert `import 'supabase_errors.dart';`
- Replace `setCoverPhoto` and `clearCoverPhoto` (lines 358–389) with:
```dart
  /// Upload the hero, then store its object key on the family row.
  @override
  Future<String> setCoverPhoto({
    required String familyId,
    required Uint8List bytes,
    String? previousPath,
  }) {
    return withAppErrors(() async {
      final path = await save(familyId: familyId, bytes: bytes);
      await _client
          .from('families')
          .update({'cover_photo_path': path})
          .eq('id', familyId);
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != path) {
        await _client.storage.from(familyCoversBucket).remove([previousPath]);
      }
      return path;
    });
  }

  /// Delete the hero object and clear `cover_photo_path`.
  @override
  Future<void> clearCoverPhoto({
    required String familyId,
    required String? path,
  }) {
    return withAppErrors(() async {
      await clear(familyId: familyId, path: path);
      await _client
          .from('families')
          .update({'cover_photo_path': null})
          .eq('id', familyId);
    });
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/add_person_modal_test.dart test/invite_chrome_test.dart test/m14_3_dob_passed_away_test.dart test/gateway_errors_test.dart test/people_api_test.dart test/family_landing_latest_test.dart
mise exec -- flutter test
```
Expected: PASS. The invite_chrome cases `'email save falls back to Try again when the person error is unmapped'` and `'a failed email save clears Try again after the retry succeeds'` still show `Try again`.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib apps/tell_me_a_story/test
git commit -m "refactor(client): catalog RPC errors surface as AppException"
```

---

### Task 7: Edge-function envelopes become `AppException`

`InviteApi._invoke` (`invite_api.dart:115-152`) and `ManageFamiliesApi._invoke` (`manage_families_api.dart:148-187`) each build their own exception type from the same `{code, message}` envelope. After this task both throw `AppException`, and `InviteApiException` / `ManageFamiliesException` are deleted.

Each envelope keeps its own fallback copy: `'Request failed'` (or the `reasonPhrase`) for invites, `'Try again'` for manage-families.

Features change `on XException` to `on AppException`. These are the only catches, and none of their try blocks call a guarded gateway (audited: `manage_family_page.dart` and `manage_families_page.dart` `_load()` catch their own errors). So the shown copy is unchanged.

`start_timeline_dialog.dart:215-227` branches on code:
- `NOT_FOUND` → `AppErrorCode.notFound`
- `FORBIDDEN` → `AppErrorCode.forbidden`
- every other code still shows `error.message` unless it is internal.

`add_person_modal.dart:189-200` sends invites inside the save `try`. Before this task an `InviteApiException` was not mapped there, so it showed `Couldn’t save person. Try again.`. An explicit catch keeps that copy.

**Files:**
- Modify: `lib/data/supabase_errors.dart` (append), `lib/data/invite_api.dart:1-5,115-152,222-231`, `lib/data/manage_families_api.dart:1,44-49,71-73,134-139,148-197`
- Modify: `lib/features/invites/invite_modal.dart:171,240`; `lib/features/family/manage_families_page.dart:10,191`; `lib/features/family/manage_family_page.dart:12,222,241,274,297,314,344,365,383`; `lib/features/family/start_family_dialog.dart:7,64`; `lib/features/family/start_timeline_dialog.dart:6,200,215-224`; `lib/features/people/add_person_modal.dart:127-131,189-200`
- Test: `test/supabase_errors_test.dart`, `test/gateway_errors_test.dart`, `test/invite_chrome_test.dart:225,396`, `test/manage_family_rename_guard_test.dart:189`, `test/start_timeline_test.dart:943,953,962,981,991,1006`, `test/m14_people_profiles_test.dart`

- [ ] **Step 1: Write the failing tests**

(a) Append inside `main()` of `test/supabase_errors_test.dart`, before its closing `}`:
```dart

  group('edge-function envelopes', () {
    test('map codes; unknown or missing codes are validation', () {
      expect(envelopeErrorCode('NOT_FOUND'), AppErrorCode.notFound);
      expect(envelopeErrorCode('FORBIDDEN'), AppErrorCode.forbidden);
      expect(envelopeErrorCode('VALIDATION'), AppErrorCode.validation);
      expect(envelopeErrorCode('INVITE_INVALID'), AppErrorCode.inviteInvalid);
      expect(envelopeErrorCode('INVITE_EXPIRED'), AppErrorCode.inviteInvalid);
      expect(envelopeErrorCode('INVITE_ACCEPTED'), AppErrorCode.inviteInvalid);
      expect(envelopeErrorCode('AUTH_REQUIRED'), AppErrorCode.unauthenticated);
      expect(envelopeErrorCode('SOMETHING_NEW'), AppErrorCode.validation);
      expect(envelopeErrorCode(null), AppErrorCode.validation);
    });

    test('use the body message, else the fallback', () {
      final withMessage = appExceptionFromEnvelope(
        envelopeBody({'code': 'FORBIDDEN', 'message': 'member only'}),
        fallbackMessage: 'Try again',
      );
      expect(withMessage.code, AppErrorCode.forbidden);
      expect(withMessage.message, 'member only');

      final bare = appExceptionFromEnvelope(
        envelopeBody('not a map'),
        fallbackMessage: 'Request failed',
      );
      expect(bare.code, AppErrorCode.validation);
      expect(bare.message, 'Request failed');
    });
  });
```

(b) `test/gateway_errors_test.dart`: add `import 'package:tell_me_a_story/data/invite_api.dart';` and `import 'package:tell_me_a_story/data/manage_families_api.dart';` after the `app_exception.dart` import. Append inside `main()`:
```dart

  group('edge functions without a session', () {
    test('InviteApi reports unauthenticated', () async {
      final api = InviteApi(
        client: _client(_Http((_) => (status: 200, body: const <String, Object>{}))),
      );
      await expectLater(
        api.createInvite(familyId: 'f1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.unauthenticated)
              .having((e) => e.message, 'message', 'Sign-in required'),
        ),
      );
    });

    test('ManageFamiliesApi reports unauthenticated', () async {
      final api = ManageFamiliesApi(
        client: _client(_Http((_) => (status: 200, body: const <String, Object>{}))),
      );
      await expectLater(
        api.renameFamily(familyId: 'f1', name: 'Morgan'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.unauthenticated)
              .having((e) => e.message, 'message', 'Sign-in required'),
        ),
      );
    });
  });
```

(c) Migrate the fakes to `AppException`:
- `test/invite_chrome_test.dart` lines 225–228 →
```dart
      ..createError = const AppException(
        code: AppErrorCode.validation,
        message: 'person is already linked',
      );
```
  and lines 396–399 →
```dart
      ..sendError = const AppException(
        code: AppErrorCode.validation,
        message: 'Invite has no email address to send to',
      );
```
- `test/manage_family_rename_guard_test.dart`: before line 6 (`'package:tell_me_a_story/data/families_api.dart'`), insert `import 'package:tell_me_a_story/data/app_exception.dart';`. Replace lines 189–192 with:
```dart
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Rename failed',
      );
```
- `test/start_timeline_test.dart`: before line 10 (`'package:tell_me_a_story/data/comments_api.dart'`), insert `import 'package:tell_me_a_story/data/app_exception.dart';`. Then:
  - lines 943–946 → `manage.error = const AppException(code: AppErrorCode.validation, message: 'too many levels');`
  - line 953 → `manage.error = const AppException(code: AppErrorCode.notFound, message: 'story');`
  - lines 962–965 → `manage.error = const AppException(code: AppErrorCode.forbidden, message: 'member only');`
  - lines 981–984 → `manage.error = const AppException(code: AppErrorCode.validation, message: 'create_branch_family returned no id');`
  - lines 991–994 → `manage.error = const AppException(code: AppErrorCode.validation, message: 'Request failed');`
  - line 1006 → `..error = const AppException(code: AppErrorCode.notFound, message: 'story');`

(d) Add an add-person regression test to `test/m14_people_profiles_test.dart`:
- Before line 6 (`'package:tell_me_a_story/data/families_api.dart'`), insert `import 'package:tell_me_a_story/data/app_exception.dart';`
- In `class _Invites` (line 747), after `final sent = <String>[];` (line 751), insert:
```dart
  Object? createError;
```
- In `_Invites.createInvite`, after `emails.add(email);` (line 769), insert:
```dart
    final error = createError;
    if (error != null) throw error;
```
- After the test ending at line 150 (`'Send invite saves, then create-invite, then send-invite-email'`), insert:
```dart

  testWidgets('a failed invite after saving keeps the save sentence', (
    tester,
  ) async {
    final api = _People();
    final invites = _Invites()
      ..createError = const AppException(
        code: AppErrorCode.validation,
        message: 'person is already linked',
      );
    await _openAdd(tester, api, invites: invites);
    await tester.enterText(find.byKey(const Key('add-person-name')), 'Ada');
    await tester.enterText(
      find.byKey(const Key('add-person-email')),
      'ada@example.com',
    );
    final save = find.widgetWithText(FilledButton, 'Add person');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-invite-confirm-yes')));
    await tester.pumpAndSettle();

    expect(api.createCalls, 1);
    expect(find.text('Couldn’t save person. Try again.'), findsOneWidget);
    expect(find.text('person is already linked'), findsNothing);
    expect(invites.sent, isEmpty);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/supabase_errors_test.dart test/gateway_errors_test.dart test/invite_chrome_test.dart test/manage_family_rename_guard_test.dart test/start_timeline_test.dart test/m14_people_profiles_test.dart`
Expected: FAIL. `supabase_errors_test` fails to compile (`envelopeErrorCode` isn't defined). The widget tests show fallback copy instead of the fake message: `Found 0 widgets with text "person is already linked"`, `"too many levels"`, `"Rename failed"`. The new m14 test finds `person is already linked` because `appErrorMessage` now maps it.

- [ ] **Step 3: Write minimal implementation**

(a) Append to `lib/data/supabase_errors.dart`:
```dart

/// Edge-function JSON body as a map. Anything else is empty.
Map<String, dynamic> envelopeBody(Object? data) {
  return switch (data) {
    final Map<String, dynamic> m => m,
    final Map m => Map<String, dynamic>.from(m),
    _ => <String, dynamic>{},
  };
}

/// Edge-function `code` → [AppErrorCode]. Unknown or missing codes are
/// [AppErrorCode.validation], as the old envelopes defaulted to `VALIDATION`.
AppErrorCode envelopeErrorCode(Object? code) {
  return switch (code) {
    'NOT_FOUND' => AppErrorCode.notFound,
    'FORBIDDEN' => AppErrorCode.forbidden,
    'INVITE_INVALID' ||
    'INVITE_EXPIRED' ||
    'INVITE_ACCEPTED' => AppErrorCode.inviteInvalid,
    'AUTH_REQUIRED' => AppErrorCode.unauthenticated,
    _ => AppErrorCode.validation,
  };
}

/// Edge-function error body `{code, message}` as an [AppException].
AppException appExceptionFromEnvelope(
  Map<String, dynamic> body, {
  required String fallbackMessage,
}) {
  return AppException(
    code: envelopeErrorCode(body['code']),
    message: body['message'] as String? ?? fallbackMessage,
  );
}
```

(b) `lib/data/invite_api.dart`
- After line 3 (`import '../core/config/env.dart';`), insert `import 'app_exception.dart';`. After line 5 (`import 'profile_session.dart';`), insert `import 'supabase_errors.dart';`
- Replace lines 115–153 (`_invoke`, `_asMap` and the `}` that closes `InviteApi`) with:
```dart
  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body, {
    int expectStatus = 200,
  }) async {
    if (_client.auth.currentSession == null) {
      throw const AppException(
        code: AppErrorCode.unauthenticated,
        message: 'Sign-in required',
      );
    }
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final decoded = envelopeBody(res.data);
      if (res.status != expectStatus) {
        throw appExceptionFromEnvelope(
          decoded,
          fallbackMessage: 'Request failed',
        );
      }
      return decoded;
    } on FunctionException catch (e) {
      throw appExceptionFromEnvelope(
        envelopeBody(e.details),
        fallbackMessage: e.reasonPhrase ?? 'Request failed',
      );
    }
  }
}
```
(The trailing `}` closes `InviteApi`.)
- Delete lines 222–231 (the blank line plus `class InviteApiException … }`).

(c) `lib/data/manage_families_api.dart`
- After line 1 (`import 'package:supabase_flutter/supabase_flutter.dart';`), insert:
```dart

import 'app_exception.dart';
import 'supabase_errors.dart';
```
- Lines 45–48 →
```dart
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'create_family returned no id',
      );
```
- Line 72 →
```dart
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Try again',
      );
```
- Lines 135–138 →
```dart
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'resend_invite returned no expires_at',
      );
```
- Replace lines 148–197 (`_invoke`, the class's closing `}`, top-level `_asMap`, and `class ManageFamiliesException`) with:
```dart
  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, dynamic> body, {
    int expectStatus = 200,
  }) async {
    if (_client.auth.currentSession == null) {
      throw const AppException(
        code: AppErrorCode.unauthenticated,
        message: 'Sign-in required',
      );
    }
    try {
      final res = await _client.functions.invoke(functionName, body: body);
      final decoded = envelopeBody(res.data);
      if (res.status != expectStatus) {
        throw appExceptionFromEnvelope(decoded, fallbackMessage: 'Try again');
      }
      return decoded;
    } on FunctionException catch (e) {
      throw appExceptionFromEnvelope(
        envelopeBody(e.details),
        fallbackMessage: 'Try again',
      );
    }
  }
}
```

(d) Features
- `lib/features/invites/invite_modal.dart` lines 171 and 240: `} on InviteApiException catch (error) {` → `} on AppException catch (error) {` (the `app_exception.dart` import was added in Task 6).
- `lib/features/family/manage_families_page.dart`: before line 10 (`import '../../data/families_api.dart';`), insert `import '../../data/app_exception.dart';`. Line 191: `} on ManageFamiliesException catch (e) {` → `} on AppException catch (e) {`.
- `lib/features/family/manage_family_page.dart`: before line 12 (`import '../../data/families_api.dart';`), insert `import '../../data/app_exception.dart';`. Replace all eight occurrences of `} on ManageFamiliesException catch (e) {` (lines 222, 241, 274, 297, 314, 344, 365, 383) with `} on AppException catch (e) {`.
- `lib/features/family/start_family_dialog.dart`: before line 7 (`import '../../data/manage_families_api.dart';`), insert `import '../../data/app_exception.dart';`. Line 64: `} on ManageFamiliesException catch (e) {` → `} on AppException catch (e) {`.
- `lib/features/family/start_timeline_dialog.dart`: before line 6 (`import '../../data/comments_api.dart';`), insert `import '../../data/app_exception.dart';`. Line 200: `} on ManageFamiliesException catch (error) {` → `} on AppException catch (error) {`. Replace lines 215–224 with:
```dart
  String _inlineError(AppException error) {
    if (error.code == AppErrorCode.notFound) {
      if (widget.allowChange) {
        return "That story isn't available anymore. Pick another one.";
      }
      return "That story isn't available anymore.";
    }
    if (error.code == AppErrorCode.forbidden) {
      return "You're not a member of ${widget.parentName} anymore.";
    }
```
- `lib/features/people/add_person_modal.dart`: replace `_showSaveError` (lines 127–131) with:
```dart
  static const _saveFailed = 'Couldn’t save person. Try again.';

  void _showSaveError(Object error) {
    _snack(appErrorMessage(error) ?? _saveFailed);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
```
  Then replace lines 189–200 (the `if (_sendInvite && !_inviteSent) { … }` block) with:
```dart
      if (_sendInvite && !_inviteSent) {
        final invites = widget.invites;
        if (invites != null) {
          try {
            final created = await invites.createInvite(
              familyId: widget.familyId,
              email: email,
              personId: person.id,
            );
            await invites.sendInviteEmail(inviteId: created.inviteId);
          } on AppException {
            // The person row is saved; invite failures keep the save sentence.
            if (mounted) _snack(_saveFailed);
            return;
          }
        }
        _inviteSent = true;
      }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/supabase_errors_test.dart test/gateway_errors_test.dart test/invite_chrome_test.dart test/manage_family_rename_guard_test.dart test/start_timeline_test.dart test/m14_people_profiles_test.dart test/family_menu_cleanup_test.dart
mise exec -- flutter test
git grep -n -E "InviteApiException|ManageFamiliesException" -- apps/tell_me_a_story
```
Expected: tests PASS. The grep prints nothing.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib apps/tell_me_a_story/test
git commit -m "refactor(client): edge-function envelopes surface as AppException"
```

---

### Task 8: Origin and person-profile errors become `AppException`

`originRpcException` (`families_api.dart:145-167`) keeps its §12 sentences: `You do not have permission to do that.`, `Not found.`, and the VALIDATION detail. It now builds `AppException`, and `OriginRpcException` is deleted.

`PeopleApi.personProfile` (`people_api.dart:334-348`) uses `withAppErrors`, so NOT_FOUND becomes `AppException(notFound)` and `PersonProfileNotFound` is deleted. Its callers:
- `person_profile_dialog.dart:127-134` treats every error as "missing", so the `on PersonProfileNotFound` clause is simply removed.
- `PeopleApi._treePerson` (`:257-271`) used to fail the tree listing with a non-catalog error, which showed generic copy in `add_person_modal`. `_treeProfile` keeps that.

**Files:**
- Modify: `lib/data/families_api.dart:5,133-167,459-462,474-477`; `lib/data/people_api.dart:5,121-123,257-271,334-348`
- Modify: `lib/features/stories/story_reader_page.dart:13,683`; `lib/features/people/person_profile_dialog.dart:130-131`
- Test: `test/gateway_errors_test.dart`, `test/story_reader_page_test.dart:2198-2201,2212-2215,2694`, `test/m14_people_profiles_test.dart:705`

- [ ] **Step 1: Write the failing tests**

(a) `test/gateway_errors_test.dart`: add `import 'package:tell_me_a_story/data/families_api.dart';` after the `app_exception.dart` import. Append inside `main()`:
```dart

  group('origin and profile RPCs', () {
    test('FamiliesApi.setFamilyOrigin keeps the VALIDATION detail', () async {
      final api = FamiliesApi(
        client: _client(
          _Http(
            (_) => _error(400, 'P0001', 'VALIDATION: origin must be published'),
          ),
        ),
      );
      await expectLater(
        api.setFamilyOrigin(familyId: 'f1', storyId: 's1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.validation)
              .having((e) => e.message, 'message', 'origin must be published'),
        ),
      );
    });

    test('FamiliesApi.setFamilyOrigin uses the FORBIDDEN sentence', () async {
      final api = FamiliesApi(
        client: _client(
          _Http((_) => _error(400, 'P0001', 'FORBIDDEN: not a steward')),
        ),
      );
      await expectLater(
        api.setFamilyOrigin(familyId: 'f1', storyId: 's1'),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', AppErrorCode.forbidden)
              .having(
                (e) => e.message,
                'message',
                'You do not have permission to do that.',
              ),
        ),
      );
    });

    test('PeopleApi.personProfile reports NOT_FOUND as AppException', () async {
      final api = PeopleApi(
        client: _client(_Http((_) => _error(400, 'P0001', 'NOT_FOUND: person'))),
      );
      await expectLater(
        api.personProfile('p1'),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', AppErrorCode.notFound),
        ),
      );
    });
  });
```

(b) `test/story_reader_page_test.dart`: before line 10 (`'package:tell_me_a_story/data/comments_api.dart'`), insert `import 'package:tell_me_a_story/data/app_exception.dart';`. Then:
- lines 2198–2201 →
```dart
      families.originError = const AppException(
        code: AppErrorCode.validation,
        message: 'origin must be published',
      );
```
- lines 2212–2215 →
```dart
      families.originError = const AppException(
        code: AppErrorCode.forbidden,
        message: 'You do not have permission to do that.',
      );
```
- line 2694 → `AppException? originError;`

(c) `test/m14_people_profiles_test.dart` line 705 (in `_People.personProfile`) →
```dart
    if (missing) {
      throw const AppException(
        code: AppErrorCode.notFound,
        message: 'person',
      );
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/gateway_errors_test.dart test/story_reader_page_test.dart test/m14_people_profiles_test.dart`
Expected: FAIL. `gateway_errors_test` gets `OriginRpcException` / `PersonProfileNotFound` where it expects `AppException`. `story_reader_page_test` finds `Try again` instead of `origin must be published`, because the reader still checks `is OriginRpcException`.

- [ ] **Step 3: Write minimal implementation**

`lib/data/families_api.dart`
- Before line 5 (`import 'family_covers.dart';`), insert `import 'app_exception.dart';`
- Replace lines 133–167 (`class OriginRpcException` and `originRpcException`) with:
```dart
/// §12 catalog text for a `set_family_origin` / `list_origin_dependents`
/// failure. Null when [error] is not one.
AppException? _originError(Object error) {
  if (error is! PostgrestException) return null;
  final raw = error.message;
  if (raw.contains('FORBIDDEN')) {
    return const AppException(
      code: AppErrorCode.forbidden,
      message: 'You do not have permission to do that.',
    );
  }
  if (raw.contains('NOT_FOUND')) {
    return const AppException(code: AppErrorCode.notFound, message: 'Not found.');
  }
  if (raw.contains('VALIDATION')) {
    const marker = 'VALIDATION: ';
    final index = raw.indexOf(marker);
    final detail = index >= 0
        ? raw.substring(index + marker.length).trim()
        : raw;
    return AppException(code: AppErrorCode.validation, message: detail);
  }
  return null;
}
```
- Lines 460 and 475: `final mapped = originRpcException(error);` → `final mapped = _originError(error);`

`lib/data/people_api.dart`
- Before line 5 (`import 'families_api.dart';`), insert `import 'app_exception.dart';`
- Delete lines 121–124 (`class PersonProfileNotFound … }` and the blank line after it).
- In `_treePerson` (line 259–261), replace
```dart
    final profile = userId == null
        ? null
        : await personProfile(row['id'] as String);
```
  with
```dart
    final profile = userId == null
        ? null
        : await _treeProfile(row['id'] as String);
```
  and add this method right after `_treePerson`:
```dart

  /// [personProfile] for one tree row. A hidden linked row fails the listing
  /// with a non-catalog error, so callers keep their generic failure copy.
  Future<PersonProfile?> _treeProfile(String personId) async {
    try {
      return await personProfile(personId);
    } on AppException catch (error) {
      if (error.code != AppErrorCode.notFound) rethrow;
      throw StateError('person_profile: ${error.message}');
    }
  }
```
- Replace `personProfile` (lines 334–348) with:
```dart
  @override
  Future<PersonProfile?> personProfile(String personId) {
    return withAppErrors(() async {
      final res = await _client.rpc(
        'person_profile',
        params: {'p_person_id': personId},
      );
      return personProfileFromRpc(res);
    });
  }
```

`lib/features/people/person_profile_dialog.dart`
- Delete lines 130–131:
```dart
    } on PersonProfileNotFound {
      missing = true;
```
(the remaining `} catch (_) { missing = true; }` handles it).

`lib/features/stories/story_reader_page.dart`
- Before line 13 (`import '../../data/comments_api.dart';`), insert `import '../../data/app_exception.dart';`
- Line 683: `final message = error is OriginRpcException ? error.message : 'Try again';` → `final message = error is AppException ? error.message : 'Try again';`

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/gateway_errors_test.dart test/story_reader_page_test.dart test/m14_people_profiles_test.dart test/people_api_test.dart test/add_person_modal_test.dart
mise exec -- flutter test
git grep -n -E "OriginRpcException|originRpcException|PersonProfileNotFound" -- apps/tell_me_a_story
```
Expected: tests PASS. The grep prints nothing.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib apps/tell_me_a_story/test
git commit -m "refactor(client): origin and person-profile errors surface as AppException"
```

---

### Task 9: Duplicate writes are idempotent inside `StoriesApi`

Today `new_story_page.dart` catches `PostgrestException` twice:
- `:468-480`, to ignore a duplicate `story_people_pkey`;
- `:726-729`, to turn a retried create with the same client id into an update.

Both move into `StoriesApi`, matching the server contract (§2.2: `createDraft` is idempotent on id, `linkPerson` is ON CONFLICT DO NOTHING). The page then has no Supabase import.

**Files:**
- Modify: `lib/data/stories_api.dart:346-352` (add a helper after it), `:428-465`, `:736-745`
- Modify: `lib/features/stories/new_story_page.dart:7,451,468-481,708-730`
- Test: `test/stories_api_test.dart` (after line 163), `test/gateway_errors_test.dart`, `test/new_story_shell_test.dart:5,548-563,897,942-949`, `test/new_story_capture_test.dart:7,184,356-361,1607-1634,1638-1641,1838-1868`

- [ ] **Step 1: Write the failing tests**

(a) `test/stories_api_test.dart`: after the `isDuplicateStoryKey` test (ends line 163), insert:
```dart

  group('createOrUpdateExisting', () {
    test('a duplicate client id runs the update', () async {
      final calls = <String>[];
      final result = await createOrUpdateExisting<String>(
        id: 's1',
        insert: () async {
          calls.add('insert');
          throw const PostgrestException(
            message:
                'duplicate key value violates unique constraint "stories_pkey"',
            code: '23505',
          );
        },
        update: () async {
          calls.add('update');
          return 'updated';
        },
      );
      expect(result, 'updated');
      expect(calls, ['insert', 'update']);
    });

    test('without a client id the duplicate is rethrown', () async {
      await expectLater(
        createOrUpdateExisting<String>(
          id: null,
          insert: () async => throw const PostgrestException(
            message: 'duplicate key value',
            code: '23505',
          ),
          update: () async => 'updated',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('other insert errors are rethrown', () async {
      final error = StateError('network');
      await expectLater(
        createOrUpdateExisting<String>(
          id: 's1',
          insert: () async => throw error,
          update: () async => 'updated',
        ),
        throwsA(same(error)),
      );
    });
  });
```

(b) `test/gateway_errors_test.dart`: append inside `main()`:
```dart

  group('StoriesApi.linkPerson duplicates', () {
    test('an existing story_people row counts as linked', () async {
      final api = StoriesApi(
        client: _client(
          _Http(
            (_) => _error(
              409,
              '23505',
              'duplicate key value violates unique constraint "story_people_pkey"',
            ),
          ),
        ),
      );
      await api.linkPerson(storyId: 's1', personId: 'p1');
    });

    test('a duplicate on another constraint still fails', () async {
      final api = StoriesApi(
        client: _client(
          _Http(
            (_) => _error(
              409,
              '23505',
              'duplicate key value violates unique constraint "photos_pkey"',
            ),
          ),
        ),
      );
      await expectLater(
        api.linkPerson(storyId: 's1', personId: 'p1'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
```

(c) Page tests now model the idempotent gateway:
- `test/new_story_shell_test.dart`: delete line 5 (`supabase_flutter` import). Delete the test `'a duplicate-key insert becomes an update by the same id'` (lines 548–563, plus the blank line after it). It now lives in `stories_api_test` as `createOrUpdateExisting`. Delete line 897 (`var duplicateOnCreate = false;`) and lines 942–949 (the `if (duplicateOnCreate) { … }` block).
- `test/new_story_capture_test.dart`:
  - delete line 7 (`supabase_flutter … show PostgrestException`);
  - delete line 184 (`Set<String> duplicateLinkIds = {};`);
  - delete lines 356–361 (the `if (duplicateLinkIds.contains(personId)) { throw … }` block);
  - delete the test `'re-adding a person already on the story shows no error'` (lines 1607–1634 plus the blank line after it), since the duplicate case is now covered by `gateway_errors_test`;
  - in `'other link errors still show the save error'` replace lines 1638–1641 with:
```dart
      ..linkError = Exception(
        'new row violates row-level security policy for table "story_people"',
      );
```
  - delete the test `'a duplicate key on another constraint still shows the save error'` (lines 1838–1868 plus the blank line after it). The page no longer inspects constraint names, and the gateway test above covers `photos_pkey`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/stories_api_test.dart test/gateway_errors_test.dart`
Expected: FAIL. `stories_api_test` fails to compile (`The function 'createOrUpdateExisting' isn't defined`). The first linkPerson duplicate test throws `PostgrestException(... story_people_pkey ...)`.

- [ ] **Step 3: Write minimal implementation**

`lib/data/stories_api.dart`
- After `isDuplicateStoryKey` (ends line 352), insert:
```dart

/// Runs [insert]. When a retried create collides on its client-chosen [id],
/// runs [update] instead, so creating the same draft twice is one draft.
Future<T> createOrUpdateExisting<T>({
  required String? id,
  required Future<T> Function() insert,
  required Future<T> Function() update,
}) async {
  try {
    return await insert();
  } catch (error) {
    if (id == null || !isDuplicateStoryKey(error)) rethrow;
    return update();
  }
}
```
- Replace the `createDraft` body (lines 441–464, from `if (!allowUndated) {` through `return getStory(story.id);`) with:
```dart
    if (!allowUndated) {
      ensureValidDraftSave(timeframeStart: timeframeStart);
    }
    return createOrUpdateExisting(
      id: id,
      insert: () async {
        final uid = _client.auth.currentUser!.id;
        final payload = <String, dynamic>{
          'family_id': familyId,
          'author_id': uid,
          'title': storedStoryTitle(title),
          'body': body?.trim(),
          'timeframe_start': timeframeStart == null
              ? null
              : _date(timeframeStart),
          'timeframe_end': timeframeEnd == null ? null : _date(timeframeEnd),
          if (datePrecision != null) 'date_precision': datePrecision,
          'place_id': placeId,
          'status': 'draft',
        };
        if (id != null) payload['id'] = id;
        final row = await _client
            .from('stories')
            .insert(payload)
            .select(_storySelect)
            .single();
        final story = Story.fromJson(row);
        await _replacePeople(story.id, personIds);
        return getStory(story.id);
      },
      update: () => updateDraft(
        storyId: id!,
        timeframeStart: timeframeStart,
        timeframeEnd: timeframeEnd,
        datePrecision: datePrecision,
        title: title,
        body: body,
        placeId: placeId,
        personIds: personIds,
      ),
    );
```
- Replace `linkPerson` (the Task 6 version) with:
```dart
  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) {
    return withAppErrors(() async {
      try {
        await _client.from('story_people').insert({
          'story_id': storyId,
          'person_id': personId,
        });
      } on PostgrestException catch (error) {
        // A retried link: the row this call writes already exists.
        if (error.code != '23505' ||
            !error.message.contains('story_people_pkey')) {
          rethrow;
        }
      }
    });
  }
```

`lib/features/stories/new_story_page.dart`
- Delete line 7: `import 'package:supabase_flutter/supabase_flutter.dart';`
- Line 451: `linkPerson: _linkIgnoringDuplicate,` → `linkPerson: _stories.linkPerson,`
- Delete lines 468–481 (`_linkIgnoringDuplicate` and the blank line after it).
- Replace lines 708–730 (the `if (!_autosaveInserted) { … }` block in `_writeDraft`) with:
```dart
    if (!_autosaveInserted) {
      if (!autosave && snapshot.start == null) return null;
      final created = await _stories.createDraft(
        id: snapshot.id,
        allowUndated: autosave,
        familyId: snapshot.familyId,
        timeframeStart: snapshot.start,
        timeframeEnd: snapshot.end,
        datePrecision: snapshot.precision,
        title: snapshot.title,
        body: snapshot.body,
        placeId: snapshot.placeId,
        personIds: snapshot.personIds ?? const [],
      );
      _autosaveInserted = true;
      _storyId = created.id;
      return created;
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/stories_api_test.dart test/gateway_errors_test.dart test/new_story_shell_test.dart test/new_story_capture_test.dart test/new_story_guard_test.dart test/add_person_modal_test.dart
mise exec -- flutter test
git grep -n -E "PostgrestException|FunctionException|supabase_flutter" -- apps/tell_me_a_story/lib/features
```
Expected: tests PASS. The grep prints only `lib/features/auth/invite_sign_in_page.dart` and `lib/features/auth/magic_link_page.dart` (deferred OTP work).

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/data/stories_api.dart apps/tell_me_a_story/lib/features/stories/new_story_page.dart apps/tell_me_a_story/test/stories_api_test.dart apps/tell_me_a_story/test/gateway_errors_test.dart apps/tell_me_a_story/test/new_story_shell_test.dart apps/tell_me_a_story/test/new_story_capture_test.dart
git commit -m "refactor(client): StoriesApi makes create and link idempotent"
```

---

### Task 10: `StoriesApi.discard` cleans up photo objects

Today `drafts_page.dart:253-255` calls `PhotosGateway.deleteAllForStory` and then `StoriesGateway.discard`, while `story_reader_page.dart:712` calls only `discard`, which leaks storage objects. This task folds the cleanup into `StoriesApi.discard`: it reads `family_id`, removes the `{family}/{story}` objects, then deletes the row. A storage failure keeps the row, as in drafts today. `deleteAllForStory` leaves the `PhotosGateway` interface (contract §2.3 "removed (folded into `story.discard`)") and stays on `PhotosApi` for `StoriesApi` to call.

**Files:**
- Modify: `lib/data/stories_api.dart:409,417-420,731-734`; `lib/data/photos_api.dart:176-179,308`
- Modify: `lib/features/drafts/drafts_page.dart:13,35,42,53,67-69,253-254`; `lib/core/router/app_router.dart:462`
- Test: `test/gateway_errors_test.dart`; `test/drafts_page_test.dart:84-90,161-166,263-305,308-321,483-525`
- Test fakes losing their `deleteAllForStory` override: `test/all_stories_page_test.dart:944-949`, `test/edit_story_guard_test.dart:453-458`, `test/logout_ordering_test.dart:287-292`, `test/new_story_capture_test.dart:450-455`, `test/new_story_guard_test.dart:652-657`, `test/router_test.dart:234-239`, `test/search_page_test.dart:180-185`, `test/start_timeline_test.dart:382-387`, `test/stories_api_test.dart:325-330`, `test/story_reader_page_test.dart:396-401`, `test/timeline_page_test.dart:460-465`

- [ ] **Step 1: Write the failing tests**

(a) `test/gateway_errors_test.dart`: add `import 'package:tell_me_a_story/data/photos_api.dart';` after the `people_api.dart` import. Append inside `main()`:
```dart

  group('StoriesApi.discard', () {
    _Reply storyRow(http.BaseRequest request) => request.method == 'GET'
        ? (status: 200, body: [{'family_id': 'f1'}])
        : (status: 200, body: const <Object>[]);

    test('removes the photo objects, then the row', () async {
      final log = <String>[];
      final transport = _Http((request) {
        log.add('${request.method} ${request.url.path}');
        return storyRow(request);
      });
      final client = _client(transport);
      final api = StoriesApi(
        client: client,
        photos: PhotosApi(
          client: client,
          listStoryObjects: (prefix) async {
            log.add('list $prefix');
            return ['ph1.jpg', 'ph1.edited.2.jpg'];
          },
          removeObjects: (paths) async {
            log.add('remove ${paths.join(',')}');
          },
        ),
      );

      await api.discard('s1');

      expect(log, [
        'GET /rest/v1/stories',
        'list f1/s1',
        'remove f1/s1/ph1.jpg,f1/s1/ph1.edited.2.jpg',
        'DELETE /rest/v1/stories',
      ]);
    });

    test('keeps the row when photo cleanup fails', () async {
      final transport = _Http(storyRow);
      final client = _client(transport);
      final api = StoriesApi(
        client: client,
        photos: PhotosApi(
          client: client,
          listStoryObjects: (_) async => throw Exception('storage'),
        ),
      );

      await expectLater(api.discard('s1'), throwsA(isA<Exception>()));
      expect(transport.calls, ['GET /rest/v1/stories']);
    });
  });
```

(b) `test/drafts_page_test.dart`: the page no longer touches photos.
- Replace lines 84–90 (constructor and fields) with:
```dart
  _FakeStoriesApi({List<Story>? drafts}) : drafts = [...?drafts];

  final List<Story> drafts;
  final List<String> discarded = [];
  var failDiscard = false;
```
- Replace `discard` (lines 161–166) with:
```dart
  @override
  Future<void> discard(String storyId) async {
    if (failDiscard) throw Exception('storage');
    discarded.add(storyId);
    drafts.removeWhere((s) => s.id == storyId);
  }
```
- In `_FakePhotosApi` (lines 263–306): delete lines 264–270 (constructor, the `deletedStories`/`callLog`/`failDelete` fields and the blank line after them), so the class body starts at `@override Future<List<Photo>> listPhotos`. Delete lines 294–303 (the `deleteAllForStory` override and the blank line after it). The class stays because `createAppRouter` uses it at line 451.
- Replace `_drafts` (lines 308–321) with:
```dart
Widget _drafts({required StoriesGateway stories, FamiliesGateway? families}) {
  return MaterialApp(
    home: DraftsPage(
      inviteApi: _FakeInviteApi(),
      storiesApi: stories,
      familiesApi: families,
    ),
  );
}
```
- Replace the two tests at lines 483–525 with:
```dart
  testWidgets('Discard calls discard and removes the row', (tester) async {
    final api = _FakeStoriesApi(drafts: [_draft(id: 's1')]);
    await tester.pumpWidget(_drafts(stories: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();

    expect(api.discarded, ['s1']);
    expect(find.text('Continue writing'), findsNothing);
    expect(
      find.text(
        'No drafts yet. Stories you’re still writing will show up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed discard keeps the draft row', (tester) async {
    final api = _FakeStoriesApi(drafts: [_draft(id: 's1')])..failDiscard = true;
    await tester.pumpWidget(_drafts(stories: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();

    expect(api.discarded, isEmpty);
    expect(find.text('Continue writing'), findsOneWidget);
    expect(find.text('Couldn’t discard draft. Try again.'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/gateway_errors_test.dart test/drafts_page_test.dart`
Expected: FAIL. `gateway_errors_test` fails to compile with `No named parameter with the name 'photos'`. (`drafts_page_test` still compiles and passes at this point, because `DraftsPage.photosApi` is optional.)

- [ ] **Step 3: Write minimal implementation**

`lib/data/stories_api.dart`
- Replace the constructor and field (lines 417–420) with:
```dart
  StoriesApi({SupabaseClient? client, PhotosApi? photos})
    : _client = client ?? Supabase.instance.client,
      _photosOverride = photos;

  final SupabaseClient _client;
  final PhotosApi? _photosOverride;

  /// Story photo storage that [discard] cleans up.
  late final PhotosApi _photos = _photosOverride ?? PhotosApi(client: _client);
```
- Line 409 in `StoriesGateway`: replace `Future<void> discard(String storyId);` with:
```dart
  /// Deletes the story and its photo objects. A storage failure keeps the row.
  Future<void> discard(String storyId);
```
- Replace `discard` (lines 731–734) with:
```dart
  @override
  Future<void> discard(String storyId) async {
    final rows = await _client
        .from('stories')
        .select('family_id')
        .eq('id', storyId)
        .limit(1);
    final familyId = rows.isEmpty ? null : rows.first['family_id'] as String?;
    if (familyId != null) {
      await _photos.deleteAllForStory(familyId: familyId, storyId: storyId);
    }
    await _client.from('stories').delete().eq('id', storyId);
  }
```

`lib/data/photos_api.dart`
- Delete lines 176–179 (`deleteAllForStory` from `PhotosGateway`).
- Line 308: replace `@override` (above `Future<void> deleteAllForStory({`) with:
```dart
  /// Removes every object under `{familyId}/{storyId}`. Called by
  /// `StoriesApi.discard`.
```

`lib/features/drafts/drafts_page.dart`
- Delete line 13 (`import '../../data/photos_api.dart';`), line 35 (`this.photosApi,`), line 42 (`final PhotosGateway? photosApi;`), line 53 (`PhotosGateway? _photosOverride;`), and lines 67–69 (the blank line and the `_photos` getter).
- In `_discard`, delete lines 253–254:
```dart
      final familyId = _familyId ?? story.familyId;
      await _photos.deleteAllForStory(familyId: familyId, storyId: story.id);
```

`lib/core/router/app_router.dart`
- Delete line 462 (`photosApi: photosApi,` inside the `DraftsPage(` builder). The router's `photosApi` parameter is still used by the other routes.

Test fakes: delete this override and the blank line after it from each file in the list above:
```dart
  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}
```
In `test/all_stories_page_test.dart` (lines 944–949) the body is `=> Future<void>.error(UnimplementedError());` and it is the class's last member. Delete the blank line 944 plus lines 945–949, and keep the closing `}` at line 950.

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/gateway_errors_test.dart test/drafts_page_test.dart test/photos_api_test.dart test/story_reader_page_test.dart
mise exec -- flutter test
```
Expected: PASS. `photos_api_test` still exercises `PhotosApi.deleteAllForStory` directly.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib apps/tell_me_a_story/test
git commit -m "refactor(client): StoriesApi.discard removes photo objects"
```

---

### Task 11: Picture URLs become bytes

The cutover reads blobs through `media.get` → `ByteData` (contract §2.3 rows `People.signedPictureUrl` and `storiesForPerson`). This task changes the client shape first:
- `PeopleGateway.signedPictureUrl` → `pictureBytes`
- `PersonStoryCard.thumbUrl` → `thumbBytes`
- the three `Image.network` sites become `Image.memory`: `person_profile_dialog.dart:493,558` and `edit_person_dialog.dart:434`.

**Files:**
- Modify: `lib/data/people_api.dart:215-219,435-445`; `lib/data/stories_api.dart:277-294,628-646`
- Modify: `lib/features/people/person_profile_dialog.dart:1,115,136,144-151,173,479-503,534-569`; `lib/features/people/edit_person_dialog.dart:61,80-89,112,432-445`
- Test: `test/m14_people_profiles_test.dart`

- [ ] **Step 1: Write the failing tests**

In `test/m14_people_profiles_test.dart`:
1. After line 5 (`import 'package:google_fonts/google_fonts.dart';`), insert `import 'package:image/image.dart' as img;`
2. In `_People`, replace `String? signedUrl;` (line 669) with `Uint8List? picture;` and `String? signedPath;` (line 673) with `String? picturePath;`. Replace the `signedPictureUrl` override (lines 712–719) with:
```dart
  @override
  Future<Uint8List?> pictureBytes({
    required String personId,
    String? path,
  }) async {
    picturePath = path;
    return picture;
  }
```
3. Append inside `main()` (before its closing `}`):
```dart

  testWidgets('a stored person picture renders from bytes', (tester) async {
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: false,
        avatarPath: 'p1/avatar.jpg',
      )
      ..picture = _png();
    await _openProfileWith(tester, people);

    final image = tester.widget<Image>(
      find.byKey(const Key('person-avatar-image')),
    );
    expect(image.image, isA<MemoryImage>());
    expect(people.picturePath, 'p1/avatar.jpg');
  });

  testWidgets('a story card thumbnail renders from bytes', (tester) async {
    final people = _People()
      ..profile = const PersonProfile(
        id: 'p1',
        familyId: _familyId,
        name: 'Ada',
        isLinked: false,
      );
    await _openProfileWith(
      tester,
      people,
      stories: [
        PersonStoryCard(
          id: 's1',
          title: 'First notes',
          whenLabel: 'Summer 1972',
          photoCount: 1,
          thumbBytes: _png(),
        ),
      ],
    );

    final thumb = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('person-profile-story-s1')),
        matching: find.byType(Image),
      ),
    );
    expect(thumb.image, isA<MemoryImage>());
  });

  testWidgets('Edit person shows the stored picture from bytes', (tester) async {
    final people = _People()..picture = _png();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditPersonDialog(
              context,
              person: const Person(
                id: 'p1',
                familyId: _familyId,
                name: 'Ada',
                avatarPath: 'p1/avatar.jpg',
              ),
              people: people,
              signedInUserId: 'me',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final preview = tester.widget<Image>(
      find.byKey(const Key('edit-person-picture-preview')),
    );
    expect(preview.image, isA<MemoryImage>());
  });
```
4. At the end of the file, append:
```dart

Uint8List _png() => Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));

Future<void> _openProfileWith(
  WidgetTester tester,
  _People people, {
  List<PersonStoryCard> stories = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showPersonProfile(
            context,
            personId: 'p1',
            name: 'Ada',
            people: people,
            signedInUserId: 'me',
            loadStories: (_) async => stories,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/m14_people_profiles_test.dart`
Expected: FAIL to compile: `The method 'pictureBytes' isn't defined in a superclass of '_People'` and `No named parameter with the name 'thumbBytes'`.

- [ ] **Step 3: Write minimal implementation**

`lib/data/people_api.dart`
- Replace lines 215–219 in `PeopleGateway` with:
```dart
  /// Picture bytes: `person-avatars` when [path] is `{personId}/avatar.jpg`,
  /// else `avatars`. Null when there is no picture.
  Future<Uint8List?> pictureBytes({
    required String personId,
    String? path,
  }) async => null;
```
- Replace `signedPictureUrl` in `PeopleApi` (lines 435–445) with:
```dart
  @override
  Future<Uint8List?> pictureBytes({
    required String personId,
    String? path,
  }) async {
    if (path == null || path.isEmpty) return null;
    final bucket = path == personAvatarObjectPath(personId)
        ? personAvatarsBucket
        : avatarsBucketName;
    return _client.storage.from(bucket).download(path);
  }
```

`lib/data/stories_api.dart`
- In `PersonStoryCard` (lines 277–294), rename the field: `this.thumbUrl,` → `this.thumbBytes,` and `final String? thumbUrl;` → `final Uint8List? thumbBytes;`.
- In `storiesForPerson`, replace lines 628–638 with:
```dart
      Uint8List? thumb;
      final path = story.photoPaths.isEmpty ? null : story.photoPaths.first;
      if (path != null && path.isNotEmpty) {
        try {
          thumb = await _client.storage
              .from(storyPhotosBucket)
              .download(path);
        } catch (_) {
          thumb = null;
        }
      }
```
  and line 646 `thumbUrl: thumb,` → `thumbBytes: thumb,`.

`lib/features/people/person_profile_dialog.dart`
- Insert at the top (before line 1):
```dart
import 'dart:typed_data';

```
- Line 115: `String? _pictureUrl;` → `Uint8List? _pictureBytes;`
- Line 136: `String? pictureUrl;` → `Uint8List? picture;`
- Lines 144–151 →
```dart
      try {
        picture = await widget.people.pictureBytes(
          personId: widget.personId,
          path: profile.avatarPath,
        );
      } catch (_) {
        picture = null;
      }
```
- Line 173: `_pictureUrl = pictureUrl;` → `_pictureBytes = picture;`
- In `_thumb`, replace lines 479–503 (from `Widget _thumb(PersonStoryCard story) {` through the `),` that closes the `ClipRRect`) with:
```dart
  Widget _thumb(PersonStoryCard story) {
    final bytes = story.thumbBytes;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bytes == null || bytes.isEmpty
                ? const ColoredBox(
                    color: albumParchment,
                    child: SizedBox(width: 56, height: 56),
                  )
                : Image.memory(
                    bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: albumParchment,
                      child: SizedBox(width: 56, height: 56),
                    ),
                  ),
          ),
```
  (the photo-count `Positioned` that follows is unchanged).
- In `_picture`, replace lines 535–536 with:
```dart
    final stored = _pictureBytes;
    final bytes = profile.avatarPath == null || stored == null || stored.isEmpty
        ? null
        : stored;
```
  Replace lines 553–568 (`child: empty ? … : Image.network(url, …)`) with:
```dart
                child: bytes == null
                    ? const ColoredBox(
                        key: Key('person-avatar-empty'),
                        color: albumParchment,
                      )
                    : Image.memory(
                        bytes,
                        key: const Key('person-avatar-image'),
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          key: Key('person-avatar-empty'),
                          color: albumParchment,
                        ),
                      ),
```

`lib/features/people/edit_person_dialog.dart`
- Line 61: `String? _existingUrl;` → `Uint8List? _existingBytes;`
- Replace `_loadExisting` (lines 80–89) with:
```dart
  Future<void> _loadExisting(String path) async {
    try {
      final bytes = await widget.people.pictureBytes(
        personId: widget.person.id,
        path: path,
      );
      if (!mounted || _removed || _picture != null) return;
      setState(() => _existingBytes = bytes);
    } catch (_) {}
  }
```
- Line 112: `_existingUrl = null;` → `_existingBytes = null;`
- Replace lines 432–445 with:
```dart
    final existing = _existingBytes;
    if (!_removed && existing != null && existing.isNotEmpty) {
      return Image.memory(
        existing,
        key: const Key('edit-person-picture-preview'),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(
          key: Key('edit-person-picture-empty'),
          color: albumParchment,
        ),
      );
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test test/m14_people_profiles_test.dart test/m14_3_dob_passed_away_test.dart test/invite_chrome_test.dart test/theme/no_hardcoded_colors_test.dart
mise exec -- flutter test
git grep -n -E "signedPictureUrl|thumbUrl|Image\.network" -- apps/tell_me_a_story
```
Expected: tests PASS. The grep prints nothing.

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib apps/tell_me_a_story/test
git commit -m "refactor(client): person pictures and story thumbs load as bytes"
```

---

### Task 12: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Full suite and analyzer**

Run:
```bash
cd apps/tell_me_a_story
mise exec -- flutter test
mise exec -- flutter analyze > /tmp/phase2-analyze-after.txt; echo "analyze exit $?"
diff /tmp/phase2-analyze-before.txt /tmp/phase2-analyze-after.txt
```
Expected: `All tests passed!`. `diff` shows no new issues (only removed ones, if any). Fix any `unused_import` / `override_on_non_overriding_member` it reports in files touched by this plan.

- [ ] **Step 2: Seam checks**

Run from the repo root:
```bash
git grep -n "Supabase.instance" -- apps/tell_me_a_story/lib/features apps/tell_me_a_story/lib/core
git grep -n -E "PostgrestException|FunctionException|supabase_flutter" -- apps/tell_me_a_story/lib/features
git grep -n -E "InviteApiException|ManageFamiliesException|OriginRpcException|PersonProfileNotFound|mapRpcError|rpc_error|signedPictureUrl|thumbUrl|Image\.network" -- apps/tell_me_a_story
git grep -l supabase_flutter -- apps/tell_me_a_story/test
```
Expected:
1. `lib/core/supabase/supabase_init.dart`, `lib/features/auth/invite_sign_in_page.dart` and `lib/features/auth/magic_link_page.dart` only.
2. The two auth pages only.
3. No output.
4. Data/auth tests only: `comments_api_test`, `family_landing_latest_test`, `family_selection_test`, `gateway_errors_test`, `m13_fit_finish_test`, `people_api_test`, `perspectives_api_test`, `photos_api_test`, `profile_session_test`, `stories_api_test`, `supabase_errors_test`. Phase C rewrites or deletes each per contract §4.

- [ ] **Step 3: `just test` from the repo root**

Run: `just test`
Expected: `All tests passed!` (includes `test/theme/no_hardcoded_colors_test.dart`).

---

## Self-review

**1. Spec coverage**

| Requirement | Task |
|---|---|
| `AppSession`: single source for user id + auth state | 1. `currentUserId` + `signOut`. `isSignedIn` / listenable stay on `AuthRefresh` until Phase C (contract §3 `auth_refresh.dart` row) |
| Replace every `auth.currentUser` read in `lib/features/**`, `lib/core/**` (file:line list) | 2 (table with all ten sites), 4 (add_perspective) |
| Injection consistent with existing patterns | 1–2. Static `instance`, as in `ProfileSession.instance`. Existing `currentUserId` / `signedInUserId` / `onLogout` constructor args keep priority |
| One `AppException{code, message}`; gateways translate Postgrest/Function errors | 5, 6, 7, 8 |
| Delete feature-level `PostgrestException` catches | 9 (`new_story_page.dart:474,726`). `families_api.dart:400` is gateway-internal and stays until Phase C |
| Unify `rpc_error.dart` / `originRpcException` / `_invoke` envelopes | 6 / 8 / 7 |
| UI copy unchanged, verified from call sites and tests | Audit tables in 6 and 7. Explicit guards: add-person invite step (7), tree listing NOT_FOUND (8). Existing copy assertions are kept and the new regression test is in 7 |
| Move direct query out of `add_perspective_page.dart` | 4 (`ProfileSession`, which `ProfileGateway.loadOwn` backs) |
| Move `signOut` from `album_header.dart` behind the session | 3 |
| Composition root in `main.dart` | Skipped: not in contract §5 Phase A (see Scope) |
| Shared `test/support/fakes.dart` | Skipped: contract §4 says fakes don't change |
| Image URL → bytes (contract Phase A requires it) | 11 |
| Contract A.3 idempotency + discard fold | 9, 10 |
| Email-code login | Excluded (deferred) |

**2. Placeholder scan.** No TBD/TODO. Every code step shows the code, and every run step names the command and the expected result. Deleted tests are named with their line ranges, and each deletion gives the test that now covers it.

**3. Type consistency.**
- `AppSession.instance`, `.currentUserId`, `.signOut()` and `SupabaseAppSession` are used the same way in Tasks 1–3.
- `AppErrorCode {notFound, forbidden, validation, inviteInvalid, unauthenticated}` and `AppException({code, message})` are used throughout.
- `appErrorMessage`, `appExceptionFromPostgrest`, `withAppErrors`, `envelopeBody`, `envelopeErrorCode`, `appExceptionFromEnvelope` and `createOrUpdateExisting` are defined before first use.
- `StoriesApi({client, photos})` is introduced in 10. Earlier tests only pass `client`.
- `pictureBytes({personId, path})` and `thumbBytes` match between the gateway, the fakes and the widgets.
- `_Http`, `_client`, `_error`, `_Reply` are defined once in `gateway_errors_test.dart` (Task 6) and reused by 7–10.

**4. Known behaviour changes (intentional, contract-driven).**
- Deleting a story from the reader now also removes its storage objects (Task 10). The objects used to leak.
- A retried create's duplicate now updates through `updateDraft` instead of the page's guarded `autosaveDraft`. The row was created by the same page moments earlier, so it is still a draft.

**5. Open question for Main.** Roadmap row 2 promises "gateways injected from `main.dart`", but contract §5 Phase A does not include it. This plan follows the contract. If the composition root is wanted, it is a separate task over the ~50 `widget.xApi ?? XApi()` sites.
