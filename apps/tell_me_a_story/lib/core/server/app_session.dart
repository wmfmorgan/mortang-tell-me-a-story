import 'package:supabase_flutter/supabase_flutter.dart';

/// Who is signed in, for code outside `lib/data`.
///
/// Widgets that take a `currentUserId` / `signedInUserId` / `onLogout`
/// argument still prefer it; this is the fallback. The Serverpod cutover swaps
/// [instance] for a `client.auth`-backed session.
abstract class AppSession {
  const AppSession();

  /// App-wide session. Tests replace it and restore
  /// `const SupabaseAppSession()` in tearDown.
  static AppSession instance = const SupabaseAppSession();

  /// Signed-in user id, or null when signed out or auth has not started.
  String? get currentUserId;

  Future<void> signOut();
}

/// [AppSession] over Supabase auth.
class SupabaseAppSession extends AppSession {
  const SupabaseAppSession();

  @override
  String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase is not initialized (widget tests).
      return null;
    }
  }

  @override
  Future<void> signOut() => Supabase.instance.client.auth.signOut();
}
