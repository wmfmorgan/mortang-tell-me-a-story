import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    show EmailAccountRequestException, EmailAccountRequestExceptionReason;
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';

const signInCodeWrong = "That code isn't right. Check it and try again.";
const signInCodeExpired = 'That code has expired. Send a new one.';
const signInTooManyTries =
    'Too many tries. Wait a few minutes, then send a new code.';

/// [OtpSignIn] over the server's `emailIdp` endpoint. Every failure
/// surfaces as an [AppException] whose message is [signInErrorMessage].
class ServerOtpSignIn implements OtpSignIn {
  ServerOtpSignIn({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<String> sendCode(String email) => _signInErrors(() async {
    final requestId = await withServerErrors(
      () => _client.emailIdp.startOtpLogin(email: email),
    );
    return requestId.toString();
  });

  @override
  Future<void> signIn({required String requestId, required String code}) =>
      _signInErrors(() async {
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
      });
}

/// Boundary: maps any failure of [call] to an [AppException] carrying the
/// approved sign-in copy, and rethrows it.
Future<T> _signInErrors<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error) {
    throw AppException(
      code: error is AppException ? error.code : AppErrorCode.validation,
      message: signInErrorMessage(error),
    );
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
  EmailAccountRequestException(
    reason: EmailAccountRequestExceptionReason.policyViolation,
  ) =>
    invalidEmailMessage,
  _ => signInRequestFailed,
};
