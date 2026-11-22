import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline_river/river_density.dart';
import 'package:tell_me_a_story/features/timeline_river/river_open_state.dart';
import 'package:tell_me_a_story/features/timeline_river/river_open_state_store.dart';
import 'package:tell_me_a_story/features/timeline_river/river_story_card.dart';
import 'package:tell_me_a_story/features/timeline_river/timeline_river_page.dart';

import '../../fakes/fake_invite_api.dart';
import '../../fakes/quiet_stories.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(FamilySelection.clear);
  tearDown(FamilySelection.clear);

  testWidgets('density switching preserves focus', (tester) async {
    _wide(tester);
    await tester.pumpWidget(_app(stories: _span()));
    await _show(tester);

    await _tapBeat(tester, 'year-1996');
    expect(_focusText(tester), 'Harvest');

    await tester.tap(find.byKey(const Key('river-density-overview')));
    await _show(tester);
    expect(_focusText(tester), '1990s · 1 story');
    expect(
      find.text('The Hale Family · stories carried down the years'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('1990s, 1 story'), findsOneWidget);

    await tester.tap(find.byKey(const Key('river-density-browse')));
    await _show(tester);
    expect(_focusText(tester), 'Harvest');

    await tester.tap(find.byKey(const Key('river-density-read')));
    await _show(tester);
    expect(_focusText(tester), 'Harvest');
    expect(find.byKey(const Key('river-excerpt')), findsNothing);
    expect(find.text('The wagon broke a wheel.'), findsOneWidget);
    expect(_selectedDensity(tester, 'read'), albumTerracotta);
  });

  testWidgets('filter OR within a category and AND across, with n of N', (
    tester,
  ) async {
    _wide(tester);
    await tester.pumpWidget(_app(stories: _filtered()));
    await _show(tester);

    await tester.tap(find.byKey(const Key('timeline-river-filter-person-tom')));
    await tester.pump();
    expect(find.text('2 of 3 stories match'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp("Berry, 1992, doesn't match filters")),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('timeline-river-filter-person-ana')));
    await tester.pump();
    expect(find.text('3 of 3 stories match'), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-river-filter-clear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timeline-river-filter-person-tom')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timeline-river-filter-place-city')));
    await tester.pump();
    expect(find.text('1 of 3 stories match'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('timeline-river-filter-search')),
      'zzzz',
    );
    await tester.pump();
    expect(find.text('0 of 3 stories match'), findsOneWidget);
    expect(find.text('No stories match these filters.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('timeline-river-no-match')),
        matching: find.text('Clear filters'),
      ),
    );
    await tester.pump();
    expect(find.text('No stories match these filters.'), findsNothing);
    expect(find.textContaining('stories match'), findsNothing);
  });

  testWidgets(
    'open state restores density and falls back when the story is gone',
    (tester) async {
      _wide(tester);
      final restored = RiverOpenStateStore(
        seed: {
          kTestFamilyId: const RiverOpenState(
            density: RiverDensity.read,
            storyId: 'harvest',
            year: 1996,
          ),
        },
      );
      await tester.pumpWidget(_app(stories: _span(), store: restored));
      await _show(tester);
      expect(_focusText(tester), 'Harvest');
      expect(find.text('The wagon broke a wheel.'), findsOneWidget);
      expect(_selectedDensity(tester, 'read'), albumTerracotta);

      final missing = RiverOpenStateStore(
        seed: {
          kTestFamilyId: const RiverOpenState(
            density: RiverDensity.read,
            storyId: 'gone',
            year: 1970,
          ),
        },
      );
      await tester.pumpWidget(_app(stories: _span(), store: missing));
      await _show(tester);
      expect(_focusText(tester), 'Tractor');
      expect(_selectedDensity(tester, 'read'), albumTerracotta);
    },
  );

  testWidgets('no-photo card shows the first line and no image', (
    tester,
  ) async {
    _wide(tester);
    final store = RiverOpenStateStore(
      seed: {
        kTestFamilyId: const RiverOpenState(
          density: RiverDensity.read,
          storyId: 'letter',
          year: 1988,
        ),
      },
    );
    await tester.pumpWidget(
      _app(
        store: store,
        stories: [
          _story(
            id: 'letter',
            title: 'The letter',
            year: 1988,
            body: 'The creek rose overnight\nThe rest stayed in the envelope.',
          ),
        ],
      ),
    );
    await _show(tester);

    expect(find.text('The creek rose overnight'), findsOneWidget);
    expect(find.byKey(const Key('river-quote')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RiverStoryCard),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.broken_image), findsNothing);
  });

  testWidgets('reduced motion drops fade, shift, and the ripple', (
    tester,
  ) async {
    _wide(tester);
    await tester.pumpWidget(_app(stories: _span(), reduced: false));
    await _show(tester);
    expect(_fade(tester, 'year-1996'), 0.6);
    expect(_fade(tester, 'year-1972'), 0.3);
    expect(find.byKey(const Key('river-ripple')), findsOneWidget);

    await tester.pumpWidget(_app(stories: _span(), reduced: true));
    await _show(tester);
    expect(_fade(tester, 'year-1996'), 1);
    expect(_fade(tester, 'year-1972'), 1);
    expect(find.byKey(const Key('river-ripple')), findsNothing);
  });

  testWidgets('scrubber and jump to year move the focus', (tester) async {
    _wide(tester);
    await tester.pumpWidget(_app(stories: _span()));
    await _show(tester);
    expect(
      find.bySemanticsLabel('Timeline scrubber, 1970s to 2000s, showing 2000s'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('river-scrub-1970')));
    await _show(tester);
    expect(_focusText(tester), 'Tractor');
    expect(
      find.bySemanticsLabel('Timeline scrubber, 1970s to 2000s, showing 1970s'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('river-jump')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('river-jump-year')), '1996');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _show(tester);
    expect(_focusText(tester), 'Harvest');
  });

  testWidgets('route /timeline-river renders the river', (tester) async {
    _wide(tester);
    final auth = AuthRefresh(initiallySignedIn: true);
    addTearDown(auth.dispose);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteApi(),
      storiesApi: _Stories(_span()),
      familiesApi: _Families(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: albumTheme(), routerConfig: router),
    );
    router.go(AppRoutes.timelineRiver);
    await _show(tester);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Laptop'), findsWidgets);
  });
}

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _show(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapBeat(WidgetTester tester, String id) async {
  final key = find.byKey(Key('river-fade-$id'));
  await tester.ensureVisible(key);
  await tester.pump();
  await tester.tap(key);
  await _show(tester);
}

String? _focusText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('river-focused-label'))).data;
}

Color? _selectedDensity(WidgetTester tester, String name) {
  final button = tester.widget<TextButton>(
    find.byKey(Key('river-density-$name')),
  );
  return button.style?.backgroundColor?.resolve(const <WidgetState>{});
}

double _fade(WidgetTester tester, String id) {
  return tester.widget<Opacity>(find.byKey(Key('river-fade-$id'))).opacity;
}

Widget _app({
  required List<Story> stories,
  RiverOpenStateStore? store,
  bool reduced = false,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.timelineRiver,
    routes: [
      GoRoute(
        path: AppRoutes.timelineRiver,
        builder: (_, _) => TimelineRiverPage(
          inviteApi: FakeInviteApi(),
          storiesApi: _Stories(stories),
          familiesApi: _Families(),
          openStateStore: store ?? RiverOpenStateStore(),
        ),
      ),
      GoRoute(
        path: AppRoutes.story,
        builder: (_, state) =>
            Text('opened ${state.pathParameters['storyId']}'),
      ),
      GoRoute(
        path: AppRoutes.familyLanding,
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.drafts,
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );
  return MaterialApp.router(
    theme: albumTheme(),
    routerConfig: router,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}

class _Stories extends QuietStories {
  _Stories(this.rows);

  final List<Story> rows;

  @override
  Future<List<Story>> listPublished(String familyId) async {
    return [
      for (final story in rows)
        if (story.familyId == familyId) story,
    ];
  }
}

class _Families extends FamiliesGateway with QuietFamiliesDefaults {
  @override
  Future<List<MemberFamily>> listMine() async {
    return [
      MemberFamily(
        id: kTestFamilyId,
        name: 'Hale',
        createdAt: DateTime.utc(2020),
      ),
    ];
  }

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}

List<Story> _span() {
  return [
    _story(id: 'tractor', title: 'Tractor', year: 1972),
    _story(
      id: 'harvest',
      title: 'Harvest',
      year: 1996,
      body: 'The wagon broke a wheel.',
    ),
    _story(id: 'laptop', title: 'Laptop', year: 2004),
  ];
}

List<Story> _filtered() {
  return [
    _story(
      id: 'apple',
      title: 'Apple',
      year: 1990,
      personId: 'tom',
      personName: 'Tom',
      placeId: 'farm',
      placeLabel: 'The farm',
    ),
    _story(
      id: 'berry',
      title: 'Berry',
      year: 1992,
      personId: 'ana',
      personName: 'Ana',
      placeId: 'farm',
      placeLabel: 'The farm',
    ),
    _story(
      id: 'cedar',
      title: 'Cedar',
      year: 1996,
      personId: 'tom',
      personName: 'Tom',
      placeId: 'city',
      placeLabel: 'City',
    ),
  ];
}

Story _story({
  required String id,
  required String title,
  required int year,
  String body = 'A remembered day.',
  String? personId,
  String? personName,
  String? placeId,
  String? placeLabel,
}) {
  return Story(
    id: id,
    familyId: kTestFamilyId,
    authorId: 'author',
    title: title,
    body: body,
    timeframeStart: DateTime(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    status: StoryStatus.published,
    placeId: placeId,
    placeLabel: placeLabel,
    personIds: personId == null ? const [] : [personId],
    personNames: personName == null ? const [] : [personName],
    people: personId == null || personName == null
        ? const []
        : [(id: personId, name: personName)],
  );
}
