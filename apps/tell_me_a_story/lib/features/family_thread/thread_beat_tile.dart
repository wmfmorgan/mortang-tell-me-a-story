import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/photos_api.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import 'decade_mosaic.dart';
import 'family_thread_copy.dart';
import 'hollow_dot.dart';
import 'stitch_ring.dart';
import 'story_card.dart';
import 'thread_beat.dart';
import 'thread_filter.dart';
import 'thread_focus.dart';
import 'thread_photo_cache.dart';
import 'year_medallion.dart';

class ThreadBeatTile extends StatelessWidget {
  const ThreadBeatTile({
    super.key,
    required this.beat,
    required this.focusStoryId,
    this.columnWidth,
    this.distance = 0,
    this.ringToken = 0,
    this.onBeat,
    this.onCard,
    this.onOpen,
    this.onMore,
    this.filter = ThreadFilter.cleared,
    this.photos,
    this.cache,
  });

  final ThreadBeat beat;
  final String? focusStoryId;

  /// Side column width passed to the focused card.
  final double? columnWidth;
  final int distance;
  final int ringToken;
  final void Function({required bool focused})? onBeat;
  final VoidCallback? onCard;
  final VoidCallback? onOpen;
  final VoidCallback? onMore;
  final ThreadFilter filter;
  final PhotosGateway Function()? photos;
  final ThreadPhotoCache? cache;

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
      fit: StackFit.loose,
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
        columnWidth: columnWidth ?? 0,
        ink: ink,
        semanticsLabel: _label(),
        showBody: true,
        onCard: onCard,
        onOpen: onOpen,
        photos: photos,
        cache: cache,
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
        leading: _mosaic(decade),
      ),
      final YearBeat year => _YearContents(
        beat: year,
        focusStoryId: focusStoryId,
        ink: ink,
        leading: _medallion(year),
      ),
      final StoryBeat story => _ReadContents(beat: story, ink: ink),
    };
  }

  Widget _yearCard(YearBeat year, Color ink) {
    final card = ThreadFocus.browseCardStory(year, focusId: focusStoryId);
    return StoryCard(
      story: card,
      columnWidth: columnWidth ?? 0,
      ink: ink,
      semanticsLabel: _storyLabel(year.year, card),
      moreLabel: onMore == null ? null : _yearMore(year, card),
      onYear: onBeat == null ? null : () => onBeat!(focused: true),
      onCard: onCard,
      onMore: onMore,
      onOpen: onOpen,
      photos: photos,
      cache: cache,
    );
  }

  Widget _medallion(YearBeat beat) {
    return _ImageFade(
      distance: distance,
      child: YearMedallion(
        beat: beat,
        filter: filter,
        photos: photos,
        cache: cache,
      ),
    );
  }

  Widget _mosaic(DecadeBeat beat) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: _ImageFade(
        distance: distance,
        child: DecadeMosaic(
          stories: beat.stories,
          filter: filter,
          photos: photos,
          cache: cache,
        ),
      ),
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
    required this.leading,
  });

  final DecadeBeat beat;
  final Color ink;
  final ThreadFilter filter;
  final Widget leading;

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
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearContents extends StatelessWidget {
  const _YearContents({
    required this.beat,
    required this.focusStoryId,
    required this.ink,
    required this.leading,
  });

  final YearBeat beat;
  final String? focusStoryId;
  final Color ink;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final story = ThreadFocus.browseCardStory(beat, focusId: focusStoryId);
    final title = story.title?.trim() ?? '';
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label: _beatLabel(beat.year, title, story),
      excludeSemantics: true,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(child: _copy(theme, title)),
        ],
      ),
    );
  }

  Widget _copy(TextTheme theme, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        mainAxisSize: MainAxisSize.min,
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
  final photos = story.photoPaths.length;
  if (photos > 0) parts.add(FamilyThreadCopy.photoCount(photos));
  return parts.join(', ');
}

class _ImageFade extends StatelessWidget {
  const _ImageFade({required this.distance, required this.child});

  final int distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    // P3b forbids Opacity. The thread test rejects that widget.
    return FadeTransition(
      opacity: AlwaysStoppedAnimation<double>(
        reduced ? 1 : _imageOpacity(distance),
      ),
      child: child,
    );
  }
}

double _imageOpacity(int distance) {
  return switch (distance) {
    0 => 1,
    1 => 0.6,
    _ => 0.3,
  };
}
