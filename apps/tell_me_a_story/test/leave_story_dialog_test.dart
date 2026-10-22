import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/navigation/leave_story_dialog.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('title, both body variants and button labels are exact', (
    tester,
  ) async {
    await _open(tester, family: 'Ada');
    expect(find.text('Leave this story?'), findsOneWidget);
    expect(
      find.text(
        "You have changes that aren't saved. Save them before switching to Ada?",
      ),
      findsOneWidget,
    );
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    await _open(tester);
    expect(find.text('Leave this story?'), findsOneWidget);
    expect(find.text("You have changes that aren't saved."), findsOneWidget);
    expect(find.textContaining('Save them before switching'), findsNothing);
  });

  testWidgets('buttons are right-aligned Stay, Discard, Save', (tester) async {
    await _logicalSize(tester, const Size(800, 600));
    await _open(tester);
    final stay = tester.getTopLeft(find.text('Stay'));
    final discard = tester.getTopLeft(find.text('Discard'));
    final save = tester.getTopLeft(find.text('Save'));
    expect(stay.dx, lessThan(discard.dx));
    expect(discard.dx, lessThan(save.dx));
    expect((stay.dy - discard.dy).abs(), lessThan(2));
    expect((discard.dy - save.dy).abs(), lessThan(2));
  });

  testWidgets('below 640 px buttons stack full-width Save, Discard, Stay', (
    tester,
  ) async {
    await _logicalSize(tester, const Size(600, 900));
    await _open(tester);
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    final discard = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Discard'),
    );
    final stay = tester.getRect(find.widgetWithText(TextButton, 'Stay'));
    expect(save.top, lessThan(discard.top));
    expect(discard.top, lessThan(stay.top));
    expect(save.width, greaterThan(300));
    expect((save.width - discard.width).abs(), lessThan(1));
    expect((discard.width - stay.width).abs(), lessThan(1));
  });
}

Future<void> _logicalSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _open(WidgetTester tester, {String? family}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: albumTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showLeaveStoryDialog(
                  context,
                  switchToFamilyName: family,
                  save: () async => false,
                  discard: () {},
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
