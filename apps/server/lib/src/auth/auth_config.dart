import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';
import 'login_code_sender.dart';

/// Fixed one-time login code used in the development and test run modes.
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
