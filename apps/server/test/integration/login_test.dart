import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given email one-time-code login', (sessionBuilder, endpoints) {
    test(
      'when a new email verifies the dev code then an account is created',
      () async {
        final requestId = await endpoints.emailIdp.startOtpLogin(
          sessionBuilder,
          email: 'ana@example.com',
        );
        final result = await endpoints.emailIdp.verifyOtpLoginCode(
          sessionBuilder,
          otpLoginRequestId: requestId,
          verificationCode: devLoginCode,
        );
        expect(result.accountExists, isFalse);

        final auth = await endpoints.emailIdp.finishOtpRegistration(
          sessionBuilder,
          otpLoginToken: result.token,
        );
        final appUser = await AppUser.db.findFirstRow(
          sessionBuilder.build(),
          where: (t) => t.authUserId.equals(auth.authUserId),
        );
        expect(appUser, isNotNull);
      },
    );

    test('when the wrong code is entered then verification fails', () async {
      final requestId = await endpoints.emailIdp.startOtpLogin(
        sessionBuilder,
        email: 'ben@example.com',
      );
      await expectLater(
        endpoints.emailIdp.verifyOtpLoginCode(
          sessionBuilder,
          otpLoginRequestId: requestId,
          verificationCode: '000000',
        ),
        throwsA(
          isA<EmailAccountRequestException>().having(
            (e) => e.reason,
            'reason',
            EmailAccountRequestExceptionReason.invalid,
          ),
        ),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
