import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import '../timeline/timeline_zoom.dart' hide decadeStartYear;
import 'river_beat.dart';
import 'river_photos.dart';

/// Story card for Browse focus and Read beats.
class RiverStoryCard extends StatelessWidget {
  const RiverStoryCard({
    super.key,
    required this.story,
    required this.photos,
    required this.focused,
    required this.expanded,
    required this.onTap,
  });

  final Story story;
  final PhotosGateway? photos;
  final bool focused;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: albumParchment,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(albumCardRadius),
        side: BorderSide(color: albumSage.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(albumCardRadius),
        child: Padding(padding: const EdgeInsets.all(12), child: _body(theme)),
      ),
    );
  }

  Widget _body(TextTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RiverPhotos(story: story, photos: photos, fan: expanded),
        const SizedBox(height: 8),
        Text(
          storyTitle(story),
          key: focused ? const Key('river-focused-label') : null,
          style: theme.titleMedium,
        ),
        Text(storyDateLabelFor(story), style: theme.bodySmall),
        if (expanded) _excerpt(theme),
      ],
    );
  }

  Widget _excerpt(TextTheme theme) {
    final text = excerpt(story.body);
    if (text.isEmpty || text == riverFirstLine(story.body)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        key: const Key('river-excerpt'),
        style: theme.bodyMedium,
      ),
    );
  }
}
