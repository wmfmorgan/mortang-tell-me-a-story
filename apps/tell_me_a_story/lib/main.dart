import 'package:flutter/material.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/env.dart';
import 'package:tell_me_a_story/core/widgets/navigation/before_unload.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/session/auth_refresh.dart';
import 'package:tell_me_a_story/core/router/url_strategy_stub.dart'
    if (dart.library.html) 'package:tell_me_a_story/core/router/url_strategy_web.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/data/invite_repository.dart';
import 'package:tell_me_a_story/core/data/people_repository.dart';
import 'package:tell_me_a_story/core/data/profile_repository.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  installBeforeUnloadGuard();
  Env.validate();
  // An unreadable saved session starts the app signed out.
  await initServer(storage: appAuthStorage());

  final profileApi = ServerProfileRepository();
  ProfileSession.loadOwn = profileApi.loadOwn;
  ProfileSession.downloadAvatar = profileApi.downloadAvatar;

  final authRefresh = AuthRefresh(
    authInfo: serverClient.auth.authInfoListenable,
  );

  runApp(
    TellMeAStoryApp(
      router: createAppRouter(
        authRefresh: authRefresh,
        familiesApi: ServerFamiliesRepository(),
        inviteApi: ServerInviteRepository(),
        peopleApi: ServerPeopleRepository(),
      ),
    ),
  );
}
