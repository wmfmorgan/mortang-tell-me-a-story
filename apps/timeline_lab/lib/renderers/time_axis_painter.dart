import 'package:flutter/widgets.dart';

import '../theme/lab_theme.dart';
import 'canvas_label.dart';
import 'time_scale.dart';

const decadeTickLength = 10.0;
const yearTickLength = 4.0;
const monthTickLength = 2.0;

class AxisMark {
  const AxisMark(this.px, this.length, this.label);

  final double px;
  final double length;
  final String? label;
}

/// Ticks and labels for [scale], finest first. Pure, so it can be tested.
List<AxisMark> timeAxisMarks(
  TimeScale scale, {
  TickKind finest = TickKind.year,
  bool labelYears = false,
}) => [
  if (finest == TickKind.month)
    for (final m in scale.monthTicks()) AxisMark(m.px, monthTickLength, null),
  for (final t in scale.yearTicks())
    if (t.kind == TickKind.decade)
      AxisMark(t.px, decadeTickLength, '${t.year}')
    else if (finest != TickKind.decade)
      AxisMark(t.px, yearTickLength, labelYears ? '${t.year}' : null),
];

enum TickSide { after, both }

/// The one time-axis look: an ink-60% spine, ticks from [timeAxisMarks],
/// labels in [labelStyle] above and right of their tick. [zoom] is the canvas
/// scale, so strokes, lengths and labels stay constant on screen.
void paintTimeAxis(
  Canvas canvas,
  TimeScale scale, {
  required Axis direction,
  required double cross,
  required TextStyle labelStyle,
  TickKind finest = TickKind.year,
  bool labelYears = false,
  bool labels = true,
  TickSide side = TickSide.after,
  double spineWidth = LabStroke.hairline,
  double zoom = 1,
  double? spineFrom,
  double? spineTo,
}) {
  Offset at(double t, double c) =>
      direction == Axis.horizontal ? Offset(t, c) : Offset(c, t);
  canvas.drawLine(
    at(spineFrom ?? scale.toPx(scale.minYear.toDouble()), cross),
    at(spineTo ?? scale.toPx(scale.maxYear + 1.0), cross),
    Paint()
      ..color = labRuleStrong
      ..strokeWidth = spineWidth / zoom,
  );
  final tick = Paint()
    ..color = labRuleStrong
    ..strokeWidth = LabStroke.hairline / zoom;
  for (final m in timeAxisMarks(
    scale,
    finest: finest,
    labelYears: labelYears,
  )) {
    final len = m.length / zoom;
    final start = side == TickSide.both ? cross - len / 2 : cross;
    canvas.drawLine(at(m.px, start), at(m.px, start + len), tick);
    final label = m.label;
    if (!labels || label == null) continue;
    final o = at(m.px, cross);
    canvas
      ..save()
      ..translate(o.dx, o.dy)
      ..scale(1 / zoom);
    paintLabel(
      canvas,
      label,
      labelStyle,
      const Offset(3, -3),
      anchor: Alignment.bottomLeft,
    );
    canvas.restore();
  }
}

/// Decade labels on parchment pills centred on a vertical spine. Paint them
/// after the cards so that neither side covers them.
void paintSpineLabels(
  Canvas canvas,
  TimeScale scale, {
  required double spineX,
  required TextStyle labelStyle,
}) {
  final pill = Paint()..color = labParchment;
  for (final m in timeAxisMarks(scale, finest: TickKind.decade)) {
    final label = CanvasLabel(m.label!, labelStyle);
    final rect = Rect.fromCenter(
      center: Offset(spineX, m.px),
      width: label.size.width + LabSpace.s,
      height: label.size.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(LabRadius.tile)),
      pill,
    );
    label.paint(canvas, rect.center, anchor: Alignment.center);
    label.dispose();
  }
}
