import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'auth_callback.dart';
import 'browser_url_stub.dart'
    if (dart.library.html) 'browser_url_web.dart';

/// Initializes the Supabase anon client. Never uses the service role key.
Future<void> initSupabase() async {
  Env.validate();

  // Handle auth redirects ourselves so expired magic-link error URLs do not
  // surface as uncaught exceptions (supabase_flutter detectSessionInUri).
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      detectSessionInUri: false,
    ),
  );

  await recoverSessionFromAuthCallback(Uri.base);
}

/// Exchange a magic-link/OAuth callback when present; ignore stale/expired links.
Future<void> recoverSessionFromAuthCallback(Uri uri) async {
  if (!isAuthCallbackUri(uri)) return;

  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  } on AuthException {
    // e.g. error=access_denied&error_code=otp_expired after an old Mailpit click
  } finally {
    replaceBrowserUrl(uriWithoutAuthParams(uri));
  }
}
