import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';

/// Shown when every story is outside the filter.
class RiverNoMatch extends StatelessWidget {
  const RiverNoMatch({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        key: const Key('timeline-river-no-match'),
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(albumCardRadius),
          border: Border.all(color: albumSage.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No stories match these filters.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
