import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';

/// A timeline view with nothing to draw: [message], and an optional action
/// under it. Callers pass approved copy (O2), for example C9 for an empty
/// tree, or C17 with its "Clear filters" action.
class EmptyTimeline extends StatelessWidget {
  const EmptyTimeline({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null));

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Center(
      key: const Key('empty-timeline'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (label != null) ...[
            const SizedBox(height: AlbumSpace.s),
            TextButton(
              key: const Key('empty-action'),
              onPressed: onAction,
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
