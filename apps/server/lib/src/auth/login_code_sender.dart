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
