import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'timeline_branching.dart';

/// Moss ring for an origin story that has no callout of its own.
class OriginDot extends StatelessWidget {
  const OriginDot({super.key, required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final diameter = highlighted ? farDotHighlightedDiameter : farDotDiameter;
    final ring = diameter + 2 * calloutDotGap + 2 * calloutStroke;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: branchMoss, width: calloutStroke),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
