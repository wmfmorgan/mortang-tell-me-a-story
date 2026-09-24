import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'core/router/auth_refresh.dart';
import 'core/supabase/supabase_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();

  final authRefresh = AuthRefresh(
    authStateChanges: Supabase.instance.client.auth.onAuthStateChange,
    initiallySignedIn: Supabase.instance.client.auth.currentSession != null,
  );

  runApp(
    TellMeAStoryApp(
      router: createAppRouter(authRefresh: authRefresh),
    ),
  );
}
