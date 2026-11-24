import 'dart:math' as math;

abstract final class ThreadCenter {
  static double pad(double viewport, double extent) {
    return ((viewport - extent) / 2).clamp(0.0, double.infinity);
  }

  static double centerOffset(
    int index,
    int count,
    double viewport,
    double extent,
  ) {
    if (count == 0) return 0;
    final inset = pad(viewport, extent);
    final raw = inset + index * extent + extent / 2 - viewport / 2;
    final maxScroll = math.max(0.0, inset * 2 + count * extent - viewport);
    return raw.clamp(0.0, maxScroll);
  }

  static int nearestIndex(
    double offset,
    int count,
    double viewport,
    double extent,
  ) {
    if (count <= 0 || extent <= 0) return 0;
    final inset = pad(viewport, extent);
    final center = offset + viewport / 2;
    return ((center - inset - extent / 2) / extent).round().clamp(0, count - 1);
  }
}
