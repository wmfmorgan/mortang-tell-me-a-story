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
    expect(branchMoss, const Color(0xFF5B7F3A));
    expect(albumInk, const Color(0xFF2C2416));
    expect(albumInkFaint, const Color(0x332C2416));
    expect(albumInkDim, const Color(0xB32C2416));
    expect(albumParchmentClear, const Color(0x00FBF7F2));
    expect(albumParchmentClear, isNot(Colors.transparent));
    expect(albumBlush, const Color(0xFFF5DED6));
    expect(albumBlushWash, const Color(0xFFF5DED6).withValues(alpha: 0.3));
    expect(albumPaleRose, const Color(0xFFF5ECE9));
    expect(albumWhite, const Color(0xFFFFFFFF));
    expect(albumWhite, Colors.white);
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
