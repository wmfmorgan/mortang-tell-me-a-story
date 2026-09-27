import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('locked hex values', () {
    expect(albumParchment, const Color(0xFFFBF7F2));
    expect(albumTerracotta, const Color(0xFF8B5E4B));
    expect(albumSage, const Color(0xFF7A8B74));
    expect(albumInk, const Color(0xFF2C2416));
    expect(albumSage, isNot(const Color(0xFF665D5A)));
  });

  test('theme primary is terracotta not sage', () {
    final scheme = albumColorScheme();
    expect(scheme.primary, albumTerracotta);
    expect(scheme.surface, albumParchment);
    expect(scheme.onSurface, albumInk);
    expect(scheme.tertiary, albumSage);
    expect(scheme.secondary, isNot(const Color(0xFF665D5A)));
  });

  testWidgets('card radius is 8–12px', (tester) async {
    final shape = albumTheme().cardTheme.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(albumTheme().scaffoldBackgroundColor, albumParchment);
  });
}
