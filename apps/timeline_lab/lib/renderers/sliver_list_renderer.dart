import 'package:flutter/material.dart';

import '../filter/timeline_filter.dart';
import '../playback/reveal.dart';
import '../theme/lab_theme.dart';
import '../widgets/story_card.dart';
import 'renderer_contract.dart';
import 'story_marker.dart';

/// A: newest-first `CustomScrollView`, one pinned header + lazy list per
/// decade.
class SliverListTimeline extends StatefulWidget {
  const SliverListTimeline({super.key, required this.data});

  final TimelineViewData data;

  @override
  State<SliverListTimeline> createState() => _SliverListTimelineState();
}

class _SliverListTimelineState extends State<SliverListTimeline> {
  final _scroll = ScrollController();
  final _registry = StoryContextRegistry();
  FollowCurrentStory? _follow;

  /// Position of each story in newest-first order, for scroll estimates.
  late Map<String, int> _rowOf;

  @override
  void initState() {
    super.initState();
    _index();
    _attach();
  }

  @override
  void didUpdateWidget(SliverListTimeline old) {
    super.didUpdateWidget(old);
    if (!identical(old.data.entries, widget.data.entries)) _index();
    if (old.data.playback != widget.data.playback) {
      _follow?.dispose();
      _attach();
    }
  }

  void _index() {
    final n = widget.data.entries.length;
    _rowOf = {
      for (final (i, e) in widget.data.entries.indexed) e.story.id: n - 1 - i,
    };
  }

  void _attach() {
    final pb = widget.data.playback;
    _follow = pb == null
        ? null
        : FollowCurrentStory(
            playback: pb,
            registry: _registry,
            scroll: _scroll,
            estimateFraction: (id) =>
                (_rowOf[id] ?? 0) / (_rowOf.length - 1).clamp(1, 1 << 30),
          );
  }

  @override
  void dispose() {
    _follow?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final groups = <int, List<TimelineEntry>>{};
    for (final e in data.entries.reversed) {
      (groups[e.story.decade] ??= []).add(e);
    }
    // Insertion order is already newest decade first.
    return NotificationListener<ScrollStartNotification>(
      onNotification: (n) => disableFollowOnUserScroll(n, data.playback),
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          for (final MapEntry(key: decade, value: entries) in groups.entries)
            SliverMainAxisGroup(
              slivers: [
                PinnedHeaderSliver(
                  child: _DecadeHeader(
                    decade: decade,
                    matched: entries.where((e) => e.matched).length,
                    count: entries.length,
                  ),
                ),
                SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) => RegisterStory(
                    registry: _registry,
                    storyId: entries[i].story.id,
                    child: RevealOpacity(
                      playback: data.playback,
                      storyId: entries[i].story.id,
                      child: _Row(entry: entries[i], data: data),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DecadeHeader extends StatelessWidget {
  const _DecadeHeader({
    required this.decade,
    required this.matched,
    required this.count,
  });

  final int decade;
  final int matched;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      key: Key('decade-header-$decade'),
      color: labParchment,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('${decade}s', style: theme.headlineSmall),
          const SizedBox(width: 12),
          Text('$matched of $count', style: theme.labelMedium),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.data});

  final TimelineEntry entry;
  final TimelineViewData data;

  @override
  Widget build(BuildContext context) {
    final s = entry.story;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      // The card sets the row height; the rail fills it. Not IntrinsicHeight
      // around a Row with a Flexible card: the Row measures the card's height
      // at the full spare width, but SizedBox lays it out at 280 pt, so a
      // title that wraps only at 280 pt overflows the bottom (24 pt at ≥744 pt).
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 2, color: labRule),
                StoryDot(
                  spec: MarkerSpec(
                    matched: entry.matched,
                    origin: isOrigin(s, data.dataset),
                    selected: s.id == data.selectedId,
                  ),
                ),
              ],
            ),
          ),
          // StoryCard is 280 pt wide via SizedBox; Align hands it a loose
          // max, so it shrinks only when the row can't fit.
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Align(
              alignment: Alignment.centerLeft,
              child: StoryCard(
                story: s,
                dataset: data.dataset,
                matched: entry.matched,
                selected: s.id == data.selectedId,
                onTap: () => data.onSelect(s.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
