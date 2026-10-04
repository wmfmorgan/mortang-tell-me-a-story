import 'package:supabase_flutter/supabase_flutter.dart';

import 'stories_api.dart';

enum SearchSort { relevant, chronological, recentlyAdded }

class SearchRequest {
  const SearchRequest({
    required this.familyId,
    this.text = '',
    this.personIds = const [],
    this.placeId,
    this.rangeStart,
    this.rangeEnd,
    this.sort = SearchSort.relevant,
  });

  final String familyId;
  final String text;
  final List<String> personIds;
  final String? placeId;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final SearchSort sort;
}

class SearchRecord {
  const SearchRecord({required this.story, this.placeAddress});

  final Story story;
  final String? placeAddress;
}

/// Decade label for a story start, matching the 1900s–2020s capture chips.
String? decadeLabelFor(DateTime start) {
  final year = (start.year ~/ 10) * 10;
  if (year < 1900 || year > 2020) return null;
  return '${year}s';
}

/// Chip label for one decade or a span, using an en dash between the ends.
String decadeChipLabel(List<int> startYears) {
  if (startYears.isEmpty) return '';
  final sorted = [...startYears]..sort();
  if (sorted.length == 1) return '${sorted.first}s';
  return '${sorted.first}s–${sorted.last}s';
}

/// Inclusive overlap of the selected decade span.
(DateTime, DateTime)? decadeBounds(List<int> startYears) {
  if (startYears.isEmpty) return null;
  final sorted = [...startYears]..sort();
  return (DateTime(sorted.first, 1, 1), DateTime(sorted.last + 9, 12, 31));
}

SearchRecord searchRecordFromRow(Map<String, dynamic> json) {
  final places = json['places'];
  String? address;
  if (places is Map) {
    final raw = places['address'];
    if (raw is String && raw.trim().isNotEmpty) address = raw.trim();
  }
  return SearchRecord(story: Story.fromJson(json), placeAddress: address);
}

bool searchTextMatches(SearchRecord record, String text) {
  final needle = text.trim().toLowerCase();
  if (needle.isEmpty) return true;
  bool has(String? value) => (value ?? '').toLowerCase().contains(needle);
  final story = record.story;
  if (has(story.title) || has(story.body)) return true;
  if (has(story.placeLabel) || has(record.placeAddress)) return true;
  if (story.personNames.any((name) => name.toLowerCase().contains(needle))) {
    return true;
  }
  if ('${story.timeframeStart.year}'.contains(needle)) return true;
  final decade = decadeLabelFor(story.timeframeStart);
  return decade != null && decade.toLowerCase().contains(needle);
}

bool _dateOnOrBefore(DateTime a, DateTime b) {
  final left = DateTime(a.year, a.month, a.day);
  final right = DateTime(b.year, b.month, b.day);
  return !left.isAfter(right);
}

bool timeframeOverlaps(Story story, DateTime rangeStart, DateTime rangeEnd) {
  final storyEnd = story.timeframeEnd ?? story.timeframeStart;
  return _dateOnOrBefore(story.timeframeStart, rangeEnd) &&
      _dateOnOrBefore(rangeStart, storyEnd);
}

int _relevanceTier(SearchRecord record, String needle) {
  if (needle.isEmpty) return 0;
  bool has(String? value) => (value ?? '').toLowerCase().contains(needle);
  final story = record.story;
  if (has(story.title)) return 3;
  if (story.personNames.any((name) => name.toLowerCase().contains(needle)) ||
      has(story.placeLabel) ||
      has(record.placeAddress)) {
    return 2;
  }
  if (has(story.body) || '${story.timeframeStart.year}'.contains(needle)) {
    return 1;
  }
  final decade = decadeLabelFor(story.timeframeStart);
  if (decade != null && decade.toLowerCase().contains(needle)) return 1;
  return 0;
}

int _newestTimeframe(SearchRecord a, SearchRecord b) {
  return b.story.timeframeStart.compareTo(a.story.timeframeStart);
}

/// Published stories in [familyId] that match every active chip and the text.
List<SearchRecord> filterSearchRecords(
  List<SearchRecord> records,
  SearchRequest request,
) {
  final matched = records.where((record) {
    final story = record.story;
    if (story.status != StoryStatus.published) return false;
    if (story.familyId != request.familyId) return false;
    if (request.personIds.any((id) => !story.personIds.contains(id))) {
      return false;
    }
    if (request.placeId != null && story.placeId != request.placeId) {
      return false;
    }
    final start = request.rangeStart;
    final end = request.rangeEnd;
    if (start != null && end != null && !timeframeOverlaps(story, start, end)) {
      return false;
    }
    return searchTextMatches(record, request.text);
  }).toList();

  final needle = request.text.trim().toLowerCase();
  switch (request.sort) {
    case SearchSort.relevant:
      matched.sort((a, b) {
        final tier = _relevanceTier(
          b,
          needle,
        ).compareTo(_relevanceTier(a, needle));
        if (tier != 0) return tier;
        return _newestTimeframe(a, b);
      });
    case SearchSort.chronological:
      matched.sort(_newestTimeframe);
    case SearchSort.recentlyAdded:
      matched.sort((a, b) {
        final ap = a.story.publishedAt;
        final bp = b.story.publishedAt;
        if (ap == null && bp == null) return _newestTimeframe(a, b);
        if (ap == null) return 1;
        if (bp == null) return -1;
        final byPublished = bp.compareTo(ap);
        if (byPublished != 0) return byPublished;
        return _newestTimeframe(a, b);
      });
  }
  return matched;
}

abstract class SearchGateway {
  Future<List<SearchRecord>> search(SearchRequest request);
}

class SearchApi implements SearchGateway {
  SearchApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _select =
      'id, family_id, author_id, title, body, timeframe_start, timeframe_end, '
      'place_id, status, published_at, places(label, address), '
      'story_people(person_id, people(name)), profiles!author_id(display_name), '
      'photos(id, storage_path, sort_order)';

  @override
  Future<List<SearchRecord>> search(SearchRequest request) async {
    final rows = await _client
        .from('stories')
        .select(_select)
        .eq('family_id', request.familyId)
        .eq('status', 'published');
    final records = [
      for (final row in rows)
        searchRecordFromRow(Map<String, dynamic>.from(row)),
    ];
    return filterSearchRecords(records, request);
  }
}
