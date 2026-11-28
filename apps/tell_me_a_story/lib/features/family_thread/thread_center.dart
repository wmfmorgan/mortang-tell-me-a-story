int nearestOnScreen({
  required List<({int index, double centerY})> built,
  required double focusLineY,
  required bool Function(int index) eligible,
}) {
  var best = -1;
  var bestDistance = double.infinity;
  for (final row in built) {
    if (!eligible(row.index)) continue;
    final distance = (row.centerY - focusLineY).abs();
    if (distance < bestDistance) {
      best = row.index;
      bestDistance = distance;
    }
  }
  return best;
}
