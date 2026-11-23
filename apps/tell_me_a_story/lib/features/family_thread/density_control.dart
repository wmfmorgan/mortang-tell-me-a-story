import 'package:flutter/material.dart';

import '../../data/family_thread_density.dart';
import 'family_thread_copy.dart';

class DensityControl extends StatelessWidget {
  const DensityControl({
    super.key,
    required this.density,
    required this.onChanged,
    this.enabled = true,
  });

  final FamilyThreadDensity density;
  final ValueChanged<FamilyThreadDensity> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: FamilyThreadCopy.densityGroup,
      child: RadioGroup<FamilyThreadDensity>(
        groupValue: density,
        onChanged: (value) {
          if (!enabled || value == null) return;
          onChanged(value);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final stop in FamilyThreadDensity.values)
              _Stop(stop: stop, enabled: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.stop,
    required this.enabled,
    required this.onChanged,
  });

  final FamilyThreadDensity stop;
  final bool enabled;
  final ValueChanged<FamilyThreadDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: InkWell(
        onTap: enabled ? () => onChanged(stop) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<FamilyThreadDensity>(value: stop, enabled: enabled),
            Text(
              FamilyThreadCopy.stopName(stop),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
