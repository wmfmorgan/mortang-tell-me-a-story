import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';
import 'login_code_sender.dart';

/// Fixed one-time login code used by local servers (see `isLocalPod`).
const devLoginCode = '111111';

/// Registers JWT sessions and passwordless email-code login, and creates the
/// app's `users` row whenever an auth user is created.
///
/// Called from `run` before the server starts, and from test `setUpAll`
/// because `withServerpod` does not execute `run`.
void configureAuth({required bool useDevLoginCode}) {
  AuthServices.set(
    tokenManagerBuilders: [JwtConfigFromPasswords()],
    identityProviderBuilders: [
      EmailIdpConfigFromPasswords(
        sendOtpLoginVerificationCode: sendLoginCode,
        otpLoginVerificationCodeGenerator: useDevLoginCode
            ? () => devLoginCode
            : defaultOtpVerificationCodeGenerator,
      ),
    ],
    authUsersConfig: const AuthUsersConfig(
      onAfterAuthUserCreated: _createAppUser,
    ),
  );
}

/// Makes [pod] check request tokens with the auth services [configureAuth]
/// set up. Without it Serverpod keeps its default handler, which throws
/// `UnimplementedError`, so every signed-in call fails with HTTP 500. Call
/// before `pod.start()`; the server reads the handler when it starts.
void installAuthenticationHandler(Serverpod pod) {
  pod.authenticationHandler = AuthServices.instance.authenticationHandler;
}

Future<void> _createAppUser(
  Session session,
  AuthUserModel authUser, {
  required Transaction transaction,
}) async {
  await AppUser.db.insertRow(
    session,
    AppUser(authUserId: authUser.id),
    transaction: transaction,
  );
}
