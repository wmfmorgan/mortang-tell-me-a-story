import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/theme/lab_theme.dart';
import 'package:timeline_lab/widgets/story_chooser.dart';

void main() {
  testWidgets('lists every story at 44 pt+ and resolves to the tapped one', (
    tester,
  ) async {
    final d = generateDataset();
    final stories = d.stories.take(3).toList();
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => chosen = await showStoryChooser(
                  context,
                  globalPosition: const Offset(100, 100),
                  stories: stories,
                  dataset: d,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final s in stories) {
      final item = find.byKey(Key('chooser-${s.id}'));
      expect(item, findsOneWidget);
      expect(tester.getSize(item).height, greaterThanOrEqualTo(LabTarget.min));
    }
    await tester.tap(find.byKey(Key('chooser-${stories[1].id}')));
    await tester.pumpAndSettle();
    expect(chosen, stories[1].id);
  });
}
