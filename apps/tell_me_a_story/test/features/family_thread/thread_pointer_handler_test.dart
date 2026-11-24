import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

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

    final held = _threadOffset(tester);
    await _ctrlWheel(
      tester,
      _threadAt(tester),
      const Offset(0, 80),
      at: const Duration(milliseconds: 200),
    );
    expect(_threadOffset(tester), held);
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Read'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Browse'), findsNothing);

    await _ctrlWheel(
      tester,
      _threadAt(tester),
      const Offset(0, 80),
      at: const Duration(milliseconds: 400),
    );
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

    await _pinch(tester, 0.5, Duration.zero);
    await _pinch(tester, 0.5, const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Overview'), findsNothing);

    await _key(tester, LogicalKeyboardKey.minus);
    expect(find.bySemanticsLabel('Showing Overview'), findsOneWidget);

    await _pinch(tester, 2, const Duration(milliseconds: 400));
    await _pinch(tester, 2, const Duration(milliseconds: 416));
    await tester.pump();
    expect(find.bySemanticsLabel('Showing Browse'), findsOneWidget);
    expect(find.bySemanticsLabel('Showing Read'), findsNothing);
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
  Offset delta, {
  Duration at = Duration.zero,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendEventToBinding(
    PointerScrollEvent(position: position, scrollDelta: delta, timeStamp: at),
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _pinch(WidgetTester tester, double scale, Duration at) {
  return tester.sendEventToBinding(
    PointerScaleEvent(position: _threadAt(tester), scale: scale, timeStamp: at),
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
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      storiesApi: _stories,
      familiesApi: _families,
      currentUserId: () => 'user-1',
      live: FakeTimelineLive(),
    ),
  );
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

FamilyThreadPage _page() {
  return FamilyThreadPage(
    storiesApi: _stories,
    familiesApi: _families,
    currentUserId: () => 'user-1',
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
