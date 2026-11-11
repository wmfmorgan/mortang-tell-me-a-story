import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/widgets/timeline/time_scale.dart';

/// A published story as the timeline views draw it: the app's [Story] plus
/// whether it matches the current filter. Unmatched entries are drawn
/// dimmed, never hidden (Q4).
class TimelineEntry {
  const TimelineEntry({required this.story, required this.matched});

  final Story story;
  final bool matched;

  String get id => story.id;

  /// Where the story sits on a [TimeScale]: its fractional start year.
  double get year => fractionalYear(story.publishedStart);
}

/// One entry per story, in the given order. With no [matches], every
/// entry matches.
List<TimelineEntry> timelineEntries(
  Iterable<Story> stories, {
  bool Function(Story story)? matches,
}) => [
  for (final s in stories)
    TimelineEntry(story: s, matched: matches?.call(s) ?? true),
];
