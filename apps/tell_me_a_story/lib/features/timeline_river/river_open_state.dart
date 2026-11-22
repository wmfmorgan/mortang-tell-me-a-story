import 'dart:convert';

import '../../data/stories_api.dart';
import '../timeline/timeline_zoom.dart' hide decadeStartYear;
import 'river_density.dart';

/// Last density and focused story for one family on this device.
class RiverOpenState {
  const RiverOpenState({
    required this.density,
    required this.storyId,
    required this.year,
  });

  final RiverDensity density;
  final String storyId;
  final int year;

  String encode() {
    return jsonEncode({
      'density': density.name,
      'storyId': storyId,
      'year': year,
    });
  }

  static RiverOpenState? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final json = _json(raw);
    if (json == null) return null;
    final density = riverDensityNamed(json['density'] as String?);
    final storyId = json['storyId'];
    final year = _year(json['year']);
    if (density == null || storyId is! String || storyId.isEmpty) return null;
    if (year == null) return null;
    return RiverOpenState(density: density, storyId: storyId, year: year);
  }
}

Map<String, Object?>? _json(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } on FormatException {
    return null;
  }
  return null;
}

int? _year(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return null;
}

/// Saved story when it is still published. Otherwise the nearest year.
RiverOpenState resolveRiverOpen({
  required List<Story> stories,
  required RiverOpenState? saved,
}) {
  final ordered = [...publishedStories(stories)]..sort(compareStories);
  if (ordered.isEmpty) {
    return const RiverOpenState(
      density: RiverDensity.browse,
      storyId: '',
      year: 0,
    );
  }
  if (saved == null) return _newest(ordered);
  for (final story in ordered) {
    if (story.id == saved.storyId) {
      return RiverOpenState(
        density: saved.density,
        storyId: story.id,
        year: story.publishedStart.year,
      );
    }
  }
  final nearest = nearestStoryByYear(ordered, saved.year);
  return RiverOpenState(
    density: saved.density,
    storyId: nearest.id,
    year: nearest.publishedStart.year,
  );
}

RiverOpenState _newest(List<Story> oldestFirst) {
  final story = oldestFirst.last;
  return RiverOpenState(
    density: RiverDensity.browse,
    storyId: story.id,
    year: story.publishedStart.year,
  );
}

/// Closest published year. A tie keeps the newer story.
Story nearestStoryByYear(List<Story> oldestFirst, int year) {
  var best = oldestFirst.first;
  var bestDelta = 1 << 30;
  for (final story in oldestFirst) {
    final delta = (story.publishedStart.year - year).abs();
    final newerTie =
        delta == bestDelta && story.publishedStart.isAfter(best.publishedStart);
    if (delta < bestDelta || newerTie) {
      bestDelta = delta;
      best = story;
    }
  }
  return best;
}
