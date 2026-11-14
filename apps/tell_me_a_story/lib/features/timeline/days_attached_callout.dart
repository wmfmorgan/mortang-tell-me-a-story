import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'days_card_slot.dart';
import 'hang_parent_parent_data.dart';

/// Days parent callout. The leader matches the decade parent: 45°, then
/// horizontal. It meets the top center of the story card and runs to the
/// card's own side. A left card runs left. A right card runs right. Narrow
/// cards sit to the right of the spine, so the label runs right. The label is
/// larger than the years parent.
///
/// The label is a sibling of the row so the space above the card stays inside
/// the hit region. The row is not shifted in x, so the spine dot stays put.
class DaysAttachedCallout extends StatefulWidget {
  const DaysAttachedCallout({
    super.key,
    required this.anchor,
    required this.callout,
    required this.body,
  });

  /// Point in [callout] that sits on the top center of the card.
  final Offset anchor;
  final Widget callout;
  final Widget Function(DaysCardSlot slot) body;

  @override
  State<DaysAttachedCallout> createState() => _DaysAttachedCalloutState();
}

class _DaysAttachedCalloutState extends State<DaysAttachedCallout> {
  final _slot = DaysCardSlot();

  @override
  Widget build(BuildContext context) {
    return _DaysAttachedCalloutBox(
      slot: _slot,
      anchor: widget.anchor,
      callout: widget.callout,
      body: widget.body(_slot),
    );
  }
}

class _DaysAttachedCalloutBox extends MultiChildRenderObjectWidget {
  _DaysAttachedCalloutBox({
    required this.slot,
    required this.anchor,
    required Widget body,
    required Widget callout,
  }) : super(children: [body, callout]);

  final DaysCardSlot slot;
  final Offset anchor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDaysAttachedCallout(slot: slot, anchor: anchor);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDaysAttachedCallout renderObject,
  ) {
    renderObject
      ..slot = slot
      ..anchor = anchor;
  }
}

class _RenderDaysAttachedCallout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, HangParentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, HangParentParentData> {
  _RenderDaysAttachedCallout({required this._slot, required this._anchor});

  DaysCardSlot _slot;
  Offset _anchor;

  set slot(DaysCardSlot value) {
    if (_slot == value) return;
    _slot = value;
    markNeedsLayout();
  }

  set anchor(Offset value) {
    if (_anchor == value) return;
    _anchor = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! HangParentParentData) {
      child.parentData = HangParentParentData();
    }
  }

  /// [target]'s top-left in [ancestor]'s coordinates. Sums parent offsets, so
  /// it does not read a descendant's size. Proxy boxes keep the base
  /// [ParentData] and paint the child at their own origin, which adds nothing.
  Offset? _offsetWithin(RenderBox target, RenderBox ancestor) {
    var offset = Offset.zero;
    RenderObject? node = target;
    while (node != null && node != ancestor) {
      final data = node.parentData;
      if (data is BoxParentData) offset += data.offset;
      node = node.parent;
    }
    if (node != ancestor) return null;
    return offset;
  }

  /// Painted top center of the card in [body]'s coordinates. Focus scale grows
  /// the card from its center, so the top edge sits above the layout box.
  Offset? _cardTop(RenderBox body) {
    final box = _slot.box;
    if (box == null || !box.attached) return null;
    final origin = _offsetWithin(box, body);
    if (origin == null) return null;
    final size = _slot.layoutSize;
    final scale = _slot.scale;
    final center = origin + Offset(size.width / 2, size.height / 2);
    final layoutTop = origin + Offset(size.width / 2, 0);
    return center + (layoutTop - center) * scale;
  }

  @override
  void performLayout() {
    final body = firstChild;
    final callout = body == null ? null : childAfter(body);
    if (body == null || callout == null) {
      size = constraints.smallest;
      return;
    }
    body.layout(constraints, parentUsesSize: true);
    callout.layout(const BoxConstraints(), parentUsesSize: true);

    final top = _cardTop(body);
    var bodyOffset = Offset.zero;
    var calloutOffset = Offset.zero;
    if (top != null) {
      calloutOffset = top - _anchor;
      // The focus scale and the leader both reach above the card. Drop the
      // row so that reach stays inside this box. Shift the row in y only:
      // an x shift would pull the spine dot off center.
      if (calloutOffset.dy < 0) {
        final dy = -calloutOffset.dy;
        calloutOffset = Offset(calloutOffset.dx, 0);
        bodyOffset = Offset(0, dy);
      }
    }
    final width = math.max(
      body.size.width,
      math.max(0.0, calloutOffset.dx) + callout.size.width,
    );
    final height = math.max(
      bodyOffset.dy + body.size.height,
      calloutOffset.dy + callout.size.height,
    );
    size = constraints.constrain(Size(width, height));
    (body.parentData! as HangParentParentData).offset = bodyOffset;
    (callout.parentData! as HangParentParentData).offset = calloutOffset;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }
}
