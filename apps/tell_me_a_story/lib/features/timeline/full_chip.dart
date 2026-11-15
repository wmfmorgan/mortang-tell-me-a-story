import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';

class FullChip extends StatelessWidget {
  const FullChip({
    super.key,
    required this.icon,
    required this.label,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontSize: 12, color: albumInk.withValues(alpha: 0.75));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? albumBlush : albumPaleRose,
        borderRadius: BorderRadius.circular(999),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textMax = constraints.maxWidth.isFinite
              ? (constraints.maxWidth - 26)
                    .clamp(0.0, constraints.maxWidth)
                    .toDouble()
              : double.infinity;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: albumInk.withValues(alpha: filled ? 0.85 : 0.7),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textMax),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
