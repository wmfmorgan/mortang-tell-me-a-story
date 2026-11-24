import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/filter_button.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('sidebar at 900 wide, drawer at 899', (tester) async {
    _size(tester, const Size(900, 800));
    await tester.pumpWidget(_host(_handful()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-panel')), findsOneWidget);
    expect(find.byKey(const Key('filter-drawer')), findsNothing);
    expect(find.text('Search titles, stories and people'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Years'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('filter-panel'))).width, 280);

    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-panel')), findsNothing);

    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-panel')), findsOneWidget);

    _size(tester, const Size(899, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-panel')), findsNothing);
    expect(find.byKey(const Key('filter-drawer')), findsNothing);

    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsOneWidget);
    expect(find.byTooltip('Close filters'), findsOneWidget);

    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsNothing);
  });

  testWidgets('show 1 story singular', (tester) async {
    _size(tester, const Size(400, 800));
    await tester.pumpWidget(_host([_story('only', 1975, 'Only')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();

    expect(find.text('Show 1 story'), findsOneWidget);
    expect(find.text('1 of 1 story'), findsOneWidget);
    expect(find.text('Show 1 stories'), findsNothing);
  });

  testWidgets('selected chip uses sageTint fill and albumInk label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    _size(tester, const Size(1000, 800));
    await tester.pumpWidget(_host(_handful()));
    await tester.pumpAndSettle();

    expect(_fill(tester, 'Ada').color, isNot(sageTint));
    await tester.tap(_chip('Ada'));
    await tester.pumpAndSettle();

    expect(_fill(tester, 'Ada').color, sageTint);
    expect(_label(tester, 'Ada').style?.color, albumInk);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('filter-choice-ada'))),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('filter-choice-ben'))),
      isSemantics(isSelected: false),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('filter-panel')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(_fill(tester, 'Ben').color, isNot(sageTint));
    handle.dispose();
  });

  testWidgets('drawer footer closes the drawer', (tester) async {
    _size(tester, const Size(899, 800));
    await tester.pumpWidget(
      _host([_story('one', 1975, 'One'), _story('two', 1976, 'Two')]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();

    expect(find.text('Show 2 stories'), findsOneWidget);
    await tester.tap(find.text('Show 2 stories'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-drawer')), findsNothing);
    expect(find.text('Show 2 stories'), findsNothing);
  });

  testWidgets('esc closes the drawer', (tester) async {
    _size(tester, const Size(899, 800));
    await tester.pumpWidget(_host([_story('only', 1975, 'Only')]));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-drawer')), findsNothing);
  });

  testWidgets('or within people and and across categories reflected in count', (
    tester,
  ) async {
    _size(tester, const Size(1000, 800));
    await tester.pumpWidget(_host(_handful()));
    await tester.pumpAndSettle();
    expect(find.text('5 of 5 stories'), findsOneWidget);

    await tester.tap(_chip('Ada'));
    await tester.pumpAndSettle();
    await tester.tap(_chip('Ben'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 5 stories'), findsOneWidget);

    await tester.tap(_chip('Farm'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 5 stories'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Picnic');
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 stories'), findsOneWidget);

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    // The slider test calls onChanged directly rather than dragging.
    slider.onChanged!(const RangeValues(2000, 2000));
    await tester.pumpAndSettle();
    expect(find.text('0 of 5 stories'), findsOneWidget);
  });

  testWidgets('clear filters empties the search field', (tester) async {
    _size(tester, const Size(1000, 800));
    await tester.pumpWidget(_host(_handful()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Picnic');
    await tester.pumpAndSettle();
    expect(find.text('1 of 5 stories'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('filter-panel')),
        matching: find.text('Clear filters'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.text('5 of 5 stories'), findsOneWidget);
  });

  testWidgets('full decade span clears the decade filter', (tester) async {
    _size(tester, const Size(1000, 800));
    await tester.pumpWidget(_host(_handful()));
    await tester.pumpAndSettle();

    final narrowed = tester.widget<RangeSlider>(find.byType(RangeSlider));
    // The slider test calls onChanged directly rather than dragging.
    narrowed.onChanged!(const RangeValues(2000, 2000));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterButton, 'Filters · 1'), findsOneWidget);
    expect(find.text('2000s – 2000s'), findsWidgets);

    final full = tester.widget<RangeSlider>(find.byType(RangeSlider));
    // The slider test calls onChanged directly rather than dragging.
    full.onChanged!(RangeValues(full.min, full.max));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterButton, 'Filters'), findsOneWidget);
    expect(find.text('Filters · 1'), findsNothing);
    expect(find.text('2000s – 2000s'), findsNothing);
  });

  testWidgets('tapping the drawer scrim closes the sheet', (tester) async {
    _size(tester, const Size(899, 800));
    await tester.pumpWidget(_host([_story('only', 1975, 'Only')]));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsOneWidget);

    final scrim = tester.getRect(find.byKey(const Key('filter-drawer')));
    await tester.tapAt(Offset(scrim.center.dx, scrim.top + 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-drawer')), findsNothing);
  });

  testWidgets('esc closes the sheet and does not reach the page shortcut', (
    tester,
  ) async {
    var pageEscapes = 0;
    _size(tester, const Size(899, 800));
    await tester.pumpWidget(
      _host([_story('only', 1975, 'Only')], onPageEscape: () => pageEscapes++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('filter-drawer')),
        matching: find.byElementPredicate(
          (element) => element == FocusManager.instance.primaryFocus?.context,
        ),
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('filter-drawer')), findsNothing);
    expect(pageEscapes, 0);
  });

  testWidgets('widening to 900 closes the drawer', (tester) async {
    _size(tester, const Size(899, 800));
    await tester.pumpWidget(_host([_story('only', 1975, 'Only')]));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsOneWidget);

    _size(tester, const Size(900, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsNothing);
    expect(find.byKey(const Key('filter-panel')), findsOneWidget);

    _size(tester, const Size(899, 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-drawer')), findsNothing);
    expect(find.byKey(const Key('filter-panel')), findsNothing);
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _chip(String name) {
  return find.descendant(
    of: find.byKey(const Key('filter-panel')),
    matching: find.text(name),
  );
}

Material _fill(WidgetTester tester, String name) {
  return tester.widget<Material>(
    find.ancestor(of: _chip(name), matching: find.byType(Material)).first,
  );
}

Text _label(WidgetTester tester, String name) {
  return tester.widget<Text>(_chip(name));
}

Widget _host(List<Story> stories, {VoidCallback? onPageEscape}) {
  return MaterialApp(
    theme: albumTheme(),
    home: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          onPageEscape?.call();
        },
      },
      child: FamilyThreadPage(
        storiesApi: ThreadStories(stories),
        familiesApi: TestFamilies([
          MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
        ]),
        currentUserId: () => 'user-1',
        live: FakeTimelineLive(),
      ),
    ),
  );
}

List<Story> _handful() {
  return [
    _story(
      'p1',
      1990,
      'Picnic',
      people: [_person('ada', 'Ada')],
      placeId: 'farm',
      placeLabel: 'Farm',
    ),
    _story(
      'p2',
      1991,
      'Barn',
      people: [_person('ben', 'Ben')],
      placeId: 'farm',
      placeLabel: 'Farm',
    ),
    _story(
      'p3',
      1992,
      'Market',
      people: [_person('ada', 'Ada')],
      placeId: 'town',
      placeLabel: 'Town',
    ),
    _story(
      'p4',
      1980,
      'Creek',
      people: [_person('cy', 'Cy')],
      placeId: 'town',
      placeLabel: 'Town',
    ),
    _story('p5', 2004, 'Alone'),
  ];
}

Story _story(
  String id,
  int year,
  String title, {
  List<({String id, String name})> people = const [],
  String? placeId,
  String? placeLabel,
}) {
  return Story(
    id: id,
    familyId: 'fam-1',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    placeId: placeId,
    placeLabel: placeLabel,
    personIds: [for (final person in people) person.id],
    people: people,
  );
}

({String id, String name}) _person(String id, String name) =>
    (id: id, name: name);
