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
