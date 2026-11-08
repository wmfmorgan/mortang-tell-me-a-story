import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/ui/timeline/pointer_input.dart';

void main() {
  test('fingers get half the 44 pt target; pointers and Pencil stay precise', () {
    expect(
      hitRadiusFor(PointerDeviceKind.touch, precise: 12),
      AlbumTarget.fingerRadius,
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

  test('finger and precise devices split every kind by isFingerLike', () {
    for (final kind in PointerDeviceKind.values) {
      expect(fingerDevices.contains(kind), isFingerLike(kind), reason: '$kind');
      expect(preciseDevices.contains(kind), !isFingerLike(kind));
    }
  });
}
