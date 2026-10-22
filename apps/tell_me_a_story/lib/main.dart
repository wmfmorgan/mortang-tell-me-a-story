import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/navigation/before_unload.dart';
import 'core/router/app_router.dart';
import 'core/router/auth_refresh.dart';
import 'core/router/url_strategy_stub.dart'
    if (dart.library.html) 'core/router/url_strategy_web.dart';
import 'core/supabase/supabase_init.dart';
import 'data/families_api.dart';
import 'data/invite_api.dart';
import 'data/people_api.dart';
import 'data/profile_api.dart';
import 'data/profile_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  installBeforeUnloadGuard();
  await initSupabase();

  final profileApi = ProfileApi();
  ProfileSession.loadOwn = profileApi.loadOwn;
  ProfileSession.downloadAvatar = profileApi.downloadAvatar;

  final authRefresh = AuthRefresh(
    authStateChanges: Supabase.instance.client.auth.onAuthStateChange,
    initiallySignedIn: Supabase.instance.client.auth.currentSession != null,
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
