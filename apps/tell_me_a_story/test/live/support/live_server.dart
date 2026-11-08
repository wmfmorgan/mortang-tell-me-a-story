import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart';

/// The server live tests talk to: `just server` on :8080 unless
/// `--dart-define=LIVE_SERVER_URL=...` says otherwise. Live tests are tagged
/// `live`; plain `flutter test` skips them and `just test-live` runs them.
const liveServerUrl = String.fromEnvironment(
  'LIVE_SERVER_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

/// The fixed code a local `just server` accepts (apps/server auth_config.dart).
const devLoginCode = '111111';

/// Keeps the session in memory so live tests never touch the keychain.
class MemoryAuthStorage implements ClientAuthSuccessStorage {
  AuthSuccess? _value;

  @override
  Future<AuthSuccess?> get() async => _value;

  @override
  Future<void> set(AuthSuccess? data) async => _value = data;
}

var _counter = 0;

/// A fresh email no earlier run has used, e.g. `live-<run>-<n>-<label>@example.test`.
String freshEmail(String label) =>
    'live-${DateTime.now().microsecondsSinceEpoch}-${_counter++}-'
    '$label@example.test';

/// Waits until the live server answers (its port opens before it serves).
/// Call from `setUpAll`. Fails after [timeout] with the last error.
Future<void> waitForLiveServer({
  Duration timeout = const Duration(seconds: 30),
}) async {
  final probe = Client(serverHost(liveServerUrl));
  final deadline = DateTime.now().add(timeout);
  while (true) {
    try {
      await probe.invitePublic.preview('ready-check');
      return;
    } on ServerpodClientException {
      if (DateTime.now().isAfter(deadline)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

/// Signs [email] up or in with the dev code and makes the result the app's
/// [serverClient], so default-constructed gateways act as that user.
Future<Client> signInLive(String email) async {
  final client = await initServer(
    url: liveServerUrl,
    storage: MemoryAuthStorage(),
  );
  final requestId = await client.emailIdp.startOtpLogin(email: email);
  final verified = await client.emailIdp.verifyOtpLoginCode(
    otpLoginRequestId: requestId,
    verificationCode: devLoginCode,
  );
  final auth = verified.accountExists
      ? await client.emailIdp.finishOtpLogin(otpLoginToken: verified.token)
      : await client.emailIdp.finishOtpRegistration(
          otpLoginToken: verified.token,
        );
  await client.auth.updateSignedInUser(auth);
  return client;
}
