import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('opens at Browse centred on newest story', (tester) async {
    await tester.pumpWidget(
      _host([
        _story('old', 1990, 'Older'),
        _story('first', 1996, 'First'),
        _story('second', 1996, 'Second'),
        _story('new', 2004, 'Newest'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsNothing);
    expect(find.text('1996'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);

    final tile = tester.getRect(find.widgetWithText(ThreadBeatTile, 'Newest'));
    final view = tester.getRect(find.byType(ThreadView));
    expect(tile.center.dy, closeTo(view.center.dy, 1));
  });

  testWidgets('only on-screen beats are built', (tester) async {
    final stories = [
      for (var year = 1700; year < 2000; year++)
        _story('s$year', year, 'S$year'),
    ];

    await tester.pumpWidget(_host(stories));
    await tester.pumpAndSettle();

    expect(find.text('S1700'), findsNothing);
    expect(find.text('S1999'), findsOneWidget);
    expect(find.byType(ThreadBeatTile), findsNWidgets(6));
  });

  testWidgets('band uses sageTint and a 2px terracotta spine', (tester) async {
    await tester.pumpWidget(_host([_story('one', 1980, 'One')]));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) {
        final decoration = widget is DecoratedBox ? widget.decoration : null;
        return decoration is BoxDecoration && decoration.color == sageTint;
      }),
      findsOneWidget,
    );
    final spine = tester.widget<Positioned>(
      find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.width == 2,
      ),
    );
    expect(spine.child, isA<ColoredBox>());
    expect((spine.child! as ColoredBox).color, albumTerracotta);
  });

  testWidgets('list semantics label is Family Thread, N stories', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host([
        _story('1', 1980, 'One'),
        _story('2', 1990, 'Two'),
        _story('3', 2000, 'Three'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Family Thread, 3 stories'), findsOneWidget);
  });
}

Widget _host(List<Story> stories) {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(body: ThreadView(stories: stories)),
  );
}

Story _story(String id, int year, String title) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    title: title,
  );
}
