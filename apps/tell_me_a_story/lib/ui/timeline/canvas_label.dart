import 'package:flutter/painting.dart';

/// A one-line label for painters. Lay it out once, read [size] for pills or
/// knockouts, then [paint] it with an anchor point.
class CanvasLabel {
  CanvasLabel(String text, TextStyle style, {double maxWidth = double.infinity})
    : _painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  final TextPainter _painter;

  Size get size => _painter.size;

  /// Top-left corner when the label's [anchor] point sits at [at].
  Offset originFor(Offset at, {Alignment anchor = Alignment.topLeft}) =>
      at - anchor.alongSize(size);

  void paint(
    Canvas canvas,
    Offset at, {
    Alignment anchor = Alignment.topLeft,
  }) => _painter.paint(canvas, originFor(at, anchor: anchor));

  void dispose() => _painter.dispose();
}

/// Lays out, paints and disposes a label in one call; returns its rect.
Rect paintLabel(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset at, {
  Alignment anchor = Alignment.topLeft,
}) {
  final label = CanvasLabel(text, style);
  final rect = label.originFor(at, anchor: anchor) & label.size;
  label.paint(canvas, at, anchor: anchor);
  label.dispose();
  return rect;
}
