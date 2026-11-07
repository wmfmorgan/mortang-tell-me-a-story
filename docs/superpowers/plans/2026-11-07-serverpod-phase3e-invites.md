# Phase 3e: Invites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `InviteEndpoint` (`create`, `sendEmail`, `accept`, `resend`, `revoke`) and `InvitePublicEndpoint.preview` on Serverpod 4.1.1, with invite email delivery through a mailer shared with login codes, covering business-rules §7 cases 112–114, 117–119, 121–131, 133–135 and the invite part of 137.

**Architecture:** One endpoint file per class under `apps/server/lib/src/endpoints/`. Token, link, expiry and invite-email helpers live in `lib/src/invites/invites.dart`. The Resend transport moves out of `lib/src/auth/login_code_sender.dart` into `lib/src/mail/mailer.dart`, which both login codes and invites use. Local servers log mail instead of sending it, as before. Authorization uses the 3.0 `Authz.requireLive*` helpers, accept uses the 3.0 `accountEmail` (D2) and `ensureLinkedPerson`, and accept reruns once when it loses the `people_tree_user_uidx` race (Phase 3 index §Conventions).

**Tech Stack:** Dart 3.13.5, Serverpod 4.1.1 (`serverpod`, `serverpod_auth_idp_server`, `serverpod_test`), `crypto` (SHA-256), embedded Postgres 16, just.

**Spec of record:** `docs/migration/business-rules.md` §2.9, §3.4, §4.7, §5.2, §7; `docs/migration/schema-design.md` §3.2 (invite create, invite accept, resend/revoke rows); `docs/migration/endpoint-contract.md` §2.2; Phase 3 index (`2026-11-07-serverpod-phase3-server-endpoints.md`) row "3e Invites" and §Conventions.

**Verified:** every code block below was run on 2026-11-07 in this worktree on top of the 3.0 commit `652e670`, before any of it was committed. `dart analyze` was clean for the server and the generated client, `dart format` changed nothing, and the 54 new and login tests passed.

All commands run from the repo root unless a step says otherwise.

---

## Decisions taken in this slice (approved by Main, 2026-11-07)

1. **`sendEmail` takes the raw token.** Only `tokenHash` is stored (schema-design, invites), so the server can't rebuild the accept link from `inviteId` alone, and rotating the token would break the link `create` just returned. The contract becomes `sendEmail(Session, UuidValue inviteId, String token)`. The server compares `sha256(token)` with `tokenHash` in constant time; a mismatch is `inviteInvalid` "Invite is not valid", checked right after the member check and before the §3.4 status, expiry and no-email checks. Every app caller (`invite_modal.dart`, `add_person_modal.dart`, `edit_person_dialog.dart`) already holds `created.token`. `endpoint-contract.md` §2.2 and §2.3 are updated in the plan commit.
2. **Invite link origin.** There is no server-side origin setting yet. The origin comes from the `inviteAppOrigin` password: `config/passwords.yaml`, or the env var `SERVERPOD_PASSWORD_inviteAppOrigin`. A local server (`isLocalPod`) falls back to `http://127.0.0.1:3000`, the app's `INVITE_APP_ORIGIN` default, and any other server without it throws `StateError`. `passwords.yaml` is gitignored and has no committed template, so deployments must add the key, for example:
   ```yaml
   production:
     inviteAppOrigin: 'https://app.example.com'
   ```
   The link shape is business-rules §3.4: `{origin}/timeline?invite={token}`. The app router rewrites it to `/invite/<token>`.
3. **Tokens** are 32 `Random.secure` bytes as 64 lower-case hex characters, which matches business-rules §4.7 and the slice brief. Schema-design's "base64url" note conflicts with that. Only the SHA-256 hex is stored (`invites_token_hash_shape`).
4. **Preview has no error code.** `InvitePreviewDto` is `valid, familyId?, familyName?, inviterName?`. Every invalid case of §3.4 validate (unknown, family deleted, accepted, revoked, expired) returns `valid: false` with no family or inviter. The app shows one generic copy for all of them (business-rules §5.3).
5. **Email failures** (old 503/502) are `VALIDATION` "Email is not configured" / "Could not send invite email" (index row 3e). `resend` checks configuration before anything else, so no token rotates (BR 129).
6. **Bare NOT_FOUND** for invite persons uses `'person not found'`, the same text slice 3b uses.
7. **Accept, person rows.** This follows schema-design §3.2: link the invited person if it is still unlinked and the caller has no linked person in the tree; otherwise `ensureLinkedPerson`. When the invited person is linked to someone else (BR 112), that row is left alone and the acceptor gets their own single linked row.
8. **BR 137 (invite read part).** `InviteEndpoint` has no list method. The member read of a family's invites is `FamilyEndpoint.detail` (slice 3a, empty `pendingInvites` while deleted). Here 137 is ported as: in a soft-deleted family, a member's `sendEmail` and a steward's `resend`/`revoke` are refused with FORBIDDEN, and nothing changes.

## File map

| Path | Responsibility |
|---|---|
| `apps/server/lib/src/mail/mailer.dart` | `OutgoingMail`, `MailTransport` (`LogMailTransport` locally, `ResendMailTransport` otherwise), `mailTransport(session)`, test override |
| `apps/server/lib/src/auth/login_code_sender.dart` | Sends login codes through `mailTransport` (Resend code moved out) |
| `apps/server/lib/src/invites/invites.dart` | Token make/hash/compare, expiry, origin and link, invite email, invite `AppException`s |
| `apps/server/lib/src/endpoints/invite_endpoint.dart` | `InviteEndpoint` |
| `apps/server/lib/src/endpoints/invite_public_endpoint.dart` | `InvitePublicEndpoint.preview` (`requireLogin => false`) |
| `apps/server/pubspec.yaml` | `crypto` becomes a direct dependency (already in the lock as transitive) |
| `apps/server/test/integration/support/mail_fixtures.dart` | `RecordingMailTransport`, `uniqueEmail` |
| `apps/server/test/integration/support/invite_fixtures.dart` | `InviteFx` extension: `tokenInvite`, `reload`, `membershipOf`, `linkedPeople`, `inviteCount` |
| `apps/server/test/unit/invites_test.dart` | Token, link and mail helpers |
| `apps/server/test/integration/mailer_test.dart` | Login codes go through the mailer; local logs; Resend unconfigured |
| `apps/server/test/integration/invite_endpoint_test.dart` | `InviteEndpoint` |
| `apps/server/test/integration/invite_public_endpoint_test.dart` | `InvitePublicEndpoint` |
| Generated: `lib/src/generated/endpoints.dart`, `lib/src/generated/protocol.yaml`, `test/integration/test_tools/serverpod_test_tools.dart`, `packages/tell_me_a_story_client/lib/src/protocol/client.dart` | From `just server-generate` |

`fixtures.dart` and `lib/server.dart` are not touched. `server-generate` also adds a blank line after the `serverpod_client` import in about 25 unrelated client files. Those whitespace-only changes are reverted before each commit (`git checkout -- <file>`) so they don't collide with other slices.

## §7 coverage

| Case | Test (file › group) |
|---|---|
| 112, 113, 114 | `invite_endpoint_test` › `accept: person rows` |
| 117, 118, 119 | `invite_endpoint_test` › `create` |
| 121 | `invite_public_endpoint_test` |
| 122–126, 133–135 | `invite_endpoint_test` › `accept` |
| 127 | `resend` and `revoke` |
| 128, 129 | `resend` |
| 130 | `revoke` |
| 131 | `sendEmail` |
| 137 (invite part) | `revoke` |

---

### Task 1: Shared mailer (extract the Resend transport)

**Files:**
- Create: `apps/server/lib/src/mail/mailer.dart`
- Modify: `apps/server/lib/src/auth/login_code_sender.dart` (whole file)
- Create: `apps/server/test/integration/support/mail_fixtures.dart`
- Test: `apps/server/test/integration/mailer_test.dart`

- [ ] **Step 1: Write the test fixture and the failing test**

`apps/server/test/integration/support/mail_fixtures.dart`:

```dart
import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/mail/mailer.dart';

/// Records mail instead of sending it. Install with
/// `mailTransportOverride = RecordingMailTransport()` in `setUp` and reset
/// the override to null in `tearDown`.
class RecordingMailTransport implements MailTransport {
  RecordingMailTransport({this.configured = true, this.fails = false});

  /// False: behaves like a server without `resendApiKey`/`resendFrom`.
  final bool configured;

  /// True: every send fails like a provider error.
  final bool fails;

  final sent = <OutgoingMail>[];

  @override
  bool isConfigured(Session session) => configured;

  @override
  Future<void> send(Session session, OutgoingMail mail) async {
    if (!configured) throw const MailNotConfiguredException();
    if (fails) throw const MailDeliveryException();
    sent.add(mail);
  }
}

final _random = Random.secure();

/// A unique lower-case email, so reruns on the shared test database never
/// collide on the email-account index.
String uniqueEmail(String name) =>
    '$name-${_random.nextInt(1 << 32).toRadixString(16)}@example.com';
```

`apps/server/test/integration/mailer_test.dart`:

```dart
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/mail/mailer.dart';
import 'package:test/test.dart';

import 'support/mail_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the shared mailer', (sessionBuilder, endpoints) {
    tearDown(() => mailTransportOverride = null);

    test(
      'when a login code is requested then it goes through the mailer',
      () async {
        final mail = RecordingMailTransport();
        mailTransportOverride = mail;
        final email = uniqueEmail('login');

        await endpoints.emailIdp.startOtpLogin(sessionBuilder, email: email);

        expect(mail.sent, hasLength(1));
        expect(mail.sent.single.to, email);
        expect(mail.sent.single.subject, 'Your Tell Me a Story sign-in code');
        expect(mail.sent.single.text, contains(devLoginCode));
      },
    );

    test('when the server is local then mail is logged, not sent', () {
      final transport = mailTransport(sessionBuilder.build());
      expect(transport, isA<LogMailTransport>());
      expect(transport.isConfigured(sessionBuilder.build()), isTrue);
    });

    test(
      'when resendApiKey and resendFrom are missing then Resend is not '
      'configured and refuses to send',
      () async {
        final session = sessionBuilder.build();
        const resend = ResendMailTransport();
        expect(resend.isConfigured(session), isFalse);
        await expectLater(
          resend.send(
            session,
            const OutgoingMail(to: 'a@example.com', subject: 's', text: 't'),
          ),
          throwsA(isA<MailNotConfiguredException>()),
        );
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/mailer_test.dart`
Expected: compile error, `src/mail/mailer.dart` doesn't exist.

- [ ] **Step 3: Create the mailer and point login codes at it**

`apps/server/lib/src/mail/mailer.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../auth/local_mode.dart';

/// One outgoing email. [text] is always sent; [html] too when given.
class OutgoingMail {
  const OutgoingMail({
    required this.to,
    required this.subject,
    required this.text,
    this.html,
  });

  final String to;
  final String subject;
  final String text;
  final String? html;
}

/// No mail provider is configured (`resendApiKey` or `resendFrom` missing).
class MailNotConfiguredException implements Exception {
  const MailNotConfiguredException();
}

/// The provider could not be reached or rejected the mail. The details are
/// logged, never handed to callers.
class MailDeliveryException implements Exception {
  const MailDeliveryException();
}

/// How the server delivers mail (login codes and invites).
abstract interface class MailTransport {
  /// Whether [send] can deliver at all.
  bool isConfigured(Session session);

  /// Delivers [mail]. Throws [MailNotConfiguredException] or
  /// [MailDeliveryException].
  Future<void> send(Session session, OutgoingMail mail);
}

/// Local servers (see [isLocalPod]) log mail instead of sending it.
class LogMailTransport implements MailTransport {
  const LogMailTransport();

  @override
  bool isConfigured(Session session) => true;

  @override
  Future<void> send(Session session, OutgoingMail mail) async {
    session.log('Mail to ${mail.to}: ${mail.subject}\n${mail.text}');
  }
}

/// Sends through Resend with the `resendApiKey` and `resendFrom` entries in
/// `config/passwords.yaml` (or `SERVERPOD_PASSWORD_*` env vars).
class ResendMailTransport implements MailTransport {
  const ResendMailTransport();

  @override
  bool isConfigured(Session session) =>
      session.passwords['resendApiKey'] != null &&
      session.passwords['resendFrom'] != null;

  @override
  Future<void> send(Session session, OutgoingMail mail) async {
    final apiKey = session.passwords['resendApiKey'];
    final from = session.passwords['resendFrom'];
    if (apiKey == null || from == null) {
      throw const MailNotConfiguredException();
    }

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('https://api.resend.com/emails'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'from': from,
              'to': [mail.to],
              'subject': mail.subject,
              'text': mail.text,
              if (mail.html != null) 'html': mail.html,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      session.log('Resend email timed out', level: LogLevel.error);
      throw const MailDeliveryException();
    } on http.ClientException catch (e) {
      session.log('Resend email failed: ${e.message}', level: LogLevel.error);
      throw const MailDeliveryException();
    }
    if (response.statusCode >= 300) {
      session.log(
        'Resend rejected email: ${response.statusCode} ${response.body}',
        level: LogLevel.error,
      );
      throw const MailDeliveryException();
    }
  }
}

/// Replaces the transport for every send. Tests only; reset it to null in
/// `tearDown`.
MailTransport? mailTransportOverride;

/// The transport for [session]: [mailTransportOverride] when set, else
/// [LogMailTransport] on a local server, else [ResendMailTransport].
MailTransport mailTransport(Session session) =>
    mailTransportOverride ??
    (isLocalPod(session.serverpod)
        ? const LogMailTransport()
        : const ResendMailTransport());
```

`apps/server/lib/src/auth/login_code_sender.dart` (replace the file):

```dart
import 'package:serverpod/serverpod.dart';

import '../mail/mailer.dart';

/// Delivers a one-time login code through [mailTransport].
///
/// Local (development or test with embedded Postgres, see `isLocalPod`):
/// logs the code (the fixed dev code is `111111`).
/// Otherwise: sends it through Resend using the `resendApiKey` and
/// `resendFrom` entries in `config/passwords.yaml`.
Future<void> sendLoginCode(
  Session session, {
  required String email,
  required UuidValue otpLoginRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) async {
  try {
    await mailTransport(session).send(
      session,
      OutgoingMail(
        to: email,
        subject: 'Your Tell Me a Story sign-in code',
        text: 'Your sign-in code is $verificationCode. It expires soon.',
      ),
    );
  } on MailNotConfiguredException {
    throw StateError('resendApiKey and resendFrom must be set in passwords');
  } on MailDeliveryException {
    throw StateError('Login email could not be sent');
  }
}
```

- [ ] **Step 4: Run the mailer and login tests**

Run: `cd apps/server && mise exec -- dart test test/integration/mailer_test.dart test/integration/login_test.dart test/unit/local_mode_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/mail apps/server/lib/src/auth/login_code_sender.dart apps/server/test/integration/mailer_test.dart apps/server/test/integration/support/mail_fixtures.dart
git commit -m "refactor(server): shared mailer for login codes and invites"
```

### Task 2: Invite tokens, links and email

**Files:**
- Modify: `apps/server/pubspec.yaml` (add `crypto: ^3.0.6` under `dependencies`)
- Create: `apps/server/lib/src/invites/invites.dart`
- Test: `apps/server/test/unit/invites_test.dart`

- [ ] **Step 1: Write the failing test**

`apps/server/test/unit/invites_test.dart`:

```dart
import 'package:tell_me_a_story_server/src/invites/invites.dart';
import 'package:test/test.dart';

void main() {
  group('Given invite tokens', () {
    test('when a token is made then it is 64 lower-case hex and unique', () {
      final a = newInviteToken();
      final b = newInviteToken();
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(b, isNot(a));
    });

    test('when a token is hashed then it is its lower-case SHA-256 hex', () {
      expect(
        hashInviteToken('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('when a token is checked then only its own hash matches', () {
      final token = newInviteToken();
      final hash = hashInviteToken(token);
      expect(inviteTokenMatches(token, hash), isTrue);
      expect(inviteTokenMatches(newInviteToken(), hash), isFalse);
      expect(inviteTokenMatches(token, 'short'), isFalse);
    });
  });

  group('Given invite links and mail', () {
    test('when a link is built then it is origin/timeline?invite=token', () {
      expect(
        buildInviteUrl('https://app.example', 'ab12'),
        'https://app.example/timeline?invite=ab12',
      );
    });

    test('when the invite mail is built then it follows the §3.4 copy', () {
      final mail = inviteMail(
        to: 'kim@example.com',
        familyName: 'Smith & <Co>',
        inviteUrl: 'https://app.example/timeline?invite=ab12',
      );
      expect(mail.to, 'kim@example.com');
      expect(mail.subject, 'Invite to Smith & <Co>');
      expect(
        mail.text,
        "You're invited to join Smith & <Co> on Tell Me a Story.\n\n"
        'Accept the invite: https://app.example/timeline?invite=ab12\n\n'
        'This link expires in 7 days and can only be used once.',
      );
      expect(mail.html, contains('<strong>Smith &amp; &lt;Co&gt;</strong>'));
      expect(
        mail.html,
        contains('<a href="https://app.example/timeline?invite=ab12">'),
      );
      expect(
        mail.html,
        contains('This link expires in 7 days and can only be used once.'),
      );
    });
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/unit/invites_test.dart`
Expected: compile error, `src/invites/invites.dart` doesn't exist.

- [ ] **Step 3: Add `crypto` and the helpers**

Run: `cd apps/server && mise exec -- dart pub add crypto:^3.0.6`

`apps/server/lib/src/invites/invites.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

import '../auth/local_mode.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../mail/mailer.dart';

/// Invites expire this long after create and after every resend
/// (business-rules.md §4.7).
const inviteLifetime = Duration(days: 7);

/// Invite-link origin on a local server without `inviteAppOrigin`; the same
/// default as the app's `INVITE_APP_ORIGIN` define.
const localInviteAppOrigin = 'http://127.0.0.1:3000';

final _random = Random.secure();

/// A new raw invite token: 32 random bytes as 64 lower-case hex characters.
/// Only [hashInviteToken] of it is stored.
String newInviteToken() => List.generate(
  32,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

/// Lower-case hex SHA-256 of [token] (CHECK `invites_token_hash_shape`).
String hashInviteToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();

/// Whether [token] hashes to [tokenHash], compared in constant time.
bool inviteTokenMatches(String token, String tokenHash) {
  final hash = hashInviteToken(token);
  if (hash.length != tokenHash.length) return false;
  var diff = 0;
  for (var i = 0; i < hash.length; i++) {
    diff |= hash.codeUnitAt(i) ^ tokenHash.codeUnitAt(i);
  }
  return diff == 0;
}

/// Expired when `expiresAt <= now` (business-rules.md §4.7).
bool isInviteExpired(Invite invite, DateTime now) =>
    !invite.expiresAt.isAfter(now);

/// The app origin for invite links: the `inviteAppOrigin` password
/// (`config/passwords.yaml` or `SERVERPOD_PASSWORD_inviteAppOrigin`) without
/// trailing slashes. A local server falls back to [localInviteAppOrigin];
/// any other server without it throws [StateError].
String inviteAppOrigin(Session session) {
  final configured = session.passwords['inviteAppOrigin']?.trim() ?? '';
  if (configured.isNotEmpty) return configured.replaceAll(RegExp(r'/+$'), '');
  if (isLocalPod(session.serverpod)) return localInviteAppOrigin;
  throw StateError(
    'inviteAppOrigin must be set in config/passwords.yaml (or '
    'SERVERPOD_PASSWORD_inviteAppOrigin) unless running locally',
  );
}

/// `{origin}/timeline?invite={token}` (business-rules.md §3.4). The app's
/// router rewrites it to `/invite/<token>`.
String buildInviteUrl(String origin, String token) =>
    '$origin/timeline?invite=${Uri.encodeQueryComponent(token)}';

/// The invite email (business-rules.md §3.4).
OutgoingMail inviteMail({
  required String to,
  required String familyName,
  required String inviteUrl,
}) {
  final name = const HtmlEscape(HtmlEscapeMode.element).convert(familyName);
  final href = const HtmlEscape(HtmlEscapeMode.attribute).convert(inviteUrl);
  return OutgoingMail(
    to: to,
    subject: 'Invite to $familyName',
    text:
        "You're invited to join $familyName on Tell Me a Story.\n\n"
        'Accept the invite: $inviteUrl\n\n'
        'This link expires in 7 days and can only be used once.',
    html:
        "<p>You're invited to join <strong>$name</strong> on Tell Me a "
        'Story.</p>\n'
        '<p><a href="$href">Accept the invite</a></p>\n'
        '<p>This link expires in 7 days and can only be used once.</p>',
  );
}

/// Throws `VALIDATION: Email is not configured` unless mail can be sent.
void requireInviteMailConfigured(Session session) {
  if (!mailTransport(session).isConfigured(session)) {
    throw validation('Email is not configured');
  }
}

/// Sends [mail]. Provider problems become `VALIDATION` with the §3.4
/// messages; the details are only logged.
Future<void> deliverInviteMail(Session session, OutgoingMail mail) async {
  try {
    await mailTransport(session).send(session, mail);
  } on MailNotConfiguredException {
    throw validation('Email is not configured');
  } on MailDeliveryException {
    throw validation('Could not send invite email');
  }
}

AppException inviteInvalid([String message = 'Invite is not valid']) =>
    AppException(code: AppErrorCode.inviteInvalid, message: message);

AppException inviteExpired() => AppException(
  code: AppErrorCode.inviteExpired,
  message: 'Invite link expired',
);

AppException inviteAccepted() => AppException(
  code: AppErrorCode.inviteAccepted,
  message: 'Invite already used',
);
```

- [ ] **Step 4: Run the test**

Run: `cd apps/server && mise exec -- dart test test/unit/invites_test.dart`
Expected: 5 pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/pubspec.yaml apps/server/pubspec.lock apps/server/lib/src/invites apps/server/test/unit/invites_test.dart
git commit -m "feat(server): invite tokens, links and email"
```

### Task 3: `InviteEndpoint.create` (BR 117–119)

**Files:**
- Create: `apps/server/test/integration/support/invite_fixtures.dart`
- Create: `apps/server/lib/src/endpoints/invite_endpoint.dart`
- Test: `apps/server/test/integration/invite_endpoint_test.dart`
- Generated: see the file map

- [ ] **Step 1: Write the fixtures and the failing tests**

`apps/server/test/integration/support/invite_fixtures.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/invites/invites.dart';

import 'fixtures.dart';

/// Slice 3e row builders and lookups.
extension InviteFx on Fx {
  /// An invite stored the way `InviteEndpoint.create` stores it, plus its raw
  /// token. [expired] backdates it so `expiresAt` is a day in the past.
  Future<({Invite invite, String token})> tokenInvite(
    Family family, {
    String? email,
    UuidValue? personId,
    UuidValue? invitedById,
    UuidValue? acceptedById,
    bool revoked = false,
    bool expired = false,
  }) async {
    final token = newInviteToken();
    final now = DateTime.now().toUtc();
    final created = expired ? now.subtract(const Duration(days: 8)) : now;
    final invite = await Invite.db.insertRow(
      s,
      Invite(
        familyId: family.id!,
        treeId: family.treeId,
        personId: personId,
        email: email,
        tokenHash: hashInviteToken(token),
        invitedById: invitedById,
        acceptedById: acceptedById,
        acceptedAt: acceptedById == null ? null : now,
        revokedAt: revoked ? now : null,
        lastSentAt: created,
        createdAt: created,
        expiresAt: created.add(inviteLifetime),
      ),
    );
    return (invite: invite, token: token);
  }

  Future<Invite> reload(Invite invite) async =>
      (await Invite.db.findById(s, invite.id!))!;

  Future<Membership?> membershipOf(Family family, UuidValue user) =>
      Membership.db.findFirstRow(
        s,
        where: (t) => t.familyId.equals(family.id!) & t.userId.equals(user),
      );

  /// People linked to [user] in [treeId] (at most one: people_tree_user_uidx).
  Future<List<Person>> linkedPeople(UuidValue treeId, UuidValue user) =>
      Person.db.find(
        s,
        where: (t) => t.treeId.equals(treeId) & t.userId.equals(user),
      );

  Future<int> inviteCount(Family family) =>
      Invite.db.count(s, where: (t) => t.familyId.equals(family.id!));
}
```

`apps/server/test/integration/invite_endpoint_test.dart`: the shared header, the `create` group, and the closing lines.

```dart
import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/invites/invites.dart';
import 'package:tell_me_a_story_server/src/mail/mailer.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/invite_fixtures.dart';
import 'support/mail_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

/// Holds a write open in its own transaction until [release] runs, so a test
/// can make an endpoint call collide with it (constraint races).
Future<void Function()> holdOpen(
  Session s,
  Future<void> Function(Transaction t) write,
) async {
  final written = Completer<void>();
  final release = Completer<void>();
  unawaited(
    s.db.transaction((t) async {
      await write(t);
      written.complete();
      await release.future;
    }),
  );
  await written.future;
  return release.complete;
}

/// Long enough for an endpoint call to reach the statement that blocks on a
/// [holdOpen] row.
const raceDelay = Duration(milliseconds: 300);

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given InviteEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    late RecordingMailTransport mail;

    setUp(() {
      fx = Fx(sessionBuilder.build());
      mailTransportOverride = mail = RecordingMailTransport();
    });
    tearDown(() => mailTransportOverride = null);

    /// A family in a new tree with [user] joined as [role].
    Future<Family> familyOf(
      UuidValue user, {
      MembershipRole role = MembershipRole.member,
      DateTime? deletedAt,
      String name = 'Mortang',
    }) async {
      final family = await fx.family(
        await fx.tree(),
        deletedAt: deletedAt,
        name: name,
      );
      await fx.join(family, user, role);
      return family;
    }
    group('create', () {
      // BR 117
      test(
        'when a live member creates an invite without a person then a '
        'token, expiresAt (+7d) and invite_url come back',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final before = DateTime.now().toUtc();

          final created = await endpoints.invite.create(
            asUser(sessionBuilder, member),
            family.id!,
            email: '  Kim@Example.COM ',
          );

          expect(created.token, matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(
            created.inviteUrl,
            'http://127.0.0.1:3000/timeline?invite=${created.token}',
          );
          expect(
            created.expiresAt
                .difference(before.add(inviteLifetime))
                .inSeconds
                .abs(),
            lessThan(5),
          );
          final row = (await Invite.db.findById(fx.s, created.inviteId))!;
          expect(row.tokenHash, hashInviteToken(created.token));
          expect(row.email, 'kim@example.com');
          expect(row.invitedById, member);
          expect(row.treeId, family.treeId);
          expect(row.personId, isNull);
          expect(row.lastSentAt, isNotNull);
          expect(mail.sent, isEmpty);
        },
      );

      // BR 117
      test('when the email is blank then the invite is link-only', () async {
        final member = await fx.user();
        final family = await familyOf(member);

        final created = await endpoints.invite.create(
          asUser(sessionBuilder, member),
          family.id!,
          email: '   ',
        );

        expect((await Invite.db.findById(fx.s, created.inviteId))!.email, null);
      });

      // BR 117
      test(
        'when a non-member creates then FORBIDDEN "Not a family member"',
        () async {
          final family = await fx.family(await fx.tree());
          await expectLater(
            endpoints.invite.create(
              asUser(sessionBuilder, await fx.user()),
              family.id!,
            ),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          expect(await fx.inviteCount(family), 0);
        },
      );

      // BR 117
      test(
        'when a member of a soft-deleted family creates then FORBIDDEN',
        () async {
          final member = await fx.user();
          final family = await familyOf(
            member,
            role: MembershipRole.owner,
            deletedAt: DateTime.now().toUtc(),
          );
          await expectLater(
            endpoints.invite.create(asUser(sessionBuilder, member), family.id!),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          expect(await fx.inviteCount(family), 0);
        },
      );

      // BR 118
      test(
        'when the person is unknown or in another tree then the same '
        'NOT_FOUND',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final elsewhere = await fx.person(
            await fx.family(await fx.tree()),
          );

          for (final personId in [
            UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
            elsewhere.id!,
          ]) {
            await expectLater(
              endpoints.invite.create(
                asUser(sessionBuilder, member),
                family.id!,
                personId: personId,
              ),
              throwsAppError(AppErrorCode.notFound, 'person not found'),
            );
          }
          expect(await fx.inviteCount(family), 0);
        },
      );

      // BR 118
      test(
        'when the person is linked or passed then VALIDATION; an unlinked '
        'living tree person is OK',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final linked = await fx.person(family, userId: await fx.user());
          final passed = await fx.person(family, passedAway: true);
          final branch = await fx.family(
            Tree(id: family.treeId),
            parentId: family.id,
            branchYear: 1990,
          );
          final unlinked = await fx.person(branch);
          final session = asUser(sessionBuilder, member);

          await expectLater(
            endpoints.invite.create(
              session,
              family.id!,
              personId: linked.id,
            ),
            throwsAppError(AppErrorCode.validation, 'person is already linked'),
          );
          await expectLater(
            endpoints.invite.create(
              session,
              family.id!,
              personId: passed.id,
            ),
            throwsAppError(AppErrorCode.validation, 'person has passed'),
          );
          final created = await endpoints.invite.create(
            session,
            family.id!,
            personId: unlinked.id,
          );
          final row = (await Invite.db.findById(fx.s, created.inviteId))!;
          expect(row.personId, unlinked.id);
        },
      );

      // BR 119
      test(
        'when the insert fails then VALIDATION "Could not create invite" '
        'with no raw database text',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final person = await fx.person(family);
          // The person passes the checks, then its delete commits while the
          // invite insert waits on the FK.
          final release = await holdOpen(
            fx.s,
            (t) => Person.db.deleteRow(fx.s, person, transaction: t),
          );
          final creating = expectLater(
            endpoints.invite.create(
              asUser(sessionBuilder, member),
              family.id!,
              personId: person.id,
            ),
            throwsAppError(AppErrorCode.validation, 'Could not create invite'),
          );
          await Future<void>.delayed(raceDelay);
          release();
          await creating;
          expect(await fx.inviteCount(family), 0);
        },
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: compile error, `endpoints.invite` doesn't exist.

- [ ] **Step 3: Implement `create`**

`apps/server/lib/src/endpoints/invite_endpoint.dart`:

```dart
import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../invites/invites.dart';

/// Postgres errors an invite insert can hit when a row it refers to changes
/// underneath it (person or family deleted: FK; token hash collision:
/// unique). They map to `VALIDATION: Could not create invite`.
const _inviteInsertRefusals = {'23503', '23505'};

/// Invites (business-rules.md §2.9, §3.4; decisions D2, D3, D6a, D6b).
class InviteEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Any live member invites (D3). [email] is trimmed and lower-cased; blank
  /// means a link-only invite. The raw token is returned once; only its hash
  /// is stored.
  Future<CreatedInviteDto> create(
    Session session,
    UuidValue familyId, {
    String? email,
    UuidValue? personId,
  }) async {
    final authz = Authz(session);
    final uid = authz.requireUser();
    await authz.requireLiveMember(familyId, message: 'Not a family member');
    final family = (await Family.db.findById(session, familyId))!;
    if (personId != null) {
      await _requireInvitablePerson(session, family, personId);
    }
    final normalized = email == null ? '' : normalizeEmail(email);
    final origin = inviteAppOrigin(session);
    final token = newInviteToken();
    final now = DateTime.now().toUtc();
    final Invite invite;
    try {
      invite = await Invite.db.insertRow(
        session,
        Invite(
          familyId: familyId,
          treeId: family.treeId,
          personId: personId,
          email: normalized.isEmpty ? null : normalized,
          tokenHash: hashInviteToken(token),
          invitedById: uid,
          lastSentAt: now,
          expiresAt: now.add(inviteLifetime),
          createdAt: now,
        ),
      );
    } on DatabaseQueryException catch (e) {
      if (!_inviteInsertRefusals.contains(e.code)) rethrow;
      throw validation('Could not create invite');
    }
    return CreatedInviteDto(
      inviteId: invite.id!,
      token: token,
      expiresAt: invite.expiresAt,
      inviteUrl: buildInviteUrl(origin, token),
    );
  }

  /// `assert_invite_person`: the person is in the family's tree (unknown and
  /// out-of-tree give the same NOT_FOUND), unlinked and not passed away.
  Future<void> _requireInvitablePerson(
    Session session,
    Family family,
    UuidValue personId,
  ) async {
    final person = await Person.db.findById(session, personId);
    if (person == null || person.treeId != family.treeId) {
      throw notFound('person not found');
    }
    if (person.userId != null) throw validation('person is already linked');
    if (person.passedAway) throw validation('person has passed');
  }
}
```

Run: `mise exec -- just server-generate`, then revert the whitespace-only client changes: `git diff --name-only packages | grep -v '/client.dart$' | xargs git checkout --`.

- [ ] **Step 4: Run the tests**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: 7 pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_endpoint.dart apps/server/lib/src/generated apps/server/test/integration packages/tell_me_a_story_client/lib/src/protocol/client.dart
git commit -m "feat(server): InviteEndpoint.create"
```

### Task 4: `InvitePublicEndpoint.preview` (BR 121)

**Files:**
- Create: `apps/server/lib/src/endpoints/invite_public_endpoint.dart`
- Test: `apps/server/test/integration/invite_public_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

`apps/server/test/integration/invite_public_endpoint_test.dart`:

```dart
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/invites/invites.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/invite_fixtures.dart';
import 'support/mail_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given InvitePublicEndpoint', (sessionBuilder, endpoints) {
    late Fx fx;
    setUp(() => fx = Fx(sessionBuilder.build()));

    final hidden = isA<InvitePreviewDto>()
        .having((p) => p.valid, 'valid', isFalse)
        .having((p) => p.familyId, 'familyId', isNull)
        .having((p) => p.familyName, 'familyName', isNull)
        .having((p) => p.inviterName, 'inviterName', isNull);

    // BR 121
    test(
      'when a signed-out caller previews a live invite then it is valid with '
      'the family and the trimmed inviter name',
      () async {
        final family = await fx.family(await fx.tree(), name: 'Mortang');
        final inviter = await fx.userWithEmail(
          uniqueEmail('inviter'),
          displayName: ' Ana ',
        );
        final (invite: _, :token) = await fx.tokenInvite(
          family,
          invitedById: inviter,
        );

        final preview = await endpoints.invitePublic.preview(
          sessionBuilder,
          token,
        );

        expect(preview.valid, isTrue);
        expect(preview.familyId, family.id);
        expect(preview.familyName, 'Mortang');
        expect(preview.inviterName, 'Ana');
      },
    );

    // BR 121
    test(
      'when the inviter has no display name or is gone then inviterName is '
      'null',
      () async {
        final family = await fx.family(await fx.tree());
        final blank = await fx.userWithEmail(
          uniqueEmail('blank'),
          displayName: '  ',
        );
        final withBlank = await fx.tokenInvite(family, invitedById: blank);
        final withNone = await fx.tokenInvite(family);

        for (final token in [withBlank.token, withNone.token]) {
          final preview = await endpoints.invitePublic.preview(
            sessionBuilder,
            token,
          );
          expect(preview.valid, isTrue);
          expect(preview.inviterName, isNull);
        }
      },
    );

    // BR 121
    test(
      'when the token is unknown or blank, the family is soft-deleted, or '
      'the invite is accepted, revoked or expired then it is invalid and '
      'hides the family and inviter',
      () async {
        final inviter = await fx.userWithEmail(
          uniqueEmail('inviter'),
          displayName: 'Ana',
        );
        final live = await fx.family(await fx.tree());
        final deleted = await fx.family(
          await fx.tree(),
          deletedAt: DateTime.now().toUtc(),
        );
        final tokens = [
          newInviteToken(),
          '  ',
          (await fx.tokenInvite(deleted, invitedById: inviter)).token,
          (await fx.tokenInvite(
            live,
            invitedById: inviter,
            acceptedById: await fx.user(),
          )).token,
          (await fx.tokenInvite(
            live,
            invitedById: inviter,
            revoked: true,
          )).token,
          (await fx.tokenInvite(
            live,
            invitedById: inviter,
            expired: true,
          )).token,
        ];

        for (final token in tokens) {
          expect(
            await endpoints.invitePublic.preview(sessionBuilder, token),
            hidden,
          );
        }
      },
    );

    test(
      'when a signed-in caller previews then the same answer comes back',
      () async {
        final family = await fx.family(await fx.tree());
        final (invite: _, :token) = await fx.tokenInvite(family);
        final preview = await endpoints.invitePublic.preview(
          asUser(sessionBuilder, await fx.user()),
          token,
        );
        expect(preview.valid, isTrue);
        expect(preview.familyId, family.id);
      },
    );
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_public_endpoint_test.dart`
Expected: compile error, `endpoints.invitePublic` doesn't exist.

- [ ] **Step 3: Implement `preview`**

`apps/server/lib/src/endpoints/invite_public_endpoint.dart`:

```dart
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../invites/invites.dart';

/// The anonymous invite landing (business-rules.md §3.4, validate).
class InvitePublicEndpoint extends Endpoint {
  @override
  bool get requireLogin => false;

  /// Anyone, signed in or not. An unknown token, a soft-deleted family (D6a),
  /// an accepted, revoked or expired invite all give `valid: false` with no
  /// family or inviter.
  Future<InvitePreviewDto> preview(Session session, String token) async {
    final invalid = InvitePreviewDto(valid: false);
    final trimmed = token.trim();
    if (trimmed.isEmpty) return invalid;
    final invite = await Invite.db.findFirstRow(
      session,
      where: (t) => t.tokenHash.equals(hashInviteToken(trimmed)),
    );
    if (invite == null) return invalid;
    final family = await Family.db.findById(session, invite.familyId);
    if (family == null || family.deletedAt != null) return invalid;
    if (invite.acceptedAt != null ||
        invite.revokedAt != null ||
        isInviteExpired(invite, DateTime.now().toUtc())) {
      return invalid;
    }
    final inviterId = invite.invitedById;
    final inviter = inviterId == null
        ? null
        : await AppUser.db.findFirstRow(
            session,
            where: (t) => t.authUserId.equals(inviterId),
          );
    final inviterName = inviter?.displayName?.trim() ?? '';
    return InvitePreviewDto(
      valid: true,
      familyId: family.id,
      familyName: family.name,
      inviterName: inviterName.isEmpty ? null : inviterName,
    );
  }
}
```

Run: `mise exec -- just server-generate`, then `git diff --name-only packages | grep -v '/client.dart$' | xargs git checkout --`.

- [ ] **Step 4: Run the tests**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_public_endpoint_test.dart`
Expected: 4 pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_public_endpoint.dart apps/server/lib/src/generated apps/server/test/integration packages/tell_me_a_story_client/lib/src/protocol/client.dart
git commit -m "feat(server): InvitePublicEndpoint.preview"
```

### Task 5: `InviteEndpoint.accept` (BR 122–126, 133–135)

**Files:**
- Modify: `apps/server/lib/src/endpoints/invite_endpoint.dart`
- Test: `apps/server/test/integration/invite_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

Insert this group inside `withServerpod`, directly before the closing `}, rollbackDatabase: RollbackDatabase.disabled);` line of `apps/server/test/integration/invite_endpoint_test.dart`:

```dart
    group('accept', () {
      // BR 122
      test(
        'when a pending live invite is accepted then a member row is created '
        'and the invite is marked accepted; another user then gets '
        'INVITE_ACCEPTED; the same user again gets the same family',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();

          final joined = await endpoints.invite.accept(
            asUser(sessionBuilder, joiner),
            token,
          );

          expect(joined, family.id);
          final membership = (await fx.membershipOf(family, joiner))!;
          expect(membership.role, MembershipRole.member);
          final row = await fx.reload(invite);
          expect(row.acceptedById, joiner);
          expect(row.acceptedAt, isNotNull);

          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, await fx.user()),
              token,
            ),
            throwsAppError(AppErrorCode.inviteAccepted, 'Invite already used'),
          );
          expect(
            await endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              token,
            ),
            family.id,
          );
          expect((await fx.membershipOf(family, joiner))!.id, membership.id);
        },
      );

      // BR 123
      test(
        'when the owner opens their own family invite then accept succeeds '
        'and the role stays owner',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final (:invite, :token) = await fx.tokenInvite(family);

          expect(
            await endpoints.invite.accept(asUser(sessionBuilder, owner), token),
            family.id,
          );
          expect(
            (await fx.membershipOf(family, owner))!.role,
            MembershipRole.owner,
          );
          expect((await fx.reload(invite)).acceptedById, owner);
        },
      );

      // BR 124
      test(
        'when the pending invite is expired then INVITE_EXPIRED; revoked '
        'then INVITE_INVALID',
        () async {
          final family = await fx.family(await fx.tree());
          final expired = await fx.tokenInvite(family, expired: true);
          final revoked = await fx.tokenInvite(family, revoked: true);
          final joiner = await fx.user();

          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              expired.token,
            ),
            throwsAppError(AppErrorCode.inviteExpired, 'Invite link expired'),
          );
          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              revoked.token,
            ),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          expect(await fx.membershipOf(family, joiner), isNull);
          expect((await fx.reload(expired.invite)).acceptedAt, isNull);
        },
      );

      test(
        'when the token is unknown then INVITE_INVALID; blank then '
        'VALIDATION "token is required"',
        () async {
          final user = asUser(sessionBuilder, await fx.user());
          await expectLater(
            endpoints.invite.accept(user, newInviteToken()),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          await expectLater(
            endpoints.invite.accept(user, '  '),
            throwsAppError(AppErrorCode.validation, 'token is required'),
          );
        },
      );

      // BR 125
      test(
        'when the caller is signed out then the call is refused and the '
        'invite is not marked accepted',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);

          await expectLater(
            endpoints.invite.accept(sessionBuilder, token),
            throwsA(isA<ServerpodUnauthenticatedException>()),
          );
          expect((await fx.reload(invite)).acceptedAt, isNull);
        },
      );

      // BR 126
      test(
        'when the accepting user re-enters after their membership is gone '
        'then VALIDATION "Could not check membership"',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();
          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);
          await Membership.db.deleteWhere(
            fx.s,
            where: (t) =>
                t.familyId.equals(family.id!) & t.userId.equals(joiner),
          );

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, joiner), token),
            throwsAppError(
              AppErrorCode.validation,
              'Could not check membership',
            ),
          );
          expect((await fx.reload(invite)).acceptedById, joiner);
        },
      );

      // BR 126
      test(
        'when the membership insert collides then VALIDATION "Could not '
        'create membership" and the invite stays pending',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();
          final release = await holdOpen(
            fx.s,
            (t) => Membership.db.insertRow(
              fx.s,
              Membership(familyId: family.id!, userId: joiner),
              transaction: t,
            ),
          );
          final accepting = expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, joiner), token),
            throwsAppError(
              AppErrorCode.validation,
              'Could not create membership',
            ),
          );
          await Future<void>.delayed(raceDelay);
          release();
          await accepting;
          expect((await fx.reload(invite)).acceptedAt, isNull);
        },
      );

      // BR 133
      test(
        'when an invite emailed to a@x.com is accepted by b@x.com then '
        'INVITE_INVALID "Invite was sent to a different email" and no '
        'membership; the " A@X.com " account then succeeds',
        () async {
          final family = await fx.family(await fx.tree());
          final a = uniqueEmail('a');
          final (:invite, :token) = await fx.tokenInvite(family, email: a);
          final b = await fx.userWithEmail(uniqueEmail('b'));

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, b), token),
            throwsAppError(
              AppErrorCode.inviteInvalid,
              'Invite was sent to a different email',
            ),
          );
          expect(await fx.membershipOf(family, b), isNull);
          expect((await fx.reload(invite)).acceptedAt, isNull);

          final noEmail = await fx.user();
          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, noEmail), token),
            throwsAppError(
              AppErrorCode.inviteInvalid,
              'Invite was sent to a different email',
            ),
          );

          final owner = await fx.userWithEmail(' ${a.toUpperCase()} ');
          expect(
            await endpoints.invite.accept(asUser(sessionBuilder, owner), token),
            family.id,
          );
          expect(await fx.membershipOf(family, owner), isNotNull);
        },
      );

      // BR 134
      test(
        'when a link-only invite is accepted by any signed-in user then it '
        'succeeds',
        () async {
          final family = await fx.family(await fx.tree());
          final (invite: _, :token) = await fx.tokenInvite(family);
          final anyone = await fx.userWithEmail(uniqueEmail('anyone'));

          expect(
            await endpoints.invite.accept(
              asUser(sessionBuilder, anyone),
              token,
            ),
            family.id,
          );
          expect(await fx.membershipOf(family, anyone), isNotNull);
        },
      );

      // BR 135
      test(
        'when an invite to a soft-deleted family is accepted then '
        'INVITE_INVALID and no membership',
        () async {
          final family = await fx.family(
            await fx.tree(),
            deletedAt: DateTime.now().toUtc(),
          );
          final email = uniqueEmail('deleted');
          final (:invite, :token) = await fx.tokenInvite(family, email: email);
          final joiner = await fx.userWithEmail(email);

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, joiner), token),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          expect(await fx.membershipOf(family, joiner), isNull);
          expect((await fx.reload(invite)).acceptedAt, isNull);
        },
      );

      // BR 135 (D6a, D2 order)
      test(
        'when the family is deleted and the email differs then the family '
        'check wins; both run before the accepted check',
        () async {
          final family = await fx.family(await fx.tree());
          final email = uniqueEmail('first');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            email: email,
            acceptedById: await fx.userWithEmail(email),
          );
          final other = await fx.userWithEmail(uniqueEmail('other'));

          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, other), token),
            throwsAppError(
              AppErrorCode.inviteInvalid,
              'Invite was sent to a different email',
            ),
          );
          await Family.db.updateRow(
            fx.s,
            family.copyWith(deletedAt: DateTime.now().toUtc()),
          );
          await expectLater(
            endpoints.invite.accept(asUser(sessionBuilder, other), token),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
        },
      );
    });
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: compile error, `endpoints.invite.accept` doesn't exist.

- [ ] **Step 3: Implement `accept`, without the membership-race mapping yet**

Append to `InviteEndpoint` (after `_requireInvitablePerson`):

```dart
  /// Joins the invite's family and returns its id. Single transaction:
  /// membership, person link, invite marked accepted.
  Future<UuidValue> accept(Session session, String token) async {
    final uid = Authz(session).requireUser();
    final trimmed = token.trim();
    if (trimmed.isEmpty) throw validation('token is required');
    final tokenHash = hashInviteToken(trimmed);
    return _accept(session, uid, tokenHash);
  }

  Future<UuidValue> _accept(
    Session session,
    UuidValue uid,
    String tokenHash,
  ) => session.db.transaction((t) async {
    final invite = await Invite.db.findFirstRow(
      session,
      where: (i) => i.tokenHash.equals(tokenHash),
      transaction: t,
      lockMode: LockMode.forUpdate,
    );
    if (invite == null) throw inviteInvalid();
    final family = await Family.db.findById(
      session,
      invite.familyId,
      transaction: t,
    );
    // D6a, then D2; both before the accepted/re-entry check.
    if (family == null || family.deletedAt != null) throw inviteInvalid();
    final invitedEmail = invite.email;
    if (invitedEmail != null &&
        invitedEmail != await accountEmail(session, uid, transaction: t)) {
      throw inviteInvalid('Invite was sent to a different email');
    }

    final existing = await Membership.db.findFirstRow(
      session,
      where: (m) => m.familyId.equals(family.id!) & m.userId.equals(uid),
      transaction: t,
    );
    if (invite.acceptedAt != null) {
      if (invite.acceptedById != uid) throw inviteAccepted();
      if (existing == null) throw validation('Could not check membership');
      return family.id!;
    }
    if (invite.revokedAt != null) throw inviteInvalid();
    final now = DateTime.now().toUtc();
    if (isInviteExpired(invite, now)) throw inviteExpired();

    // No demotion: an existing member keeps their role.
    if (existing == null) {
      await Membership.db.insertRow(
        session,
        Membership(familyId: family.id!, userId: uid),
        transaction: t,
      );
    }

    await ensureLinkedPerson(
      session,
      treeId: family.treeId,
      homeFamilyId: family.id!,
      userId: uid,
      transaction: t,
    );

    await Invite.db.updateRow(
      session,
      invite.copyWith(acceptedAt: now, acceptedById: uid),
      transaction: t,
    );
    return family.id!;
  });
```

Run: `mise exec -- just server-generate`, then `git diff --name-only packages | grep -v '/client.dart$' | xargs git checkout --`.

- [ ] **Step 4: Run the tests and see only the collision case fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: every `accept` test passes except "when the membership insert collides…", which fails with a raw `DatabaseQueryException` (23505 `memberships_family_user_uidx`) instead of `VALIDATION`.

- [ ] **Step 5: Map the collision to the catalogue message**

In `_accept`, replace the plain membership insert with:

```dart
      try {
        await Membership.db.insertRow(
          session,
          Membership(familyId: family.id!, userId: uid),
          transaction: t,
        );
      } on DatabaseQueryException catch (e) {
        if (e.code != '23505' ||
            e.constraintName != 'memberships_family_user_uidx') {
          rethrow;
        }
        throw validation('Could not create membership');
      }
```

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_endpoint.dart apps/server/lib/src/generated apps/server/test/integration packages/tell_me_a_story_client/lib/src/protocol/client.dart
git commit -m "feat(server): InviteEndpoint.accept with email binding and live-family check"
```

### Task 6: Accept links the invited person; linked-person race (BR 112–114)

**Files:**
- Modify: `apps/server/lib/src/endpoints/invite_endpoint.dart`
- Test: `apps/server/test/integration/invite_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

Insert this group inside `withServerpod`, directly before the closing `}, rollbackDatabase: RollbackDatabase.disabled);` line of `apps/server/test/integration/invite_endpoint_test.dart`:

```dart
    group('accept: person rows', () {
      // BR 112
      test(
        'when the invite person is already linked to someone then no '
        'duplicate row is made and accept succeeds',
        () async {
          final family = await fx.family(await fx.tree());
          final other = await fx.user();
          final person = await fx.person(family, userId: other, name: 'Ada');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );
          final joiner = await fx.user();

          expect(
            await endpoints.invite.accept(
              asUser(sessionBuilder, joiner),
              token,
            ),
            family.id,
          );

          final reread = (await Person.db.findById(fx.s, person.id!))!;
          expect(reread.userId, other);
          expect(reread.name, 'Ada');
          expect(await fx.linkedPeople(family.treeId, other), hasLength(1));
          expect(await fx.linkedPeople(family.treeId, joiner), hasLength(1));
        },
      );

      // BR 113
      test(
        'when the invite person is unlinked then it is linked to the '
        'acceptor and takes their display name',
        () async {
          final family = await fx.family(await fx.tree());
          final person = await fx.person(family, name: 'Ada', passedAway: true);
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );
          final joiner = await fx.userWithEmail(
            uniqueEmail('kim'),
            displayName: ' Kim ',
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          final reread = (await Person.db.findById(fx.s, person.id!))!;
          expect(reread.userId, joiner);
          expect(reread.name, 'Kim');
          expect(await fx.linkedPeople(family.treeId, joiner), hasLength(1));
        },
      );

      // BR 113
      test(
        'when the acceptor has no display name then the linked person keeps '
        'its name',
        () async {
          final family = await fx.family(await fx.tree());
          final person = await fx.person(family, name: 'Ada');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );
          final joiner = await fx.userWithEmail(
            uniqueEmail('blank'),
            displayName: '   ',
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          final reread = (await Person.db.findById(fx.s, person.id!))!;
          expect(reread.userId, joiner);
          expect(reread.name, 'Ada');
        },
      );

      // BR 113
      test(
        'when the acceptor is already linked in the tree then the invite '
        'person stays unlinked',
        () async {
          final tree = await fx.tree();
          final family = await fx.family(tree);
          final joiner = await fx.user();
          final own = await fx.person(family, userId: joiner, name: 'Me');
          final person = await fx.person(family, name: 'Ada');
          final (invite: _, :token) = await fx.tokenInvite(
            family,
            personId: person.id,
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          expect((await Person.db.findById(fx.s, person.id!))!.userId, isNull);
          expect(
            (await fx.linkedPeople(tree.id!, joiner)).single.id,
            own.id,
          );
        },
      );

      // BR 114
      test(
        'when the invite has no person then exactly one linked row is '
        'created for the acceptor',
        () async {
          final family = await fx.family(await fx.tree());
          final (invite: _, :token) = await fx.tokenInvite(family);
          final joiner = await fx.userWithEmail(
            uniqueEmail('lee'),
            displayName: 'Lee',
          );

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);
          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          final linked = await fx.linkedPeople(family.treeId, joiner);
          expect(linked, hasLength(1));
          expect(linked.single.name, 'Lee');
          expect(linked.single.homeFamilyId, family.id);
        },
      );

      // BR 114
      test(
        'when the acceptor is already linked elsewhere in the tree then no '
        'row is added',
        () async {
          final tree = await fx.tree();
          final parent = await fx.family(tree);
          final branch = await fx.family(
            tree,
            parentId: parent.id,
            branchYear: 1990,
          );
          final joiner = await fx.user();
          final own = await fx.person(parent, userId: joiner);
          final (invite: _, :token) = await fx.tokenInvite(branch);

          await endpoints.invite.accept(asUser(sessionBuilder, joiner), token);

          expect((await fx.linkedPeople(tree.id!, joiner)).single.id, own.id);
        },
      );

      test(
        'when a linked person for the acceptor commits mid-accept then the '
        'accept reruns once and reuses it',
        () async {
          final tree = await fx.tree();
          final family = await fx.family(tree);
          final (:invite, :token) = await fx.tokenInvite(family);
          final joiner = await fx.user();
          final release = await holdOpen(
            fx.s,
            (t) => Person.db.insertRow(
              fx.s,
              Person(
                treeId: tree.id!,
                homeFamilyId: family.id!,
                userId: joiner,
                name: 'Racer',
              ),
              transaction: t,
            ),
          );
          final accepting = endpoints.invite.accept(
            asUser(sessionBuilder, joiner),
            token,
          );
          await Future<void>.delayed(raceDelay);
          release();

          expect(await accepting, family.id);
          expect(
            (await fx.linkedPeople(tree.id!, joiner)).single.name,
            'Racer',
          );
          expect((await fx.reload(invite)).acceptedById, joiner);
          expect(await fx.membershipOf(family, joiner), isNotNull);
        },
      );
    });
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: the BR 113 tests fail (the invited person stays unlinked), and the race test fails with 23505 `people_tree_user_uidx`.

- [ ] **Step 3: Link the person, and rerun once on the race**

In `_accept`, replace the `ensureLinkedPerson(...)` call with:

```dart
    await _linkPerson(session, invite, family, uid, now, t);
```

Add after `_accept`:

```dart
  /// Links the invited person when it is still unlinked and the caller has
  /// no linked person in the tree; otherwise makes sure the caller has one.
  Future<void> _linkPerson(
    Session session,
    Invite invite,
    Family family,
    UuidValue uid,
    DateTime now,
    Transaction t,
  ) async {
    final personId = invite.personId;
    final target = personId == null
        ? null
        : await Person.db.findById(
            session,
            personId,
            transaction: t,
            lockMode: LockMode.forUpdate,
          );
    final alreadyLinked = await Person.db.findFirstRow(
      session,
      where: (p) => p.treeId.equals(family.treeId) & p.userId.equals(uid),
      transaction: t,
    );
    if (target != null && target.userId == null && alreadyLinked == null) {
      final appUser = await AppUser.db.findFirstRow(
        session,
        where: (u) => u.authUserId.equals(uid),
        transaction: t,
      );
      final displayName = appUser?.displayName?.trim() ?? '';
      await Person.db.updateRow(
        session,
        target.copyWith(
          userId: uid,
          name: displayName.isEmpty ? target.name : displayName,
          updatedAt: now,
        ),
        transaction: t,
      );
      return;
    }
    await ensureLinkedPerson(
      session,
      treeId: family.treeId,
      homeFamilyId: family.id!,
      userId: uid,
      transaction: t,
    );
  }
```

Replace `accept` with:

```dart
  /// Joins the invite's family and returns its id. Single transaction:
  /// membership, person link, invite marked accepted. A double-tapped accept
  /// that loses the linked-person race reruns once and finds the committed
  /// person.
  Future<UuidValue> accept(Session session, String token) async {
    final uid = Authz(session).requireUser();
    final trimmed = token.trim();
    if (trimmed.isEmpty) throw validation('token is required');
    final tokenHash = hashInviteToken(trimmed);
    try {
      return await _accept(session, uid, tokenHash);
    } on DatabaseQueryException catch (e) {
      if (e.code != '23505' || e.constraintName != 'people_tree_user_uidx') {
        rethrow;
      }
      return _accept(session, uid, tokenHash);
    }
  }
```

- [ ] **Step 4: Run the tests**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_endpoint.dart apps/server/test/integration/invite_endpoint_test.dart
git commit -m "feat(server): invite accept links the invited person and survives the linked-person race"
```

### Task 7: `InviteEndpoint.sendEmail` (BR 131)

**Files:**
- Modify: `apps/server/lib/src/endpoints/invite_endpoint.dart`
- Test: `apps/server/test/integration/invite_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

Insert this group inside `withServerpod`, directly before the closing `}, rollbackDatabase: RollbackDatabase.disabled);` line of `apps/server/test/integration/invite_endpoint_test.dart`:

```dart
    group('sendEmail', () {
      test(
        'when a member sends a pending emailed invite then the invite email '
        'goes out with the accept link',
        () async {
          final member = await fx.user();
          final family = await familyOf(member, name: 'Mortang');
          final created = await endpoints.invite.create(
            asUser(sessionBuilder, member),
            family.id!,
            email: 'Kim@Example.com',
          );

          await endpoints.invite.sendEmail(
            asUser(sessionBuilder, member),
            created.inviteId,
            created.token,
          );

          final sent = mail.sent.single;
          expect(sent.to, 'kim@example.com');
          expect(sent.subject, 'Invite to Mortang');
          expect(
            sent.text,
            "You're invited to join Mortang on Tell Me a Story.\n\n"
            'Accept the invite: ${created.inviteUrl}\n\n'
            'This link expires in 7 days and can only be used once.',
          );
          expect(sent.html, contains('<strong>Mortang</strong>'));
        },
      );

      test(
        'when the invite is unknown then NOT_FOUND "Invite not found"; a '
        'non-member gets FORBIDDEN "Not a family member"',
        () async {
          final family = await fx.family(await fx.tree());
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          final stranger = asUser(sessionBuilder, await fx.user());

          await expectLater(
            endpoints.invite.sendEmail(
              stranger,
              UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
              token,
            ),
            throwsAppError(AppErrorCode.notFound, 'Invite not found'),
          );
          await expectLater(
            endpoints.invite.sendEmail(stranger, invite.id!, token),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          expect(mail.sent, isEmpty);
        },
      );

      test(
        'when the token is not the invite token then INVITE_INVALID and no '
        'mail',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (invite: invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );

          await expectLater(
            endpoints.invite.sendEmail(
              asUser(sessionBuilder, member),
              invite.id!,
              newInviteToken(),
            ),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );
          expect(mail.sent, isEmpty);
        },
      );

      // BR 131
      test(
        'when the invite is not pending, expired or has no email then '
        'INVITE_INVALID / INVITE_EXPIRED / VALIDATION',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final session = asUser(sessionBuilder, member);
          final accepted = await fx.tokenInvite(
            family,
            acceptedById: await fx.user(),
          );
          final revoked = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            revoked: true,
          );
          final expired = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            expired: true,
          );
          final linkOnly = await fx.tokenInvite(family);

          for (final notPending in [accepted, revoked]) {
            await expectLater(
              endpoints.invite.sendEmail(
                session,
                notPending.invite.id!,
                notPending.token,
              ),
              throwsAppError(
                AppErrorCode.inviteInvalid,
                'Invite is not pending',
              ),
            );
          }
          await expectLater(
            endpoints.invite.sendEmail(
              session,
              expired.invite.id!,
              expired.token,
            ),
            throwsAppError(AppErrorCode.inviteExpired, 'Invite link expired'),
          );
          await expectLater(
            endpoints.invite.sendEmail(
              session,
              linkOnly.invite.id!,
              linkOnly.token,
            ),
            throwsAppError(
              AppErrorCode.validation,
              'Invite has no email address to send to',
            ),
          );
          expect(mail.sent, isEmpty);
        },
      );

      test(
        'when email is not configured then VALIDATION "Email is not '
        'configured"; when the provider fails then VALIDATION "Could not '
        'send invite email"',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          final session = asUser(sessionBuilder, member);

          mailTransportOverride = RecordingMailTransport(configured: false);
          await expectLater(
            endpoints.invite.sendEmail(session, invite.id!, token),
            throwsAppError(AppErrorCode.validation, 'Email is not configured'),
          );
          mailTransportOverride = RecordingMailTransport(fails: true);
          await expectLater(
            endpoints.invite.sendEmail(session, invite.id!, token),
            throwsAppError(
              AppErrorCode.validation,
              'Could not send invite email',
            ),
          );
        },
      );
    });
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: compile error, `endpoints.invite.sendEmail` doesn't exist.

- [ ] **Step 3: Implement `sendEmail`**

Insert after `_requireInvitablePerson`:

```dart
  /// Any live member emails a pending invite. [token] is the raw token from
  /// [create]: only its hash is stored, so the link can't be rebuilt without
  /// it.
  Future<void> sendEmail(
    Session session,
    UuidValue inviteId,
    String token,
  ) async {
    final invite = await Invite.db.findById(session, inviteId);
    if (invite == null) throw notFound('Invite not found');
    await Authz(
      session,
    ).requireLiveMember(invite.familyId, message: 'Not a family member');
    final trimmed = token.trim();
    if (!inviteTokenMatches(trimmed, invite.tokenHash)) throw inviteInvalid();
    if (invite.acceptedAt != null || invite.revokedAt != null) {
      throw inviteInvalid('Invite is not pending');
    }
    if (isInviteExpired(invite, DateTime.now().toUtc())) throw inviteExpired();
    final to = invite.email;
    if (to == null) throw validation('Invite has no email address to send to');
    final family = (await Family.db.findById(session, invite.familyId))!;
    await deliverInviteMail(
      session,
      inviteMail(
        to: to,
        familyName: family.name,
        inviteUrl: buildInviteUrl(inviteAppOrigin(session), trimmed),
      ),
    );
  }
```

Run: `mise exec -- just server-generate`, then `git diff --name-only packages | grep -v '/client.dart$' | xargs git checkout --`.

- [ ] **Step 4: Run the tests**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_endpoint.dart apps/server/lib/src/generated apps/server/test/integration packages/tell_me_a_story_client/lib/src/protocol/client.dart
git commit -m "feat(server): InviteEndpoint.sendEmail"
```

### Task 8: `InviteEndpoint.resend` (BR 127–129)

**Files:**
- Modify: `apps/server/lib/src/endpoints/invite_endpoint.dart`
- Test: `apps/server/test/integration/invite_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

Insert this group inside `withServerpod`, directly before the closing `}, rollbackDatabase: RollbackDatabase.disabled);` line of `apps/server/test/integration/invite_endpoint_test.dart`:

```dart
    group('resend', () {
      // BR 127
      test(
        'when a plain member resends then FORBIDDEN "owner or co-owner only"',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (:invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );

          await expectLater(
            endpoints.invite.resend(asUser(sessionBuilder, member), invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          expect((await fx.reload(invite)).tokenHash, invite.tokenHash);
          expect(mail.sent, isEmpty);
        },
      );

      test(
        'when the invite is unknown then NOT_FOUND "invite not found"',
        () async {
          await expectLater(
            endpoints.invite.resend(
              asUser(sessionBuilder, await fx.user()),
              UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
            ),
            throwsAppError(AppErrorCode.notFound, 'invite not found'),
          );
        },
      );

      // BR 128
      test(
        'when the invite is accepted or revoked then INVITE_INVALID "invite '
        'is not pending"; link-only then VALIDATION "invite has no email '
        'address"',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final session = asUser(sessionBuilder, owner);
          final accepted = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            acceptedById: await fx.user(),
          );
          final revoked = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            revoked: true,
          );
          final linkOnly = await fx.tokenInvite(family);

          for (final notPending in [accepted.invite, revoked.invite]) {
            await expectLater(
              endpoints.invite.resend(session, notPending.id!),
              throwsAppError(
                AppErrorCode.inviteInvalid,
                'invite is not pending',
              ),
            );
          }
          await expectLater(
            endpoints.invite.resend(session, linkOnly.invite.id!),
            throwsAppError(
              AppErrorCode.validation,
              'invite has no email address',
            ),
          );
          expect(mail.sent, isEmpty);
        },
      );

      // BR 129
      test(
        'when a co-owner resends an expired pending invite then the token '
        'rotates, expiresAt moves to now+7d, it stays pending and the email '
        'carries the new link',
        () async {
          final coOwner = await fx.user();
          final family = await familyOf(
            coOwner,
            role: MembershipRole.coOwner,
            name: 'Mortang',
          );
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
            expired: true,
          );
          final before = DateTime.now().toUtc();

          final expiresAt = await endpoints.invite.resend(
            asUser(sessionBuilder, coOwner),
            invite.id!,
          );

          final row = await fx.reload(invite);
          expect(row.tokenHash, isNot(invite.tokenHash));
          expect(row.expiresAt, expiresAt);
          expect(
            expiresAt.difference(before.add(inviteLifetime)).inSeconds.abs(),
            lessThan(5),
          );
          expect(row.lastSentAt.isAfter(invite.lastSentAt), isTrue);
          expect(row.acceptedAt, isNull);
          expect(row.revokedAt, isNull);

          final sent = mail.sent.single;
          expect(sent.to, 'kim@example.com');
          expect(sent.subject, 'Invite to Mortang');
          final newToken = RegExp(
            r'invite=([0-9a-f]{64})',
          ).firstMatch(sent.text)!.group(1)!;
          expect(hashInviteToken(newToken), row.tokenHash);
          expect(newToken, isNot(token));
        },
      );

      // BR 129
      test(
        'when email is not configured then VALIDATION "Email is not '
        'configured" before the token rotates',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final (:invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          mailTransportOverride = RecordingMailTransport(configured: false);

          await expectLater(
            endpoints.invite.resend(asUser(sessionBuilder, owner), invite.id!),
            throwsAppError(AppErrorCode.validation, 'Email is not configured'),
          );
          expect((await fx.reload(invite)).tokenHash, invite.tokenHash);
        },
      );

      // BR 129
      test(
        'when the provider fails then VALIDATION "Could not send invite '
        'email" and the token stays rotated',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final (:invite, token: _) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          mailTransportOverride = RecordingMailTransport(fails: true);

          await expectLater(
            endpoints.invite.resend(asUser(sessionBuilder, owner), invite.id!),
            throwsAppError(
              AppErrorCode.validation,
              'Could not send invite email',
            ),
          );
          expect((await fx.reload(invite)).tokenHash, isNot(invite.tokenHash));
        },
      );
    });
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: compile error, `endpoints.invite.resend` doesn't exist.

- [ ] **Step 3: Implement `resend`**

Append to `InviteEndpoint`:

```dart
  /// Owner or co-owner: rotates the token, moves `expiresAt` to now + 7 days
  /// (reviving an expired pending invite) and emails the new link. When the
  /// email fails the token stays rotated, so a retry is safe.
  Future<DateTime> resend(Session session, UuidValue inviteId) async {
    requireInviteMailConfigured(session);
    final authz = Authz(session);
    final origin = inviteAppOrigin(session);
    final (invite, token) = await session.db.transaction((t) async {
      final row = await Invite.db.findById(
        session,
        inviteId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (row == null) throw notFound('invite not found');
      await authz.requireLiveSteward(row.familyId);
      if (row.acceptedAt != null || row.revokedAt != null) {
        throw inviteInvalid('invite is not pending');
      }
      if (row.email == null) throw validation('invite has no email address');
      final token = newInviteToken();
      final now = DateTime.now().toUtc();
      final updated = await Invite.db.updateRow(
        session,
        row.copyWith(
          tokenHash: hashInviteToken(token),
          lastSentAt: now,
          expiresAt: now.add(inviteLifetime),
        ),
        transaction: t,
      );
      return (updated, token);
    });
    final family = (await Family.db.findById(session, invite.familyId))!;
    await deliverInviteMail(
      session,
      inviteMail(
        to: invite.email!,
        familyName: family.name,
        inviteUrl: buildInviteUrl(origin, token),
      ),
    );
    return invite.expiresAt;
  }
```

Run: `mise exec -- just server-generate`, then `git diff --name-only packages | grep -v '/client.dart$' | xargs git checkout --`.

- [ ] **Step 4: Run the tests**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_endpoint.dart apps/server/lib/src/generated apps/server/test/integration packages/tell_me_a_story_client/lib/src/protocol/client.dart
git commit -m "feat(server): InviteEndpoint.resend"
```

### Task 9: `InviteEndpoint.revoke` (BR 127, 130, 137)

**Files:**
- Modify: `apps/server/lib/src/endpoints/invite_endpoint.dart`
- Test: `apps/server/test/integration/invite_endpoint_test.dart`

- [ ] **Step 1: Write the failing tests**

Insert this group inside `withServerpod`, directly before the closing `}, rollbackDatabase: RollbackDatabase.disabled);` line of `apps/server/test/integration/invite_endpoint_test.dart`:

```dart
    group('revoke', () {
      // BR 127
      test(
        'when a plain member revokes then FORBIDDEN "owner or co-owner only"',
        () async {
          final member = await fx.user();
          final family = await familyOf(member);
          final (:invite, token: _) = await fx.tokenInvite(family);

          await expectLater(
            endpoints.invite.revoke(asUser(sessionBuilder, member), invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          expect((await fx.reload(invite)).revokedAt, isNull);
        },
      );

      test(
        'when the invite is unknown then NOT_FOUND "invite not found"',
        () async {
          await expectLater(
            endpoints.invite.revoke(
              asUser(sessionBuilder, await fx.user()),
              UuidValue.fromString('00000000-0000-4000-8000-000000000000'),
            ),
            throwsAppError(AppErrorCode.notFound, 'invite not found'),
          );
        },
      );

      // BR 130
      test(
        'when an owner revokes then the row is kept as revoked and accepting '
        'its token fails; revoking twice is a no-op; revoking an accepted '
        'invite is INVITE_INVALID',
        () async {
          final owner = await fx.user();
          final family = await familyOf(owner, role: MembershipRole.owner);
          final session = asUser(sessionBuilder, owner);
          final (:invite, :token) = await fx.tokenInvite(family);

          await endpoints.invite.revoke(session, invite.id!);
          final revoked = await fx.reload(invite);
          expect(revoked.revokedAt, isNotNull);
          expect(revoked.tokenHash, invite.tokenHash);
          await expectLater(
            endpoints.invite.accept(
              asUser(sessionBuilder, await fx.user()),
              token,
            ),
            throwsAppError(AppErrorCode.inviteInvalid, 'Invite is not valid'),
          );

          await endpoints.invite.revoke(session, invite.id!);
          expect((await fx.reload(invite)).revokedAt, revoked.revokedAt);

          final accepted = await fx.tokenInvite(
            family,
            acceptedById: await fx.user(),
          );
          await expectLater(
            endpoints.invite.revoke(session, accepted.invite.id!),
            throwsAppError(AppErrorCode.inviteInvalid, 'invite is not pending'),
          );
          expect((await fx.reload(accepted.invite)).revokedAt, isNull);
        },
      );

      // BR 137 (invite part)
      test(
        'Given a soft-deleted family, when its member sends or its owner '
        'resends or revokes one of its invites then FORBIDDEN and nothing '
        'changes',
        () async {
          final owner = await fx.user();
          final family = await familyOf(
            owner,
            role: MembershipRole.owner,
            deletedAt: DateTime.now().toUtc(),
          );
          final (:invite, :token) = await fx.tokenInvite(
            family,
            email: 'kim@example.com',
          );
          final session = asUser(sessionBuilder, owner);

          await expectLater(
            endpoints.invite.sendEmail(session, invite.id!, token),
            throwsAppError(AppErrorCode.forbidden, 'Not a family member'),
          );
          await expectLater(
            endpoints.invite.resend(session, invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          await expectLater(
            endpoints.invite.revoke(session, invite.id!),
            throwsAppError(AppErrorCode.forbidden, 'owner or co-owner only'),
          );
          final row = await fx.reload(invite);
          expect(row.tokenHash, invite.tokenHash);
          expect(row.revokedAt, isNull);
          expect(mail.sent, isEmpty);
        },
      );
    });
```

- [ ] **Step 2: Run it and see it fail**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: compile error, `endpoints.invite.revoke` doesn't exist.

- [ ] **Step 3: Implement `revoke`**

Append to `InviteEndpoint`:

```dart
  /// Owner or co-owner. The row and its token hash stay, so accepting that
  /// token later fails INVITE_INVALID. Revoking twice is a no-op.
  Future<void> revoke(Session session, UuidValue inviteId) async {
    final authz = Authz(session);
    await session.db.transaction((t) async {
      final row = await Invite.db.findById(
        session,
        inviteId,
        transaction: t,
        lockMode: LockMode.forUpdate,
      );
      if (row == null) throw notFound('invite not found');
      await authz.requireLiveSteward(row.familyId);
      if (row.acceptedAt != null) throw inviteInvalid('invite is not pending');
      if (row.revokedAt != null) return;
      await Invite.db.updateRow(
        session,
        row.copyWith(revokedAt: DateTime.now().toUtc()),
        transaction: t,
      );
    });
  }
```

Run: `mise exec -- just server-generate`, then `git diff --name-only packages | grep -v '/client.dart$' | xargs git checkout --`.

- [ ] **Step 4: Run the tests**

Run: `cd apps/server && mise exec -- dart test test/integration/invite_endpoint_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add apps/server/lib/src/endpoints/invite_endpoint.dart apps/server/lib/src/generated apps/server/test/integration packages/tell_me_a_story_client/lib/src/protocol/client.dart
git commit -m "feat(server): InviteEndpoint.revoke"
```

### Task 10: Gate

- [ ] **Step 1: Format, analyze, test**

```bash
mise exec -- dart format --output=none --set-exit-if-changed apps/server/lib apps/server/test
(cd apps/server && mise exec -- dart analyze lib test)
(cd packages/tell_me_a_story_client && mise exec -- dart analyze)
mise exec -- just server-test
```

Expected: `0 changed`, `No issues found!` twice, and all tests pass (100 from 3.0 plus 52 here: 3 mailer, 5 unit, 40 `InviteEndpoint`, 4 `InvitePublicEndpoint`).

- [ ] **Step 2: Self-review against the index row**

- Every Port case is in the §7 coverage table.
- Owns: `InviteEndpoint`, `InvitePublicEndpoint` and invite email delivery.
- Nothing else: no `lib/server.dart`, no model or migration changes, no live events.
