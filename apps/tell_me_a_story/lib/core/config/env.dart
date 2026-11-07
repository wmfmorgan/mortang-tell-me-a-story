/// Compile-time env from `--dart-define`. Never commit secrets.
class Env {
  const Env._();

  /// Serverpod API server, e.g. `http://127.0.0.1:8080`.
  static const serverUrl = String.fromEnvironment('SERVER_URL');

  /// Shareable app origin for invite links. Staging MS: change define only.
  static const inviteAppOrigin = String.fromEnvironment(
    'INVITE_APP_ORIGIN',
    defaultValue: 'http://127.0.0.1:3000',
  );

  /// Public Mapbox token for geocode + basemap. OPEN (Bill) until provided.
  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  /// Soft gate: missing/placeholder token → map failure UX, not startup crash.
  static bool get hasMapboxToken => isPlausibleMapboxToken(mapboxAccessToken);

  /// Rejects empty / README placeholders; public tokens are long.
  static bool isPlausibleMapboxToken(String value) {
    if (value.isEmpty || value == '...' || value.startsWith('<')) return false;
    return value.length >= 20;
  }

  /// Fails closed when SERVER_URL is missing or clearly invalid.
  /// Does not require MAPBOX_ACCESS_TOKEN (soft — place picker failure UX).
  static void validate() => validateServerUrl(serverUrl);

  /// Throws [StateError] unless [value] is an absolute http(s) URL.
  static void validateServerUrl(String value) {
    if (value.isEmpty) {
      throw StateError(
        'Missing required --dart-define value: SERVER_URL '
        '(e.g. http://127.0.0.1:8080).',
      );
    }
    if (!isAbsoluteHttpUrl(value)) {
      throw StateError(
        'Invalid SERVER_URL="$value". Use the absolute server URL, '
        'e.g. http://127.0.0.1:8080.',
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
