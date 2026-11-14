import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'days_card_slot.dart';

/// Wraps the focused card so the parent callout can find its corner without
/// reading a descendant's [RenderBox.size] during layout.
class DaysCardProbe extends SingleChildRenderObjectWidget {
  const DaysCardProbe({
    super.key,
    required this.slot,
    required this.scale,
    required super.child,
  });

  final DaysCardSlot slot;
  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDaysCardProbe(slot, scale);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final box = renderObject as _RenderDaysCardProbe;
    box
      ..slot = slot
      ..scale = scale;
  }
}

class _RenderDaysCardProbe extends RenderProxyBox {
  _RenderDaysCardProbe(this._slot, this._scale);

  DaysCardSlot _slot;
  double _scale;

  set slot(DaysCardSlot value) {
    if (_slot == value) return;
    if (_slot.box == this) _slot.box = null;
    _slot = value;
    markNeedsLayout();
  }

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    _slot
      ..layoutSize = size
      ..scale = _scale
      ..box = this;
  }

  @override
  void detach() {
    if (_slot.box == this) _slot.box = null;
    super.detach();
  }
}
