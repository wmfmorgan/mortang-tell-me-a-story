import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token copies of `apps/tell_me_a_story/lib/core/theme/album_theme.dart`.
/// Every color in `lib/` comes from this file.
const labParchment = Color(0xFFFBF7F2);
const labInk = Color(0xFF2C2416);
const labTerracotta = Color(0xFF8B5E4B);
const labSage = Color(0xFF7A8B74);
const labMoss = Color(0xFF5B7F3A);
const labPillFill = Color(0xFFF6F1EB);
const labPillBorder = Color(0xFFE7DECE);
const labSurface = Color(0xFFFFF8F6);
const labBorder = Color(0xFFE6DCD1);

/// Darkest allowed dimmed text (docs/ux/80-all-stories.md).
const labDimmedInk = Color(0xFF6A6358);

/// Dimmed decoration (pill fills, card borders). Never text.
const labDimOpacity = 0.35;

/// Ink tints for lines; text never uses them.
const labRuleStrong = Color(0x992C2416); // 60%: axis spines, ticks
const labRule = Color(0x332C2416); // 20%: rails, connectors, edges
const labWatermark = Color(0x1F2C2416); // 12%: playback year

/// Album sage accents (album_theme.dart:91-98), one alpha per role.
const labSageTint = Color(0x597A8B74); // 35%: selected filter chip
const labSageLine = Color(0x737A8B74); // 45%: card, chip, field borders

abstract final class LabSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
}

abstract final class LabRadius {
  static const tile = 4.0;
  static const chip = 8.0;
  static const card = 12.0;
  static const pill = 20.0;
}

abstract final class LabStroke {
  static const hairline = 1.0;
  static const rule = 1.5;
  static const mark = 2.0;
}

/// Story-dot geometry (diameters and ring strokes, logical px).
abstract final class LabMarker {
  static const dot = 10.0;
  static const small = 8.0;
  static const gap = 2.0;
  static const ring = 2.0;
  static const hollow = 1.5;
}

/// Text roles on top of the theme's TextTheme. Nothing below 11 px.
abstract final class LabText {
  static TextStyle axis(TextTheme t) => t.labelMedium!.copyWith(
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle badge(TextTheme t) =>
      t.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: labParchment);
  static TextStyle count(TextTheme t) =>
      t.labelMedium!.copyWith(color: labDimmedInk);
  static TextStyle lane(TextTheme t) =>
      t.labelLarge!.copyWith(fontWeight: FontWeight.w600);
  static TextStyle group(TextTheme t) => t.titleSmall!;
}

ThemeData labTheme({required bool useGoogleFonts}) {
  TextStyle serifHeading() => useGoogleFonts
      ? GoogleFonts.newsreader(color: labInk, fontWeight: FontWeight.w600)
      : const TextStyle(
          fontFamily: 'Roboto',
          color: labInk,
          fontWeight: FontWeight.w600,
        );
  TextStyle sans({FontWeight? weight}) => useGoogleFonts
      ? GoogleFonts.sourceSans3(color: labInk, fontWeight: weight)
      : TextStyle(fontFamily: 'Roboto', color: labInk, fontWeight: weight);
  TextStyle body() => useGoogleFonts
      ? GoogleFonts.literata(color: labInk)
      : const TextStyle(fontFamily: 'Roboto', color: labInk);

  final textTheme = TextTheme(
    headlineLarge: serifHeading(),
    headlineMedium: serifHeading(),
    headlineSmall: serifHeading(),
    titleLarge: serifHeading(),
    titleMedium: serifHeading(),
    titleSmall: sans(weight: FontWeight.w600),
    bodyLarge: body(),
    bodyMedium: body(),
    bodySmall: body(),
    labelLarge: sans(),
    labelMedium: sans(),
    labelSmall: sans(),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(LabRadius.chip),
    borderSide: const BorderSide(color: labSageLine),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: useGoogleFonts ? null : 'Roboto',
    colorScheme: const ColorScheme.light(
      primary: labTerracotta,
      onPrimary: labParchment,
      secondary: labSage,
      onSecondary: labParchment,
      tertiary: labSage,
      onTertiary: labParchment,
      surface: labParchment,
      onSurface: labInk,
      error: labTerracotta,
      onError: labParchment,
    ),
    scaffoldBackgroundColor: labParchment,
    canvasColor: labParchment,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: labParchment,
      foregroundColor: labInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: serifHeading().copyWith(fontSize: 22),
    ),
    dividerColor: labBorder,
    // docs/ux/80-all-stories.md Rule 4: selected = terracotta pill,
    // parchment label; others ink on the soft beige track.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? labTerracotta : labPillFill,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? labParchment : labInk,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: labSageLine)),
        textStyle: WidgetStatePropertyAll(
          sans(weight: FontWeight.w600).copyWith(fontSize: 14),
        ),
      ),
    ),
    // album_theme.dart:94-100.
    chipTheme: ChipThemeData(
      backgroundColor: labParchment,
      selectedColor: labSageTint,
      checkmarkColor: labInk,
      labelStyle: textTheme.labelLarge,
      secondaryLabelStyle: textTheme.labelLarge,
      side: const BorderSide(color: labSageLine),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LabRadius.chip),
      ),
    ),
    // album_theme.dart:131-139; Rule 5 focus = 2 px terracotta.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: labParchment,
      isDense: true,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
        borderSide: const BorderSide(
          color: labTerracotta,
          width: LabStroke.mark,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: labInk,
        textStyle: sans(weight: FontWeight.w600).copyWith(fontSize: 14),
      ),
    ),
    // Menus use the dialog surface, as the product's family menu does
    // (docs/ux/121-family-menu.md:14).
    menuTheme: const MenuThemeData(
      style: MenuStyle(backgroundColor: WidgetStatePropertyAll(labSurface)),
    ),
    // The default inactive track vanishes on parchment; the playback
    // scrubber needs its full length visible.
    sliderTheme: const SliderThemeData(inactiveTrackColor: labBorder),
  );
}
