import 'package:flutter/widgets.dart';

import '../model/lab_models.dart';
import '../theme/lab_theme.dart';

// Story dots are terracotta in every renderer; family shows through lanes
// and labels, and moss is reserved for origin rings (Decision D2,
// docs/ux/branch-callout.md Rule 4 "One green").

/// True when some branch family starts at this story.
bool isOrigin(LabStory s, LabDataset d) =>
    d.families.values.any((f) => f.originStoryId == s.id);

/// Family ids in lane order: root first, then branches by branch year.
List<String> familyLaneOrder(LabDataset d) {
  final fams = d.families.values.toList()
    ..sort((a, b) => (a.branchYear ?? 0).compareTo(b.branchYear ?? 0));
  return [for (final f in fams) f.id];
}

/// One story dot (Decision D6). Matched dots are filled and dimmed dots are
/// hollow, so a match never rests on colour or opacity alone. The origin
/// (moss) and selection (terracotta) rings nest outside the dot without
/// touching.
class MarkerSpec {
  const MarkerSpec({
    required this.matched,
    this.origin = false,
    this.selected = false,
    this.diameter = LabMarker.dot,
  });

  final bool matched;
  final bool origin;
  final bool selected;
  final double diameter;

  double get dotRadius => diameter / 2;

  /// Centre-line radius of the hollow (dimmed) stroke.
  double get hollowRadius => dotRadius - LabMarker.hollow / 2;

  double get originRadius => dotRadius + LabMarker.gap + LabMarker.ring / 2;

  double get selectedRadius =>
      (origin ? originRadius + LabMarker.ring / 2 : dotRadius) +
      LabMarker.gap +
      LabMarker.ring / 2;

  /// Square that holds the dot and both rings, whatever the state.
  static double extent(double diameter) =>
      diameter + 4 * (LabMarker.gap + LabMarker.ring);
}

void paintStoryMarker(
  Canvas canvas,
  Offset c,
  MarkerSpec m, {
  double reveal = 1,
}) {
  final dot = Paint()..color = labTerracotta.withValues(alpha: reveal);
  if (m.matched) {
    canvas.drawCircle(c, m.dotRadius, dot);
  } else {
    canvas.drawCircle(
      c,
      m.hollowRadius,
      dot
        ..style = PaintingStyle.stroke
        ..strokeWidth = LabMarker.hollow,
    );
  }
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = LabMarker.ring;
  if (m.origin) {
    canvas.drawCircle(
      c,
      m.originRadius,
      ring..color = labMoss.withValues(alpha: reveal),
    );
  }
  if (m.selected) {
    canvas.drawCircle(
      c,
      m.selectedRadius,
      ring..color = labTerracotta.withValues(alpha: reveal),
    );
  }
}

/// Widget form for the sliver list, zoom canvas and swimlanes. It always
/// occupies [MarkerSpec.extent], so selecting a story never shifts layout.
/// [reserveRings] false sizes it to the bare dot (swimlane cells show
/// selection on the cell instead).
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
