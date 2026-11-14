import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'hang_parent_parent_data.dart';

/// Places [callout] so [anchor] sits on the top center of [card].
///
/// A left card stays flush with the right edge, and a right card stays flush
/// with the left edge, so the rail alignment does not move. [balance] adds
/// the same space below the card that the callout takes above it, which keeps
/// a centered rail dot on the card.
class HangParentCallout extends MultiChildRenderObjectWidget {
  HangParentCallout({
    super.key,
    required this.anchor,
    required this.cardOnLeft,
    required this.balance,
    required Widget card,
    required Widget callout,
  }) : super(children: [card, callout]);

  final Offset anchor;
  final bool cardOnLeft;
  final bool balance;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderHangParentCallout(anchor, cardOnLeft, balance);
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    final box = renderObject as _RenderHangParentCallout;
    box
      ..anchor = anchor
      ..cardOnLeft = cardOnLeft
      ..balance = balance;
  }
}

class _RenderHangParentCallout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, HangParentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, HangParentParentData> {
  _RenderHangParentCallout(this._anchor, this._cardOnLeft, this._balance);

  Offset _anchor;
  bool _cardOnLeft;
  bool _balance;

  set anchor(Offset value) {
    if (_anchor == value) return;
    _anchor = value;
    markNeedsLayout();
  }

  set cardOnLeft(bool value) {
    if (_cardOnLeft == value) return;
    _cardOnLeft = value;
    markNeedsLayout();
  }

  set balance(bool value) {
    if (_balance == value) return;
    _balance = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! HangParentParentData) {
      child.parentData = HangParentParentData();
    }
  }

  @override
  void performLayout() {
    final card = firstChild;
    final callout = card == null ? null : childAfter(card);
    if (card == null || callout == null) {
      size = constraints.smallest;
      return;
    }
    final maxWidth = constraints.maxWidth;
    card.layout(
      BoxConstraints(maxWidth: maxWidth.isFinite ? maxWidth : double.infinity),
      parentUsesSize: true,
    );
    callout.layout(const BoxConstraints(), parentUsesSize: true);

    final rawCalloutX = card.size.width / 2 - _anchor.dx;
    var cardX = _cardOnLeft && rawCalloutX < 0 ? -rawCalloutX : 0.0;
    var calloutX = rawCalloutX + cardX;
    final cardY = _anchor.dy;
    final contentWidth = math.max(
      cardX + card.size.width,
      math.max(calloutX, 0) + callout.size.width,
    );
    final contentHeight = math.max(
      cardY + card.size.height,
      callout.size.height,
    );
    final spaceBelow = contentHeight - cardY - card.size.height;
    final extraBelow = _balance ? math.max(0.0, cardY - spaceBelow) : 0.0;
    size = constraints.constrain(
      Size(contentWidth, contentHeight + extraBelow),
    );
    if (_cardOnLeft && size.width + 0.01 < contentWidth) {
      final shift = size.width - contentWidth;
      cardX += shift;
      calloutX += shift;
    }
    (card.parentData! as HangParentParentData).offset = Offset(cardX, cardY);
    (callout.parentData! as HangParentParentData).offset = Offset(calloutX, 0);
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
