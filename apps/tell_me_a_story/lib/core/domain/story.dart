import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';

part 'story.freezed.dart';

@freezed
abstract class Story with _$Story {
  const factory Story({
    required String id,
    required String familyId,
    required String authorId,
    String? title,
    String? body,

    /// Date only; null until the author sets one.
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    @Default(StoryDatePrecision.day) StoryDatePrecision datePrecision,
    DateTime? createdAt,
    String? placeId,
    required StoryStatus status,
    DateTime? publishedAt,
    @Default([]) List<String> personIds,
    @Default(0) int photoCount,
    String? placeLabel,

    /// Id and name for each tagged person. [personNames] stays for name search.
    @Default([]) List<({String id, String name})> people,
    @Default([]) List<String> personNames,
    String? authorDisplayName,
    String? authorAvatarPath,
    @Default(0) int commentCount,
    @Default(0) int perspectiveCount,
    @Default([]) List<String> photoPaths,

    /// `places.address`, trimmed. Null when the embed is missing or blank.
    String? placeAddress,

    /// `story_people.person_id` to `people.user_id`, only when both are non-empty.
    @Default({}) Map<String, String> personUserIds,
  }) = _Story;

  const Story._();

  /// Start date of a published story. A published row always has one.
  DateTime get publishedStart {
    final start = timeframeStart;
    if (start == null) {
      throw StateError('published story $id is missing a start date');
    }
    return start;
  }
}

/// Whitespace-only titles are stored as null so a saved title can be cleared.
String? storedStoryTitle(String? title) {
  if (title == null) return null;
  final trimmed = title.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void ensureValidDraftSave({required DateTime? timeframeStart}) {
  if (timeframeStart == null) {
    throw ArgumentError.value(
      timeframeStart,
      'timeframeStart',
      'must be set before save draft',
    );
  }
}

/// Start of the Latest window. A story at this instant is included.
DateTime latestPublishedCutoff(DateTime now, {int withinDays = 7}) {
  return now.toUtc().subtract(Duration(days: withinDays));
}

/// Published rows with `published_at` inside the window, newest first.
List<Story> latestShelf(
  Iterable<Story> stories, {
  required DateTime now,
  int withinDays = 7,
  int limit = 3,
}) {
  final cutoff = latestPublishedCutoff(now, withinDays: withinDays);
  final rows = [
    for (final story in stories)
      if (story.status == StoryStatus.published &&
          story.publishedAt != null &&
          !story.publishedAt!.toUtc().isBefore(cutoff))
        story,
  ];
  rows.sort((a, b) {
    final byTime = b.publishedAt!.compareTo(a.publishedAt!);
    if (byTime != 0) return byTime;
    return b.id.compareTo(a.id);
  });
  if (rows.length <= limit) return rows;
  return rows.sublist(0, limit);
}

/// Oldest first: start, precision, created_at, id. Newest-first is the reverse.
int compareStories(Story a, Story b) {
  final aStart = a.timeframeStart;
  final bStart = b.timeframeStart;
  if (aStart == null || bStart == null) {
    if (aStart == null && bStart != null) return 1;
    if (aStart != null && bStart == null) return -1;
  } else {
    final start = DateTime(
      aStart.year,
      aStart.month,
      aStart.day,
    ).compareTo(DateTime(bStart.year, bStart.month, bStart.day));
    if (start != 0) return start;
  }
  final precision = a.datePrecision.index.compareTo(b.datePrecision.index);
  if (precision != 0) return precision;
  final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final created = aCreated.compareTo(bCreated);
  if (created != 0) return created;
  return a.id.compareTo(b.id);
}
