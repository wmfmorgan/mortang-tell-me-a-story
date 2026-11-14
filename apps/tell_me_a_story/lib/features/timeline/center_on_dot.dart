import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CenterOnDot extends SingleChildRenderObjectWidget {
  const CenterOnDot({
    super.key,
    required this.dotExtent,
    this.dotTop = 0,
    required super.child,
  });

  final double dotExtent;

  /// Where the dot box starts in the child. Zero when the callout hangs below.
  final double dotTop;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCenterOnDot(dotExtent, dotTop);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final box = renderObject as _RenderCenterOnDot;
    box
      ..dotExtent = dotExtent
      ..dotTop = dotTop;
  }
}

class _RenderCenterOnDot extends RenderShiftedBox {
  _RenderCenterOnDot(this._dotExtent, this._dotTop) : super(null);

  double _dotExtent;
  double _dotTop;

  set dotExtent(double value) {
    if (_dotExtent == value) return;
    _dotExtent = value;
    markNeedsLayout();
  }

  set dotTop(double value) {
    if (_dotTop == value) return;
    _dotTop = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child!;
    child.layout(constraints.loosen(), parentUsesSize: true);
    final childSize = child.size;
    // A downward callout hangs under a top-aligned dot, so the spare space
    // goes above it. An upward parent callout hangs over the dot, so the
    // spare space goes below it. Either way the dot stays on the row center.
    final below = childSize.height - (_dotTop + _dotExtent);
    final extraAbove = below > _dotTop ? below - _dotTop : 0.0;
    final extraBelow = _dotTop > below ? _dotTop - below : 0.0;
    size = constraints.constrain(
      Size(childSize.width, extraAbove + childSize.height + extraBelow),
    );
    (child.parentData! as BoxParentData).offset = Offset(0, extraAbove);
  }
}
