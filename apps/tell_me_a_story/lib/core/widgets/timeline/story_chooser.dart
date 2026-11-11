import 'package:flutter/material.dart';

import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/widgets/story/story_date.dart';
import 'package:tell_me_a_story/core/widgets/story/story_title.dart';

/// Lets the user pick one of several stories that share a tap target (for
/// example a stacked year under a finger). The list opens under the C10
/// title `Stories here`, which picks nothing. Resolves to the chosen id, or
/// null when dismissed.
Future<String?> showStoryChooser(
  BuildContext context, {
  required Offset globalPosition,
  required List<Story> stories,
}) {
  // The root overlay always has a laid-out RenderBox while a menu can open.
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final at = overlay.globalToLocal(globalPosition);
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      at & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem<String>(
        key: const Key('chooser-title'),
        enabled: false,
        child: Builder(
          builder: (context) => Text(
            'Stories here',
            style: AlbumText.lane(Theme.of(context).textTheme),
          ),
        ),
      ),
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
