import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../fakes/quiet_stories.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets(
    'onChange triggers one listPublished reload and state comes only from the reload',
    (tester) async {
      final stories = _Stories([_story('a', 2000, 'Before')]);
      final live = _Live();
      await tester.pumpWidget(_host(stories, live));
      await tester.pumpAndSettle();

      stories.rows = [_story('a', 2000, 'After')];
      live.emit();
      await tester.pumpAndSettle();

      expect(live.watchCount, 1);
      expect(live.familyId, 'fam-1');
      expect(stories.listCalls, 2);
      expect(find.text('After'), findsOneWidget);
      expect(find.text('Before'), findsNothing);
      expect(find.text(_Live.decoy), findsNothing);
    },
  );

  testWidgets('focus kept by storyId after reload', (tester) async {
    final stories = _Stories([
      _story('early', 1990, 'Early'),
      _story('focus', 2000, 'Focused'),
    ]);
    final live = _Live();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    stories.rows = [
      _story('early', 1990, 'Early'),
      _story('focus', 2000, 'Focused'),
      _story('later', 2010, 'Later'),
    ];
    live.emit();
    await tester.pumpAndSettle();

    _expectOnFocusLine(tester, 'Focused');
  });

  testWidgets('focus moves to nearest in time when focused story disappears', (
    tester,
  ) async {
    final stories = _Stories([
      _story('early', 1990, 'Early'),
      _story('focus', 2000, 'Focused'),
    ]);
    final live = _Live();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    stories.rows = [
      _story('early', 1990, 'Early'),
      _story('later', 2010, 'Later'),
    ];
    live.emit();
    await tester.pumpAndSettle();

    _expectOnFocusLine(tester, 'Later');
    expect(find.text('Focused'), findsNothing);
  });
}

void _expectOnFocusLine(WidgetTester tester, String text) {
  final tile = tester.getRect(find.widgetWithText(ThreadBeatTile, text));
  final view = tester.getRect(find.byType(ThreadView));
  expect(tile.center.dy, closeTo(view.center.dy, 1));
}

Widget _host(_Stories stories, _Live live) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      storiesApi: stories,
      familiesApi: TestFamilies([
        MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
      ]),
      currentUserId: () => 'user-1',
      live: live,
    ),
  );
}

class _Live implements TimelineLive {
  static const decoy = 'Wire payload';

  void Function()? onChange;
  String? familyId;
  var watchCount = 0;

  void emit() => onChange?.call();

  @override
  void watch({required String familyId, required void Function() onChange}) {
    watchCount += 1;
    this.familyId = familyId;
    this.onChange = onChange;
  }

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  @override
  void dispose() {}
}

class _Stories extends QuietStories {
  _Stories(this.rows);

  List<Story> rows;
  var listCalls = 0;

  @override
  Future<List<Story>> listPublished(String familyId) async {
    listCalls += 1;
    return rows;
  }
}

Story _story(String id, int year, String title) {
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
