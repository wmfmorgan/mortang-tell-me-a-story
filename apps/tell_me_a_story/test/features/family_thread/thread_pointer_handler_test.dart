import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_pointer_handler.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() {
    FamilySelection.clear();
    _elapsed = Duration.zero;
  });

  testWidgets('handler pinch in then pinch out records -1 then +1', (
    tester,
  ) async {
    final steps = <int>[];
    var time = Duration.zero;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ThreadPointerHandler(
          now: () => time,
          onDensityDelta: steps.add,
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(ThreadPointerHandler));
    await tester.sendEventToBinding(
      PointerScaleEvent(position: center, scale: 0.5),
    );
    time += const Duration(milliseconds: 400);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendEventToBinding(
      PointerScaleEvent(position: center, scale: 2),
    );
    expect(steps, [-1, 1]);
  });

  testWidgets('wheel gap resets a partial accumulation', (tester) async {
    final steps = <int>[];
    var time = Duration.zero;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ThreadPointerHandler(
          now: () => time,
          onDensityDelta: steps.add,
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(ThreadPointerHandler));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await _wheel(tester, center, const Offset(0, -30));
    time += const Duration(milliseconds: 121);
    await _wheel(tester, center, const Offset(0, -30));
    expect(steps, isEmpty);
    await _wheel(tester, center, const Offset(0, -30));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(steps, [1]);
  });

  testWidgets('non positive scale holds the pinch', (tester) async {
    final steps = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ThreadPointerHandler(
          now: () => Duration.zero,
          onDensityDelta: steps.add,
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(ThreadPointerHandler));
    await _scale(tester, center, 0.9);
    await _scale(tester, center, 0);
    await _scale(tester, center, 0.9);
    expect(steps, [-1]);
  });

  testWidgets('ctrl wheel over thread steps density once and does not scroll', (
    tester,
  ) async {
    await _pump(tester);
    await _key(tester, LogicalKeyboardKey.minus);
    expect(find.bySemanticsLabel('Showing Overview'), findsOneWidget);

    final before = _threadOffset(tester);
    await _ctrlWheel(tester, _threadAt(tester), const Offset(0, -400));

    expect(_threadOffset(tester), before);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Read'), findsNothing);
  });

  testWidgets('second step blocked inside 300ms cooldown', (tester) async {
    await _pump(tester);
    await _ctrlWheel(tester, _threadAt(tester), const Offset(0, -80));
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);

    _elapse(const Duration(milliseconds: 200));
    final held = _threadOffset(tester);
    await _ctrlWheel(tester, _threadAt(tester), const Offset(0, 80));
    expect(_threadOffset(tester), held);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Browse'), findsNothing);

    _elapse(const Duration(milliseconds: 200));
    await _ctrlWheel(tester, _threadAt(tester), const Offset(0, 80));
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
  });

  testWidgets('ctrl wheel outside thread is not claimed', (tester) async {
    await tester.pumpWidget(_split());
    await tester.pumpAndSettle();

    final outside = find.byKey(const Key('outside-thread'));
    final before = _offsetOf(tester, outside);
    await _ctrlWheel(tester, tester.getCenter(outside), const Offset(0, 80));

    expect(_offsetOf(tester, outside), greaterThan(before));
    expect(find.bySemanticsLabel('Showing Read'), findsNothing);
    expect(find.bySemanticsLabel('Showing Overview'), findsNothing);
  });

  testWidgets('pinch in coarser, pinch out finer, one step per gesture', (
    tester,
  ) async {
    await _pump(tester);
    await _key(tester, LogicalKeyboardKey.equal);
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);

    await _pinch(tester, 0.5);
    await _pinch(tester, 0.5);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Overview'), findsNothing);

    await _key(tester, LogicalKeyboardKey.minus);
    expect(find.bySemanticsLabel('Showing Overview'), findsOneWidget);
    _elapse(const Duration(milliseconds: 400));

    await _pinch(tester, 2);
    await _pinch(tester, 2);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Read'), findsNothing);
  });

  testWidgets('card tap lands after a density change', (tester) async {
    final home = _page();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/stories/:storyId',
          builder: (_, state) =>
              Text('opened ${state.pathParameters['storyId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: albumTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await _key(tester, LogicalKeyboardKey.equal);
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);

    await _pinch(tester, 0.5);
    await _pinch(tester, 0.5);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(find.text('opened new'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.storyPath('new'));
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> _ctrlWheel(
  WidgetTester tester,
  Offset position,
  Offset delta,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendEventToBinding(
    PointerScrollEvent(position: position, scrollDelta: delta),
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _pinch(WidgetTester tester, double scale) {
  return tester.sendEventToBinding(
    PointerScaleEvent(position: _threadAt(tester), scale: scale),
  );
}

Future<void> _wheel(WidgetTester tester, Offset position, Offset delta) {
  return tester.sendEventToBinding(
    PointerScrollEvent(position: position, scrollDelta: delta),
  );
}

Future<void> _scale(WidgetTester tester, Offset position, double scale) {
  return tester.sendEventToBinding(
    PointerScaleEvent(position: position, scale: scale),
  );
}

Offset _threadAt(WidgetTester tester) {
  return tester.getCenter(find.byType(ThreadView));
}

double _threadOffset(WidgetTester tester) {
  return _offsetOf(tester, find.byType(ThreadView));
}

double _offsetOf(WidgetTester tester, Finder root) {
  final scrollable = find.descendant(
    of: root,
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable).position.pixels;
}

Widget _host() {
  return MaterialApp(theme: albumTheme(), home: _page());
}

Widget _split() {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 80,
            child: ListView.builder(
              key: const Key('outside-thread'),
              itemCount: 20,
              itemBuilder: (_, index) =>
                  SizedBox(height: 40, child: Text('row $index')),
            ),
          ),
          Expanded(child: _page()),
        ],
      ),
    ),
  );
}

var _elapsed = Duration.zero;

void _elapse(Duration duration) {
  _elapsed += duration;
}

FamilyThreadPage _page() {
  return FamilyThreadPage(
    storiesApi: _stories,
    familiesApi: _families,
    currentUserId: () => 'user-1',
    now: () => _elapsed,
    live: FakeTimelineLive(),
  );
}

final _stories = ThreadStories([
  threadStory('old', 1980, 'Old'),
  threadStory('mid', 1996, 'Tractor'),
  threadStory('new', 2004, 'Newest'),
]);

final _families = TestFamilies([
  MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
]);
