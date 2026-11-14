import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import 'timeline_branching.dart';
import 'timeline_zoom.dart';

class FarDot extends StatelessWidget {
  const FarDot({
    super.key,
    required this.story,
    required this.highlighted,
    required this.onTap,
    this.origin = false,
  });

  final Story story;
  final bool highlighted;
  final VoidCallback onTap;
  final bool origin;

  @override
  Widget build(BuildContext context) {
    final dot = GestureDetector(
      key: Key('timeline-dot-${story.id}'),
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: highlighted ? farDotHighlightedDiameter : farDotDiameter,
          height: highlighted ? farDotHighlightedDiameter : farDotDiameter,
          decoration: BoxDecoration(
            color: albumTerracotta,
            shape: BoxShape.circle,
            border: highlighted
                ? Border.all(color: albumTerracotta, width: 2)
                : null,
          ),
        ),
      ),
    );
    return Tooltip(
      message: dotTooltip(story, origin: origin),
      child: dot,
    );
  }
}
