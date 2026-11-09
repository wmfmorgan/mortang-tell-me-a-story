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
