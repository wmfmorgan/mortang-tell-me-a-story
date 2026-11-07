import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/lab_app.dart';
import 'package:timeline_lab/lab_controller.dart';
import 'package:timeline_lab/playback/playback_controller.dart';

Future<(LabController, PlaybackController)> _pump(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = LabController();
  addTearDown(c.dispose);
  await tester.pumpWidget(LabApp(useGoogleFonts: false, controller: c));
  await tester.pumpAndSettle();
  return (c, tester.widget<LabHome>(find.byType(LabHome)).playback);
}

FocusNode _search(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('filter-search'))).focusNode!;

Future<void> _cmdF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Space plays and pauses; → steps to the oldest story', (
    tester,
  ) async {
    final (c, pb) = await _pump(tester, const Size(1280, 800));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pb.playing, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pb.playing, isFalse);

    pb.stop();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(pb.current, same(c.entries.first.story));
  });

  testWidgets('⌘F focuses search; Space then types instead of playing', (
    tester,
  ) async {
    final (_, pb) = await _pump(tester, const Size(1280, 800));
    await _cmdF(tester);
    expect(_search(tester).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(pb.playing, isFalse);
  });

  testWidgets('⌘F below the sidebar breakpoint opens the drawer first', (
    tester,
  ) async {
    await _pump(tester, const Size(744, 1133));
    await _cmdF(tester);
    expect(find.byKey(const Key('filters-drawer')), findsOneWidget);
    expect(_search(tester).hasFocus, isTrue);
  });

  testWidgets('Esc closes the selected story', (tester) async {
    final (c, _) = await _pump(tester, const Size(1280, 800));
    c.select(c.entries.last.story.id);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(c.selectedStoryId, isNull);
  });
}
