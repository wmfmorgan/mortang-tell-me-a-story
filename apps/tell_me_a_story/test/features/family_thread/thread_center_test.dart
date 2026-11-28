import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/family_thread/thread_center.dart';

void main() {
  test('centre offset is top padding plus prefix sum plus half the row minus half the viewport', () {
    const extents = [56.0, 88.0, 200.0];
    final offsets = ThreadCenter.prefixSums(extents);
    const viewport = 400.0;
    final top = ThreadCenter.topPad(viewport, extents.first);
    final raw = top + offsets[2] + extents[2] / 2 - viewport / 2;
    final expected = raw.clamp(0.0, ThreadCenter.maxScroll(extents, viewport));
    expect(
      ThreadCenter.centreOffset(
        index: 2,
        extents: extents,
        offsets: offsets,
        viewport: viewport,
      ),
      closeTo(expected, 0.001),
    );
    expect(offsets[2], 56 + 88);
  });

  test('top aligned card sits 24 below the thread top', () {
    const extents = [800.0];
    final offset = ThreadCenter.centreOffset(
      index: 0,
      extents: extents,
      offsets: const [0],
      viewport: 400,
      alignCardTop: 32,
      alignViewportY: 24,
    );
    expect(offset, 8);
    expect(32 - offset, 24);
  });

  test('nearest row skips landmark and non-matching rows', () {
    const extents = [56.0, 44.0, 100.0, 80.0];
    final offsets = ThreadCenter.prefixSums(extents);
    final nearest = ThreadCenter.nearestRow(
      offset: 0,
      extents: extents,
      offsets: offsets,
      viewport: 300,
      eligible: (index) => index >= 2,
    );
    expect(nearest, 2);
  });
}
