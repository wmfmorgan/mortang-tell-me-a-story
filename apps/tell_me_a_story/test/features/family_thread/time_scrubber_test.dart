import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/family_thread_open_state.dart';
import 'package:tell_me_a_story/data/family_thread_open_state_store.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';
import 'package:tell_me_a_story/features/family_thread/time_scrubber.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('each decade tick appears once in order', (tester) async {
    await tester.pumpWidget(
      _scrubber(
        stories: [
          threadStory('a', 1952, 'A'),
          threadStory('b', 1958, 'B'),
          threadStory('c', 1964, 'C'),
          threadStory('d', 2021, 'D'),
        ],
        focusId: 'd',
      ),
    );

    expect(_tickLabels(tester), ["'50s", "'60s", "'20s"]);
  });

  testWidgets("handle label shows the focused decade '90s", (tester) async {
    await tester.pumpWidget(
      _scrubber(
        stories: [
          threadStory('old', 1952, 'Old'),
          threadStory('focus', 1994, 'Focus'),
          threadStory('now', 2022, 'Now'),
        ],
        focusId: 'focus',
      ),
    );

    expect(
      tester.widget<Text>(find.byKey(const Key('scrubber-handle'))).data,
      "'90s",
    );
  });

  testWidgets(
    'tap jumps to nearest matching story in that decade without changing density',
    (tester) async {
      await tester.pumpWidget(
        _page([
          _person('far', 1951, 'Far', 'ada'),
          _person('mid', 1955, 'Mid', 'ada'),
          _person('late', 1959, 'Late', 'bea'),
          _person('now', 2022, 'Now', 'ada'),
        ], filter: const ThreadFilter(personIds: {'ada'})),
      );
      await tester.pumpAndSettle();

      expect(_density(tester), FamilyThreadDensity.browse);
      expectOnFocusLine(tester, 'Now');

      await tester.tap(find.text("'50s"));
      await tester.pumpAndSettle();

      expectOnFocusLine(tester, 'Mid');
      expect(_density(tester), FamilyThreadDensity.browse);
    },
  );

  testWidgets('drag moves thread and focus settles on release', (tester) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      _page([
        threadStory('early', 1952, 'Early'),
        threadStory('middle', 1994, 'Middle'),
        threadStory('now', 2022, 'Now'),
      ], store: store),
    );
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Now');

    final scrubber = tester.getRect(find.byKey(const Key('time-scrubber')));
    final gesture = await tester.startGesture(
      scrubber.bottomCenter - const Offset(0, 4),
    );
    await gesture.moveTo(scrubber.topCenter + const Offset(0, 4));
    await tester.pump();
    await tester.pump();

    expectOnFocusLine(tester, 'Early');
    expect(store.writes, isEmpty);

    await gesture.up();
    await tester.pump();

    expect(store.writes, ['early']);
    expectOnFocusLine(tester, 'Early');
    expect(_density(tester), FamilyThreadDensity.browse);
  });

  testWidgets(
    'slider label reads Timeline scrubber, 1950s to 2020s, showing 1990s',
    (tester) async {
      await tester.pumpWidget(
        _scrubber(
          stories: [
            threadStory('old', 1952, 'Old'),
            threadStory('focus', 1994, 'Focus'),
            threadStory('now', 2022, 'Now'),
          ],
          focusId: 'focus',
        ),
      );

      expect(
        find.bySemanticsLabel(
          'Timeline scrubber, 1950s to 2020s, showing 1990s',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('arrow moves one decade and page down moves two', (tester) async {
    final commits = <String>[];
    var focus = 'y1950';
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 56,
                height: 480,
                child: TimeScrubber(
                  stories: [
                    threadStory('y1950', 1950, 'A'),
                    threadStory('y1960', 1960, 'B'),
                    threadStory('y1970', 1970, 'C'),
                    threadStory('y1980', 1980, 'D'),
                  ],
                  focusStoryId: focus,
                  vertical: true,
                  onPreview: (_) {},
                  onCommit: (id) {
                    commits.add(id);
                    setState(() => focus = id);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('scrubber-handle')));
    await tester.pump();
    commits.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(commits, ['y1960']);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(commits, ['y1960', 'y1980']);
  });

  testWidgets('hides the scrubber when the family has no stories', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const []));
    await tester.pumpAndSettle();

    expect(find.byType(TimeScrubber), findsNothing);
    expect(find.byKey(const Key('time-scrubber')), findsNothing);
  });
}

List<String?> _tickLabels(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('scrubber-ticks')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data)
      .toList();
}

FamilyThreadDensity _density(WidgetTester tester) {
  return tester
      .widget<RadioGroup<FamilyThreadDensity>>(
        find.byType(RadioGroup<FamilyThreadDensity>),
      )
      .groupValue!;
}

Widget _scrubber({
  required List<Story> stories,
  required String focusId,
  ThreadFilter filter = ThreadFilter.cleared,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(
      body: SizedBox(
        width: 56,
        height: 480,
        child: TimeScrubber(
          stories: stories,
          filter: filter,
          focusStoryId: focusId,
          vertical: true,
          onPreview: (_) {},
          onCommit: (_) {},
        ),
      ),
    ),
  );
}

Widget _page(
  List<Story> stories, {
  _MemoryStore? store,
  ThreadFilter filter = ThreadFilter.cleared,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      storiesApi: ThreadStories(stories),
      familiesApi: TestFamilies.member(),
      openStateStore: store ?? _MemoryStore(),
      currentUserId: () => 'user-1',
      initialFilter: filter,
      live: FakeTimelineLive(),
    ),
  );
}

Story _person(String id, int year, String title, String personId) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    personIds: [personId],
  );
}

class _MemoryStore extends FamilyThreadOpenStateStore {
  final writes = <String>[];

  @override
  Future<FamilyThreadOpenState?> read({required String familyId}) async {
    return null;
  }

  @override
  Future<void> write({
    required String familyId,
    required FamilyThreadOpenState state,
  }) async {
    writes.add(state.storyId);
  }

  @override
  Future<void> remove({required String familyId}) async {}
}
