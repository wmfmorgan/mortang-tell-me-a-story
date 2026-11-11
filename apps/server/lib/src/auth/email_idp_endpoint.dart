import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../errors.dart';

/// The email identity provider endpoint. Only passwordless sign-in with
/// one-time codes (and [hasAccount]) works.
///
/// The inherited password methods (login, registration and password reset)
/// always refuse with `forbidden`. They stay generated because the client's
/// `EndpointEmailOtpIdpBase` declares them abstract.
class EmailIdpEndpoint extends EmailOtpIdpBaseEndpoint {
  @override
  Future<AuthSuccess> login(
    Session session, {
    required String email,
    required String password,
  }) => throw forbidden();

  @override
  Future<UuidValue> startRegistration(
    Session session, {
    required String email,
  }) => throw forbidden();

  @override
  Future<String> verifyRegistrationCode(
    Session session, {
    required UuidValue accountRequestId,
    required String verificationCode,
  }) => throw forbidden();

  @override
  Future<AuthSuccess> finishRegistration(
    Session session, {
    required String registrationToken,
    required String password,
  }) => throw forbidden();

  @override
  Future<UuidValue> startPasswordReset(
    Session session, {
    required String email,
  }) => throw forbidden();

  @override
  Future<String> verifyPasswordResetCode(
    Session session, {
    required UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => throw forbidden();

  @override
  Future<void> finishPasswordReset(
    Session session, {
    required String finishPasswordResetToken,
    required String newPassword,
  }) => throw forbidden();
}
