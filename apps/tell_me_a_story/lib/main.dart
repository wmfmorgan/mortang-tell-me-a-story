import 'package:flutter/material.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'package:tell_me_a_story/app/app.dart';
import 'package:tell_me_a_story/core/config/env.dart';
import 'package:tell_me_a_story/ui/navigation/before_unload.dart';
import 'package:tell_me_a_story/app/app_router.dart';
import 'package:tell_me_a_story/data/auth_refresh.dart';
import 'package:tell_me_a_story/app/url_strategy_stub.dart'
    if (dart.library.html) 'package:tell_me_a_story/app/url_strategy_web.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/profile_api.dart';
import 'package:tell_me_a_story/data/profile_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  installBeforeUnloadGuard();
  Env.validate();
  // An unreadable saved session starts the app signed out.
  await initServer(storage: appAuthStorage());

  final profileApi = ProfileApi();
  ProfileSession.loadOwn = profileApi.loadOwn;
  ProfileSession.downloadAvatar = profileApi.downloadAvatar;

  final authRefresh = AuthRefresh(
    authInfo: serverClient.auth.authInfoListenable,
  );

  runApp(
    TellMeAStoryApp(
      router: createAppRouter(
        authRefresh: authRefresh,
        familiesApi: FamiliesApi(),
        inviteApi: InviteApi(),
        peopleApi: PeopleApi(),
      ),
    ),
  );
}
