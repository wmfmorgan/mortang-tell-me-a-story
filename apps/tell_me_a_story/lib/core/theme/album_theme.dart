import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Memory Album tokens (Impl Spec §15 M4.5 / UXD DESIGN.md).
const albumParchment = Color(0xFFFBF7F2);
const albumModalScrim = Color(0x661C140C);
const albumModalBorder = Color(0xFFE6DCD1);
const albumPillFill = Color(0xFFF6F1EB);
const albumPillBorder = Color(0xFFE7DECE);
const albumTerracotta = Color(0xFF8B5E4B);
const albumSage = Color(0xFF7A8B74);
const branchMoss = Color(0xFF5B7F3A);
const albumInk = Color(0xFF2C2416);
const albumDialogSurface = Color(0xFFFFF8F6);
const albumBackdropClear = Colors.transparent;

/// Plus glyph and button text on terracotta; sign-in landing card fill.
const albumWhite = Color(0xFFFFFFFF);

/// Text on terracotta buttons (Publish story, sign-in landing buttons).
const albumOnAccent = Color(0xFFFFF6F3);

/// Header avatar menu fill.
const albumMenuSurface = Color(0xFFFCF9F5);

/// Profile avatar circle fill when there is no picture.
const albumAvatarFill = Color(0xFFEDE0DC);

/// Profile avatar circle border.
const albumAvatarBorder = Color(0xFFD5C7B7);

/// Send-invite confirm: card and note borders, divider (at alpha 0x80).
const albumInviteBorder = Color(0xFFE8DFD5);

/// Send-invite confirm: note row fill.
const albumInviteNoteFill = Color(0xFFF7F1EA);

/// Black for drop shadows; use with withAlpha.
const albumShadow = Color(0xFF000000);

/// Sign-in landing: card borders, footer rules, muted lines (with alpha).
const albumLandingLine = Color(0xFFB9B0AD);

const albumCardRadius = 12.0;

// Timeline visual system (Phase 7, Q5), ported from the timeline lab's
// lab_theme.dart. Names approved by the owner (O3, 2026-11-08).

/// Darkest allowed dimmed text: ink at 70% on parchment
/// (docs/archive/ux/80-all-stories.md). All Stories dims with it.
const albumDimInk = Color(0xFF6A6358);

/// Timeline: focused-dot halo, focused-card glow and filled chip.
const albumBlush = Color(0xFFF5DED6);

/// Timeline: unfilled chip.
const albumBlushPale = Color(0xFFF5ECE9);

/// Ink tints for lines; text never uses them.
const albumRuleStrong = Color(0x992C2416); // 60%: axis spines, ticks
const albumRule = Color(0x332C2416); // 20%: rails, connectors, edges
const albumWatermark = Color(0x1F2C2416); // 12%: background year

/// Sage accents, one alpha per role.
const albumSageTint = Color(0x597A8B74); // 35%: selected filter chip
const albumSageLine = Color(0x737A8B74); // 45%: card, chip, field borders

abstract final class AlbumSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

/// Corner radii. Two shape families:
/// * Pills ([StadiumBorder]) for every small tappable control: segmented
///   buttons, filter chips, tags, badges.
/// * Containers use these radii with continuous (superellipse) corners via
///   [albumContainerShape]. A container nested inside another uses the
///   outer radius minus the inset between them, rounded to this scale.
abstract final class AlbumRadius {
  /// Painted knockouts and treemap cells (inside an 8 px group).
  static const tile = 4.0;

  /// Treemap groups and story tiles.
  static const group = 8.0;

  /// Cards and text fields.
  static const card = 12.0;

  /// Menus, popovers and drawers.
  static const sheet = 16.0;

  /// Painted pills (badges): any radius past half the height is a stadium.
  static const pill = 20.0;
}

/// Continuous-corner container shape (the iOS "squircle"), so curves blend
/// into the straight edges instead of meeting them at a visible join.
OutlinedBorder albumContainerShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: side,
);

/// Text-field outline with the same continuous corners as the cards.
///
/// Flutter's `OutlineInputBorder` only draws circular corners and cuts a
/// notch for a floating label. Fields using this border use hint text
/// instead of a floating label, so it never needs a gap.
class AlbumFieldBorder extends InputBorder {
  const AlbumFieldBorder({super.borderSide, this.radius = AlbumRadius.card});

  final double radius;

  RSuperellipse _shape(Rect rect) =>
      BorderRadius.circular(radius).toRSuperellipse(rect);

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  AlbumFieldBorder copyWith({BorderSide? borderSide}) => AlbumFieldBorder(
    borderSide: borderSide ?? this.borderSide,
    radius: radius,
  );

  @override
  ShapeBorder scale(double t) =>
      AlbumFieldBorder(borderSide: borderSide.scale(t), radius: radius * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is AlbumFieldBorder
      ? AlbumFieldBorder(
          borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
          radius: lerpDouble(a.radius, radius, t)!,
        )
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is AlbumFieldBorder
      ? AlbumFieldBorder(
          borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
          radius: lerpDouble(radius, b.radius, t)!,
        )
      : super.lerpTo(b, t);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRSuperellipse(_shape(rect));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRSuperellipse(_shape(rect.deflate(borderSide.width)));

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none) return;
    canvas.drawRSuperellipse(
      _shape(rect.deflate(borderSide.width / 2)),
      borderSide.toPaint(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlbumFieldBorder &&
      other.borderSide == borderSide &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(borderSide, radius);
}

abstract final class AlbumStroke {
  static const hairline = 1.0;
  static const rule = 1.5;
  static const mark = 2.0;
}

/// Story-dot geometry (diameters and ring strokes, logical px).
abstract final class AlbumMarker {
  static const dot = 10.0;
  static const small = 8.0;
  static const gap = 2.0;
  static const ring = 2.0;
  static const hollow = 1.5;
}

/// Timeline text roles on top of the theme's TextTheme. Nothing below 11 px.
abstract final class AlbumText {
  static TextStyle axis(TextTheme t) => t.labelMedium!.copyWith(
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle count(TextTheme t) =>
      t.labelMedium!.copyWith(color: albumDimInk);
  static TextStyle lane(TextTheme t) =>
      t.labelLarge!.copyWith(fontWeight: FontWeight.w600);
  static TextStyle group(TextTheme t) => t.titleSmall!;

  /// Text on a painted ink pill (the tree graph's `+N`).
  static TextStyle badge(TextTheme t) => t.labelSmall!.copyWith(
    fontWeight: FontWeight.w700,
    color: albumParchment,
  );
}

/// Touch targets (Apple HIG: 44 pt minimum).
abstract final class AlbumTarget {
  /// Smallest tappable extent for a finger.
  static const min = 44.0;

  /// Hit radius a finger tap gets around a painted point.
  static const fingerRadius = min / 2;
}

/// Window widths where a timeline layout changes.
abstract final class AlbumBreakpoint {
  /// At or above: a persistent side panel. Below: an end drawer.
  static const sidebar = 900.0;

  /// Below: stacked compact layout.
  static const compact = 600.0;
}

ColorScheme albumColorScheme() {
  return const ColorScheme.light(
    primary: albumTerracotta,
    onPrimary: albumParchment,
    secondary: albumSage,
    onSecondary: albumParchment,
    tertiary: albumSage,
    onTertiary: albumParchment,
    surface: albumParchment,
    onSurface: albumInk,
    error: albumTerracotta,
    onError: albumParchment,
  );
}

ThemeData albumTheme() {
  final colorScheme = albumColorScheme();

  final textTheme = TextTheme(
    headlineLarge: GoogleFonts.newsreader(
      color: albumInk,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: GoogleFonts.newsreader(
      color: albumInk,
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: GoogleFonts.newsreader(
      color: albumInk,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.newsreader(
      color: albumInk,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: GoogleFonts.newsreader(
      color: albumInk,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: GoogleFonts.sourceSans3(
      color: albumInk,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.literata(color: albumInk),
    bodyMedium: GoogleFonts.literata(color: albumInk),
    bodySmall: GoogleFonts.literata(color: albumInk),
    labelLarge: GoogleFonts.sourceSans3(color: albumInk),
    labelMedium: GoogleFonts.sourceSans3(color: albumInk),
    labelSmall: GoogleFonts.sourceSans3(color: albumInk),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: albumParchment,
    canvasColor: albumParchment,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: albumParchment,
      foregroundColor: albumInk,
      elevation: 0,
      titleTextStyle: GoogleFonts.newsreader(
        color: albumInk,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: albumParchment,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(albumCardRadius),
        side: BorderSide(color: albumSage.withValues(alpha: 0.45)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: albumParchment,
      selectedColor: albumSage.withValues(alpha: 0.35),
      labelStyle: GoogleFonts.sourceSans3(color: albumInk),
      side: BorderSide(color: albumSage.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: albumTerracotta,
        foregroundColor: albumParchment,
        minimumSize: const Size(48, 48),
        textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: albumInk,
        minimumSize: const Size(48, 40),
        textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: albumInk,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: albumSage),
        textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: albumParchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: albumParchment,
      labelStyle: GoogleFonts.sourceSans3(color: albumInk),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: albumSage.withValues(alpha: 0.6)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: albumParchment,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: albumTerracotta,
    ),
    // docs/archive/ux/80-all-stories.md Rule 4: selected = terracotta pill
    // with a parchment label (5.18:1); others ink on the pill fill.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? albumTerracotta
              : albumPillFill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? albumParchment : albumInk,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: albumSageLine)),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.sourceSans3(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    ),
  );
}
