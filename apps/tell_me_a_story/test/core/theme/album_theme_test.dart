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

  test('timeline tints are album colours at fixed alphas', () {
    expect(albumRule, albumInk.withAlpha(0x33));
    expect(albumRuleStrong, albumInk.withAlpha(0x99));
    expect(albumWatermark, albumInk.withAlpha(0x1F));
    expect(albumSageTint, albumSage.withAlpha(0x59));
    expect(albumSageLine, albumSage.withAlpha(0x73));
  });

  test('exact-value tokens keep their hex values (O3)', () {
    expect(albumDimInk, const Color(0xFF6A6358));
    expect(albumBlush, const Color(0xFFF5DED6));
    expect(albumBlushPale, const Color(0xFFF5ECE9));
  });

  test('timeline scales match the lab', () {
    expect(
      [AlbumSpace.xs, AlbumSpace.s, AlbumSpace.m, AlbumSpace.l, AlbumSpace.xl],
      [4, 8, 12, 16, 24],
    );
    expect(
      [
        AlbumRadius.tile,
        AlbumRadius.group,
        AlbumRadius.card,
        AlbumRadius.sheet,
        AlbumRadius.pill,
      ],
      [4, 8, 12, 16, 20],
    );
    expect(
      [AlbumStroke.hairline, AlbumStroke.rule, AlbumStroke.mark],
      [1, 1.5, 2],
    );
    expect(
      [
        AlbumMarker.dot,
        AlbumMarker.small,
        AlbumMarker.gap,
        AlbumMarker.ring,
        AlbumMarker.hollow,
      ],
      [10, 8, 2, 2, 1.5],
    );
    expect(AlbumTarget.min, 44);
    expect(AlbumTarget.fingerRadius, 22);
    expect(AlbumBreakpoint.sidebar, 900);
    expect(AlbumBreakpoint.compact, 600);
  });

  test('text roles build on the theme text styles', () {
    final t = albumTheme().textTheme;
    expect(AlbumText.axis(t).fontWeight, FontWeight.w600);
    expect(AlbumText.axis(t).fontFeatures, const [
      FontFeature.tabularFigures(),
    ]);
    expect(AlbumText.count(t).color, albumDimInk);
    expect(AlbumText.lane(t).fontWeight, FontWeight.w600);
    expect(AlbumText.group(t), t.titleSmall);
  });

  test('containers have continuous corners', () {
    const side = BorderSide(color: albumSageLine);
    final shape = albumContainerShape(AlbumRadius.card, side: side);
    expect(shape, isA<RoundedSuperellipseBorder>());
    expect(
      (shape as RoundedSuperellipseBorder).borderRadius,
      BorderRadius.circular(12),
    );
    expect(shape.side, side);
  });

  test('selected segment is terracotta with a parchment label', () {
    final style = albumTheme().segmentedButtonTheme.style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.selected}),
      albumTerracotta,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.selected}),
      albumParchment,
    );
    expect(style.backgroundColor!.resolve({}), albumPillFill);
    expect(style.foregroundColor!.resolve({}), albumInk);
  });
}
