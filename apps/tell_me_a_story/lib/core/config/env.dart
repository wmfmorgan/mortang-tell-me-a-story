/// Compile-time env from `--dart-define`. Never commit secrets.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Shareable app origin for invite links. Staging MS: change define only.
  static const inviteAppOrigin = String.fromEnvironment(
    'INVITE_APP_ORIGIN',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Fails closed when required dart-defines are missing or clearly invalid.
  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing required --dart-define values: '
        'SUPABASE_URL and SUPABASE_ANON_KEY (anon key only).',
      );
    }
    if (!isAbsoluteHttpUrl(supabaseUrl)) {
      throw StateError(
        'Invalid SUPABASE_URL="$supabaseUrl". '
        'Use the absolute API URL from `supabase status` '
        '(e.g. http://127.0.0.1:57321), not "..." or the Flutter web port.',
      );
    }
    if (supabaseAnonKey == '...' ||
        supabaseAnonKey.startsWith('<') ||
        supabaseAnonKey.length < 20) {
      throw StateError(
        'Invalid SUPABASE_ANON_KEY. Copy ANON_KEY from '
        '`supabase status -o env` (do not use README placeholders).',
      );
    }
  }

  /// Absolute http(s) URL check (rejects relative "..." which resolves to :3000).
  static bool isAbsoluteHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }
}
