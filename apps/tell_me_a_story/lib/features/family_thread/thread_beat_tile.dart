import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'family_thread_copy.dart';
import 'hollow_dot.dart';
import 'stitch_ring.dart';
import 'story_card.dart';
import 'thread_beat.dart';
import 'thread_filter.dart';
import 'thread_focus.dart';

class ThreadBeatTile extends StatelessWidget {
  const ThreadBeatTile({
    super.key,
    required this.beat,
    required this.focusStoryId,
    this.distance = 0,
    this.ringToken = 0,
    this.onBeat,
    this.onCard,
    this.onOpen,
    this.onMore,
    this.filter = ThreadFilter.cleared,
  });

  final ThreadBeat beat;
  final String? focusStoryId;
  final int distance;
  final int ringToken;
  final void Function({required bool focused})? onBeat;
  final VoidCallback? onCard;
  final VoidCallback? onOpen;
  final VoidCallback? onMore;
  final ThreadFilter filter;

  @override
  Widget build(BuildContext context) {
    if (!filter.matchesBeat(beat)) {
      return _HollowBeat(
        beat: beat,
        focusStoryId: focusStoryId,
        filter: filter,
      );
    }
    final ink = distance >= 2 ? albumInkDim : albumInk;
    return Stack(
      fit: StackFit.expand,
      children: [
        _main(ink),
        if (distance == 0)
          Positioned.fill(child: StitchRing(key: ValueKey<int>(ringToken))),
      ],
    );
  }

  Widget _main(Color ink) {
    final card = _focusedCard(ink);
    if (card != null) return card;
    return threadTap(
      _plain(ink),
      onBeat == null ? null : () => onBeat!(focused: distance == 0),
    );
  }

  Widget? _focusedCard(Color ink) {
    final beat = this.beat;
    return switch (beat) {
      final YearBeat year when distance == 0 => _yearCard(year, ink),
      StoryBeat(:final story) when distance == 0 => StoryCard(
        story: story,
        ink: ink,
        semanticsLabel: _label(),
        showBody: true,
        onCard: onCard,
        onOpen: onOpen,
      ),
      DecadeBeat() || YearBeat() || StoryBeat() => null,
    };
  }

  Widget _plain(Color ink) {
    final beat = this.beat;
    return switch (beat) {
      final DecadeBeat decade => _DecadeContents(
        beat: decade,
        ink: ink,
        filter: filter,
      ),
      final YearBeat year => _YearContents(
        beat: year,
        focusStoryId: focusStoryId,
        ink: ink,
      ),
      final StoryBeat story => _ReadContents(beat: story, ink: ink),
    };
  }

  Widget _yearCard(YearBeat year, Color ink) {
    final card = ThreadFocus.browseCardStory(year, focusId: focusStoryId);
    return StoryCard(
      story: card,
      ink: ink,
      semanticsLabel: _storyLabel(year.year, card),
      moreLabel: onMore == null ? null : _yearMore(year, card),
      onYear: onBeat == null ? null : () => onBeat!(focused: true),
      onCard: onCard,
      onMore: onMore,
      onOpen: onOpen,
    );
  }

  String _label() {
    final beat = this.beat;
    return switch (beat) {
      DecadeBeat() => FamilyThreadCopy.decadeBeat(
        beat.decadeStart,
        beat.stories.length,
      ),
      YearBeat() => _storyLabel(
        beat.year,
        ThreadFocus.browseCardStory(beat, focusId: focusStoryId),
      ),
      StoryBeat(:final story) => _storyLabel(story.publishedStart.year, story),
    };
  }
}

String _storyLabel(int year, Story story) {
  return _beatLabel(year, story.title?.trim() ?? '', story);
}

String? _yearMore(YearBeat beat, Story card) {
  final index = beat.stories.indexWhere((story) => story.id == card.id);
  final extra = beat.stories.length - index - 1;
  if (extra <= 0) return null;
  return FamilyThreadCopy.moreInYear(extra, beat.year);
}

class _HollowBeat extends StatelessWidget {
  const _HollowBeat({
    required this.beat,
    required this.focusStoryId,
    required this.filter,
  });

  final ThreadBeat beat;
  final String? focusStoryId;
  final ThreadFilter filter;

  @override
  Widget build(BuildContext context) {
    final story = ThreadFocus.representative(
      beat,
      previousFocusId: focusStoryId,
      filter: filter,
    );
    return Semantics(
      label: FamilyThreadCopy.nonMatch(
        story.title ?? '',
        story.publishedStart.year,
      ),
      excludeSemantics: true,
      child: const Center(child: HollowDot()),
    );
  }
}

class _DecadeContents extends StatelessWidget {
  const _DecadeContents({
    required this.beat,
    required this.ink,
    required this.filter,
  });

  final DecadeBeat beat;
  final Color ink;
  final ThreadFilter filter;

  @override
  Widget build(BuildContext context) {
    final total = beat.stories.length;
    final active = filter.isActive;
    final matched = active ? filter.countStories(beat.stories).n : total;
    final text = active
        ? FamilyThreadCopy.decadeFiltered(beat.decadeStart, matched, total)
        : FamilyThreadCopy.decadeLabel(beat.decadeStart, total);
    return Semantics(
      label: active
          ? text
          : FamilyThreadCopy.decadeBeat(beat.decadeStart, total),
      excludeSemantics: true,
      child: Text(
        text,
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
