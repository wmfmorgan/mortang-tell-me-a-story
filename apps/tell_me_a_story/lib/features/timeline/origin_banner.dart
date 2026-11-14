import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';

class OriginBanner extends StatelessWidget {
  const OriginBanner({
    super.key,
    required this.familyName,
    required this.parentName,
    required this.onChoose,
    required this.onClose,
  });

  final String familyName;
  final String? parentName;
  final VoidCallback onChoose;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final parent = parentName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: DecoratedBox(
        key: const Key('timeline-origin-banner'),
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: albumSage.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Every timeline starts with a story. Set the origin story for $familyName.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: albumInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (parent != null)
                      TextButton(
                        key: const Key('timeline-origin-choose'),
                        onPressed: onChoose,
                        style: TextButton.styleFrom(
                          foregroundColor: albumSage,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Choose from $parent'),
                      )
                    else
                      Text(
                        'Open one of your stories and choose Set as origin for $familyName.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: albumInk),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                color: albumInk,
                tooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
