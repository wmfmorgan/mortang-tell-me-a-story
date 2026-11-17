// ignore_for_file: avoid_catches_without_on_clauses

import 'package:supabase_flutter/supabase_flutter.dart';

/// Signed-in auth uid, or null when Supabase is not initialized (widget tests).
///
/// §7.2 exception: Supabase throws AssertionError before initialize; return null.
String? readAuthUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
}

/// GoTrue client when initialized; null in widget tests without init.
GoTrueClient? readGoTrueClient() {
  try {
    return Supabase.instance.client.auth;
  } catch (_) {
    return null;
  }
}

/// Anon client when initialized; null in widget tests without init.
SupabaseClient? readSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
