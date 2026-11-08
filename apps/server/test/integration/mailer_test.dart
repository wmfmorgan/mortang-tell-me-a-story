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
