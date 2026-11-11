import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    show EmailAccountRequestException, EmailAccountRequestExceptionReason;
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';

const signInCodeWrong = "That code isn't right. Check it and try again.";
const signInCodeExpired = 'That code has expired. Send a new one.';
const signInTooManyTries =
    'Too many tries. Wait a few minutes, then send a new code.';
const signInRequestFailed = 'Request failed';

/// [OtpSignIn] over the server's `emailIdp` endpoint.
class ServerOtpSignIn implements OtpSignIn {
  ServerOtpSignIn({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<String> sendCode(String email) async {
    final requestId = await withServerErrors(
      () => _client.emailIdp.startOtpLogin(email: email),
    );
    return requestId.toString();
  }

  @override
  Future<void> signIn({required String requestId, required String code}) async {
    final client = _client;
    final idp = client.emailIdp;
    final verified = await withServerErrors(
      () => idp.verifyOtpLoginCode(
        otpLoginRequestId: server.UuidValue.fromString(requestId),
        verificationCode: code,
      ),
    );
    final auth = await withServerErrors(
      () => verified.accountExists
          ? idp.finishOtpLogin(otpLoginToken: verified.token)
          : idp.finishOtpRegistration(otpLoginToken: verified.token),
    );
    await client.auth.updateSignedInUser(auth);
  }
}

/// The approved copy for a failed send or sign-in.
String signInErrorMessage(Object error) => switch (error) {
  EmailAccountRequestException(
    reason: EmailAccountRequestExceptionReason.invalid,
  ) =>
    signInCodeWrong,
  EmailAccountRequestException(
    reason: EmailAccountRequestExceptionReason.expired,
  ) =>
    signInCodeExpired,
  EmailAccountRequestException(
    reason: EmailAccountRequestExceptionReason.tooManyAttempts,
  ) =>
    signInTooManyTries,
  _ => signInRequestFailed,
};
