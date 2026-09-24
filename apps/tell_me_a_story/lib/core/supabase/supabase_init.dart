import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initializes the Supabase anon client. Never uses the service role key.
Future<void> initSupabase() async {
  Env.validate();
  // M1 lock: anon key via SUPABASE_ANON_KEY (not service role).
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: Env.supabaseAnonKey,
  );
}
