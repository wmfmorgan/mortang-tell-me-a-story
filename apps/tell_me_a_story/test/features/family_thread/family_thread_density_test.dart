import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets(
    'density radio group labelled Density with three selectable stops',
    (tester) async {
      await tester.pumpWidget(_host(_rows([threadStory('a', 2004, 'Kept')])));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Density'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);

      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Showing Overview'), findsOneWidget);

      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);

      await tester.tap(find.text('Browse'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
    },
  );

  testWidgets('changing density keeps the focus story on the focus line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _rows([
          threadStory('old', 1980, 'Old'),
          threadStory('mid', 2001, 'Mid'),
          threadStory('new', 2004, 'Newest'),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, '2000s · 2 stories');

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');
  });

  testWidgets('read to browse to overview and back returns the same story', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _rows([
          threadStory('old', 1980, 'Old'),
          threadStory('new', 2004, 'Newest'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, '2000s · 1 story');

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');
  });

  testWidgets('a density change anchors on the scrolled focus', (tester) async {
    await tester.pumpWidget(
      _host(
        _rows([
          threadStory('old', 1980, 'Old'),
          threadStory('mid', 2000, 'Mid'),
          threadStory('new', 2010, 'Newest'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Old');

    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Old');
  });

  testWidgets('a long read title does not overflow', (tester) async {
    final title = List.filled(40, 'carried').join(' ');
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: ThreadView(
            stories: [threadStory('a', 2004, title)],
            density: FamilyThreadDensity.read,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('carried'), findsWidgets);
  });

  testWidgets('announces Showing Overview', (tester) async {
    await tester.pumpWidget(_host(_rows([threadStory('a', 2004, 'Kept')])));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Showing Overview'), findsNothing);
    await tester.tap(find.text('Overview'));
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Overview'), findsOneWidget);
  });

  testWidgets('reduced motion swaps instantly', (tester) async {
    await tester.pumpWidget(
      _host(_rows([threadStory('a', 2004, 'Kept')]), animations: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Overview'));
    await tester.pump();

    expect(find.text('2000s · 1 story'), findsOneWidget);
    expect(_opacity(tester, find.text('2000s · 1 story')), 1);
  });

  testWidgets(
    'overview caption reads {Family name} · stories carried down the years',
    (tester) async {
      await tester.pumpWidget(_host(_rows([threadStory('a', 2004, 'Kept')])));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      expect(find.text('Ada · stories carried down the years'), findsOneWidget);
      expect(find.bySemanticsLabel('2000s, 1 story'), findsOneWidget);
    },
  );

  testWidgets('density disabled while loading', (tester) async {
    final pending = Completer<List<Story>>();
    final stories = ThreadStories(const [], pending: pending.future);
    await tester.pumpWidget(_host(stories));

    expect(find.text('Overview'), findsOneWidget);
    await tester.tap(find.text('Overview'));
    await tester.pump();

    pending.complete([threadStory('a', 2004, 'Kept')]);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Showing Overview'), findsNothing);
    expect(find.text('Kept'), findsOneWidget);
    expect(find.textContaining('carried down the years'), findsNothing);
  });
}

double _opacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  tester.element(finder).visitAncestorElements((element) {
    final render = element.renderObject;
    if (render is RenderAnimatedOpacity) {
      opacity = render.opacity.value;
      return false;
    }
    return true;
  });
  return opacity;
}

ThreadStories _rows(List<Story> rows) => ThreadStories(rows);

class _QuietThreadLive implements TimelineLive {
  @override
  void watch({required String familyId, required void Function() onChange}) {}

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  @override
  void dispose() {}
}

Widget _host(ThreadStories stories, {bool animations = true}) {
  return _frame(
    animations: animations,
    page: FamilyThreadPage(
      storiesApi: stories,
      familiesApi: _families,
      currentUserId: () => 'user-1',
      live: _QuietThreadLive(),
    ),
  );
}

Widget _frame({required Widget page, bool animations = true}) {
  return MaterialApp(
    theme: albumTheme(),
    builder: (context, child) {
      final data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(disableAnimations: !animations),
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: page,
  );
}

final _families = TestFamilies([
  MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
]);
