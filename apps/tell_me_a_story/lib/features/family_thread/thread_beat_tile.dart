import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'family_thread_copy.dart';
import 'stitch_ring.dart';
import 'thread_beat.dart';
import 'thread_focus.dart';

class ThreadBeatTile extends StatelessWidget {
  const ThreadBeatTile({
    super.key,
    required this.beat,
    required this.focusStoryId,
    this.distance = 0,
  });

  final ThreadBeat beat;
  final String? focusStoryId;
  final int distance;

  @override
  Widget build(BuildContext context) {
    final ink = distance >= 2 ? albumInkDim : albumInk;
    final beat = this.beat;
    final contents = switch (beat) {
      final DecadeBeat decade => _DecadeContents(beat: decade, ink: ink),
      final YearBeat year => _YearContents(
        beat: year,
        focusStoryId: focusStoryId,
        ink: ink,
      ),
      final StoryBeat story => _ReadContents(beat: story, ink: ink),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        contents,
        if (distance == 0) const Positioned.fill(child: StitchRing()),
      ],
    );
  }
}

class _DecadeContents extends StatelessWidget {
  const _DecadeContents({required this.beat, required this.ink});

  final DecadeBeat beat;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final count = beat.stories.length;
    return Semantics(
      label: FamilyThreadCopy.decadeBeat(beat.decadeStart, count),
      excludeSemantics: true,
      child: Text(
        FamilyThreadCopy.decadeLabel(beat.decadeStart, count),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: ink),
      ),
    );
  }
}

class _YearContents extends StatelessWidget {
  const _YearContents({
    required this.beat,
    required this.focusStoryId,
    required this.ink,
  });

  final YearBeat beat;
  final String? focusStoryId;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final story = ThreadFocus.browseCardStory(beat, focusId: focusStoryId);
    final title = story.title?.trim() ?? '';
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label: _beatLabel(beat.year, title, story),
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${beat.year}', style: theme.labelLarge?.copyWith(color: ink)),
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.titleMedium?.copyWith(color: ink),
            ),
        ],
      ),
    );
  }
}

class _ReadContents extends StatelessWidget {
  const _ReadContents({required this.beat, required this.ink});

  final StoryBeat beat;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final story = beat.story;
    final title = story.title?.trim() ?? '';
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label: _beatLabel(story.publishedStart.year, title, story),
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.titleMedium?.copyWith(color: ink),
            ),
          Text(
            storyDateLabelFor(story),
            style: theme.labelLarge?.copyWith(color: ink),
          ),
        ],
      ),
    );
  }
}

String _beatLabel(int year, String title, Story story) {
  final parts = <String>['$year'];
  if (title.isNotEmpty) parts.add(title);
  final place = story.placeLabel?.trim();
  if (place != null && place.isNotEmpty) parts.add(place);
  final names = <String>[
    for (final person in story.people)
      if (person.name.trim().isNotEmpty) person.name.trim(),
  ];
  if (names.isNotEmpty) parts.add(names.join(', '));
  return parts.join(', ');
}
