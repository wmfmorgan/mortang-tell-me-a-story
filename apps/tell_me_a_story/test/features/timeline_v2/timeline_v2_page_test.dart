import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline_v2/timeline_v2_page.dart';

import '../../fakes/quiet_stories.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets('the header Timeline v2 item opens /timeline-v2', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.timeline,
      routes: [
        GoRoute(
          path: AppRoutes.timeline,
          builder: (_, _) => Scaffold(
            appBar: AlbumHeader(
              page: AlbumHeaderPage.timeline,
              familyName: 'Ada',
              families: const [],
              currentFamilyId: 'ada',
              onFamilySelected: (_) {},
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.timelineV2,
          builder: (_, _) => const Scaffold(body: Text('v2 route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: albumTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('header-nav-timeline-v2')));
    await tester.pumpAndSettle();

    expect(find.text('v2 route'), findsOneWidget);
    expect(find.text('Timeline'), findsNothing);
  });

  testWidgets('misses stay put, dim, and count n of N', (tester) async {
    await _pump(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();

    expect(find.text('2 of 3 stories match'), findsOneWidget);
    expect(_icon('wedding').icon, Icons.circle);
    expect(_icon('wedding').color, albumTerracotta);
    expect(_icon('picnic').icon, Icons.circle_outlined);
    expect(_icon('picnic').color, albumInkDim);
    expect(_icon('grad').icon, Icons.circle);
    expect(_text('Picnic').style?.color, albumInkDim);
    expect(_text('Wedding').style?.color, albumInk);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(_top('Graduation'), lessThan(_top('Picnic')));
    expect(_top('Picnic'), lessThan(_top('Wedding')));
  });

  testWidgets('people and places use OR inside and AND across', (tester) async {
    await _pump(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-bea')));
    await tester.pumpAndSettle();

    expect(find.text('3 of 3 stories match'), findsOneWidget);
    expect(_icon('picnic').icon, Icons.circle);

    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-bea')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('timeline-v2-filter-search')),
      'lemons',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 stories match'), findsOneWidget);
    expect(_icon('picnic').icon, Icons.circle);
    expect(_icon('wedding').icon, Icons.circle_outlined);

    await tester.enterText(
      find.byKey(const Key('timeline-v2-filter-search')),
      '',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-v2-filter-place-park')));
    await tester.pumpAndSettle();

    expect(find.text('0 of 3 stories match'), findsOneWidget);
    expect(find.text('No stories match these filters.'), findsOneWidget);
    expect(find.text('Wedding'), findsOneWidget);
    expect(find.text('Picnic'), findsOneWidget);
    expect(find.text('Graduation'), findsOneWidget);
    expect(_text('1950s').style?.color, albumInkDim);
    expect(find.text('0 of 2'), findsOneWidget);
  });

  testWidgets('clear filters restores every story', (tester) async {
    await _pump(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-v2-filter-place-park')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('timeline-v2-no-match')),
        matching: find.text('Clear filters'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No stories match these filters.'), findsNothing);
    expect(find.textContaining('stories match'), findsNothing);
    expect(_icon('wedding').icon, Icons.circle);
    expect(_icon('picnic').icon, Icons.circle);
    expect(_icon('grad').icon, Icons.circle);
  });

  testWidgets('a decade range keeps stories outside it hollow', (tester) async {
    await _pump(tester);
    await _openFilters(tester);
    final slider = tester.widget<RangeSlider>(
      find.byKey(const Key('timeline-v2-filter-decades')),
    );
    slider.onChanged!(const RangeValues(1, 1));
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 stories match'), findsOneWidget);
    expect(_icon('grad').icon, Icons.circle);
    expect(_icon('wedding').icon, Icons.circle_outlined);
    expect(_icon('picnic').icon, Icons.circle_outlined);
    expect(find.text('1970s – 1970s'), findsOneWidget);
  });

  testWidgets('filters survive zoom and opening a story', (tester) async {
    await _pump(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('timeline-v2-zoom-years')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-v2-year-1955')), findsOneWidget);
    expect(find.byKey(const Key('timeline-v2-decade-1950')), findsNothing);
    expect(find.text('2 of 3 stories match'), findsOneWidget);
    expect(_icon('picnic').icon, Icons.circle_outlined);

    await tester.tap(find.byKey(const Key('timeline-v2-zoom-days')));
    await tester.pumpAndSettle();
    expect(find.textContaining('lemons under the tree'), findsOneWidget);
    expect(find.text('2 of 3 stories match'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-v2-dot-picnic')));
    await tester.pumpAndSettle();
    expect(find.text('reader picnic'), findsOneWidget);

    GoRouter.of(tester.element(find.text('reader picnic'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('2 of 3 stories match'), findsOneWidget);
    expect(_icon('picnic').icon, Icons.circle_outlined);
  });

  testWidgets('a family switch clears the filter and stays on the page', (
    tester,
  ) async {
    await _pump(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const Key('timeline-v2-filter-person-ada')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('family-menu-item-bea')));
    await tester.pumpAndSettle();

    expect(find.text('Bea story'), findsOneWidget);
    expect(find.text('Wedding'), findsNothing);
    expect(find.textContaining('stories match'), findsNothing);
    expect(_icon('bea-story').icon, Icons.circle);
    expect(find.byKey(const Key('header-nav-timeline-v2')), findsOneWidget);
  });

  testWidgets('filters dock at 900pt and draw from the end below that', (
    tester,
  ) async {
    await _pump(tester, const Size(899, 800));
    await tester.tap(find.byKey(const Key('timeline-v2-filters-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-v2-filter-drawer')), findsOneWidget);
    expect(find.byKey(const Key('timeline-v2-filter-sidebar')), findsNothing);

    await _pump(tester, const Size(900, 800));
    await tester.tap(find.byKey(const Key('timeline-v2-filters-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-v2-filter-sidebar')), findsOneWidget);
    expect(find.byKey(const Key('timeline-v2-filter-drawer')), findsNothing);
  });
}

Future<void> _pump(WidgetTester tester, [Size size = const Size(1200, 900)]) {
  return _show(tester, size);
}

Future<void> _show(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FamilySelection.remember('ada');
  final router = GoRouter(
    initialLocation: AppRoutes.timelineV2,
    routes: [
      GoRoute(
        path: AppRoutes.timelineV2,
        builder: (_, _) => TimelineV2Page(
          storiesApi: _Stories({
            'ada': [_wedding, _picnic, _grad],
            'bea': [_beaStory],
          }),
          familiesApi: TestFamilies([
            MemberFamily(id: 'ada', name: 'Ada', createdAt: DateTime.utc(2020)),
            MemberFamily(id: 'bea', name: 'Bea', createdAt: DateTime.utc(2021)),
          ]),
        ),
      ),
      GoRoute(
        path: AppRoutes.story,
        builder: (_, state) =>
            Scaffold(body: Text('reader ${state.pathParameters['storyId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: albumTheme(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('timeline-v2-filters-open')));
  await tester.pumpAndSettle();
}

Icon _icon(String id) {
  return find.byKey(Key('timeline-v2-dot-$id')).evaluate().single.widget
      as Icon;
}

Text _text(String label) {
  return find.text(label).evaluate().single.widget as Text;
}

double _top(String label) {
  final box = find.text(label).evaluate().single.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero).dy;
}

Story _story({
  required String id,
  required String familyId,
  required String title,
  required DateTime start,
  required String body,
  required String placeId,
  required String placeLabel,
  required String personId,
  required String personName,
}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'author',
    title: title,
    body: body,
    timeframeStart: start,
    status: StoryStatus.published,
    placeId: placeId,
    placeLabel: placeLabel,
    people: [(id: personId, name: personName)],
    personIds: [personId],
    personNames: [personName],
  );
}

final _wedding = _story(
  id: 'wedding',
  familyId: 'ada',
  title: 'Wedding',
  start: DateTime(1952, 6, 1),
  body: 'vows',
  placeId: 'kitchen',
  placeLabel: 'Kitchen',
  personId: 'ada',
  personName: 'Ada',
);

final _picnic = _story(
  id: 'picnic',
  familyId: 'ada',
  title: 'Picnic',
  start: DateTime(1955, 5, 2),
  body: 'lemons under the tree',
  placeId: 'park',
  placeLabel: 'Park',
  personId: 'bea',
  personName: 'Bea',
);

final _grad = _story(
  id: 'grad',
  familyId: 'ada',
  title: 'Graduation',
  start: DateTime(1971, 6, 15),
  body: 'cap',
  placeId: 'kitchen',
  placeLabel: 'Kitchen',
  personId: 'ada',
  personName: 'Ada',
);

final _beaStory = _story(
  id: 'bea-story',
  familyId: 'bea',
  title: 'Bea story',
  start: DateTime(1980, 1, 1),
  body: 'branch',
  placeId: 'park',
  placeLabel: 'Park',
  personId: 'bea',
  personName: 'Bea',
);

class _Stories extends QuietStories {
  _Stories(this.byFamily);

  final Map<String, List<Story>> byFamily;

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return byFamily[familyId] ?? const [];
  }
}
