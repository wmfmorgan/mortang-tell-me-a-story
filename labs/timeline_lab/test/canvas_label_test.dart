import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/renderers/canvas_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const style = TextStyle(fontSize: 10, fontFamily: 'Roboto');

  test('originFor puts the anchor point of the label box at the point', () {
    final l = CanvasLabel('1980', style);
    addTearDown(l.dispose);
    final s = l.size;
    const at = Offset(100, 50);
    expect(l.originFor(at), at);
    expect(
      l.originFor(at, anchor: Alignment.center),
      Offset(100 - s.width / 2, 50 - s.height / 2),
    );
    expect(
      l.originFor(at, anchor: Alignment.bottomLeft),
      Offset(100, 50 - s.height),
    );
  });

  test('maxWidth truncates to a single line', () {
    final l = CanvasLabel(
      'A very long story title that will never fit',
      style,
      maxWidth: 40,
    );
    addTearDown(l.dispose);
    expect(l.size.width, lessThanOrEqualTo(40));
    expect(l.size.height, lessThan(2 * 10 * 1.5));
  });

  test('paintLabel returns the rect it painted', () {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = paintLabel(
      canvas,
      '+3',
      style,
      const Offset(20, 20),
      anchor: Alignment.center,
    );
    recorder.endRecording().dispose();
    expect(rect.center.dx, closeTo(20, 1e-9));
    expect(rect.center.dy, closeTo(20, 1e-9));
  });
}
