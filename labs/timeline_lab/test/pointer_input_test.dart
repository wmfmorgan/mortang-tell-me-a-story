import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/input/pointer_input.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

void main() {
  test('fingers get half the 44 pt target; pointers and Pencil stay precise', () {
    expect(
      hitRadiusFor(PointerDeviceKind.touch, precise: 12),
      LabTarget.fingerRadius,
    );
    expect(hitRadiusFor(PointerDeviceKind.touch, precise: 30), 30);
    for (final kind in [
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      // Semantics actions and synthesized taps report unknown; keep them exact.
      PointerDeviceKind.unknown,
    ]) {
      expect(hitRadiusFor(kind, precise: 12), 12, reason: '$kind');
    }
  });
}
