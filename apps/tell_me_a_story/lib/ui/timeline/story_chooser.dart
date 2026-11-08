import 'package:flutter/material.dart';

import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/ui/story/story_date.dart';
import 'package:tell_me_a_story/ui/story/story_title.dart';

/// Lets the user pick one of several stories that share a tap target (for
/// example a stacked year under a finger). Resolves to the chosen id, or
/// null when dismissed.
Future<String?> showStoryChooser(
  BuildContext context, {
  required Offset globalPosition,
  required List<Story> stories,
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
            '${storyTitle(s)} · ${storyDateLabelFor(s)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
}
