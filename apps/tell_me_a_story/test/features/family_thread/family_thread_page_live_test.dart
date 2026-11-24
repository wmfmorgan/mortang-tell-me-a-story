import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('onChange triggers one listPublished reload', (tester) async {
    final stories = ThreadStories([threadStory('a', 2000, 'Before')]);
    final live = QuietTimelineLive();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    stories.rows = [threadStory('a', 2000, 'After')];
    live.emit();
    await tester.pumpAndSettle();

    expect(live.watchCount, 1);
    expect(live.familyId, 'fam-1');
    expect(stories.listCalls, 2);
    expect(find.text('After'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
  });

  testWidgets('reload keeps the story scrolled onto the focus line', (
    tester,
  ) async {
    final stories = ThreadStories([
      threadStory('early', 1990, 'Early'),
      threadStory('mid', 2000, 'Mid'),
      threadStory('new', 2010, 'Newest'),
    ]);
    final live = QuietTimelineLive();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Early');

    stories.rows = [
      threadStory('early', 1990, 'Early'),
      threadStory('mid', 2000, 'Mid'),
      threadStory('new', 2010, 'Newest'),
      threadStory('later', 2020, 'Later'),
    ];
    live.emit();
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Early');
  });

  testWidgets('returning to the route reloads once', (tester) async {
    final stories = ThreadStories([threadStory('a', 2000, 'Before')]);
    await tester.pumpWidget(_host(stories, QuietTimelineLive()));
    await tester.pumpAndSettle();
    stories.listCalls = 0;

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
    );
    await tester.pumpAndSettle();
    stories.rows = [threadStory('a', 2000, 'After')];
    navigator.pop();
    await tester.pumpAndSettle();

    expect(stories.listCalls, 1);
    expect(find.text('After'), findsOneWidget);
  });

  testWidgets('a failed reload keeps the loaded thread', (tester) async {
    final stories = ThreadStories([threadStory('a', 2000, 'Kept')]);
    final live = QuietTimelineLive();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    stories.fail = true;
    live.emit();
    await tester.pumpAndSettle();
    expect(find.text('Kept'), findsOneWidget);
    expect(find.text("Couldn't load stories."), findsNothing);

    stories
      ..fail = false
      ..rows = [threadStory('a', 2000, 'Again')];
    live.emit();
    await tester.pumpAndSettle();
    expect(find.text('Again'), findsOneWidget);
  });

  testWidgets('focus kept by storyId after reload', (tester) async {
    final stories = ThreadStories([
      threadStory('early', 1990, 'Early'),
      threadStory('focus', 2000, 'Focused'),
    ]);
    final live = QuietTimelineLive();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    stories.rows = [
      threadStory('early', 1990, 'Early'),
      threadStory('focus', 2000, 'Focused'),
      threadStory('later', 2010, 'Later'),
    ];
    live.emit();
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Focused');
  });

  testWidgets('focus moves to nearest in time when focused story disappears', (
    tester,
  ) async {
    final stories = ThreadStories([
      threadStory('early', 1990, 'Early'),
      threadStory('focus', 2000, 'Focused'),
    ]);
    final live = QuietTimelineLive();
    await tester.pumpWidget(_host(stories, live));
    await tester.pumpAndSettle();

    stories.rows = [
      threadStory('early', 1990, 'Early'),
      threadStory('later', 2010, 'Later'),
    ];
    live.emit();
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Later');
    expect(find.text('Focused'), findsNothing);
  });
}

Widget _host(ThreadStories stories, QuietTimelineLive live) {
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
