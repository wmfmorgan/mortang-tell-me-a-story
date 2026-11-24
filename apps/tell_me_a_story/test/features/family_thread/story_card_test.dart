import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/stitch_ring.dart';
import 'package:tell_me_a_story/features/family_thread/thread_keyboard.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('decade tap at overview opens browse', (tester) async {
    await tester.pumpWidget(_plain(_pair()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2000s · 1 story'));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Newest');
    expect(find.text('2000s · 1 story'), findsNothing);
    expect(find.text('Kept the letter'), findsNothing);
  });

  testWidgets('unfocused year snaps and opens its card', (tester) async {
    await tester.pumpWidget(_plain(_pair(barnBody: 'Barn letter')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1990'));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Barn');
    expect(find.text('Barn letter'), findsNothing);
    expect(find.text('Open story'), findsOneWidget);
  });

  testWidgets('focused year drills to read', (tester) async {
    await tester.pumpWidget(_plain(_pair()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('thread-year')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);
    expect(find.text('Kept the letter'), findsOneWidget);
    expectOnFocusLine(tester, 'Newest');
  });

  testWidgets('{k} more in {year} opens Read on the next story', (
    tester,
  ) async {
    await tester.pumpWidget(_plain(_year()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1996'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 more in 1996'));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Second');
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);
    expect(find.text('Second letter'), findsOneWidget);
  });

  testWidgets('card or Open story opens the reader', (tester) async {
    await tester.pumpWidget(_router(_pair()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(find.text('new'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open story'));
    await tester.pumpAndSettle();
    expect(find.text('new'), findsOneWidget);
  });

  testWidgets('unfocused read card snaps and expands', (tester) async {
    await tester.pumpWidget(_plain(_pair(barnBody: 'Barn letter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Barn'));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Barn');
    expect(find.text('Barn letter'), findsOneWidget);
  });

  testWidgets('focused read card opens the reader', (tester) async {
    await tester.pumpWidget(_router(_pair()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();

    expect(find.text('new'), findsOneWidget);
  });

  testWidgets('enter drills one level, not straight to the reader', (
    tester,
  ) async {
    await tester.pumpWidget(_plain(_pair()));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);
    expect(find.text('Kept the letter'), findsOneWidget);
    expect(find.text('Open story'), findsOneWidget);
    expect(find.byKey(const Key('reader-back')), findsNothing);
  });

  testWidgets('back from reader keeps density focus and scroll', (
    tester,
  ) async {
    await tester.pumpWidget(_router(_span()));
    await tester.pumpAndSettle();
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();
    final offset = _offset(tester);

    await tester.tap(find.text('Open story'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reader-back')));
    await tester.pumpAndSettle();

    expect(find.text('mid'), findsNothing);
    expectOnFocusLine(tester, 'Mid');
    expect(find.text('Mid letter'), findsOneWidget);
    expect(_offset(tester), closeTo(offset, 0.5));
  });

  testWidgets(
    'card button takes focus and Enter activates it, not drill-down',
    (tester) async {
      await tester.pumpWidget(_router(_pair()));
      await tester.pumpAndSettle();

      await _tab(tester);
      expect(_buttonFocused(tester), isTrue);
      _expectRing(tester);

      await _tab(tester, shift: true);
      expect(_threadFocused(tester), isTrue);

      await _tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('new'), findsOneWidget);
      expect(find.bySemanticsLabel('Showing Read'), findsNothing);
    },
  );

  testWidgets('arrow keys do nothing while a card control has focus', (
    tester,
  ) async {
    await tester.pumpWidget(_plain(_pair()));
    await tester.pumpAndSettle();
    await _tab(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_buttonFocused(tester), isTrue);
    expectOnFocusLine(tester, 'Newest');
  });

  testWidgets('thread keys still fire when the thread has focus', (
    tester,
  ) async {
    await tester.pumpWidget(_plain(_pair()));
    await tester.pumpAndSettle();

    await _key(tester, LogicalKeyboardKey.arrowUp);
    expectOnFocusLine(tester, 'Barn');

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);
  });

  testWidgets('back restores focus to the thread node on the same story', (
    tester,
  ) async {
    await tester.pumpWidget(_router(_pair()));
    await tester.pumpAndSettle();
    await _tab(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader-back')));
    await tester.pumpAndSettle();

    expect(_threadFocused(tester), isTrue);
    expect(_buttonFocused(tester), isFalse);
    expectOnFocusLine(tester, 'Newest');
    expect(find.byType(StitchRing), findsOneWidget);
    expect(
      tester.widget<StitchRing>(find.byType(StitchRing)).key,
      const ValueKey<int>(1),
    );
  });
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

bool _threadFocused(WidgetTester tester) {
  return tester
      .widget<Focus>(
        find.descendant(
          of: find.byType(ThreadKeyboard),
          matching: find.byWidgetPredicate(
            (widget) => widget is Focus && widget.autofocus,
          ),
        ),
      )
      .focusNode!
      .hasPrimaryFocus;
}

bool _buttonFocused(WidgetTester tester) {
  return tester
      .widget<TextButton>(find.byKey(const Key('open-story')))
      .focusNode!
      .hasPrimaryFocus;
}

void _expectRing(WidgetTester tester) {
  final ring = tester.widget<Container>(
    find.byKey(const Key('open-story-ring')),
  );
  final border = (ring.decoration! as BoxDecoration).border! as Border;
  expect(ring.padding, const EdgeInsets.all(2));
  expect(border.top.width, 2);
  expect(border.top.color, albumTerracotta);
  expect(
    tester.getRect(find.byKey(const Key('open-story-ring'))).top,
    greaterThan(tester.getRect(find.byType(AlbumHeader)).bottom),
  );
}

double _offset(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(FamilyThreadPage),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position.pixels;
}

Widget _plain(List<Story> stories) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      storiesApi: ThreadStories(stories),
      familiesApi: _families,
      currentUserId: () => 'user-1',
      live: FakeTimelineLive(),
    ),
  );
}

Widget _router(List<Story> stories) {
  return MaterialApp.router(
    theme: albumTheme(),
    routerConfig: GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => FamilyThreadPage(
            storiesApi: ThreadStories(stories),
            familiesApi: _families,
            currentUserId: () => 'user-1',
            live: FakeTimelineLive(),
          ),
        ),
        GoRoute(
          path: '/stories/:storyId',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text(state.pathParameters['storyId']!),
                TextButton(
                  key: const Key('reader-back'),
                  onPressed: () => context.pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

List<Story> _pair({String barnBody = ''}) {
  return [
    _story('barn', 1990, 'Barn', body: barnBody),
    _story('new', 2004, 'Newest', body: 'Kept the letter'),
  ];
}

List<Story> _year() {
  return [
    _story('first', 1996, 'First'),
    _story('second', 1996, 'Second', body: 'Second letter'),
    _story('third', 1996, 'Third'),
    _story('new', 2004, 'Newest'),
  ];
}

List<Story> _span() {
  return [
    _story('a', 1980, 'Old'),
    _story('b', 1988, 'Early'),
    _story('mid', 1996, 'Mid', body: 'Mid letter'),
    _story('c', 2000, 'Late'),
    _story('d', 2004, 'Newest'),
  ];
}

Story _story(String id, int year, String title, {String body = ''}) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    body: body.isEmpty ? null : body,
  );
}

final _families = TestFamilies([
  MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
]);
