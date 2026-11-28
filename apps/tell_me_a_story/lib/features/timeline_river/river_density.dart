enum RiverDensity { overview, browse, read }

RiverDensity riverDensityStep(RiverDensity density, int delta) {
  const order = RiverDensity.values;
  final next = order.indexOf(density) + delta;
  if (next < 0) return order.first;
  if (next >= order.length) return order.last;
  return order[next];
}

RiverDensity? riverDensityNamed(String? raw) {
  for (final density in RiverDensity.values) {
    if (density.name == raw) return density;
  }
  return null;
}
