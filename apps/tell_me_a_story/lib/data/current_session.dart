import 'package:supabase_flutter/supabase_flutter.dart' show GoTrueClient;

import '../core/supabase/auth_user_id.dart';
import 'families_api.dart';

/// Signed-in user for feature code.
///
/// Null [userId] is signed out, including widget tests before Supabase starts.
/// Reads go through `readAuthUserId` so the §7.2 catch stays in one file.
class CurrentSession {
  const CurrentSession._();

  static String? get userId => readAuthUserId();

  static bool get isSignedIn => userId != null;

  /// Auth client for magic-link send. Null before Supabase starts.
  static GoTrueClient? get auth => readGoTrueClient();

  static String requireUserId() {
    final id = userId;
    if (id == null) throw const NotSignedInException();
    return id;
  }
}
