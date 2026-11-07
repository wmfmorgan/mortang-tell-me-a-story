# Phase 4a: Shell and Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app starts on the Serverpod client, tracks sign-in through `serverClient.auth`, and signs in with a 6-digit email code on both the landing page and the invite page.

**Architecture:** `main` validates `SERVER_URL` and calls `initServer()` with a storage wrapper that turns an unreadable saved session into "signed out". `AuthRefresh` listens to `serverClient.auth.authInfoListenable` and binds/clears `ProfileSession` and `FamilySelection`. `AppSession.instance` reads `authInfo`. Both login pages talk to an `OtpSignIn` seam (`ServerOtpSignIn` over `emailIdp`) and share one code-entry widget.

**Tech Stack:** Flutter 3.47.7, `tell_me_a_story_client`, `serverpod_auth_core_flutter` / `serverpod_auth_idp_client` 4.1.1.

**Scope contract:** Phase 4 index, row "4a Shell and auth" (`2026-11-07-serverpod-phase4-client-cutover.md`).

---

## File map

| File | Action | Responsibility |
|---|---|---|
| `lib/core/config/env.dart` | modify | drop `SUPABASE_*`; `validate()` requires an absolute http(s) `SERVER_URL` |
| `lib/core/server/app_session.dart` | modify | `ServerAppSession` over `client.auth`; `SessionRecoveringStorage` |
| `lib/core/router/auth_refresh.dart` | modify | listen to `ValueListenable<AuthSuccess?>`; bind/clear sessions |
| `lib/features/auth/otp_sign_in.dart` | create | `OtpSignIn`, `ServerOtpSignIn`, `signInErrorMessage` + error copy |
| `lib/features/auth/sign_in_code_form.dart` | create | shared code step (field, submit, resend, different email); album tokens only |
| `lib/features/auth/magic_link_page.dart` | modify | email → code steps over `OtpSignIn` |
| `lib/features/auth/invite_sign_in_page.dart` | modify | email → code steps; `_onAuth` → `_accept()` unchanged |
| `lib/features/auth/magic_link_redirect.dart` | delete | Supabase redirect helper |
| `lib/core/supabase/` | delete | Supabase init + callback recovery |
| `lib/main.dart` | modify | `initServer()` + `AuthRefresh(authInfo: …)` |
| `integration_test/e2e_test.dart`, `integration_test/support/prod_guard.dart` | minimal compile fix (Main-approved; 4f's version wins at merge) |
| tests | see tasks | |

Fake inventory touched: `MagicLinkSender` fake `_Sender` (m13) → `_Otp implements OtpSignIn`. No gateway interface (`*Gateway`) changes in 4a.

Copy (approved 2026-11-07) lives as constants: `landingPasswordNote`, `sendCodeLabel`, `sendingLabel` in `magic_link_page.dart`; code-step strings in `sign_in_code_form.dart`; error strings in `otp_sign_in.dart`.

---

### Task 1: Env requires SERVER_URL

**Files:** Modify `lib/core/config/env.dart`; Test `test/env_test.dart`.

- [ ] **Step 1: failing test** — replace the Supabase assertions:

```dart
test('Env.validate fails closed when SERVER_URL is missing', () {
  expect(Env.serverUrl, isEmpty);
  expect(
    Env.validate,
    throwsA(isA<StateError>().having((e) => e.message, 'message', contains('SERVER_URL'))),
  );
});

test('validateServerUrl accepts only an absolute http(s) URL', () {
  expect(() => Env.validateServerUrl('http://127.0.0.1:8080'), returnsNormally);
  expect(() => Env.validateServerUrl('https://api.example.com/'), returnsNormally);
  expect(() => Env.validateServerUrl(''), throwsStateError);
  expect(() => Env.validateServerUrl('...'), throwsStateError);
  expect(() => Env.validateServerUrl('/api'), throwsStateError);
  expect(() => Env.validateServerUrl('ws://127.0.0.1:8080'), throwsStateError);
});
```
Keep the Mapbox tests; the "does not require MAPBOX" test asserts the message does not mention MAPBOX.

- [ ] **Step 2:** `mise exec -- flutter test test/env_test.dart` → FAIL (`validateServerUrl` undefined).
- [ ] **Step 3: implement**

```dart
static void validate() => validateServerUrl(serverUrl);

static void validateServerUrl(String value) {
  if (value.isEmpty) {
    throw StateError('Missing required --dart-define value: SERVER_URL (e.g. http://127.0.0.1:8080).');
  }
  if (!isAbsoluteHttpUrl(value)) {
    throw StateError('Invalid SERVER_URL="$value". Use the absolute server URL, e.g. http://127.0.0.1:8080.');
  }
}
```
Delete `supabaseUrl` / `supabaseAnonKey`.

- [ ] **Step 4:** test passes. **Step 5:** commit `feat(client): Env validates SERVER_URL`. (Env.supabase* removal breaks `core/supabase` and integration_test until Tasks 7–8; commit Task 1 together with Task 7 if analyze must stay green per commit — it does not need to per commit, only at the gate.)

### Task 2: ServerAppSession and startup recovery

**Files:** Modify `lib/core/server/app_session.dart`; Test `test/app_session_test.dart`, `test/m14_3_dob_passed_away_test.dart` (tearDown).

- [ ] **Step 1: failing tests** (in `app_session_test.dart`):

```dart
tearDown(() {
  AppSession.instance = const ServerAppSession();
  serverClientForTesting = null;
});

test('the server session has no user before initServer', () {
  serverClientForTesting = null;
  expect(const ServerAppSession().currentUserId, isNull);
});

test('the server session reads the signed-in auth user', () async {
  final storage = _Storage(_auth('6f1c2b4e-0000-4000-8000-000000000001'));
  final client = await initServer(url: 'http://127.0.0.1:1', storage: storage);
  // restore() alone; initialize() would also try to validate with the server
  expect(ServerAppSession(client: client).currentUserId, '6f1c2b4e-0000-4000-8000-000000000001');
});

test('an unreadable saved session starts signed out and is cleared', () async {
  final broken = _BrokenStorage();
  final client = await initServer(
    url: 'http://127.0.0.1:1',
    storage: SessionRecoveringStorage(broken),
  );
  expect(client.auth.authInfo, isNull);
  expect(ServerAppSession(client: client).currentUserId, isNull);
  expect(broken.cleared, isTrue);
});
```
`_BrokenStorage.get` throws `FormatException` until `set(null)` runs. The second test needs no server only if `initialize()` tolerates an unreachable server: it catches `ServerpodClientException`/`TimeoutException`; verify while implementing, else build the client and call `auth.restore()` directly.

- [ ] **Step 2:** FAIL (`ServerAppSession`, `SessionRecoveringStorage` undefined).
- [ ] **Step 3: implement**

```dart
class ServerAppSession extends AppSession {
  const ServerAppSession({server.Client? client}) : _injected = client;
  final server.Client? _injected;

  server.Client? get _client {
    if (_injected != null) return _injected;
    try { return serverClient; } on StateError { return null; }
  }

  @override
  String? get currentUserId => _client?.auth.authInfo?.authUserId.toString();

  @override
  Future<void> signOut() async { await (_injected ?? serverClient).auth.signOutDevice(); }
}

/// Saved-session storage that treats an unreadable entry as signed out.
class SessionRecoveringStorage implements ClientAuthSuccessStorage {
  SessionRecoveringStorage(this._delegate);
  final ClientAuthSuccessStorage _delegate;

  @override
  Future<AuthSuccess?> get() async {
    try { return await _delegate.get(); } catch (_) {
      try { await _delegate.set(null); } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> set(AuthSuccess? data) => _delegate.set(data);
}
```
`AppSession.instance` defaults to `const ServerAppSession()`. m14_3 tearDown restores `const ServerAppSession()`.

- [ ] **Step 4:** PASS. **Step 5:** commit `feat(client): ServerAppSession over serverClient.auth with startup recovery`.

### Task 3: AuthRefresh on authInfoListenable

**Files:** Modify `lib/core/router/auth_refresh.dart`; Test `test/family_selection_test.dart`, `test/profile_session_test.dart`, `test/router_test.dart`.

- [ ] **Step 1: failing tests** — the listener tests use `ValueNotifier<AuthSuccess?>`:

```dart
test('the auth listener clears the family when the session drops', () {
  FamilySelection.remember('fam-a');
  final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
  final auth = AuthRefresh(authInfo: info);
  addTearDown(auth.dispose);

  info.value = null;

  expect(auth.isSignedIn, isFalse);
  expect(FamilySelection.id, isNull);
});

test('signing in as another user drops the remembered family', () {
  final info = ValueNotifier<AuthSuccess?>(_auth(_userA));
  final auth = AuthRefresh(authInfo: info);
  addTearDown(auth.dispose);
  FamilySelection.remember('fam-a');

  info.value = _auth(_userB);

  expect(FamilySelection.id, isNull);
});
```
profile_session: "a dropped session clears the profile" (same shape) and "sign-in binds the profile user" (switching user clears `displayName`). router_test: "auth refresh moves signed-out user to Family Landing after sign-in" drives a `ValueNotifier<AuthSuccess?>` instead of `setSignedIn`.

- [ ] **Step 2:** FAIL (no `authInfo` parameter).
- [ ] **Step 3: implement**

```dart
class AuthRefresh extends ChangeNotifier {
  AuthRefresh({ValueListenable<AuthSuccess?>? authInfo, bool? initiallySignedIn})
    : _authInfo = authInfo,
      _signedIn = initiallySignedIn ?? (authInfo?.value != null) {
    final info = authInfo;
    if (info == null) return;
    if (info.value != null) _bind(info.value);
    info.addListener(_onAuthInfo);
  }

  final ValueListenable<AuthSuccess?>? _authInfo;
  bool _signedIn;

  void _onAuthInfo() {
    final value = _authInfo!.value;
    _bind(value);
    final next = value != null;
    if (next != _signedIn) { _signedIn = next; notifyListeners(); }
  }

  /// Binds the session caches to the signed-in user; sign-out clears them.
  static void _bind(AuthSuccess? info) {
    if (info == null) { FamilySelection.clear(); ProfileSession.instance.clear(); return; }
    final userId = info.authUserId.toString();
    ProfileSession.instance.bindUser(userId);
    FamilySelection.bindUser(userId);
  }
  // isSignedIn, setSignedIn (visibleForTesting), dispose removes the listener
}
```

- [ ] **Step 4:** PASS. **Step 5:** commit `feat(client): AuthRefresh follows serverClient.auth and binds sessions`.

### Task 4: OtpSignIn seam

**Files:** Create `lib/features/auth/otp_sign_in.dart`; Test `test/otp_sign_in_test.dart`, `test/live/auth_live_test.dart`.

- [ ] **Step 1: failing tests**

```dart
test('sign-in errors map to the approved copy', () {
  EmailAccountRequestException r(EmailAccountRequestExceptionReason x) => EmailAccountRequestException(reason: x);
  expect(signInErrorMessage(r(EmailAccountRequestExceptionReason.invalid)), signInCodeWrong);
  expect(signInErrorMessage(r(EmailAccountRequestExceptionReason.expired)), signInCodeExpired);
  expect(signInErrorMessage(r(EmailAccountRequestExceptionReason.tooManyAttempts)), signInTooManyTries);
  expect(signInErrorMessage(r(EmailAccountRequestExceptionReason.policyViolation)), signInRequestFailed);
  expect(signInErrorMessage(Exception('offline')), signInRequestFailed);
});
```
Live (`@Tags(['live'])`, `setUpAll(waitForLiveServer)`):

```dart
test('ServerOtpSignIn signs in with the dev code and AppSession sees the user', () async {
  final client = await initServer(url: liveServerUrl, storage: MemoryAuthStorage());
  final otp = ServerOtpSignIn(client: client);
  final email = freshEmail('otp');
  final requestId = await otp.sendCode(email);
  await otp.signIn(requestId: requestId, code: devLoginCode);
  final userId = client.auth.authInfo!.authUserId.toString();
  expect(const ServerAppSession().currentUserId, userId);
  // second sign-in of the same email takes the existing-account path
  await client.auth.signOutDevice();
  await otp.signIn(requestId: await otp.sendCode(email), code: devLoginCode);
  expect(const ServerAppSession().currentUserId, userId);
});

test('a wrong code is reported as invalid', () async {
  final client = await initServer(url: liveServerUrl, storage: MemoryAuthStorage());
  final otp = ServerOtpSignIn(client: client);
  final requestId = await otp.sendCode(freshEmail('wrong'));
  await expectLater(
    otp.signIn(requestId: requestId, code: '000000'),
    throwsA(predicate((e) => signInErrorMessage(e!) == signInCodeWrong)),
  );
});
```

- [ ] **Step 2:** FAIL (file missing).
- [ ] **Step 3: implement**

```dart
abstract class OtpSignIn {
  Future<String> sendCode(String email);
  Future<void> signIn({required String requestId, required String code});
}

class ServerOtpSignIn implements OtpSignIn {
  ServerOtpSignIn({server.Client? client}) : _injected = client;
  final server.Client? _injected;
  server.Client get _client => _injected ?? serverClient;

  @override
  Future<String> sendCode(String email) async {
    final id = await withServerErrors(() => _client.emailIdp.startOtpLogin(email: email));
    return id.toString();
  }

  @override
  Future<void> signIn({required String requestId, required String code}) async {
    final idp = _client.emailIdp;
    final verified = await withServerErrors(() => idp.verifyOtpLoginCode(
      otpLoginRequestId: server.UuidValue.fromString(requestId), verificationCode: code));
    final auth = await withServerErrors(() => verified.accountExists
        ? idp.finishOtpLogin(otpLoginToken: verified.token)
        : idp.finishOtpRegistration(otpLoginToken: verified.token));
    await _client.auth.updateSignedInUser(auth);
  }
}

String signInErrorMessage(Object error) => switch (error) {
  EmailAccountRequestException(reason: EmailAccountRequestExceptionReason.invalid) => signInCodeWrong,
  EmailAccountRequestException(reason: EmailAccountRequestExceptionReason.expired) => signInCodeExpired,
  EmailAccountRequestException(reason: EmailAccountRequestExceptionReason.tooManyAttempts) => signInTooManyTries,
  _ => signInRequestFailed,
};
```
Copy: `signInCodeWrong = "That code isn't right. Check it and try again."`, `signInCodeExpired = 'That code has expired. Send a new one.'`, `signInTooManyTries = 'Too many tries. Wait a few minutes, then send a new code.'`, `signInRequestFailed = 'Request failed'`.

- [ ] **Step 4:** `flutter test test/otp_sign_in_test.dart` and `just test-live` PASS. **Step 5:** commit `feat(client): ServerOtpSignIn over emailIdp`.

### Task 5: Landing page code step

**Files:** Create `lib/features/auth/sign_in_code_form.dart`; Modify `lib/features/auth/magic_link_page.dart`; Test `test/m13_fit_finish_test.dart`.

- [ ] **Step 1: failing tests** — m13 landing test uses `_Otp implements OtpSignIn` (records emails, codes; optional `sendError`/`signInError`):
  - landing copy: `landingPasswordNote` = "We'll email you a 6-digit code. No password needed.", button "Email me a sign-in code";
  - bad email → "Please enter a full email address.", no send;
  - `a@b.co` → "Check your email", "We sent a 6-digit code to a@b.co.", label "Sign-in code", button "Sign in";
  - enter `123456` in `sign-in-code`, tap `sign-in-code-submit` with `signInError = invalid` → "That code isn't right. Check it and try again."; expired → "That code has expired. Send a new one."; tooManyAttempts → "Too many tries. Wait a few minutes, then send a new code.";
  - correct code → `otp.codes == [... '123456']`, `otp.requestIds.last == 'req-1'`;
  - "Send a new code" sends again (2 calls) and clears the error; send error → "Request failed";
  - "Use a different email" returns to "Sign in or get started".
  - while signing in, the button reads "Signing in…" (a `Completer` holds the fake).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: implement** `SignInCodeForm` (stateful; owns the code controller):

```dart
class SignInCodeForm extends StatefulWidget {
  const SignInCodeForm({super.key, required this.message, this.messageKey, required this.signingIn,
    required this.sending, required this.error, required this.onSubmit, required this.onResend,
    required this.onUseDifferentEmail});
  // Column: message Text, 'Sign-in code' label, TextField(key: Key('sign-in-code'),
  // keyboardType number, autofillHints oneTimeCode, onSubmitted → submit),
  // error Text(key: Key('sign-in-error')), FilledButton(key: Key('sign-in-code-submit'),
  // 'Sign in' / 'Signing in…'), TextButton 'Send a new code', TextButton 'Use a different email'.
  // Colors: albumInk, albumTerracotta, albumParchment, albumModalBorder only.
}
```
`MagicLinkPage({super.key, this.otpSignIn})`: state `_requestId`, `_sentTo`, `_sending`, `_signingIn`, `_error`. `_sendCode()` validates, calls `sendCode`, stores the id; `_signIn(code)` calls `signIn` (the router moves on via `AuthRefresh`); errors via `signInErrorMessage`. The sent card shows "Check your email" + `SignInCodeForm(message: 'We sent a 6-digit code to $email.')`.

- [ ] **Step 4:** PASS. **Step 5:** commit `feat(client): landing page signs in with an email code`.

### Task 6: Invite page code step

**Files:** Modify `lib/features/auth/invite_sign_in_page.dart`; Test `test/m13_fit_finish_test.dart`.

- [ ] **Step 1: failing test** — invite test: `otpSignIn: otp`, `authRefresh: auth`, `signedIn: () => auth.isSignedIn` with `AuthRefresh(initiallySignedIn: false)`; send → `invite-sent` reads "We sent a code to a@b.co. Enter it to join Ada."; enter code, submit; the fake's `signIn` calls `auth.setSignedIn(true)`; then `landing-home` shows and `invites.accepts == 1`. Wrong code shows the wrong-code copy and no accept.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: implement** — replace `sender` with `OtpSignIn? otpSignIn`; same `_sendCode` / `_signIn` as the landing page; `_onAuth` → `_accept()` unchanged; send button "Email me a sign-in code"; note = `landingPasswordNote`.
- [ ] **Step 4:** PASS. **Step 5:** commit `feat(client): invite page signs in with an email code`.

### Task 7: main on Serverpod; delete Supabase shell

**Files:** Modify `lib/main.dart`; Delete `lib/core/supabase/`, `lib/features/auth/magic_link_redirect.dart`, `test/auth_callback_test.dart`, `test/magic_link_redirect_test.dart`.

- [ ] **Step 1:** main:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  installBeforeUnloadGuard();
  Env.validate();
  await initServer(storage: SessionRecoveringStorage(SecureClientAuthSuccessStorage()));

  final profileApi = ProfileApi();
  ProfileSession.loadOwn = profileApi.loadOwn;
  ProfileSession.downloadAvatar = profileApi.downloadAvatar;
  final authRefresh = AuthRefresh(authInfo: serverClient.auth.authInfoListenable);
  runApp(TellMeAStoryApp(router: createAppRouter(authRefresh: authRefresh,
    familiesApi: FamiliesApi(), inviteApi: InviteApi(), peopleApi: PeopleApi())));
}
```
- [ ] **Step 2:** delete the files; `rg -n "core/supabase|magic_link_redirect|SupabaseAppSession|Env.supabase" lib test` → nothing.
- [ ] **Step 3:** `flutter test` PASS. **Step 4:** commit `refactor(client): start on initServer and delete the Supabase shell`.

### Task 8: integration_test keeps compiling (Main-approved, separate commit)

- `prod_guard.dart`: check `Env.serverUrl` (local `127.0.0.1:8080` / `localhost:8080`).
- `e2e_test.dart`: drop the `supabase_init` import and the three `recover-session` steps; `_mountApp` builds `AuthRefresh(authInfo: serverClient.auth.authInfoListenable)`.
- Commit `chore(client): keep integration_test compiling after Supabase shell removal`. 4f rewrites both files; at merge 4f's version wins.

### Task 9: Gate

```bash
cd apps/tell_me_a_story
mise exec -- dart format --output=none --set-exit-if-changed lib test   # 0 changed
mise exec -- flutter analyze                                            # ≤ 23 issues
mise exec -- flutter test
cd ../.. && mise exec -- just test-live
```

## Hand-offs
- **4b:** `invite_api.currentFamilyId` still calls `ProfileSession.bindUser` / `FamilySelection.bindUser`; `AuthRefresh` now binds on sign-in, so 4b drops those calls.
- **4f:** keys `magic-link-email`, `invite-email`, `sign-in-code`, `sign-in-code-submit`; send text "Email me a sign-in code"; landing code step heading "Check your email" (the invite page has no heading, it shows `invite-sent`); main mounts as in Task 7.
