import '../../data/stories_api.dart';
import '../timeline/timeline_zoom.dart' hide decadeStartYear;
import 'river_density.dart';
import 'river_filter.dart';

/// One stop on the spine. Oldest stories sit first inside the beat.
class RiverBeat {
  const RiverBeat({
    required this.id,
    required this.anchorYear,
    required this.stories,
    required this.matches,
  });

  final String id;
  final int anchorYear;
  final List<Story> stories;
  final bool matches;
}

List<RiverBeat> buildRiverBeats({
  required List<Story> stories,
  required RiverDensity density,
  required RiverFilter filter,
}) {
  final ordered = [...publishedStories(stories)]..sort(compareStories);
  return switch (density) {
    RiverDensity.overview => _byDecade(ordered, filter),
    RiverDensity.browse => _byYear(ordered, filter),
    RiverDensity.read => [
      for (final story in ordered) _storyBeat(story, filter),
    ],
  };
}

List<RiverBeat> _byDecade(List<Story> ordered, RiverFilter filter) {
  final grouped = <int, List<Story>>{};
  for (final story in ordered) {
    final start = decadeStartYear(story.publishedStart);
    (grouped[start] ??= []).add(story);
  }
  final years = grouped.keys.toList()..sort();
  return [
    for (final year in years)
      RiverBeat(
        id: 'decade-$year',
        anchorYear: year,
        stories: grouped[year]!,
        matches: grouped[year]!.any(filter.matches),
      ),
  ];
}

List<RiverBeat> _byYear(List<Story> ordered, RiverFilter filter) {
  final grouped = <int, List<Story>>{};
  for (final story in ordered) {
    final year = story.publishedStart.year;
    (grouped[year] ??= []).add(story);
  }
  final years = grouped.keys.toList()..sort();
  return [
    for (final year in years)
      RiverBeat(
        id: 'year-$year',
        anchorYear: year,
        stories: grouped[year]!,
        matches: grouped[year]!.any(filter.matches),
      ),
  ];
}

RiverBeat _storyBeat(Story story, RiverFilter filter) {
  return RiverBeat(
    id: 'story-${story.id}',
    anchorYear: story.publishedStart.year,
    stories: [story],
    matches: filter.matches(story),
  );
}

int beatIndexFor(List<RiverBeat> beats, String storyId) {
  final index = beats.indexWhere(
    (beat) => beat.stories.any((story) => story.id == storyId),
  );
  return index < 0 ? 0 : index;
}

String storyIdForBeat(RiverBeat beat, String currentId, List<Story> all) {
  if (beat.stories.any((story) => story.id == currentId)) return currentId;
  Story? current;
  for (final story in all) {
    if (story.id == currentId) current = story;
  }
  if (current == null) return beat.stories.last.id;
  return nearestStoryByDate(beat.stories, current.publishedStart).id;
}

Story nearestStoryByDate(List<Story> stories, DateTime when) {
  var best = stories.first;
  var bestDelta = 1 << 62;
  for (final story in stories) {
    final delta = story.publishedStart.difference(when).inDays.abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = story;
    }
  }
  return best;
}

Story riverLead(RiverBeat beat, String focusId) {
  for (final story in beat.stories) {
    if (story.id == focusId) return story;
  }
  return beat.stories.last;
}

double riverBeatOpacity(int distance, {required bool reducedMotion}) {
  if (reducedMotion || distance <= 0) return 1;
  if (distance == 1) return 0.6;
  return 0.3;
}

double riverBeatShift(int distance, {required bool reducedMotion}) {
  if (reducedMotion || distance <= 0) return 0;
  return distance * 6;
}

String riverBeatSemantics({
  required RiverBeat beat,
  required RiverDensity density,
  required String focusId,
}) {
  if (!beat.matches) return _missLabel(riverLead(beat, focusId));
  return switch (density) {
    RiverDensity.overview => _clusterLabel(beat),
    RiverDensity.browse => riverMedallionLabel(riverLead(beat, focusId)),
    RiverDensity.read => riverMedallionLabel(beat.stories.first),
  };
}

String _missLabel(Story story) {
  final title = storyTitle(story);
  final year = story.publishedStart.year;
  return "$title, $year, doesn't match filters";
}

String _clusterLabel(RiverBeat beat) {
  final count = countWord(beat.stories.length, 'story', 'stories');
  return '${beat.anchorYear}s, $count';
}

String riverDecadeLine(RiverBeat beat) {
  final count = countWord(beat.stories.length, 'story', 'stories');
  return '${beat.anchorYear}s · $count';
}

String riverOverviewCaption(String familyName) {
  return 'The $familyName Family · stories carried down the years';
}

String riverMedallionLabel(Story story) {
  final parts = <String>['${story.publishedStart.year}', storyTitle(story)];
  final place = story.placeLabel?.trim();
  if (place != null && place.isNotEmpty) parts.add(place);
  if (story.personNames.isNotEmpty) parts.add(story.personNames.join(', '));
  final photos = story.photoPaths.length;
  parts.add(photos == 1 ? '1 photo' : '$photos photos');
  return parts.join(', ');
}

String riverScrubberLabel({
  required int oldestDecade,
  required int newestDecade,
  required int showingDecade,
}) {
  return 'Timeline scrubber, ${oldestDecade}s to ${newestDecade}s, '
      'showing ${showingDecade}s';
}

String riverPhotoAlt(Story story) {
  final count = story.photoPaths.length;
  if (count > 1) return '${storyTitle(story)}, $count photos';
  return storyTitle(story);
}

String riverFirstLine(String? body) {
  final text = (body ?? '').trim();
  if (text.isEmpty) return '';
  final line = text.split(RegExp(r'\r?\n')).first.trim();
  return line;
}

String riverInitial(Story story) {
  final title = storyTitle(story).trim();
  if (title.isEmpty) return '?';
  return title[0].toUpperCase();
}
