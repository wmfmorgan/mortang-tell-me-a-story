/// Local Auth `site_url` pinned for Flutter web (see `supabase/config.toml`).
const kLocalAuthSiteUrl = 'http://127.0.0.1:3000';

/// Redirect target for magic-link emails.
///
/// Uses the current page origin when running in a browser (`http`/`https`) so
/// the verify step returns to the Flutter web app. Falls back to
/// [kLocalAuthSiteUrl] for non-http schemes (tests / native shells).
String magicLinkEmailRedirectTo({Uri? baseUri}) {
  final uri = baseUri ?? Uri.base;
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return uri.origin;
  }
  return kLocalAuthSiteUrl;
}
