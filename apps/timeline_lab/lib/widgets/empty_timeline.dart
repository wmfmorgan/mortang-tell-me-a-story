import 'package:flutter/material.dart';

import '../theme/lab_theme.dart';

/// The only empty state: nothing left to draw after Hide-mode filtering.
class EmptyTimeline extends StatelessWidget {
  const EmptyTimeline({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('empty-timeline'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'No stories match these filters.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: LabSpace.s),
        TextButton(
          key: const Key('empty-clear'),
          onPressed: onClear,
          child: const Text('Clear filters'),
        ),
      ],
    ),
  );
}
