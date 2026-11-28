import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_band.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('opens at Browse centred on newest story', (tester) async {
    await tester.pumpWidget(
      _host([
        _story('old', 1990, 'Older'),
        _story('first', 1996, 'First'),
        _story('second', 1996, 'Second'),
        _story('new', 2004, 'Newest'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsNothing);
    expect(find.text('1996'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);

    final tile = tester.getRect(find.widgetWithText(ThreadBeatTile, 'Newest'));
    final view = tester.getRect(find.byType(ThreadView));
    expect(tile.center.dy, closeTo(view.center.dy, 1));
  });

  testWidgets('only on-screen beats are built', (tester) async {
    final stories = [
      for (var year = 1700; year < 2000; year++)
        _story('s$year', year, 'S$year'),
    ];

    await tester.pumpWidget(_host(stories));
    await tester.pumpAndSettle();

    expect(find.text('S1700', skipOffstage: false), findsNothing);
    expect(find.text('S1999'), findsOneWidget);
  });

  testWidgets('band uses sageTint and a 2px terracotta spine', (tester) async {
    await tester.pumpWidget(_host([_story('one', 1980, 'One')]));
    await tester.pumpAndSettle();

    final band = find.descendant(
      of: find.byKey(const ValueKey('y1980')),
      matching: find.byType(ThreadBand),
    );
    expect(tester.getSize(band).width, 24);
    expect(
      find.descendant(
        of: band,
        matching: find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == sageTint,
        ),
      ),
      findsOneWidget,
    );
    final spine = find.descendant(
      of: band,
      matching: find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == albumTerracotta,
      ),
    );
    expect(tester.getSize(spine).width, 2);
  });

  testWidgets('list semantics label is Family Thread, N stories', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _story('1', 1980, 'One'),
        _story('2', 1990, 'Two'),
        _story('3', 2000, 'Three'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Family Thread, 3 stories'), findsOneWidget);
  });

  testWidgets('list semantics label is Family Thread, 1 story', (tester) async {
    await tester.pumpWidget(_host([_story('1', 1980, 'One')]));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Family Thread, 1 story'), findsOneWidget);
  });

  testWidgets(
    'a jump from newest to oldest lands the target on the focus line',
    (tester) async {
      final stories = [
        for (var year = 1800; year <= 2000; year += 10)
          _story('s$year', year, 'S$year'),
      ];
      await tester.pumpWidget(_host(stories));
      await tester.pumpAndSettle();
      _expectCentred(tester, 'S2000');

      await tester.pumpWidget(_host(stories, focusStoryId: 's1800'));
      await tester.pumpAndSettle();

      _expectCentred(tester, 'S1800');
      expect(find.text('S2000'), findsNothing);
    },
  );

  testWidgets('density change keeps the focused beat on the focus line', (
    tester,
  ) async {
    final stories = [_story('old', 1980, 'Old'), _story('new', 2004, 'Newest')];
    await tester.pumpWidget(_host(stories, focusStoryId: 'new'));
    await tester.pumpAndSettle();
    _expectCentred(tester, 'Newest');

    await tester.pumpWidget(
      _host(stories, focusStoryId: 'new', density: FamilyThreadDensity.read),
    );
    await tester.pumpAndSettle();
    _expectCentred(tester, 'Newest');
  });

  testWidgets(
    'landmark row is 56 before the first beat of each decade in browse and read and never takes focus',
    (tester) async {
      final stories = [
        _story('old', 1982, 'Old'),
        _story('mid', 1994, 'Mid'),
        _story('new', 2004, 'Newest'),
      ];
      await tester.pumpWidget(_host(stories, focusStoryId: 'mid'));
      await tester.pumpAndSettle();
      _expectLandmark(tester, 1980, before: 'Old');
      _expectLandmark(tester, 1990, before: 'Mid');
      _expectLandmark(tester, 2000, before: 'Newest');
      _expectCentred(tester, 'Mid');

      await tester.pumpWidget(
        _host(stories, focusStoryId: 'mid', density: FamilyThreadDensity.read),
      );
      await tester.pumpAndSettle();
      _expectLandmark(tester, 1990, before: 'Mid');
      _expectCentred(tester, 'Mid');

      await tester.pumpWidget(
        _host(
          stories,
          focusStoryId: 'mid',
          density: FamilyThreadDensity.overview,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('landmark-1980')), findsNothing);
      expect(find.byKey(const ValueKey('landmark-1990')), findsNothing);
    },
  );

  testWidgets('a focused card keeps its state across a re-anchor', (
    tester,
  ) async {
    final stories = [_story('old', 1980, 'Old'), _story('new', 2004, 'Newest')];
    await tester.pumpWidget(_host(stories, focusStoryId: 'new'));
    await tester.pumpAndSettle();
    final kept = tester.element(find.byKey(const ValueKey('y2004')));

    await tester.pumpWidget(_host(stories, focusStoryId: 'old'));
    await tester.pumpAndSettle();

    expect(tester.element(find.byKey(const ValueKey('y2004'))), same(kept));
    _expectCentred(tester, 'Old');
  });

  testWidgets('1000 story jump from newest to oldest', (tester) async {
    final stories = [
      for (var i = 0; i < 1000; i++) _story('s$i', 1000 + i, 'S$i'),
    ];
    await tester.pumpWidget(_host(stories));
    final open = await _framesUntilCentred(tester, 'S999');
    expect(open.centred, isTrue);
    expect(find.text('S0', skipOffstage: false), findsNothing);

    await tester.pumpWidget(_host(stories, focusStoryId: 's0'));
    final jump = await _framesUntilCentred(tester, 'S0');
    final built = find
        .byType(ThreadBeatTile, skipOffstage: false)
        .evaluate()
        .length;
    final line =
        'P4 jumpFrames=${jump.frames} jumpMs=${jump.ms} '
        'openFrames=${open.frames} builtAfterJump=$built '
        'target=2 frames';
    debugPrint(line);
    expect(jump.centred, isTrue);
    expect(find.text('S500', skipOffstage: false), findsNothing);
    expect(built, lessThan(40));
  });
}

Future<({int frames, int ms, bool centred})> _framesUntilCentred(
  WidgetTester tester,
  String text,
) async {
  final watch = Stopwatch()..start();
  var frames = 1;
  var centred = _isCentred(tester, text);
  while (!centred && frames < 8) {
    await tester.pump();
    frames += 1;
    centred = _isCentred(tester, text);
  }
  return (frames: frames, ms: watch.elapsedMilliseconds, centred: centred);
}

bool _isCentred(WidgetTester tester, String text) {
  final tiles = find.widgetWithText(ThreadBeatTile, text);
  if (tiles.evaluate().isEmpty) return false;
  final tile = tester.getRect(tiles);
  final view = tester.getRect(find.byType(ThreadView));
  return (tile.center.dy - view.center.dy).abs() <= 1;
}

void _expectCentred(WidgetTester tester, String text) {
  final tile = tester.getRect(find.widgetWithText(ThreadBeatTile, text));
  final view = tester.getRect(find.byType(ThreadView));
  expect(tile.center.dy, closeTo(view.center.dy, 1));
}

void _expectLandmark(
  WidgetTester tester,
  int decade, {
  required String before,
}) {
  final mark = find.byKey(ValueKey('landmark-$decade'));
  expect(tester.getSize(mark).height, 56);
  final markRect = tester.getRect(mark);
  final beat = tester.getRect(find.widgetWithText(ThreadBeatTile, before));
  expect(markRect.bottom, lessThanOrEqualTo(beat.top + 1));
  final view = tester.getRect(find.byType(ThreadView));
  expect((markRect.center.dy - view.center.dy).abs(), greaterThan(1));
}

Widget _host(
  List<Story> stories, {
  String? focusStoryId,
  FamilyThreadDensity density = FamilyThreadDensity.browse,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(
      body: ThreadView(
        stories: stories,
        focusStoryId: focusStoryId,
        density: density,
      ),
    ),
  );
}

Story _story(String id, int year, String title) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    title: title,
  );
}
