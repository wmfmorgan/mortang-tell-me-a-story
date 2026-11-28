import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';
import '../../data/stories_api.dart';
import '../stories/story_date.dart';
import '../timeline/timeline_zoom.dart';
import 'timeline_v2_filter.dart';

/// Decades, years, and days. Misses stay in place as hollow, dim rows.
class TimelineV2Rails extends StatelessWidget {
  const TimelineV2Rails({
    super.key,
    required this.stories,
    required this.zoom,
    required this.filter,
    required this.onOpen,
  });

  final List<Story> stories;
  final TimelineZoom zoom;
  final TimelineV2Filter filter;
  final ValueChanged<Story> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = _newest(stories);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: albumSage.withValues(alpha: 0.45), width: 2),
        ),
      ),
      child: switch (zoom) {
        TimelineZoom.far => _DecadeRail(bands: decadeBands(rows), host: this),
        TimelineZoom.mid => _YearRail(groups: _yearGroups(rows), host: this),
        TimelineZoom.near => _DayRail(stories: rows, host: this),
      },
    );
  }
}

List<Story> _newest(Iterable<Story> stories) {
  final rows = publishedStories(stories).toList();
  rows.sort((a, b) => compareStories(b, a));
  return rows;
}

List<({int year, List<Story> stories})> _yearGroups(List<Story> stories) {
  final grouped = <int, List<Story>>{};
  for (final story in stories) {
    final start = story.timeframeStart;
    if (start == null) continue;
    (grouped[start.year] ??= []).add(story);
  }
  final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final year in years) (year: year, stories: grouped[year]!)];
}

class _DecadeRail extends StatelessWidget {
  const _DecadeRail({required this.bands, required this.host});

  final List<DecadeBand> bands;
  final TimelineV2Rails host;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final band in bands) ...[
          _GroupHeader(
            groupKey: Key('timeline-v2-decade-${band.startYear}'),
            label: band.label,
            stories: band.stories,
            filter: host.filter,
          ),
          for (final story in band.stories)
            _StoryLine(story: story, host: host),
        ],
      ],
    );
  }
}

class _YearRail extends StatelessWidget {
  const _YearRail({required this.groups, required this.host});

  final List<({int year, List<Story> stories})> groups;
  final TimelineV2Rails host;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final group in groups) ...[
          _GroupHeader(
            groupKey: Key('timeline-v2-year-${group.year}'),
            label: '${group.year}',
            stories: group.stories,
            filter: host.filter,
          ),
          for (final story in group.stories)
            _StoryLine(
              story: story,
              host: host,
              detail: storyDateLabelFor(story),
            ),
        ],
      ],
    );
  }
}

class _DayRail extends StatelessWidget {
  const _DayRail({required this.stories, required this.host});

  final List<Story> stories;
  final TimelineV2Rails host;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final story in stories) _DayCard(story: story, host: host),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.story, required this.host});

  final Story story;
  final TimelineV2Rails host;

  @override
  Widget build(BuildContext context) {
    final blurb = excerpt(story.body);
    final when = storyDateLabelFor(story);
    final detail = blurb.isEmpty ? when : '$when\n$blurb';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        key: Key('timeline-v2-day-${story.id}'),
        decoration: BoxDecoration(
          color: albumParchment,
          borderRadius: BorderRadius.circular(albumCardRadius),
          border: Border.all(color: albumPillBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _StoryLine(story: story, host: host, detail: detail),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.groupKey,
    required this.label,
    required this.stories,
    required this.filter,
  });

  final Key groupKey;
  final String label;
  final List<Story> stories;
  final TimelineV2Filter filter;

  @override
  Widget build(BuildContext context) {
    final filtering = filter.isActive;
    final matched = stories.where(filter.matches).length;
    final color = filtering && matched == 0 ? albumInkDim : albumInk;
    final style = TextStyle(
      color: color,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      key: groupKey,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          if (filtering)
            Text(
              TimelineV2Filter.decadeCount(matched, stories.length),
              style: style,
            ),
        ],
      ),
    );
  }
}

class _StoryLine extends StatelessWidget {
  const _StoryLine({required this.story, required this.host, this.detail});

  final Story story;
  final TimelineV2Rails host;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final hit = host.filter.matches(story);
    final color = hit ? albumInk : albumInkDim;
    return InkWell(
      onTap: () => host.onOpen(story),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hit ? Icons.circle : Icons.circle_outlined,
              key: Key('timeline-v2-dot-${story.id}'),
              size: 14,
              color: hit ? albumTerracotta : albumInkDim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storyTitle(story),
                    style: TextStyle(color: color, fontSize: 16),
                  ),
                  if (detail != null)
                    Text(detail!, style: TextStyle(color: color, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
