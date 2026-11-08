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
