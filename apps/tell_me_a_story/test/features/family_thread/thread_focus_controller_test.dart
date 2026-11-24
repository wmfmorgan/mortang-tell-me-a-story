import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/stitch_ring.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../support/family_thread_surface.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('snaps nearest beat after scroll end', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('old', 1980, 'Old'),
        threadStory('mid', 1996, 'Mid'),
        threadStory('new', 2004, 'Newest'),
      ]),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(_listCenter(tester));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pump();
    await tester.pump();
    final release = _offset(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _offset(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final at200 = _offset(tester);
    await tester.pumpAndSettle();

    expect(mid, greaterThan(_lesser(release, at200)));
    expect(mid, lessThan(_greater(release, at200)));
    expect(_offset(tester), closeTo(at200, 0.5));
    expectOnFocusLine(tester, 'Newest');
  });

  testWidgets('does not snap during an active drag', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('old', 1980, 'Old'),
        threadStory('mid', 1996, 'Mid'),
        threadStory('new', 2004, 'Newest'),
      ]),
    );
    await tester.pumpAndSettle();
    final start = _offset(tester);

    final gesture = await tester.startGesture(_listCenter(tester));
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();
    final held = _offset(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(held, isNot(closeTo(start, 8)));
    expect(_offset(tester), closeTo(held, 0.5));
    await gesture.up();
  });

  testWidgets('announces Focused 1996, Tractor', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('barn', 1990, 'Barn'),
        threadStory('tractor', 1996, 'Tractor'),
        threadStory('later', 2004, 'Later'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Focused 1996, Tractor'), findsNothing);

    await _drag(tester, const Offset(0, 90));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Focused 1996, Tractor'), findsOneWidget);
    expectOnFocusLine(tester, 'Tractor');
  });

  testWidgets('Focused 1990s, 3 stories', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('a', 1990, 'One'),
        threadStory('b', 1992, 'Two'),
        threadStory('c', 1995, 'Three'),
        threadStory('d', 2001, 'Later'),
      ], density: FamilyThreadDensity.overview),
    );
    await tester.pumpAndSettle();

    await _drag(tester, const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Focused 1990s, 3 stories'), findsOneWidget);
    expectOnFocusLine(tester, '1990s · 3 stories');
  });

  testWidgets('snaps onto the beat with reduced motion', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('old', 1980, 'Old'),
        threadStory('mid', 1996, 'Mid'),
        threadStory('new', 2004, 'Newest'),
      ], animations: false),
    );
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    final gesture = await tester.startGesture(_listCenter(tester));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expectOnFocusLine(tester, 'Mid');
    final landed = _offset(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_offset(tester), closeTo(landed, 0.5));
  });

  testWidgets('beats two away use albumInkDim text', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('far', 2002, 'Far'),
        threadStory('near', 2003, 'Near'),
        threadStory('focus', 2004, 'Focus'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(_color(tester, 'Far'), albumInkDim);
    expect(_color(tester, 'Near'), albumInk);
  });

  testWidgets('stitch ring drawn once then static', (tester) async {
    await tester.pumpWidget(_host([threadStory('a', 1996, 'Tractor')]));
    await tester.pump();
    expect(find.byType(StitchRing), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump(const Duration(milliseconds: 201));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(
      _host([threadStory('a', 1996, 'Tractor')], animations: false),
    );
    await tester.pump();
    expect(find.byType(StitchRing), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_host([threadStory('a', 1996, 'Tractor')]));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(StitchRing), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('no Opacity widget in the thread subtree', (tester) async {
    await tester.pumpWidget(
      _host([
        threadStory('old', 1980, 'Old'),
        threadStory('new', 2004, 'Newest'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ThreadView),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('read row fits at 1.3x text scale', (tester) async {
    final title = List.filled(40, 'carried').join(' ');
    await tester.pumpWidget(
      _host(
        [threadStory('a', 2004, title)],
        density: FamilyThreadDensity.read,
        textScaler: TextScaler.linear(1.3),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('carried'), findsWidgets);
  });

  testWidgets(
    'keeps the newer title on a settled year and reports the oldest from another year',
    (tester) async {
      final reported = <String>[];
      String? focusId = 'tractor';
      final stories = [
        _dated('barn', 1996, 1, 'Barn'),
        _dated('tractor', 1996, 6, 'Tractor'),
        threadStory('later', 2004, 'Later'),
      ];
      await tester.pumpWidget(
        _host(
          stories,
          focusStoryId: focusId,
          onFocusChanged: (id) {
            reported.add(id);
            focusId = id;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tractor'), findsOneWidget);
      expect(find.text('Barn'), findsNothing);

      await _drag(tester, const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(find.text('Tractor'), findsOneWidget);
      expect(reported, isEmpty);

      await tester.pumpWidget(
        _host(
          stories,
          focusStoryId: focusId,
          onFocusChanged: (id) {
            reported.add(id);
            focusId = id;
          },
        ),
      );
      await _drag(tester, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(reported, ['later']);

      await tester.pumpWidget(
        _host(
          stories,
          focusStoryId: focusId,
          onFocusChanged: (id) {
            reported.add(id);
            focusId = id;
          },
        ),
      );
      await _drag(tester, const Offset(0, 180));
      await tester.pumpAndSettle();

      expect(reported.last, 'barn');
      expect(find.text('Barn'), findsOneWidget);
      expect(find.text('Tractor'), findsNothing);
    },
  );
}

Future<void> _drag(WidgetTester tester, Offset delta) async {
  final gesture = await tester.startGesture(_listCenter(tester));
  await gesture.moveBy(delta);
  await tester.pump(const Duration(milliseconds: 70));
  await gesture.moveBy(Offset(0, delta.dy.sign));
  await tester.pump(const Duration(milliseconds: 70));
  await gesture.up();
}

Offset _listCenter(WidgetTester tester) {
  return tester.getCenter(find.byType(ListView));
}

double _offset(WidgetTester tester) {
  return tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
}

double _lesser(double a, double b) => a < b ? a : b;

double _greater(double a, double b) => a > b ? a : b;

Color? _color(WidgetTester tester, String title) {
  final tile = find.widgetWithText(ThreadBeatTile, title);
  return tester
      .widget<Text>(find.descendant(of: tile, matching: find.text(title)))
      .style
      ?.color;
}

Widget _host(
  List<Story> stories, {
  FamilyThreadDensity density = FamilyThreadDensity.browse,
  String? focusStoryId,
  ValueChanged<String>? onFocusChanged,
  bool animations = true,
  TextScaler? textScaler,
}) {
  return MaterialApp(
    theme: albumTheme(),
    builder: (context, child) {
      var data = MediaQuery.of(context);
      if (!animations) {
        data = data.copyWith(disableAnimations: true);
      }
      if (textScaler != null) data = data.copyWith(textScaler: textScaler);
      return MediaQuery(data: data, child: child!);
    },
    home: Scaffold(
      body: ThreadView(
        stories: stories,
        density: density,
        focusStoryId: focusStoryId,
        onFocusChanged: onFocusChanged,
      ),
    ),
  );
}

Story _dated(String id, int year, int month, String title) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, month, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
  );
}
