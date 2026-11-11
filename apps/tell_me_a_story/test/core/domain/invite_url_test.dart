import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/domain/invite_url.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('buildInviteUrl uses /invite/<token>', () {
    expect(
      buildInviteUrl('abc', origin: 'http://127.0.0.1:3000/'),
      'http://127.0.0.1:3000/invite/abc',
    );
  });
}
