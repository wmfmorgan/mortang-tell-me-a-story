import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/family_covers.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

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

  test('cover object path is the family id and a cover basename', () {
    expect(
      familyCoverObjectPath('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'PNG'),
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/cover.png',
    );
    expect(
      () => familyCoverObjectPath('not-a-uuid', 'jpg'),
      throwsA(isA<CoverPhotoException>()),
    );
    expect(
      () =>
          familyCoverObjectPath('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'gif'),
      throwsA(isA<CoverPhotoException>()),
    );
  });
}
