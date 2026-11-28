abstract final class ThreadCenter {
  static double topPad(double viewport, double extent) {
    final pad = (viewport - extent) / 2;
    return pad > 0 ? pad : 0;
  }

  static double bottomPad(double viewport, double extent) =>
      topPad(viewport, extent);

  static List<double> prefixSums(List<double> extents) {
    final offsets = List<double>.filled(extents.length, 0);
    var sum = 0.0;
    for (var i = 0; i < extents.length; i++) {
      offsets[i] = sum;
      sum += extents[i];
    }
    return offsets;
  }

  static double maxScroll(List<double> extents, double viewport) {
    if (extents.isEmpty) return 0;
    var total = 0.0;
    for (final extent in extents) {
      total += extent;
    }
    final raw =
        topPad(viewport, extents.first) +
        bottomPad(viewport, extents.last) +
        total -
        viewport;
    return raw > 0 ? raw : 0;
  }

  static double centreOffset({
    required int index,
    required List<double> extents,
    required List<double> offsets,
    required double viewport,
    double? alignCardTop,
    double alignViewportY = 24,
  }) {
    if (extents.isEmpty || index < 0 || index >= extents.length) return 0;
    final top = topPad(viewport, extents.first);
    final raw = alignCardTop == null
        ? top + offsets[index] + extents[index] / 2 - viewport / 2
        : top + offsets[index] + alignCardTop - alignViewportY;
    return raw.clamp(0.0, maxScroll(extents, viewport)).toDouble();
  }

  static int nearestRow({
    required double offset,
    required List<double> extents,
    required List<double> offsets,
    required double viewport,
    required bool Function(int index) eligible,
  }) {
    final count = extents.length;
    if (count == 0) return 0;
    final focus = offset + viewport / 2;
    final top = topPad(viewport, extents.first);
    final probe = _probe(top, offsets, extents, focus);
    final right = _from(probe, 1, count, eligible);
    final left = _from(probe - 1, -1, count, eligible);
    return _closer(left, right, top, offsets, extents, focus);
  }

  static int _probe(
    double top,
    List<double> offsets,
    List<double> extents,
    double focus,
  ) {
    var lo = 0;
    var hi = extents.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_centre(top, offsets, extents, mid) < focus) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  static int? _from(
    int start,
    int step,
    int count,
    bool Function(int) eligible,
  ) {
    for (var i = start; step > 0 ? i < count : i >= 0; i += step) {
      if (eligible(i)) return i;
    }
    return null;
  }

  static int _closer(
    int? left,
    int? right,
    double top,
    List<double> offsets,
    List<double> extents,
    double focus,
  ) {
    if (right == null) return left ?? 0;
    if (left == null) return right;
    final rightDist = (_centre(top, offsets, extents, right) - focus).abs();
    final leftDist = (_centre(top, offsets, extents, left) - focus).abs();
    return rightDist < leftDist ? right : left;
  }

  static double _centre(
    double top,
    List<double> offsets,
    List<double> extents,
    int index,
  ) => top + offsets[index] + extents[index] / 2;
}
