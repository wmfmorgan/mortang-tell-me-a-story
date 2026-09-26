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

  /// Fails closed when required dart-defines are missing.
  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing required --dart-define values: '
        'SUPABASE_URL and SUPABASE_ANON_KEY (anon key only).',
      );
    }
  }
}
