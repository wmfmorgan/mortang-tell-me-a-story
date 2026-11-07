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
const labCardRadius = 12.0;

/// Darkest allowed dimmed text (docs/ux/80-all-stories.md).
const labDimmedInk = Color(0xFF6A6358);
const labDimOpacity = 0.35;

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
    chipTheme: ChipThemeData(
      backgroundColor: labPillFill,
      selectedColor: labBorder,
      checkmarkColor: labInk,
      labelStyle: textTheme.labelLarge,
      secondaryLabelStyle: textTheme.labelLarge,
      side: const BorderSide(color: labPillBorder),
    ),
    // The default inactive track vanishes on parchment; the playback
    // scrubber needs its full length visible.
    sliderTheme: const SliderThemeData(inactiveTrackColor: labBorder),
  );
}
