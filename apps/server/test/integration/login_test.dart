import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
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

    test(
      'when the server handler is installed then a login token authenticates '
      'its user (without it Serverpod rejects every signed-in call)',
      () async {
        final requestId = await endpoints.emailIdp.startOtpLogin(
          sessionBuilder,
          email: 'cy@example.com',
        );
        final result = await endpoints.emailIdp.verifyOtpLoginCode(
          sessionBuilder,
          otpLoginRequestId: requestId,
          verificationCode: devLoginCode,
        );
        final auth = await endpoints.emailIdp.finishOtpRegistration(
          sessionBuilder,
          otpLoginToken: result.token,
        );
        final session = sessionBuilder.build();
        final pod = session.serverpod;

        installAuthenticationHandler(pod);
        final info = await pod.authenticationHandler!(session, auth.token);

        expect(info?.authUserId, auth.authUserId);
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

    test('when a password method is called then it is forbidden', () async {
      final forbidden = throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.forbidden,
        ),
      );
      final idp = endpoints.emailIdp;
      final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');

      await expectLater(
        idp.login(sessionBuilder, email: 'ana@example.com', password: 'x'),
        forbidden,
      );
      await expectLater(
        idp.startRegistration(sessionBuilder, email: 'ana@example.com'),
        forbidden,
      );
      await expectLater(
        idp.verifyRegistrationCode(
          sessionBuilder,
          accountRequestId: id,
          verificationCode: '111111',
        ),
        forbidden,
      );
      await expectLater(
        idp.finishRegistration(
          sessionBuilder,
          registrationToken: 't',
          password: 'x',
        ),
        forbidden,
      );
      await expectLater(
        idp.startPasswordReset(sessionBuilder, email: 'ana@example.com'),
        forbidden,
      );
      await expectLater(
        idp.verifyPasswordResetCode(
          sessionBuilder,
          passwordResetRequestId: id,
          verificationCode: '111111',
        ),
        forbidden,
      );
      await expectLater(
        idp.finishPasswordReset(
          sessionBuilder,
          finishPasswordResetToken: 't',
          newPassword: 'x',
        ),
        forbidden,
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
