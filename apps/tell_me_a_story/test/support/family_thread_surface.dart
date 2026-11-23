import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../fakes/quiet_stories.dart';

class ThreadStories extends QuietStories {
  ThreadStories(this.rows, {this.pending});

  List<Story> rows;
  Future<List<Story>>? pending;

  @override
  Future<List<Story>> listPublished(String familyId) async {
    final pending = this.pending;
    if (pending != null) return pending;
    return rows;
  }
}

Story threadStory(String id, int year, String title) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
  );
}

void expectOnFocusLine(WidgetTester tester, String text) {
  final tile = tester.getRect(find.widgetWithText(ThreadBeatTile, text));
  final view = tester.getRect(find.byType(ThreadView));
  expect(tile.center.dy, closeTo(view.center.dy, 1));
}
