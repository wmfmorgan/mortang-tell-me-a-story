@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/features/auth/otp_sign_in.dart';

import 'support/live_server.dart';

void main() {
  setUpAll(waitForLiveServer);
  tearDown(() => serverClientForTesting = null);

  test(
    'ServerOtpSignIn signs in with the dev code and AppSession sees the user',
    () async {
      final client = await initServer(
        url: liveServerUrl,
        storage: MemoryAuthStorage(),
      );
      final otp = ServerOtpSignIn();
      final email = freshEmail('otp');

      // A new email registers.
      await otp.signIn(requestId: await otp.sendCode(email), code: devLoginCode);
      final userId = client.auth.authInfo?.authUserId.toString();
      expect(userId, isNotNull);
      expect(AppSession.instance.currentUserId, userId);

      // The same email signs in to the existing account.
      await AppSession.instance.signOut();
      expect(AppSession.instance.currentUserId, isNull);
      await otp.signIn(requestId: await otp.sendCode(email), code: devLoginCode);
      expect(AppSession.instance.currentUserId, userId);
    },
  );

  test('a wrong code is reported with the wrong-code copy', () async {
    final client = await initServer(
      url: liveServerUrl,
      storage: MemoryAuthStorage(),
    );
    final otp = ServerOtpSignIn(client: client);
    final requestId = await otp.sendCode(freshEmail('wrong'));

    Object? error;
    try {
      await otp.signIn(requestId: requestId, code: '000000');
    } catch (e) {
      error = e;
    }

    expect(error, isNotNull);
    expect(signInErrorMessage(error!), signInCodeWrong);
    expect(client.auth.authInfo, isNull);
  });
}
