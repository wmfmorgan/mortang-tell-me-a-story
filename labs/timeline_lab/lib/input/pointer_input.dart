import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import '../theme/lab_theme.dart';

/// Fingers are imprecise. Mouse, trackpad and Apple Pencil are not, and
/// semantics actions and synthesized taps (unknown) must hit exactly.
bool isFingerLike(PointerDeviceKind kind) => switch (kind) {
  PointerDeviceKind.touch => true,
  PointerDeviceKind.mouse ||
  PointerDeviceKind.trackpad ||
  PointerDeviceKind.stylus ||
  PointerDeviceKind.invertedStylus ||
  PointerDeviceKind.unknown => false,
};

/// Hit radius around a painted point for a tap from [kind]: [precise] for
/// pointers, at least [LabTarget.fingerRadius] for fingers.
double hitRadiusFor(PointerDeviceKind kind, {required double precise}) =>
    isFingerLike(kind) ? math.max(precise, LabTarget.fingerRadius) : precise;
