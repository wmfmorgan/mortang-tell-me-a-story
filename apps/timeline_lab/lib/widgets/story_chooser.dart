import 'package:flutter/material.dart';

import '../model/lab_models.dart';

/// Lets a finger pick one of several stories that share a tap target, such
/// as a stacked rail cluster or a multi-story swimlane cell. Resolves to the
/// chosen id, or null when dismissed.
Future<String?> showStoryChooser(
  BuildContext context, {
  required Offset globalPosition,
  required List<LabStory> stories,
  required LabDataset dataset,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final at = overlay.globalToLocal(globalPosition);
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      at & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final s in stories)
        PopupMenuItem<String>(
          key: Key('chooser-${s.id}'),
          value: s.id,
          child: Text(
            '${s.title} · ${dataset.dateLabel(s)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
