import 'package:flutter/widgets.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';

// Story dots are terracotta everywhere; family shows through lanes and
// labels, and moss is reserved for origin rings
// (docs/archive/ux/branch-callout.md Rule 4 "One green").

/// True when some branch family in [families] starts at [story].
bool isOrigin(Story story, Iterable<TreeFamily> families) =>
    families.any((f) => f.originStoryId == story.id);

/// One story dot. Matched dots are filled and dimmed dots are hollow, so a
/// match never rests on colour or opacity alone. The origin (moss) and
/// selection (terracotta) rings nest outside the dot without touching.
class MarkerSpec {
  const MarkerSpec({
    required this.matched,
    this.origin = false,
    this.selected = false,
    this.diameter = AlbumMarker.dot,
  });

  final bool matched;
  final bool origin;
  final bool selected;
  final double diameter;

  double get dotRadius => diameter / 2;

  /// Centre-line radius of the hollow (dimmed) stroke.
  double get hollowRadius => dotRadius - AlbumMarker.hollow / 2;

  double get originRadius => dotRadius + AlbumMarker.gap + AlbumMarker.ring / 2;

  double get selectedRadius =>
      (origin ? originRadius + AlbumMarker.ring / 2 : dotRadius) +
      AlbumMarker.gap +
      AlbumMarker.ring / 2;

  /// Square that holds the dot and both rings, whatever the state.
  static double extent(double diameter) =>
      diameter + 4 * (AlbumMarker.gap + AlbumMarker.ring);
}

void paintStoryMarker(Canvas canvas, Offset c, MarkerSpec m) {
  final dot = Paint()..color = albumTerracotta;
  if (m.matched) {
    canvas.drawCircle(c, m.dotRadius, dot);
  } else {
    canvas.drawCircle(
      c,
      m.hollowRadius,
      dot
        ..style = PaintingStyle.stroke
        ..strokeWidth = AlbumMarker.hollow,
    );
  }
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = AlbumMarker.ring;
  if (m.origin) {
    canvas.drawCircle(c, m.originRadius, ring..color = branchMoss);
  }
  if (m.selected) {
    canvas.drawCircle(c, m.selectedRadius, ring..color = albumTerracotta);
  }
}

/// Widget form of [paintStoryMarker]. It always occupies
/// [MarkerSpec.extent], so selecting a story never shifts layout.
/// [reserveRings] false sizes it to the bare dot.
class StoryDot extends StatelessWidget {
  const StoryDot({super.key, required this.spec, this.reserveRings = true});

  final MarkerSpec spec;
  final bool reserveRings;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(
      reserveRings ? MarkerSpec.extent(spec.diameter) : spec.diameter,
    ),
    painter: _StoryDotPainter(spec),
  );
}

class _StoryDotPainter extends CustomPainter {
  _StoryDotPainter(this.spec);

  final MarkerSpec spec;

  @override
  void paint(Canvas canvas, Size size) =>
      paintStoryMarker(canvas, size.center(Offset.zero), spec);

  @override
  bool shouldRepaint(_StoryDotPainter old) =>
      old.spec.matched != spec.matched ||
      old.spec.origin != spec.origin ||
      old.spec.selected != spec.selected ||
      old.spec.diameter != spec.diameter;
}
