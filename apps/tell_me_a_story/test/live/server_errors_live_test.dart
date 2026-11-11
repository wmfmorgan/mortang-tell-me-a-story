@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'support/live_server.dart';

Matcher clientError(AppErrorCode code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  setUpAll(waitForLiveServer);

  test('a server refusal reaches the client as the client error', () async {
    await signInLive(freshEmail('refused'));

    await expectLater(
      withServerErrors(
        () => serverClient.family.rename(
          server.UuidValue.fromString('0190d7a0-0000-7000-8000-000000000000'),
          'X',
        ),
      ),
      clientError(AppErrorCode.forbidden),
    );
  });

  test('after sign-out a signed-in call is unauthenticated', () async {
    await signInLive(freshEmail('signed-out'));
    await serverClient.auth.signOutDevice();

    await expectLater(
      withServerErrors(() => serverClient.profile.me()),
      clientError(AppErrorCode.unauthenticated),
    );
  });
}
