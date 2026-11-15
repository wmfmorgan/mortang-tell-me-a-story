import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'timeline_branching.dart';

class FullCardDot extends StatelessWidget {
  const FullCardDot({super.key, required this.focused, required this.branched});

  final bool focused;
  final bool branched;

  @override
  Widget build(BuildContext context) {
    final size = focused ? fullDotFocusedDiameter : fullDotDiameter;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: focused ? albumTerracotta : albumParchment,
        border: focused
            ? null
            : Border.all(color: albumInk.withValues(alpha: 0.4), width: 2),
        boxShadow: focused && !branched
            ? const [
                BoxShadow(color: albumBlush, spreadRadius: 8, blurRadius: 0),
              ]
            : null,
      ),
    );
  }
}
