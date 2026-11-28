import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('plus and minus change density but not with ctrl or meta', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(ThreadStories([threadStory('a', 2004, 'Kept')])),
    );
    await tester.pumpAndSettle();

    await _withModifier(tester, LogicalKeyboardKey.controlLeft, const [
      LogicalKeyboardKey.equal,
      LogicalKeyboardKey.minus,
    ]);
    await _withModifier(tester, LogicalKeyboardKey.metaLeft, const [
      LogicalKeyboardKey.add,
      LogicalKeyboardKey.minus,
      LogicalKeyboardKey.digit0,
    ]);

    await _density(tester, LogicalKeyboardKey.equal, 'Showing Read');
    await _density(tester, LogicalKeyboardKey.minus, 'Showing Browse');
    await _density(tester, LogicalKeyboardKey.minus, 'Showing Overview');
    await _density(tester, LogicalKeyboardKey.add, 'Showing Browse');
  });

  testWidgets('plus ignored while a text field has focus', (tester) async {
    await tester.pumpWidget(
      _host(
        ThreadStories([
          threadStory('old', 1980, 'Old'),
          threadStory('new', 2004, 'Newest'),
        ]),
        field: true,
      ),
    );
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _send(tester, LogicalKeyboardKey.equal);
    await tester.pump();

    expect(find.bySemanticsLabel('Showing Read'), findsNothing);
    expectOnFocusLine(tester, 'Newest');
  });
  testWidgets('Up and Down move to the previous and next beat', (tester) async {
    await _pumpBeats(tester);

    expectOnFocusLine(tester, 'Newest');
    expect(find.bySemanticsLabel('Focused 1996, Tractor'), findsNothing);

    await _key(tester, LogicalKeyboardKey.arrowUp);
    expectOnFocusLine(tester, 'Tractor');
    expect(find.bySemanticsLabel('Focused 1996, Tractor'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.arrowDown);
    expectOnFocusLine(tester, 'Newest');
    expect(find.bySemanticsLabel('Focused 2004, Newest'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.arrowDown);
    expectOnFocusLine(tester, 'Newest');
  });
  testWidgets('Home and End jump to the first and last beat', (tester) async {
    await _pumpBeats(tester);
    expectOnFocusLine(tester, 'Newest');

    await _key(tester, LogicalKeyboardKey.home);
    expectOnFocusLine(tester, 'Old');
    expect(find.bySemanticsLabel('Focused 1980, Old'), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.end);
    expectOnFocusLine(tester, 'Newest');
    expect(find.bySemanticsLabel('Focused 2004, Newest'), findsOneWidget);
  });
  testWidgets('Reduced motion moves instantly', (tester) async {
    await _pumpBeats(tester, animations: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Tractor');
  });
}

Future<void> _pumpBeats(WidgetTester tester, {bool animations = true}) async {
  await tester.pumpWidget(
    _host(
      ThreadStories([
        threadStory('old', 1980, 'Old'),
        threadStory('tractor', 1996, 'Tractor'),
        threadStory('new', 2004, 'Newest'),
      ]),
      animations: animations,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await _send(tester, key);
  await tester.pumpAndSettle();
}

Future<void> _withModifier(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  List<LogicalKeyboardKey> keys,
) async {
  await tester.sendKeyDownEvent(modifier);
  for (final key in keys) {
    await _send(tester, key);
  }
  await tester.pump();
  expect(find.bySemanticsLabel('Showing Read'), findsNothing);
  expect(find.bySemanticsLabel('Showing Browse'), findsNothing);
  expect(find.bySemanticsLabel('Showing Overview'), findsNothing);
  await tester.sendKeyUpEvent(modifier);
}

Future<void> _density(
  WidgetTester tester,
  LogicalKeyboardKey key,
  String label,
) async {
  await _send(tester, key);
  await tester.pump();
  expect(find.bySemanticsLabel(label), findsOneWidget);
}

Future<bool> _send(WidgetTester tester, LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.add) {
    return tester.sendKeyEvent(
      key,
      platform: 'android',
      physicalKey: PhysicalKeyboardKey.numpadAdd,
    );
  }
  return tester.sendKeyEvent(key);
}

Widget _host(
  ThreadStories stories, {
  bool animations = true,
  bool field = false,
}) {
  final page = FamilyThreadPage(
    storiesApi: stories,
    familiesApi: _families,
    currentUserId: () => 'user-1',
    live: FakeTimelineLive(),
  );
  return MaterialApp(
    theme: albumTheme(),
    builder: (context, child) {
      final data = MediaQuery.of(context);
      return MediaQuery(
        data: data.copyWith(disableAnimations: !animations),
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: field
        ? Scaffold(
            body: Column(
              children: [
                const TextField(),
                Expanded(child: page),
              ],
            ),
          )
        : page,
  );
}

final _families = TestFamilies([
  MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
]);
