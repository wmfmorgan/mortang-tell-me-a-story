import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed-in auth uid, or null when Supabase is not initialized (widget tests).
///
/// Boundary: [Supabase.instance] asserts before [Supabase.initialize]; tests
/// omit init and expect null here.
String? readAuthUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (e) {
    return null;
  }
}

/// GoTrue client when initialized; null in widget tests without init.
GoTrueClient? readGoTrueClient() {
  try {
    return Supabase.instance.client.auth;
  } catch (e) {
    return null;
  }
}

/// Anon client when initialized; null in widget tests without init.
SupabaseClient? readSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (e) {
    return null;
  }
}
