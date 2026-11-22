import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import 'river_density.dart';

/// Overview, Browse, and Read as one radio group.
class RiverDensityPill extends StatelessWidget {
  const RiverDensityPill({
    super.key,
    required this.density,
    required this.onChanged,
  });

  final RiverDensity density;
  final ValueChanged<RiverDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: albumSage.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in RiverDensity.values) _segment(context, value),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, RiverDensity value) {
    final selected = value == density;
    final label = _label(value);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      child: TextButton(
        key: Key('river-density-${value.name}'),
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: selected ? albumTerracotta : albumParchment,
          foregroundColor: selected ? albumParchment : albumInk,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        onPressed: () => onChanged(value),
        child: ExcludeSemantics(child: Text(label)),
      ),
    );
  }
}

String _label(RiverDensity density) {
  return switch (density) {
    RiverDensity.overview => 'Overview',
    RiverDensity.browse => 'Browse',
    RiverDensity.read => 'Read',
  };
}
