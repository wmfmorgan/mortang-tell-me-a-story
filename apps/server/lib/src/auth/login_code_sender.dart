import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import 'local_mode.dart';

/// Delivers a one-time login code.
///
/// Local (development or test with embedded Postgres, see [isLocalPod]):
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
  if (isLocalPod(session.serverpod)) {
    session.log('Login code for $email: $verificationCode');
    return;
  }

  final apiKey = session.passwords['resendApiKey'];
  final from = session.passwords['resendFrom'];
  if (apiKey == null || from == null) {
    throw StateError('resendApiKey and resendFrom must be set in passwords');
  }

  final response = await http.post(
    Uri.parse('https://api.resend.com/emails'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'from': from,
      'to': [email],
      'subject': 'Your Tell Me a Story sign-in code',
      'text': 'Your sign-in code is $verificationCode. It expires soon.',
    }),
  );
  if (response.statusCode >= 300) {
    session.log(
      'Resend rejected login email: ${response.statusCode} ${response.body}',
      level: LogLevel.error,
    );
    throw StateError('Login email could not be sent');
  }
}
