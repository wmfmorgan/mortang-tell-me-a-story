import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// forui theme skinned to the Memory Album tokens. Touch sizing everywhere:
/// the app is iPad-first.
FThemeData albumForuiTheme() {
  final colors = _albumForuiColors();
  final typography = _albumForuiTypography(colors);
  const radius = FBorderRadius(
    xs2: BorderRadius.all(Radius.circular(AlbumRadius.tile)),
    sm: BorderRadius.all(Radius.circular(AlbumRadius.group)),
    md: BorderRadius.all(Radius.circular(AlbumRadius.card)),
    lg: BorderRadius.all(Radius.circular(AlbumRadius.sheet)),
  );
  final style = FStyle.inherit(
    colors: colors,
    typography: typography,
    touch: true,
  ).copyWith(borderRadius: radius);
  // Buttons are pills (AlbumRadius: pills for small tappable controls):
  // forui sizes button radii from sm/md, so inherit them from a pill style.
  final buttonStyles = FButtonStyles.inherit(
    colors: colors,
    typography: typography,
    style: style.copyWith(
      borderRadius: radius.copyWith(sm: radius.pill, md: radius.pill),
    ),
    touch: true,
  );
  return FThemeData(
    touch: true,
    colors: colors,
    typography: typography,
    style: style,
    buttonStyles: buttonStyles,
  );
}

FColors _albumForuiColors() {
  return FColors(
    brightness: Brightness.light,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    barrier: albumModalScrim,
    background: albumParchment,
    foreground: albumInk,
    primary: albumTerracotta,
    primaryForeground: albumOnAccent,
    secondary: albumPillFill,
    secondaryForeground: albumInk,
    muted: albumPillFill,
    mutedForeground: albumDimInk,
    destructive: albumTerracotta,
    destructiveForeground: albumOnAccent,
    error: albumTerracotta,
    errorForeground: albumOnAccent,
    card: albumMenuSurface,
    border: albumSageLine,
  );
}

FTypography _albumForuiTypography(FColors colors) {
  return FTypography(
    display: FTypeface.inherit(
      colors: colors,
      touch: true,
      // GoogleFonts styles always carry their registered family name.
      fontFamily: GoogleFonts.newsreader().fontFamily!,
    ),
    body: FTypeface.inherit(
      colors: colors,
      touch: true,
      // GoogleFonts styles always carry their registered family name.
      fontFamily: GoogleFonts.sourceSans3().fontFamily!,
    ),
  );
}

/// `MaterialApp.builder` that puts [albumForuiTheme] above every route.
Widget albumAppBuilder(BuildContext context, Widget? child) =>
    // MaterialApp always passes its navigator or router as the child.
    FTheme(data: albumForuiTheme(), child: child!);
