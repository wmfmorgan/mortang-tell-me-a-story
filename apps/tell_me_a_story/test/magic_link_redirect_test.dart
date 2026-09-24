import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/auth/magic_link_redirect.dart';

void main() {
  test('uses http origin when running in a browser context', () {
    expect(
      magicLinkEmailRedirectTo(baseUri: Uri.parse('http://127.0.0.1:3000/')),
      'http://127.0.0.1:3000',
    );
    expect(
      magicLinkEmailRedirectTo(
        baseUri: Uri.parse('http://localhost:3000/some/path'),
      ),
      'http://localhost:3000',
    );
  });

  test('falls back to pinned local site_url for non-http schemes', () {
    expect(
      magicLinkEmailRedirectTo(baseUri: Uri.parse('file:///tmp/test')),
      kLocalAuthSiteUrl,
    );
  });
}
