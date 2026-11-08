import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/playback/reveal.dart';

ScrollMetrics _metrics({double viewport = 1000, double max = 5000}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: max,
      pixels: 0,
      viewportDimension: viewport,
      axisDirection: AxisDirection.right,
      devicePixelRatio: 1,
    );

void main() {
  test('puts content at the viewport fraction', () {
    expect(scrollOffsetToPlace(3000, _metrics(), kFollowAt), 2350);
  });

  test('clamps to the scroll range', () {
    expect(scrollOffsetToPlace(100, _metrics(), kFollowAt), 0);
    expect(scrollOffsetToPlace(9000, _metrics(), kFollowAt), 5000);
  });
}
