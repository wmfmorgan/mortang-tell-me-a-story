import 'package:flutter/material.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/navigation/before_unload.dart';
import 'core/router/app_router.dart';
import 'core/router/auth_refresh.dart';
import 'core/router/url_strategy_stub.dart'
    if (dart.library.html) 'core/router/url_strategy_web.dart';
import 'core/server/app_session.dart';
import 'core/server/server_client.dart';
import 'data/families_api.dart';
import 'data/invite_api.dart';
import 'data/people_api.dart';
import 'data/profile_api.dart';
import 'data/profile_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  installBeforeUnloadGuard();
  Env.validate();
  // An unreadable saved session starts the app signed out.
  await initServer(
    storage: SessionRecoveringStorage(SecureClientAuthSuccessStorage()),
  );

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
