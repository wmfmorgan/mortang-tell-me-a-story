import 'dart:async';
import 'dart:typed_data';

// SemanticsNode.flagsCollection does not mirror toggled/selected in this SDK.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/all_stories/all_stories_card.dart';
import 'package:tell_me_a_story/features/all_stories/all_stories_logic.dart';
import 'package:tell_me_a_story/features/all_stories/all_stories_page.dart';

const _family = 'fam-1';
const _name = 'The Morgans';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
    AllStoriesSession.resetForTest();
  });

  tearDown(() {
    FamilySelection.clear();
    AllStoriesSession.resetForTest();
  });

  testWidgets('W-01 Stories opens All Stories from Landing and the timeline', (
    tester,
  ) async {
    await _size(tester, const Size(1440, 900));
    final stories = _Stories();
    final families = _Families();
    final router = _router(
      stories: stories,
      families: families,
      location: '/landing',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-underline-timeline')), findsNothing);

    await tester.tap(find.byKey(const Key('timeline-nav')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/family/$_family/stories');
    expect(find.byKey(const Key('header-underline-timeline')), findsOneWidget);

    router.go(AppRoutes.timeline);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('header-underline-timeline')), findsOneWidget);
    await tester.tap(find.byKey(const Key('timeline-nav')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/family/$_family/stories');
    expect(find.byKey(const Key('header-underline-timeline')), findsOneWidget);
  });

  testWidgets('W-03 the header search icon still opens Search', (tester) async {
    await _size(tester, const Size(1440, 900));
    final router = _router(stories: _Stories(), families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-search')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.search);
  });

  testWidgets('W-04 the page opens grouped by Date, newest decade first', (
    tester,
  ) async {
    await _pumpReady(tester);
    expect(find.text('All Stories'), findsOneWidget);
    expect(_top(tester, '2020s'), lessThan(_top(tester, '2010s')));
    expect(_top(tester, '2010s'), lessThan(_top(tester, '1990s')));
    expect(
      tester.getTopLeft(find.text('Plain day')).dx,
      lessThan(tester.getTopLeft(find.text('Spawn')).dx),
    );
  });

  testWidgets('W-05 Member then Place keeps the query and the toggle', (
    tester,
  ) async {
    await _size(tester, const Size(1440, 700));
    final router = _router(stories: _Stories(), families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('all-stories-search')),
      'sarah',
    );
    await tester.tap(find.byKey(const Key('all-stories-toggle')));
    await tester.pumpAndSettle();
    final scroll = _controller(tester);
    scroll.jumpTo(40);
    await tester.pump();

    await tester.tap(find.byKey(const Key('all-stories-group-member')));
    await tester.pumpAndSettle();
    expect(find.text('Sarah'), findsWidgets);
    expect(find.text('Ben'), findsWidgets);
    expect(_controller(tester).offset, 0);
    expect(
      find.text('1 of 4 stories match "sarah" and started a timeline'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('all-stories-group-place')));
    await tester.pumpAndSettle();
    expect(find.text('Pier'), findsWidgets);
    expect(find.text('No place yet'), findsOneWidget);
    expect(_controller(tester).offset, 0);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('all-stories-search')))
          .controller
          ?.text,
      'sarah',
    );
  });

  testWidgets('W-06 loading shows skeletons and no spinner text', (
    tester,
  ) async {
    await _size(tester, const Size(1440, 900));
    final gate = Completer<List<Story>>();
    final stories = _Stories(publishedOverride: (_) => gate.future);
    final router = _router(stories: stories, families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('All Stories'), findsOneWidget);
    expect(find.byKey(const Key('all-stories-search')), findsOneWidget);
    expect(find.byKey(const Key('all-stories-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Loading'), findsNothing);
    gate.complete(_published());
    await tester.pumpAndSettle();
  });

  testWidgets('W-07 an empty family disables the controls', (tester) async {
    await _size(tester, const Size(1440, 900));
    final stories = _Stories(published: const [], includeOrigin: false);
    final router = _router(stories: stories, families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('No stories yet.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('all-stories-search')))
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('all-stories-toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('started a timeline'), findsNothing);
    final closeSemantics = _trackSemantics(tester);
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-toggle')))
          .hasFlag(SemanticsFlag.isEnabled),
      isFalse,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-group-date')))
          .hasFlag(SemanticsFlag.isEnabled),
      isFalse,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('all-stories-timeline')))
          .onPressed,
      isNotNull,
    );
    closeSemantics();
  });

  testWidgets('W-08 a load error offers Retry and not the empty line', (
    tester,
  ) async {
    await _size(tester, const Size(1440, 900));
    final stories = _Stories(publishedError: StateError('down'));
    final router = _router(stories: stories, families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load stories."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No stories yet.'), findsNothing);
    expect(find.text('All Stories'), findsOneWidget);
    final errorText = tester.widget<Text>(find.text("Couldn't load stories."));
    expect(
      errorText.style?.color,
      Theme.of(tester.element(find.text("Couldn't load stories.")))
          .colorScheme
          .error,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('all-stories-search')))
          .enabled,
      isFalse,
    );
    final closeSemantics = _trackSemantics(tester);
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-toggle')))
          .hasFlag(SemanticsFlag.isEnabled),
      isFalse,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-group-date')))
          .hasFlag(SemanticsFlag.isEnabled),
      isFalse,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('all-stories-timeline')))
          .onPressed,
      isNotNull,
    );
    closeSemantics();
  });

  testWidgets('W-09 Retry loads the groups', (tester) async {
    await _size(tester, const Size(1440, 900));
    final stories = _Stories(publishedError: StateError('down'));
    final router = _router(stories: stories, families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    stories.publishedError = null;
    await tester.tap(find.byKey(const Key('all-stories-retry')));
    await tester.pumpAndSettle();
    expect(find.text('2020s'), findsOneWidget);
    expect(stories.publishedCalls, 2);
  });

  testWidgets('W-10 search dims non-matches and keeps every card', (
    tester,
  ) async {
    final router = await _pumpReady(tester);
    await tester.enterText(
      find.byKey(const Key('all-stories-search')),
      'sarah',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('all-stories-card-spawn')), findsOneWidget);
    expect(find.byKey(const Key('all-stories-card-plain')), findsOneWidget);
    expect(find.byKey(const Key('all-stories-card-kitchen')), findsOneWidget);
    expect(find.byKey(const Key('all-stories-card-origin')), findsOneWidget);
    expect(find.text('2 of 4 stories match "sarah"'), findsOneWidget);
    expect(router.state.uri.path, '/family/$_family/stories');
    final closeSemantics = _trackSemantics(tester);
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-card-plain')))
          .label,
      contains('not a match'),
    );
    closeSemantics();
  });

  testWidgets('W-11 a place name alone does not match', (tester) async {
    await _pumpReady(tester);
    await tester.enterText(find.byKey(const Key('all-stories-search')), 'pier');
    await tester.pumpAndSettle();
    final closeSemantics = _trackSemantics(tester);
    final label = tester.getSemantics(
      find.byKey(const Key('all-stories-card-plain')),
    );
    expect(label.label, contains('not a match'));
    expect(find.text('0 of 4 stories match "pier"'), findsOneWidget);
    closeSemantics();
  });

  testWidgets('W-12 the toggle dims stories that did not start a timeline', (
    tester,
  ) async {
    await _pumpReady(tester);
    final closeSemantics = _trackSemantics(tester);
    await tester.tap(find.byKey(const Key('all-stories-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('2 of 4 stories started a timeline'), findsOneWidget);
    final toggle = tester.getSemantics(
      find.byKey(const Key('all-stories-toggle')),
    );
    expect(toggle.hasFlag(SemanticsFlag.isToggled), isTrue);
    final plain = tester.getSemantics(
      find.byKey(const Key('all-stories-card-plain')),
    );
    expect(plain.label, contains('not a match'));
    closeSemantics();
  });

  testWidgets('W-13 search and the toggle combine', (tester) async {
    await _pumpReady(tester);
    await tester.enterText(
      find.byKey(const Key('all-stories-search')),
      'sarah',
    );
    await tester.tap(find.byKey(const Key('all-stories-toggle')));
    await tester.pumpAndSettle();
    expect(
      find.text('1 of 4 stories match "sarah" and started a timeline'),
      findsOneWidget,
    );
  });

  testWidgets('W-14 spawn marks show the origin line, branches, and ring', (
    tester,
  ) async {
    await _pumpReady(tester);
    expect(find.text('Origin · from Hart'), findsOneWidget);
    expect(find.byKey(const Key('all-stories-ring-origin')), findsOneWidget);
    expect(find.byKey(const Key('all-stories-ring-spawn')), findsOneWidget);
    final east = tester.getTopLeft(
      find.byKey(const Key('all-stories-branch-spawn-east')),
    );
    final north = tester.getTopLeft(
      find.byKey(const Key('all-stories-branch-spawn-north')),
    );
    expect(east.dx, lessThan(north.dx));

    const address =
        '100 Very Long Archive Lane That Must Stay On One Heading Line';
    final lane = _router(
      stories: _Stories(
        published: [
          Story(
            id: 'lane',
            familyId: _family,
            authorId: 'author',
            title: 'Lane',
            status: StoryStatus.published,
            timeframeStart: DateTime(2018, 6, 1),
            datePrecision: StoryDatePrecision.day,
            placeId: 'lane',
            placeAddress: address,
          ),
        ],
        includeOrigin: false,
      ),
      families: _Families(),
    );
    addTearDown(lane.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: lane));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-stories-group-place')));
    await tester.pumpAndSettle();
    final heading = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == address &&
            widget.style?.fontSize == 28,
      ),
    );
    expect(heading.maxLines, 1);
    expect(heading.overflow, TextOverflow.ellipsis);
  });

  testWidgets(
    'a matching card fades its border over 240ms and skips the fade under reduced motion',
    (tester) async {
      await _pumpReady(tester);
      await tester.enterText(
        find.byKey(const Key('all-stories-search')),
        'sarah',
      );
      await tester.pump();
      expect(_cardBorder(tester, 'spawn').width, 1);
      await tester.pump(allStoriesSearchDebounce);
      expect(_cardBorder(tester, 'spawn').width, lessThan(1.5));
      await tester.pump(allStoriesMotion);
      final matched = _cardBorder(tester, 'spawn');
      expect(matched.width, 2);
      expect(matched.color, albumTerracotta);

      await _pumpReady(tester, disableAnimations: true);
      await tester.enterText(
        find.byKey(const Key('all-stories-search')),
        'sarah',
      );
      await tester.pump(allStoriesSearchDebounce);
      await tester.pump();
      final instant = _cardBorder(tester, 'spawn');
      expect(instant.width, 2);
      expect(instant.color, albumTerracotta);
    },
  );

  testWidgets('W-15 the reader returns to the same scroll and filters', (
    tester,
  ) async {
    await _size(tester, const Size(1440, 700));
    final stories = _Stories();
    final router = _router(stories: stories, families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-stories-group-place')));
    await tester.enterText(
      find.byKey(const Key('all-stories-search')),
      'sarah',
    );
    await tester.tap(find.byKey(const Key('all-stories-toggle')));
    await tester.pumpAndSettle();
    final before = stories.publishedCalls;
    await tester.ensureVisible(find.byKey(const Key('all-stories-card-spawn')));
    await tester.pumpAndSettle();
    final offset = _controller(tester).offset;
    await tester.tap(find.byKey(const Key('all-stories-card-spawn')));
    await tester.pumpAndSettle();
    expect(find.text('reader-spawn'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(stories.publishedCalls, greaterThan(before));
    expect(_controller(tester).offset, offset);
    final closeSemantics = _trackSemantics(tester);
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-group-place')))
          .hasFlag(SemanticsFlag.isChecked),
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('all-stories-search')))
          .controller
          ?.text,
      'sarah',
    );
    expect(
      find.text('1 of 4 stories match "sarah" and started a timeline'),
      findsOneWidget,
    );
    closeSemantics();
  });

  testWidgets(
    'W-16 a branch pill remembers that family and opens the timeline',
    (tester) async {
      await _pumpReady(tester);
      FamilySelection.remember(_family);
      await tester.ensureVisible(
        find.byKey(const Key('all-stories-branch-spawn-east')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('all-stories-branch-spawn-east')));
      await tester.pumpAndSettle();
      expect(find.text('reader-spawn'), findsNothing);
      expect(find.text('timeline-page'), findsOneWidget);
      expect(FamilySelection.id, 'east');
    },
  );

  testWidgets('W-17 disposing during load does not throw', (tester) async {
    await _size(tester, const Size(1440, 900));
    final gate = Completer<List<Story>>();
    final stories = _Stories(publishedOverride: (_) => gate.future);
    final router = _router(stories: stories, families: _Families());
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete(_published());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('W-18 the timeline button has no icon', (tester) async {
    final router = await _pumpReady(tester);
    final button = find.byKey(const Key('all-stories-timeline'));
    expect(find.text('View a Timeline of Stories for $_name'), findsOneWidget);
    expect(
      find.descendant(of: button, matching: find.byType(Icon)),
      findsNothing,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(FamilySelection.id, _family);
    expect(router.state.uri.path, AppRoutes.timeline);
  });

  testWidgets('W-19 returning from the timeline restores the view', (
    tester,
  ) async {
    final router = await _pumpReady(tester);
    await tester.tap(find.byKey(const Key('all-stories-group-member')));
    await tester.enterText(
      find.byKey(const Key('all-stories-search')),
      'sarah',
    );
    await tester.tap(find.byKey(const Key('all-stories-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('all-stories-timeline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-nav')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/family/$_family/stories');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('all-stories-search')))
          .controller
          ?.text,
      'sarah',
    );
    expect(
      find.text('1 of 4 stories match "sarah" and started a timeline'),
      findsOneWidget,
    );
    final closeSemantics = _trackSemantics(tester);
    expect(
      tester
          .getSemantics(find.byKey(const Key('all-stories-group-member')))
          .hasFlag(SemanticsFlag.isChecked),
      isTrue,
    );
    closeSemantics();
  });

  testWidgets('W-20 group, status, and cards expose the locked semantics', (
    tester,
  ) async {
    await _pumpReady(tester);
    final closeSemantics = _trackSemantics(tester);
    await tester.enterText(
      find.byKey(const Key('all-stories-search')),
      'sarah',
    );
    await tester.pumpAndSettle();
    final date = tester.getSemantics(
      find.byKey(const Key('all-stories-group-date')),
    );
    expect(date.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);
    expect(date.hasFlag(SemanticsFlag.isChecked), isTrue);
    final status = tester.getSemantics(
      find.byKey(const Key('all-stories-status')),
    );
    expect(status.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    final spawn = tester.getSemantics(
      find.byKey(const Key('all-stories-card-spawn')),
    );
    expect(spawn.label, contains(', matches'));
    expect(spawn.label, contains('Started the East timeline'));
    final plain = tester.getSemantics(
      find.byKey(const Key('all-stories-card-plain')),
    );
    expect(plain.label, contains(', not a match'));
    closeSemantics();
  });
}

/// Keeps a semantics handle for this test. [addTearDown] covers a failure
/// that skips the explicit close. The close still runs in the test body,
/// because Flutter checks for an open handle before tearDowns.
VoidCallback _trackSemantics(WidgetTester tester) {
  final handle = tester.ensureSemantics();
  var open = true;
  void close() {
    if (!open) return;
    open = false;
    handle.dispose();
  }

  addTearDown(close);
  return close;
}

Future<GoRouter> _pumpReady(
  WidgetTester tester, {
  bool disableAnimations = false,
}) async {
  await _size(tester, const Size(1440, 900));
  final router = _router(stories: _Stories(), families: _Families());
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

BorderSide _cardBorder(WidgetTester tester, String id) {
  final material = tester.widget<Material>(
    find.descendant(
      of: find.byKey(Key('all-stories-card-$id')),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Material) return false;
        final shape = widget.shape;
        return shape is RoundedRectangleBorder &&
            shape.borderRadius == BorderRadius.circular(albumCardRadius);
      }),
    ),
  );
  final shape = material.shape;
  if (shape is! RoundedRectangleBorder) {
    throw StateError('card $id has no rounded border');
  }
  return shape.side;
}

Future<void> _size(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

double _top(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dy;
}

ScrollController _controller(WidgetTester tester) {
  return tester
      .widget<CustomScrollView>(find.byKey(const Key('all-stories-scroll')))
      .controller!;
}

GoRouter _router({
  required _Stories stories,
  required _Families families,
  String location = '/family/fam-1/stories',
}) {
  return GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, state) => Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.familyLanding,
            familyName: _name,
            families: [_member()],
            currentFamilyId: _family,
            onFamilySelected: FamilySelection.remember,
          ),
          body: const Text('landing-page'),
        ),
      ),
      GoRoute(
        path: AppRoutes.allStories,
        builder: (context, state) => AllStoriesPage(
          familyId: state.pathParameters['id']!,
          storiesApi: stories,
          familiesApi: families,
          photosApi: _Photos(),
        ),
      ),
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) => Scaffold(
          appBar: AlbumHeader(
            page: AlbumHeaderPage.timeline,
            familyName: _name,
            families: [_member()],
            currentFamilyId: FamilySelection.id ?? _family,
            onFamilySelected: FamilySelection.remember,
          ),
          body: const Text('timeline-page'),
        ),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const Scaffold(body: Text('search-page')),
      ),
      GoRoute(
        path: AppRoutes.story,
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              Text('reader-${state.pathParameters['storyId']}'),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

MemberFamily _member() {
  return MemberFamily(
    id: _family,
    name: _name,
    createdAt: DateTime.utc(2020),
    role: 'member',
  );
}

List<Story> _published() {
  return [
    Story(
      id: 'plain',
      familyId: _family,
      authorId: 'author',
      title: 'Plain day',
      status: StoryStatus.published,
      timeframeStart: DateTime(2021, 1, 2),
      datePrecision: StoryDatePrecision.day,
      placeId: 'pier',
      placeLabel: 'Pier',
      placeAddress: '1 Dock',
      people: const [(id: 'ben', name: 'Ben')],
      personNames: const ['Ben'],
    ),
    Story(
      id: 'spawn',
      familyId: _family,
      authorId: 'author',
      title: 'Spawn',
      status: StoryStatus.published,
      timeframeStart: DateTime(2020, 5, 5),
      datePrecision: StoryDatePrecision.day,
      people: const [(id: 'sarah', name: 'Sarah')],
      personNames: const ['Sarah'],
    ),
    Story(
      id: 'kitchen',
      familyId: _family,
      authorId: 'author',
      title: 'Kitchen',
      status: StoryStatus.published,
      timeframeStart: DateTime(2019, 4, 4),
      datePrecision: StoryDatePrecision.day,
      people: const [(id: 'sarah', name: 'Sarah')],
      personNames: const ['Sarah'],
    ),
  ];
}

Story _origin() {
  return Story(
    id: 'origin',
    familyId: 'parent',
    authorId: 'author',
    title: 'From Hart',
    status: StoryStatus.published,
    timeframeStart: DateTime(1999, 8, 8),
    datePrecision: StoryDatePrecision.day,
  );
}

class _Stories implements StoriesGateway {
  _Stories({
    List<Story>? published,
    this.publishedError,
    this.publishedOverride,
    Story? origin,
    bool includeOrigin = true,
  }) : published = published ?? _published(),
       origin = includeOrigin ? (origin ?? _origin()) : null;

  List<Story> published;
  Object? publishedError;
  Future<List<Story>> Function(String familyId)? publishedOverride;
  final Story? origin;
  var publishedCalls = 0;

  @override
  Future<List<Story>> listPublished(String familyId) {
    publishedCalls++;
    final override = publishedOverride;
    if (override != null) return override(familyId);
    if (publishedError != null) {
      return Future<List<Story>>.error(publishedError!);
    }
    return Future<List<Story>>.value(published);
  }

  @override
  Future<Story?> getPublishedOrigin(String storyId) async => origin;

  @override
  Future<Story> createDraft({
    String? id,
    required String familyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    bool allowUndated = false,
    List<String> personIds = const [],
  }) => Future<Story>.error(UnimplementedError());

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) => Future<Story>.error(UnimplementedError());

  @override
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) => Future<bool>.error(UnimplementedError());

  @override
  Future<Story> publish(String storyId) =>
      Future<Story>.error(UnimplementedError());

  @override
  Future<Story> getStory(String storyId) =>
      Future<Story>.error(UnimplementedError());

  @override
  Future<Story?> getPublished(String storyId) =>
      Future<Story?>.error(UnimplementedError());

  @override
  Future<List<Story>> listMyDrafts(String familyId) =>
      Future<List<Story>>.error(UnimplementedError());

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) => Future<List<Story>>.error(UnimplementedError());

  @override
  Future<void> discard(String storyId) =>
      Future<void>.error(UnimplementedError());

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) => Future<void>.error(UnimplementedError());
}

class _Families extends FamiliesGateway {
  @override
  Future<List<MemberFamily>> listMine() async => [_member()];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    return const [
      TreeFamily(id: 'parent', name: 'Hart'),
      TreeFamily(
        id: _family,
        name: _name,
        parentFamilyId: 'parent',
        originStoryId: 'origin',
      ),
      TreeFamily(
        id: 'east',
        name: 'East',
        parentFamilyId: _family,
        originStoryId: 'spawn',
      ),
      TreeFamily(
        id: 'north',
        name: 'North',
        parentFamilyId: _family,
        originStoryId: 'spawn',
      ),
    ];
  }
}

class _Photos implements PhotosGateway {
  @override
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);

  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) => Future<Photo>.error(UnimplementedError());

  @override
  Future<void> deletePhoto(Photo photo) =>
      Future<void>.error(UnimplementedError());

  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) => Future<void>.error(UnimplementedError());

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) => Future<void>.error(UnimplementedError());
}
