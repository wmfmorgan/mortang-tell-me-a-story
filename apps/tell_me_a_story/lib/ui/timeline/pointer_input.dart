import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

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
/// pointers, at least [AlbumTarget.fingerRadius] for fingers.
double hitRadiusFor(PointerDeviceKind kind, {required double precise}) =>
    isFingerLike(kind) ? math.max(precise, AlbumTarget.fingerRadius) : precise;

/// The [isFingerLike] kinds, for `GestureDetector.supportedDevices`.
const fingerDevices = {PointerDeviceKind.touch};

/// Every kind that is not [isFingerLike]: these hit a dot exactly.
const preciseDevices = {
  PointerDeviceKind.mouse,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown,
};
