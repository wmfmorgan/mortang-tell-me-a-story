import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'otp_sign_in.g.dart';

const signInRequestFailed = 'Request failed';
const invalidEmailMessage = 'Please enter a full email address.';

/// Email-code sign-in. Tests inject this instead of the server.
abstract class OtpSignIn {
  /// Emails a 6-digit code to [email]. Returns the request id [signIn] needs.
  Future<String> sendCode(String email);

  /// Signs in with the [code] sent for [requestId]. An email without an
  /// account gets one. On success the auth session changes, and
  /// `AuthRefresh` moves the router on.
  Future<void> signIn({required String requestId, required String code});
}

@Riverpod(keepAlive: true)
OtpSignIn otpSignIn(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
