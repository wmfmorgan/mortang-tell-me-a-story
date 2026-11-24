import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_copy.dart';
import 'package:tell_me_a_story/features/family_thread/hollow_dot.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../support/family_thread_surface.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('non-matching beat is a 12pt hollow dot and not tappable', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_gap(), filter: _ada));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(HollowDot)), const Size(12, 12));
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(HollowDot),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, anyOf(isNull, albumBackdropClear));
    expect(decoration.border?.top.width, greaterThan(0));

    await tester.tap(find.byType(HollowDot));
    await tester.pump();
    expect(find.text('opened'), findsNothing);

    await tester.tap(find.text('Newest'));
    await tester.pump();
    expect(find.text('opened'), findsOneWidget);
  });

  testWidgets(
    "non-match semantics reads <title>, <year>, doesn't match filters",
    (tester) async {
      await tester.pumpWidget(_host(_gap(), filter: _ada));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel("Skipped, 1996, doesn't match filters"),
        findsOneWidget,
      );
    },
  );

  testWidgets('snap and arrow keys skip non-matching beats', (tester) async {
    await tester.pumpWidget(_host(_gap(), filter: _ada));
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Kept');
    expect(find.bySemanticsLabel('Focused 1996, Skipped'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Newest');

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Kept');

    await _drag(tester, const Offset(0, -64));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Focused 1996, Skipped'), findsNothing);
    expectOnFocusLine(tester, 'Newest');
  });

  testWidgets(
    'focus moves to nearest matching story when focus stops matching',
    (tester) async {
      final stories = [
        _story('early', 1980, 'Early', person: 'ada'),
        _story('near', 2002, 'Near', person: 'ada'),
        _story('now', 2004, 'Now'),
      ];
      final reported = <String>[];
      await tester.pumpWidget(_host(stories, onFocusChanged: reported.add));
      await tester.pumpAndSettle();
      expectOnFocusLine(tester, 'Now');

      await tester.pumpWidget(
        _host(stories, filter: _ada, onFocusChanged: reported.add),
      );
      await tester.pumpAndSettle();

      expect(reported, ['near']);
      expectOnFocusLine(tester, 'Near');
      expect(find.bySemanticsLabel('Focused 2004, Now'), findsNothing);
    },
  );

  testWidgets('no match hides Clear filters when clear is not wired', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _gap(),
        filter: const ThreadFilter(personIds: {'nobody'}),
        wireClear: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(FamilyThreadCopy.noMatch), findsOneWidget);
    expect(find.text(FamilyThreadCopy.clearFilters), findsNothing);
  });

  testWidgets(
    'no match shows card with No stories match these filters. and Clear filters',
    (tester) async {
      await tester.pumpWidget(
        _host(_gap(), filter: const ThreadFilter(personIds: {'nobody'})),
      );
      await tester.pumpAndSettle();

      expect(find.text(FamilyThreadCopy.noMatch), findsOneWidget);
      expect(find.text('No stories match these filters.'), findsOneWidget);
      expect(find.text(FamilyThreadCopy.clearFilters), findsOneWidget);

      await tester.tap(find.text(FamilyThreadCopy.clearFilters));
      await tester.pumpAndSettle();

      expect(find.text('No stories match these filters.'), findsNothing);
      expect(find.text('Newest'), findsOneWidget);
    },
  );

  testWidgets('overview decade label reads 1990s · 2 of 5 stories', (
    tester,
  ) async {
    final stories = [
      for (var index = 0; index < 5; index++)
        _story(
          's$index',
          1990 + index * 2,
          'Story $index',
          person: index < 2 ? 'ada' : null,
        ),
    ];
    await tester.pumpWidget(
      _host(stories, filter: _ada, density: FamilyThreadDensity.overview),
    );
    await tester.pumpAndSettle();

    expect(find.text('1990s · 2 of 5 stories'), findsOneWidget);
  });
}

const _ada = ThreadFilter(personIds: {'ada'});

Widget _host(
  List<Story> stories, {
  ThreadFilter filter = ThreadFilter.cleared,
  FamilyThreadDensity density = FamilyThreadDensity.browse,
  ValueChanged<String>? onFocusChanged,
  bool wireClear = true,
}) {
  return _Harness(
    stories: stories,
    filter: filter,
    density: density,
    onFocusChanged: onFocusChanged,
    wireClear: wireClear,
  );
}

class _Harness extends StatefulWidget {
  const _Harness({
    required this.stories,
    required this.filter,
    required this.density,
    this.onFocusChanged,
    this.wireClear = true,
  });

  final List<Story> stories;
  final ThreadFilter filter;
  final FamilyThreadDensity density;
  final ValueChanged<String>? onFocusChanged;
  final bool wireClear;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late ThreadFilter _filter = widget.filter;
  var _opened = false;

  @override
  void didUpdateWidget(_Harness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) _filter = widget.filter;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: albumTheme(),
      home: Scaffold(
        body: Stack(
          children: [
            ThreadView(
              stories: widget.stories,
              density: widget.density,
              filter: _filter,
              onClearFilter: widget.wireClear
                  ? () {
                      setState(() => _filter = ThreadFilter.cleared);
                    }
                  : null,
              onFocusChanged: widget.onFocusChanged,
              onBeat: (_, {required bool focused}) {
                setState(() => _opened = true);
              },
              onCard: (_) {
                setState(() => _opened = true);
              },
            ),
            Text(_opened ? 'opened' : 'idle'),
          ],
        ),
      ),
    );
  }
}

List<Story> _gap() {
  return [
    _story('kept', 1990, 'Kept', person: 'ada'),
    _story('skipped', 1996, 'Skipped'),
    _story('newest', 2004, 'Newest', person: 'ada'),
  ];
}

Story _story(String id, int year, String title, {String? person}) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    personIds: [?person],
  );
}

Future<void> _drag(WidgetTester tester, Offset delta) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.bySubtype<ListView>()),
  );
  await gesture.moveBy(delta);
  await tester.pump(const Duration(milliseconds: 70));
  await gesture.moveBy(Offset(0, delta.dy.sign));
  await tester.pump(const Duration(milliseconds: 70));
  await gesture.up();
}
