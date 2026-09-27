import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Memory Album tokens (Impl Spec §15 M4.5 / UXD DESIGN.md).
const albumParchment = Color(0xFFFBF7F2);
const albumTerracotta = Color(0xFF8B5E4B);
const albumSage = Color(0xFF7A8B74);
const albumInk = Color(0xFF2C2416);

const albumCardRadius = 12.0;

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
        textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: albumInk,
        textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: albumInk,
        side: const BorderSide(color: albumSage),
        textStyle: GoogleFonts.sourceSans3(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
  );
}
