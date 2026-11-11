import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/timeline/empty_timeline.dart';

Future<void> _pump(WidgetTester tester, EmptyTimeline child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        builder: albumAppBuilder,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('shows the message and runs the action', (tester) async {
    var cleared = 0;
    await _pump(
      tester,
      EmptyTimeline(
        message: 'No stories match these filters.',
        actionLabel: 'Clear filters',
        onAction: () => cleared++,
      ),
    );
    expect(find.byKey(const Key('empty-timeline')), findsOneWidget);
    expect(find.text('No stories match these filters.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('empty-action')));
    await tester.pumpAndSettle();
    expect(cleared, 1);
  });

  testWidgets('without an action it shows the message alone', (tester) async {
    await _pump(
      tester,
      const EmptyTimeline(message: 'No stories in this family tree yet.'),
    );
    expect(find.text('No stories in this family tree yet.'), findsOneWidget);
    expect(find.byKey(const Key('empty-action')), findsNothing);
  });
}
