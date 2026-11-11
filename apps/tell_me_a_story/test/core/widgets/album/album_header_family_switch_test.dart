import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/widgets/album/album_header.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';

import '../../../support/album_test_scope.dart';

const _ada = 'ada';
const _bea = 'bea';
const _related = 'rel';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'a different family goes to /family from Drafts, Settings, New, Edit, Manage',
    (tester) async {
      final container = albumTestContainer();
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const cases = <(AlbumHeaderPage, String)>[
        (AlbumHeaderPage.drafts, '/drafts'),
        (AlbumHeaderPage.settings, '/settings'),
        (AlbumHeaderPage.capture, '/stories/new'),
        (AlbumHeaderPage.capture, '/stories/s1/edit'),
        (AlbumHeaderPage.manageFamilies, '/manage-families'),
        (AlbumHeaderPage.manageFamilies, '/manage-families/ada'),
        (AlbumHeaderPage.familyLanding, '/family'),
      ];
      for (final (page, location) in cases) {
        final selected = <String>[];
        final router = _router(
          container: container,
          page: page,
          location: location,
          onSelected: selected.add,
        );
        addTearDown(router.dispose);
        await pumpScoped(
          tester,
          container,
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
        await _pick(tester, const Key('family-menu-item-$_bea'));
        expect(router.state.uri.path, '/family');
        expect(selected, [_bea]);
        expect(container.read(familySelectionProvider), _bea);
      }
    },
  );

  testWidgets('Rule 1: nested family rows behave the same', (tester) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final extra = [
      MemberFamily(
        id: _related,
        name: 'Cousin',
        parentFamilyId: _ada,
        createdAt: DateTime.utc(2022),
      ),
    ];

    final fromDrafts = <String>[];
    final drafts = _router(
      container: container,
      page: AlbumHeaderPage.drafts,
      location: '/drafts',
      extra: extra,
      onSelected: fromDrafts.add,
    );
    addTearDown(drafts.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: drafts),
    );
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_related'));
    expect(drafts.state.uri.path, '/family');
    expect(fromDrafts, [_related]);

    final fromTimeline = <String>[];
    final timeline = _router(
      container: container,
      page: AlbumHeaderPage.timeline,
      location: '/timeline',
      extra: extra,
      onSelected: fromTimeline.add,
    );
    addTearDown(timeline.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: timeline),
    );
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_related'));
    expect(timeline.state.uri.path, '/timeline');
    expect(fromTimeline, [_related]);
  });

  testWidgets('a different family on Timeline stays on /timeline', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = <String>[];
    final router = _router(
      container: container,
      page: AlbumHeaderPage.timeline,
      location: '/timeline',
      onSelected: selected.add,
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_bea'));
    expect(router.state.uri.path, '/timeline');
    expect(selected, [_bea]);
    expect(container.read(familySelectionProvider), _bea);
  });

  testWidgets('a different family on the tree goes to that family tree', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = <String>[];
    final router = _router(
      container: container,
      page: AlbumHeaderPage.familyTree,
      location: '/family/$_ada/tree',
      onSelected: selected.add,
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_bea'));
    expect(router.state.uri.path, '/family/$_bea/tree');
    expect(selected, [_bea]);
  });

  testWidgets('a different family on All stories goes to its stories', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = <String>[];
    final router = _router(
      container: container,
      page: AlbumHeaderPage.allStories,
      location: '/family/$_ada/stories',
      onSelected: selected.add,
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_bea'));
    expect(router.state.uri.path, '/family/$_bea/stories');
    expect(selected, [_bea]);
  });

  testWidgets('picking the current family on Timeline, tree or stories stays', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const cases = <(AlbumHeaderPage, String)>[
      (AlbumHeaderPage.timeline, '/timeline'),
      (AlbumHeaderPage.familyTree, '/family/$_ada/tree'),
      (AlbumHeaderPage.allStories, '/family/$_ada/stories'),
    ];
    for (final (page, location) in cases) {
      final selected = <String>[];
      final router = _router(
        container: container,
        page: page,
        location: location,
        onSelected: selected.add,
      );
      addTearDown(router.dispose);
      await pumpScoped(
        tester,
        container,
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();
      await _pick(tester, const Key('family-menu-item-$_ada'));
      expect(selected, isEmpty, reason: location);
      expect(router.state.uri.path, location, reason: location);
    }
  });

  testWidgets(
    'Rule 9: picking the current family off Landing goes to /family',
    (tester) async {
      final container = albumTestContainer();
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const cases = <(AlbumHeaderPage, String)>[
        (AlbumHeaderPage.drafts, '/drafts'),
        (AlbumHeaderPage.settings, '/settings'),
        (AlbumHeaderPage.capture, '/stories/new'),
        (AlbumHeaderPage.capture, '/stories/s1/edit'),
        (AlbumHeaderPage.manageFamilies, '/manage-families'),
        (AlbumHeaderPage.manageFamilies, '/manage-families/ada'),
      ];
      for (final (page, location) in cases) {
        container.read(familySelectionProvider.notifier).remember('keep');
        final selected = <String>[];
        final router = _router(
          container: container,
          page: page,
          location: location,
          onSelected: selected.add,
        );
        addTearDown(router.dispose);
        await pumpScoped(
          tester,
          container,
          MaterialApp.router(routerConfig: router),
        );
        await tester.pumpAndSettle();
        await _pick(tester, const Key('family-menu-item-$_ada'));
        expect(selected, isEmpty, reason: location);
        expect(router.state.uri.path, '/family', reason: location);
        expect(
          container.read(familySelectionProvider),
          'keep',
          reason: location,
        );
      }
    },
  );

  testWidgets('home sits left of Timeline and opens Landing', (tester) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selected = <String>[];
    container.read(familySelectionProvider.notifier).remember('keep');
    final router = _router(
      container: container,
      page: AlbumHeaderPage.timeline,
      location: '/timeline',
      onSelected: selected.add,
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();

    final home = tester.getTopLeft(find.byKey(const Key('header-nav-home')));
    final stories = tester.getTopLeft(
      find.byKey(const Key('header-nav-stories')),
    );
    final timeline = tester.getTopLeft(
      find.byKey(const Key('header-nav-timeline')),
    );
    final drafts = tester.getTopLeft(find.byKey(const Key('drafts-nav')));
    expect(home.dx, lessThan(stories.dx));
    expect(stories.dx, lessThan(timeline.dx));
    expect(timeline.dx, lessThan(drafts.dx));
    final icon = tester.widget<Icon>(find.byIcon(Icons.home));
    expect(icon.color, albumTerracotta);
    expect(icon.size, 26);
    expect(
      tester.getSize(find.byKey(const Key('header-nav-home'))),
      const Size(44, 44),
    );
    expect(find.byTooltip('Home'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    semantics.dispose();
    expect(
      tester.getRect(find.byIcon(Icons.home)).center.dy,
      closeTo(tester.getRect(find.text('Stories')).center.dy, 1),
    );

    await tester.tap(find.byKey(const Key('header-nav-home')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/family');
    expect(selected, isEmpty);
    expect(container.read(familySelectionProvider), 'keep');
  });

  testWidgets('home on Landing stays', (tester) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = _router(
      container: container,
      page: AlbumHeaderPage.familyLanding,
      location: '/family',
      onSelected: (_) {},
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('header-nav-home')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/family');
  });

  testWidgets('Rule 9: picking the current family on Landing stays', (
    tester,
  ) async {
    final container = albumTestContainer();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    container.read(familySelectionProvider.notifier).remember('keep');
    final selected = <String>[];
    final router = _router(
      container: container,
      page: AlbumHeaderPage.familyLanding,
      location: '/family',
      onSelected: selected.add,
    );
    addTearDown(router.dispose);
    await pumpScoped(
      tester,
      container,
      MaterialApp.router(routerConfig: router),
    );
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_ada'));
    expect(selected, isEmpty);
    expect(router.state.uri.path, '/family');
    expect(container.read(familySelectionProvider), 'keep');
  });
}

GoRouter _router({
  required AlbumHeaderPage page,
  required String location,
  required void Function(String id) onSelected,
  required ProviderContainer container,
  List<MemberFamily> extra = const [],
}) {
  Widget screen() {
    return Scaffold(
      appBar: AlbumHeader(
        page: page,
        familyName: 'Ada',
        families: [
          MemberFamily(id: _ada, name: 'Ada', createdAt: DateTime.utc(2020)),
          MemberFamily(id: _bea, name: 'Bea', createdAt: DateTime.utc(2021)),
          ...extra,
        ],
        currentFamilyId: _ada,
        onFamilySelected: (id) {
          onSelected(id);
          container.read(familySelectionProvider.notifier).remember(id);
        },
      ),
      body: Text(location),
    );
  }

  return GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/family', builder: (_, _) => screen()),
      GoRoute(path: '/family/:familyId/tree', builder: (_, _) => screen()),
      GoRoute(path: '/family/:familyId/stories', builder: (_, _) => screen()),
      GoRoute(path: '/timeline', builder: (_, _) => screen()),
      GoRoute(path: '/drafts', builder: (_, _) => screen()),
      GoRoute(path: '/settings', builder: (_, _) => screen()),
      GoRoute(path: '/stories/new', builder: (_, _) => screen()),
      GoRoute(path: '/stories/:storyId/edit', builder: (_, _) => screen()),
      GoRoute(path: '/manage-families', builder: (_, _) => screen()),
      GoRoute(path: '/manage-families/:familyId', builder: (_, _) => screen()),
    ],
  );
}

Future<void> _pick(WidgetTester tester, Key item) async {
  await tester.tap(find.byKey(const Key('family-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(item));
  await tester.pumpAndSettle();
}
