import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);

  Story story({
    required String id,
    DateTime? publishedAt,
    StoryStatus status = StoryStatus.published,
    String? title,
    DateTime? timeframeStart,
  }) {
    return Story(
      id: id,
      familyId: 'fam',
      authorId: 'author',
      title: title,
      status: status,
      publishedAt: publishedAt,
      timeframeStart: timeframeStart,
      datePrecision: StoryDatePrecision.year,
    );
  }

  test('latest shelf keeps published stories from the past 7 days', () {
    final rows = latestShelf([
      story(id: 'old', publishedAt: now.subtract(const Duration(days: 8))),
      story(id: 'week', publishedAt: now.subtract(const Duration(days: 6))),
      story(id: 'edge', publishedAt: latestPublishedCutoff(now)),
      story(id: 'blank', publishedAt: now.subtract(const Duration(days: 1))),
      story(id: 'draft', publishedAt: now, status: StoryStatus.draft),
      story(id: 'none', publishedAt: null),
    ], now: now);

    expect(rows.map((row) => row.id), ['blank', 'week', 'edge']);
    expect(rows.any((row) => row.title == 'Untitled'), isFalse);
  });

  test('latest shelf orders ties by id descending and stops at 3', () {
    final same = now.subtract(const Duration(days: 1));
    final rows = latestShelf([
      story(id: 'a', publishedAt: same),
      story(id: 'c', publishedAt: same),
      story(id: 'b', publishedAt: same),
      story(id: 'd', publishedAt: now),
    ], now: now);

    expect(rows.map((row) => row.id), ['d', 'c', 'b']);
  });
}
