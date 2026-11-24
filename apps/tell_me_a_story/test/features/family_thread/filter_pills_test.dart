import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/family_thread_open_state.dart';
import 'package:tell_me_a_story/data/family_thread_open_state_store.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  testWidgets('count reads 3 of 12 stories and 1 of 1 story', (tester) async {
    await tester.pumpWidget(
      _host(
        ThreadStories(_dozen()),
        filter: const ThreadFilter(decadeFrom: 1990, decadeTo: 1990),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 of 12 stories'), findsOneWidget);

    await tester.pumpWidget(
      _host(ThreadStories([_story('only', 1975, 'Only')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 story'), findsOneWidget);
  });

  testWidgets('filters button reads Filters · 2 when two values active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _host(
        ThreadStories([_story('only', 1975, 'Only')]),
        filter: const ThreadFilter(personIds: {'ada', 'ben'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filters · 2'), findsOneWidget);
  });

  testWidgets('removing a pill updates the count', (tester) async {
    await tester.pumpWidget(
      _host(
        ThreadStories(_tagged()),
        filter: const ThreadFilter(personIds: {'ada', 'ben'}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('5 of 12 stories'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Remove filter: Ben'));
    await tester.pumpAndSettle();

    expect(find.text('3 of 12 stories'), findsOneWidget);
    expect(find.text('Filters · 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove filter: Ben'), findsNothing);
    expect(find.bySemanticsLabel('Remove filter: Ada'), findsOneWidget);
  });

  testWidgets('pill remove label is Remove filter: <value>', (tester) async {
    await tester.pumpWidget(
      _host(
        ThreadStories([
          _story(
            'picnic',
            1962,
            'Picnic',
            people: [_person('ada', 'Ada')],
            placeId: 'farm',
            placeLabel: 'Farm',
          ),
        ]),
        filter: const ThreadFilter(
          search: 'picnic',
          personIds: {'ada'},
          placeIds: {'farm'},
          decadeFrom: 1950,
          decadeTo: 2000,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1950s – 2000s'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Remove filter: 1950s – 2000s'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Remove filter: picnic'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove filter: Ada'), findsOneWidget);
    expect(find.bySemanticsLabel('Remove filter: Farm'), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel('Remove filter: Ada')),
      const Size(44, 44),
    );
  });

  testWidgets('clear filters keeps focus', (tester) async {
    await tester.pumpWidget(
      _host(
        ThreadStories([
          _story('older', 1990, 'Older'),
          _story('newer', 2004, 'Newest'),
        ]),
        filter: const ThreadFilter(personIds: {'ada'}),
        store: _MemoryStore(
          const FamilyThreadOpenState(
            density: FamilyThreadDensity.browse,
            storyId: 'older',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectOnFocusLine(tester, 'Older');

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expectOnFocusLine(tester, 'Older');
    expect(find.text('2 of 2 stories'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Filters · 1'), findsNothing);
    expect(find.text('Clear filters'), findsNothing);
  });
}

Widget _host(
  ThreadStories stories, {
  ThreadFilter filter = ThreadFilter.cleared,
  FamilyThreadOpenStateStore? store,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      key: UniqueKey(),
      storiesApi: stories,
      familiesApi: _families,
      currentUserId: () => 'user-1',
      openStateStore: store,
      initialFilter: filter,
      live: FakeTimelineLive(),
    ),
  );
}

class _MemoryStore extends FamilyThreadOpenStateStore {
  _MemoryStore(this.state);

  final FamilyThreadOpenState state;

  @override
  Future<FamilyThreadOpenState?> read({required String familyId}) async {
    return state;
  }
}

List<Story> _dozen() {
  return [
    for (var year = 1980; year < 1989; year++)
      _story('y$year', year, 'Story $year'),
    for (var year = 1990; year < 1993; year++)
      _story('y$year', year, 'Story $year'),
  ];
}

List<Story> _tagged() {
  return [
    for (var index = 0; index < 12; index++)
      _story(
        's$index',
        1970 + index,
        'Story $index',
        people: index < 3
            ? [_person('ada', 'Ada')]
            : index < 5
            ? [_person('ben', 'Ben')]
            : const [],
      ),
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

final _families = TestFamilies([
  MemberFamily(id: 'fam-1', name: 'Ada', createdAt: DateTime.utc(2020)),
]);
