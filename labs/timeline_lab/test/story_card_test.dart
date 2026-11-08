import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/model/lab_models.dart';
import 'package:timeline_lab/model/seed.dart';
import 'package:timeline_lab/theme/lab_theme.dart';
import 'package:timeline_lab/widgets/story_card.dart';

Future<void> _pumpCard(
  WidgetTester tester,
  LabStory s,
  LabDataset d, {
  bool matched = true,
  bool compact = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: labTheme(useGoogleFonts: false),
    home: Scaffold(
      body: Center(
        child: StoryCard(
          story: s,
          dataset: d,
          matched: matched,
          selected: false,
          compact: compact,
        ),
      ),
    ),
  ),
);

void main() {
  final d = generateDataset();

  testWidgets('dimmed card text sits exactly at the dim floor', (tester) async {
    final s = d.stories.firstWhere(
      (s) => s.personIds.isNotEmpty && s.placeId != null,
    );
    await _pumpCard(tester, s, d, matched: false);
    final texts = tester.widgetList<Text>(
      find.descendant(of: find.byType(StoryCard), matching: find.byType(Text)),
    );
    for (final t in texts) {
      expect(t.style!.color, labDimmedInk, reason: t.data);
    }
    expect(
      find.descendant(
        of: find.byType(StoryCard),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });

  testWidgets('compact titles keep the serif title role', (tester) async {
    final s = d.stories.first;
    await _pumpCard(tester, s, d, compact: true);
    final title = tester.widget<Text>(find.text(s.title));
    final theme = Theme.of(tester.element(find.byType(StoryCard))).textTheme;
    expect(title.style!.fontSize, theme.titleMedium!.fontSize);
  });

  testWidgets('origin stories carry an Origin pill, not only a border', (
    tester,
  ) async {
    final originId = d.families.values
        .map((f) => f.originStoryId)
        .whereType<String>()
        .first;
    await _pumpCard(tester, d.stories.firstWhere((s) => s.id == originId), d);
    expect(find.text('Origin'), findsOneWidget);
  });
}
