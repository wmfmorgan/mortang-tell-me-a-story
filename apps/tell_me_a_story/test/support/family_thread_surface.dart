import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../fakes/quiet_stories.dart';

class ThreadStories extends QuietStories {
  ThreadStories(this.rows, {this.pending, this.origin, this.fail = false});

  List<Story> rows;
  Future<List<Story>>? pending;
  Story? origin;
  bool fail;
  var listCalls = 0;
  final getPublishedIds = <String>[];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    listCalls += 1;
    if (fail) throw const FormatException('load');
    final pending = this.pending;
    if (pending != null) return pending;
    return rows;
  }

  @override
  Future<Story?> getPublished(String storyId) async {
    getPublishedIds.add(storyId);
    return origin;
  }
}

class QuietTimelineLive implements TimelineLive {
  void Function()? onChange;
  String? familyId;
  var watchCount = 0;

  void emit() => onChange?.call();

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  @override
  void watch({required String familyId, required void Function() onChange}) {
    watchCount += 1;
    this.familyId = familyId;
    this.onChange = onChange;
  }

  @override
  void dispose() {}
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
