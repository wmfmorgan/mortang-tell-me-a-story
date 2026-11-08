import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/ui/timeline/story_chooser.dart';

Story _story(
  String id,
  String? title,
  DateTime start,
  StoryDatePrecision precision,
) => Story(
  id: id,
  familyId: 'root',
  authorId: 'u1',
  title: title,
  timeframeStart: start,
  datePrecision: precision,
  status: StoryStatus.published,
);

void main() {
  testWidgets('lists every story at 44 pt+ and resolves to the tapped one', (
    tester,
  ) async {
    final stories = [
      _story('a', 'The flood year', DateTime(1952), StoryDatePrecision.year),
      _story('b', 'First car', DateTime(1952, 6), StoryDatePrecision.month),
      _story('c', '  ', DateTime(1952, 6, 2), StoryDatePrecision.day),
    ];
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => chosen = await showStoryChooser(
                  context,
                  globalPosition: const Offset(100, 100),
                  stories: stories,
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
      expect(
        tester.getSize(item).height,
        greaterThanOrEqualTo(AlbumTarget.min),
      );
    }
    // Titles and dates as the rest of the app shows them (story_title.dart,
    // story_date.dart).
    expect(find.text('The flood year · 1952'), findsOneWidget);
    expect(find.text('First car · June 1952'), findsOneWidget);
    expect(find.text('Untitled · June 2, 1952'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chooser-b')));
    await tester.pumpAndSettle();
    expect(chosen, 'b');
  });

  testWidgets('heads the list with the C10 title, which picks nothing', (
    tester,
  ) async {
    final stories = [
      _story('a', 'Summer fair', DateTime(1962, 6, 3), StoryDatePrecision.day),
      _story('b', 'First car', DateTime(1962, 6, 20), StoryDatePrecision.day),
    ];
    var resolved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  await showStoryChooser(
                    context,
                    globalPosition: const Offset(100, 100),
                    stories: stories,
                  );
                  resolved = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final title = find.byKey(const Key('chooser-title'));
    expect(title, findsOneWidget);
    expect(
      find.descendant(of: title, matching: find.text('Stories here')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(title).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('chooser-a'))).dy),
    );
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chooser-a')), findsOneWidget);
    expect(resolved, isFalse);
  });
}
