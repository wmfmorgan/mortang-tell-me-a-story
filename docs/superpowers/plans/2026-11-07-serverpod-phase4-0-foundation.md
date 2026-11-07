# Phase 4.0: Client Cutover — Shared Foundation Implementation Plan

> Executes on `feat/serverpod-migration` before the cutover branch exists. Everything here is additive: the app still runs on Supabase afterwards.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Phase 4 slices one shared way to reach the Serverpod server from the Flutter app. That means the dependencies, `Env.serverUrl`, a single `serverClient`, server-to-client error mapping, wire helpers for dates, roles and precision, and a live-test harness that runs gateway tests against `just server`.

**Architecture:** New files only, under `apps/tell_me_a_story/lib/core/server/` and `lib/data/server/`, plus `test/server/` and `test/live/`. No gateway changes yet. Live tests are tagged `live`: plain `flutter test` skips them, and `just test-live` runs them against a running `just server`.

**Tech Stack:** Flutter 3.47.7 / Dart 3.13.5, the generated `tell_me_a_story_client` (Serverpod 4.1.1), `serverpod_auth_core_flutter` 4.1.1, `serverpod_auth_idp_client` 4.1.1, just.

**Verified:** every file below was written and run on 2026-11-07 in a scratch worktree of `feat/serverpod-migration`.
- `flutter analyze` stayed at the 23-issue baseline.
- `flutter test` gave 723/723 (708 before), with the `live` tests skipped.
- `just test-live` passed 2/2 against `just server`, including a cold start where the tests began before the server was up.
- A throwaway smoke test, later deleted, ran the whole path against the real server: code login, a persisted and restored session, `profile.me`, `family.createRoot`/`listMine`, a refusal mapped to the client `forbidden`, and `unauthenticated` after sign-out. That smoke test found the missing server auth handler, fixed in `f203a6d`.

**Dependencies:** `tell_me_a_story_client` (path), `serverpod_auth_core_flutter` and `serverpod_auth_idp_client` are the endpoint-contract §3 set, made lighter:
- `serverpod_auth_core_flutter` replaces `serverpod_auth_idp_flutter`, which would pull in Google and Apple sign-in, `pinput` and more.
- `serverpod_auth_idp_client` is needed directly for `EmailAccountRequestException` (slice 4a).
- `serverpod_flutter` is not needed: `Env.serverUrl` replaces its `getServerUrl`.
- All three are added here once, so slices never conflict on `pubspec.lock`.

All commands run from the repo root unless a step says otherwise.

---

## File map

| Path | Responsibility |
|---|---|
| `apps/tell_me_a_story/pubspec.yaml`, `pubspec.lock` | Client package and auth dependencies |
| `apps/tell_me_a_story/lib/core/config/env.dart` | `Env.serverUrl` (`SERVER_URL`) |
| `apps/tell_me_a_story/lib/core/server/server_client.dart` | `serverClient`, `initServer`, `serverHost` |
| `apps/tell_me_a_story/lib/data/server/server_errors.dart` | `withServerErrors`, `clientError` |
| `apps/tell_me_a_story/lib/data/server/wire.dart` | date-only, role and precision conversions |
| `apps/tell_me_a_story/dart_test.yaml` | `live` tag skipped by default |
| `apps/tell_me_a_story/test/live/support/live_server.dart` | `waitForLiveServer`, `signInLive`, `freshEmail`, `MemoryAuthStorage` |
| `justfile` | `test-live` recipe |

---

### Task 1: Dependencies and `Env.serverUrl`

**Files:**
- Modify: `apps/tell_me_a_story/pubspec.yaml` (dependencies), `pubspec.lock` (by `flutter pub add`)
- Modify: `apps/tell_me_a_story/lib/core/config/env.dart` (after `supabaseAnonKey`)

- [ ] **Step 1: Add the dependencies**

```bash
cd apps/tell_me_a_story
mise exec -- flutter pub add 'tell_me_a_story_client:{"path":"../../packages/tell_me_a_story_client"}' serverpod_auth_core_flutter:4.1.1 serverpod_auth_idp_client:4.1.1
```
Expected: `Changed … dependencies!`. `pubspec.yaml` gains:

```yaml
  tell_me_a_story_client:
    path: ../../packages/tell_me_a_story_client
  serverpod_auth_core_flutter: 4.1.1
  serverpod_auth_idp_client: 4.1.1
```

- [ ] **Step 2: Add `SERVER_URL`** right after `supabaseAnonKey` in `env.dart`:

```dart
  /// Serverpod API server, e.g. `http://127.0.0.1:8080`. Replaces the
  /// Supabase defines at the Phase 4 cutover.
  static const serverUrl = String.fromEnvironment('SERVER_URL');
```

- [ ] **Step 3: Check nothing broke**

Run: `cd apps/tell_me_a_story && mise exec -- flutter analyze && mise exec -- flutter test`
Expected: `23 issues found.` (the baseline) and `+708: All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add apps/tell_me_a_story/pubspec.yaml apps/tell_me_a_story/pubspec.lock apps/tell_me_a_story/lib/core/config/env.dart
git commit -m "chore(client): add the Serverpod client and SERVER_URL"
```

---

### Task 2: `serverClient` and `initServer`

One client for the whole app, holding a persisted `FlutterAuthSessionManager`. Tests and live tests pass in-memory storage. Gateways read `serverClient` lazily (Phase 4 index §Conventions), so building a gateway in a widget test never touches it.

**Files:**
- Create: `apps/tell_me_a_story/lib/core/server/server_client.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/foundation.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart';

import '../config/env.dart';

Client? _serverClient;

/// The app's Serverpod client. [initServer] must have run first.
Client get serverClient =>
    _serverClient ?? (throw StateError('initServer() has not run'));

/// Builds the client for [url] (default [Env.serverUrl]) with a persisted
/// auth session, restores a saved sign-in, and makes it [serverClient].
/// Tests pass an in-memory [storage].
Future<Client> initServer({
  String? url,
  ClientAuthSuccessStorage? storage,
}) async {
  final client = Client(serverHost(url ?? Env.serverUrl))
    ..authSessionManager = FlutterAuthSessionManager(storage: storage);
  await client.auth.initialize();
  return _serverClient = client;
}

/// Replaces [serverClient] in tests; null forgets it.
@visibleForTesting
set serverClientForTesting(Client? client) => _serverClient = client;

/// Serverpod clients expect the host URL to end with a slash.
String serverHost(String url) => url.endsWith('/') ? url : '$url/';
```

- [ ] **Step 2: Analyze**

Run: `cd apps/tell_me_a_story && mise exec -- flutter analyze`
Expected: `23 issues found.`

It has no test of its own: `test/live/server_errors_live_test.dart` (Task 5) builds a real client through `initServer`.

- [ ] **Step 3: Commit**

```bash
git add apps/tell_me_a_story/lib/core/server/server_client.dart
git commit -m "feat(client): serverClient and initServer"
```

---

### Task 3: Server errors become client errors

Features keep catching the client `AppException` and the photo exceptions. Every gateway call goes through `withServerErrors`.

**Files:**
- Create: `apps/tell_me_a_story/lib/data/server/server_errors.dart`
- Test: `apps/tell_me_a_story/test/server/server_errors_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/photos_api.dart'
    show StorageFailedException;
import 'package:tell_me_a_story/data/server/server_errors.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

Future<void> fails(server.AppErrorCode code) =>
    withServerErrors<void>(() async {
      throw server.AppException(code: code, message: 'server text');
    });

Matcher clientError(AppErrorCode code, [String message = 'server text']) =>
    throwsA(
      isA<AppException>()
          .having((e) => e.code, 'code', code)
          .having((e) => e.message, 'message', message),
    );

void main() {
  test('codes the client knows keep their code and message', () async {
    await expectLater(
      fails(server.AppErrorCode.forbidden),
      clientError(AppErrorCode.forbidden),
    );
    await expectLater(
      fails(server.AppErrorCode.notFound),
      clientError(AppErrorCode.notFound),
    );
    await expectLater(
      fails(server.AppErrorCode.validation),
      clientError(AppErrorCode.validation),
    );
    await expectLater(
      fails(server.AppErrorCode.inviteInvalid),
      clientError(AppErrorCode.inviteInvalid),
    );
  });

  test('authRequired becomes unauthenticated', () async {
    await expectLater(
      fails(server.AppErrorCode.authRequired),
      clientError(AppErrorCode.unauthenticated),
    );
  });

  test('used and expired invites read as invalid invites', () async {
    await expectLater(
      fails(server.AppErrorCode.inviteAccepted),
      clientError(AppErrorCode.inviteInvalid),
    );
    await expectLater(
      fails(server.AppErrorCode.inviteExpired),
      clientError(AppErrorCode.inviteInvalid),
    );
  });

  test(
    'conflict, which the server never sends today, is a validation error',
    () async {
      await expectLater(
        fails(server.AppErrorCode.conflict),
        clientError(AppErrorCode.validation),
      );
    },
  );

  test('photo cap and storage failure keep the photo exceptions', () async {
    await expectLater(
      fails(server.AppErrorCode.photoCap),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'PHOTO_CAP'),
      ),
    );
    await expectLater(
      fails(server.AppErrorCode.storageFailed),
      throwsA(isA<StorageFailedException>()),
    );
  });

  test('a rejected session reads as unauthenticated', () async {
    await expectLater(
      withServerErrors<void>(() async {
        throw server.ServerpodClientUnauthorized();
      }),
      clientError(AppErrorCode.unauthenticated, 'Sign-in required'),
    );
  });

  test('anything else passes through unchanged', () async {
    final error = StateError('network down');
    await expectLater(
      withServerErrors<void>(() async => throw error),
      throwsA(same(error)),
    );
  });

  test('a successful call returns its value', () async {
    expect(await withServerErrors(() async => 42), 42);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/server/server_errors_test.dart`
Expected: `Error when reading 'lib/data/server/server_errors.dart': No such file or directory`

- [ ] **Step 3: Implement**

```dart
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import '../app_exception.dart';
import '../photos_api.dart' show StorageFailedException;

/// Runs a server call and turns the server's errors into the client's, so
/// features keep catching the client [AppException] and the photo
/// exceptions. Anything else (network failures, bugs) passes through.
Future<T> withServerErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on server.AppException catch (e, stackTrace) {
    Error.throwWithStackTrace(clientError(e), stackTrace);
  } on server.ServerpodClientUnauthorized catch (_, stackTrace) {
    Error.throwWithStackTrace(
      const AppException(
        code: AppErrorCode.unauthenticated,
        message: 'Sign-in required',
      ),
      stackTrace,
    );
  }
}

/// The client error for a server [AppException][server.AppException].
Object clientError(server.AppException e) => switch (e.code) {
  server.AppErrorCode.authRequired => AppException(
    code: AppErrorCode.unauthenticated,
    message: e.message,
  ),
  server.AppErrorCode.forbidden => AppException(
    code: AppErrorCode.forbidden,
    message: e.message,
  ),
  server.AppErrorCode.notFound => AppException(
    code: AppErrorCode.notFound,
    message: e.message,
  ),
  server.AppErrorCode.validation || server.AppErrorCode.conflict =>
    AppException(code: AppErrorCode.validation, message: e.message),
  server.AppErrorCode.inviteInvalid ||
  server.AppErrorCode.inviteAccepted ||
  server.AppErrorCode.inviteExpired => AppException(
    code: AppErrorCode.inviteInvalid,
    message: e.message,
  ),
  server.AppErrorCode.photoCap => StateError('PHOTO_CAP'),
  server.AppErrorCode.storageFailed => StorageFailedException(cause: e),
};
```

- [ ] **Step 4: Run it**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/server/server_errors_test.dart`
Expected: `+8: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/data/server/server_errors.dart apps/tell_me_a_story/test/server/server_errors_test.dart
git commit -m "feat(client): map server errors to client errors"
```

---

### Task 4: Wire helpers

Date-only values travel as UTC midnight and come back as the same local calendar day. Roles keep the client strings (`co_owner`). `decade` is refused (D9).

**Files:**
- Create: `apps/tell_me_a_story/lib/data/server/wire.dart`
- Test: `apps/tell_me_a_story/test/server/wire_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/server/wire.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

void main() {
  group('date-only values', () {
    test('a local calendar day travels as UTC midnight of that day', () {
      expect(
        toWireDate(DateTime(1974, 7, 14, 23, 30)),
        DateTime.utc(1974, 7, 14),
      );
      expect(toWireDate(null), isNull);
    });

    test('a wire date comes back as the same local calendar day', () {
      final day = fromWireDate(DateTime.utc(1974, 7, 14));
      expect(day, DateTime(1974, 7, 14));
      expect(day!.isUtc, isFalse);
      expect(fromWireDate(null), isNull);
    });

    test('a round trip keeps the calendar day', () {
      final day = DateTime(2000, 2, 29);
      expect(fromWireDate(toWireDate(day)), day);
    });
  });

  group('membership roles', () {
    test('server roles use the client role strings', () {
      expect(roleName(server.MembershipRole.owner), 'owner');
      expect(roleName(server.MembershipRole.coOwner), 'co_owner');
      expect(roleName(server.MembershipRole.member), 'member');
    });

    test('client role strings map back, and unknown strings are refused', () {
      for (final role in server.MembershipRole.values) {
        expect(roleFromName(roleName(role)), role);
      }
      expect(() => roleFromName('admin'), throwsArgumentError);
    });
  });

  group('date precision', () {
    test('year, month and day round-trip through their names', () {
      for (final precision in server.DatePrecision.values) {
        expect(precisionFromName(precisionName(precision)), precision);
      }
      expect(precisionFromName(null), isNull);
    });

    test('decade is refused: it was dropped (D9)', () {
      expect(() => precisionFromName('decade'), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/server/wire_test.dart`
Expected: `Error when reading 'lib/data/server/wire.dart': No such file or directory`

- [ ] **Step 3: Implement**

```dart
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

/// Date-only values (story dates, birth and death dates) travel as UTC
/// midnight of the calendar day, the server's stored shape.
DateTime? toWireDate(DateTime? day) =>
    day == null ? null : DateTime.utc(day.year, day.month, day.day);

/// The local calendar day of a wire date, the shape the client models hold.
DateTime? fromWireDate(DateTime? wire) {
  if (wire == null) return null;
  final utc = wire.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// The client's role strings (`owner`, `co_owner`, `member`).
String roleName(server.MembershipRole role) => switch (role) {
  server.MembershipRole.owner => 'owner',
  server.MembershipRole.coOwner => 'co_owner',
  server.MembershipRole.member => 'member',
};

server.MembershipRole roleFromName(String name) => switch (name) {
  'owner' => server.MembershipRole.owner,
  'co_owner' => server.MembershipRole.coOwner,
  'member' => server.MembershipRole.member,
  _ => throw ArgumentError.value(name, 'role', 'unknown membership role'),
};

/// The client's precision strings (`year`, `month`, `day`).
String precisionName(server.DatePrecision precision) => precision.name;

/// Null stays null. `decade` was dropped (D9) and is refused.
server.DatePrecision? precisionFromName(String? name) => switch (name) {
  null => null,
  'year' => server.DatePrecision.year,
  'month' => server.DatePrecision.month,
  'day' => server.DatePrecision.day,
  _ => throw ArgumentError.value(name, 'precision', 'unknown date precision'),
};
```

- [ ] **Step 4: Run it**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test test/server/wire_test.dart`
Expected: `+7: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add apps/tell_me_a_story/lib/data/server/wire.dart apps/tell_me_a_story/test/server/wire_test.dart
git commit -m "feat(client): wire helpers for dates, roles and precision"
```

---

### Task 5: Live-test harness

Flutter tests use fakes and cannot see server behaviour. The missing auth handler (`f203a6d`) passed every server test and failed the first real call. So every slice proves its gateway against `just server` with tests tagged `live`. The server port opens before requests are served, so each live file waits in `setUpAll`.

**Files:**
- Create: `apps/tell_me_a_story/dart_test.yaml`
- Create: `apps/tell_me_a_story/test/live/support/live_server.dart`
- Create: `apps/tell_me_a_story/test/live/server_errors_live_test.dart`
- Modify: `justfile` (after the `test` recipe)

- [ ] **Step 1: Skip `live` by default** in `apps/tell_me_a_story/dart_test.yaml`:

```yaml
tags:
  live:
    skip: "Needs `just server`. Run with `just test-live`."
```

- [ ] **Step 2: The harness**

```dart
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart';

/// The server live tests talk to: `just server` on :8080 unless
/// `--dart-define=LIVE_SERVER_URL=...` says otherwise. Live tests are tagged
/// `live`; plain `flutter test` skips them and `just test-live` runs them.
const liveServerUrl = String.fromEnvironment(
  'LIVE_SERVER_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

/// The fixed code a local `just server` accepts (apps/server auth_config.dart).
const devLoginCode = '111111';

/// Keeps the session in memory so live tests never touch the keychain.
class MemoryAuthStorage implements ClientAuthSuccessStorage {
  AuthSuccess? _value;

  @override
  Future<AuthSuccess?> get() async => _value;

  @override
  Future<void> set(AuthSuccess? data) async => _value = data;
}

var _counter = 0;

/// A fresh email no earlier run has used, e.g. `live-<run>-<n>-<label>@example.test`.
String freshEmail(String label) =>
    'live-${DateTime.now().microsecondsSinceEpoch}-${_counter++}-'
    '$label@example.test';

/// Waits until the live server answers (its port opens before it serves).
/// Call from `setUpAll`. Fails after [timeout] with the last error.
Future<void> waitForLiveServer({
  Duration timeout = const Duration(seconds: 30),
}) async {
  final probe = Client(serverHost(liveServerUrl));
  final deadline = DateTime.now().add(timeout);
  while (true) {
    try {
      await probe.invitePublic.preview('ready-check');
      return;
    } on ServerpodClientException {
      if (DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

/// Signs [email] up or in with the dev code and makes the result the app's
/// [serverClient], so default-constructed gateways act as that user.
Future<Client> signInLive(String email) async {
  final client = await initServer(
    url: liveServerUrl,
    storage: MemoryAuthStorage(),
  );
  final requestId = await client.emailIdp.startOtpLogin(email: email);
  final verified = await client.emailIdp.verifyOtpLoginCode(
    otpLoginRequestId: requestId,
    verificationCode: devLoginCode,
  );
  final auth = verified.accountExists
      ? await client.emailIdp.finishOtpLogin(otpLoginToken: verified.token)
      : await client.emailIdp.finishOtpRegistration(
          otpLoginToken: verified.token,
        );
  await client.auth.updateSignedInUser(auth);
  return client;
}
```

- [ ] **Step 3: The live test** (server errors over the real wire, and the harness end to end):

```dart
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/server/server_errors.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'support/live_server.dart';

Matcher clientError(AppErrorCode code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  setUpAll(waitForLiveServer);

  test('a server refusal reaches the client as the client error', () async {
    await signInLive(freshEmail('refused'));

    await expectLater(
      withServerErrors(
        () => serverClient.family.rename(
          server.UuidValue.fromString('0190d7a0-0000-7000-8000-000000000000'),
          'X',
        ),
      ),
      clientError(AppErrorCode.forbidden),
    );
  });

  test('after sign-out a signed-in call is unauthenticated', () async {
    await signInLive(freshEmail('signed-out'));
    await serverClient.auth.signOutDevice();

    await expectLater(
      withServerErrors(() => serverClient.profile.me()),
      clientError(AppErrorCode.unauthenticated),
    );
  });
}
```

- [ ] **Step 4: The recipe**, after `test:` in `justfile`:

```just
# Live client tests against a running `just server` (start it first)
test-live:
    cd apps/tell_me_a_story && flutter test --tags live --run-skipped test/live
```

- [ ] **Step 5: Run both ways**

Run: `cd apps/tell_me_a_story && mise exec -- flutter test` (no server needed)
Expected: `+723 ~1: All tests passed!` (the `live` file is skipped as one entry)

Then, in one shell, run `mise exec -- just server`. In another: `mise exec -- just test-live`
Expected: `+2: All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add apps/tell_me_a_story/dart_test.yaml apps/tell_me_a_story/test/live justfile
git commit -m "test(client): live-test harness against just server"
```

---

### Task 6: Gate

- [ ] **Step 1:**
```bash
mise exec -- dart format --output=none --set-exit-if-changed apps/tell_me_a_story/lib apps/tell_me_a_story/test
(cd apps/tell_me_a_story && mise exec -- flutter analyze)
mise exec -- just test
mise exec -- just server-test
```
With `just server` running: `mise exec -- just test-live`.
Expected:
- format: 0 changed;
- analyze: `23 issues found.`;
- `+723 ~1`;
- server: `+425`;
- live: `+2`.

- [ ] **Step 2:** In `docs/superpowers/plans/2026-11-07-serverpod-phase4-client-cutover.md`, set the 4.0 status to `landed`, then commit `docs: Phase 4.0 foundation landed`.
