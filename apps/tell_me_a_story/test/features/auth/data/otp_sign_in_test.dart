import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    show EmailAccountRequestException, EmailAccountRequestExceptionReason;
import 'package:tell_me_a_story/features/auth/data/otp_sign_in.dart';

void main() {
  EmailAccountRequestException refusal(EmailAccountRequestExceptionReason r) =>
      EmailAccountRequestException(reason: r);

  test('sign-in errors map to the approved copy', () {
    expect(
      signInErrorMessage(refusal(EmailAccountRequestExceptionReason.invalid)),
      "That code isn't right. Check it and try again.",
    );
    expect(
      signInErrorMessage(refusal(EmailAccountRequestExceptionReason.expired)),
      'That code has expired. Send a new one.',
    );
    expect(
      signInErrorMessage(
        refusal(EmailAccountRequestExceptionReason.tooManyAttempts),
      ),
      'Too many tries. Wait a few minutes, then send a new code.',
    );
    expect(
      signInErrorMessage(
        refusal(EmailAccountRequestExceptionReason.policyViolation),
      ),
      'Request failed',
    );
    expect(signInErrorMessage(Exception('offline')), 'Request failed');
  });
}
