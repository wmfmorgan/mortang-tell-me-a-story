/// Compile-time env from `--dart-define`. Never commit secrets.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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
