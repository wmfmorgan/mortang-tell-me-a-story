import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_header.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';

const _ada = 'ada';
const _bea = 'bea';
const _related = 'rel';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });

  tearDown(FamilySelection.clear);

  testWidgets(
    'a different family goes to /family from Drafts, Settings, New, Edit, Manage, and Timeline',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const cases = <(AlbumHeaderPage, String)>[
        (AlbumHeaderPage.drafts, '/drafts'),
        (AlbumHeaderPage.settings, '/settings'),
        (AlbumHeaderPage.capture, '/stories/new'),
        (AlbumHeaderPage.capture, '/stories/s1/edit'),
        (AlbumHeaderPage.manageFamilies, '/manage-families'),
        (AlbumHeaderPage.manageFamilies, '/manage-families/ada'),
        (AlbumHeaderPage.timeline, '/timeline'),
        (AlbumHeaderPage.familyLanding, '/family'),
      ];
      for (final (page, location) in cases) {
        final selected = <String>[];
        final router = _router(
          page: page,
          location: location,
          onSelected: selected.add,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        await _pick(tester, const Key('family-menu-item-$_bea'));
        expect(router.state.uri.path, '/family');
        expect(selected, [_bea]);
        expect(FamilySelection.id, _bea);
      }
    },
  );

  testWidgets('Rule 1: nested family rows behave the same', (tester) async {
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
      page: AlbumHeaderPage.drafts,
      location: '/drafts',
      extra: extra,
      onSelected: fromDrafts.add,
    );
    addTearDown(drafts.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: drafts));
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_related'));
    expect(drafts.state.uri.path, '/family');
    expect(fromDrafts, [_related]);

    final fromTimeline = <String>[];
    final timeline = _router(
      page: AlbumHeaderPage.timeline,
      location: '/timeline',
      extra: extra,
      onSelected: fromTimeline.add,
    );
    addTearDown(timeline.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: timeline));
    await tester.pumpAndSettle();
    await _pick(tester, const Key('family-menu-item-$_related'));
    expect(timeline.state.uri.path, '/family');
    expect(fromTimeline, [_related]);
  });

  testWidgets(
    'Rule 9: picking the current family off Landing goes to /family',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const cases = <(AlbumHeaderPage, String)>[
        (AlbumHeaderPage.drafts, '/drafts'),
        (AlbumHeaderPage.settings, '/settings'),
        (AlbumHeaderPage.capture, '/stories/new'),
        (AlbumHeaderPage.capture, '/stories/s1/edit'),
        (AlbumHeaderPage.manageFamilies, '/manage-families'),
        (AlbumHeaderPage.manageFamilies, '/manage-families/ada'),
        (AlbumHeaderPage.timeline, '/timeline'),
      ];
      for (final (page, location) in cases) {
        FamilySelection.remember('keep');
        final selected = <String>[];
        final router = _router(
          page: page,
          location: location,
          onSelected: selected.add,
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        await _pick(tester, const Key('family-menu-item-$_ada'));
        expect(selected, isEmpty, reason: location);
        expect(router.state.uri.path, '/family', reason: location);
        expect(FamilySelection.id, 'keep', reason: location);
      }
    },
  );

  testWidgets(
    'Rule 9: picking the current family on Landing stays',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FamilySelection.remember('keep');
      final selected = <String>[];
      final router = _router(
        page: AlbumHeaderPage.familyLanding,
        location: '/family',
        onSelected: selected.add,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await _pick(tester, const Key('family-menu-item-$_ada'));
      expect(selected, isEmpty);
      expect(router.state.uri.path, '/family');
      expect(FamilySelection.id, 'keep');
    },
  );
}

GoRouter _router({
  required AlbumHeaderPage page,
  required String location,
  required void Function(String id) onSelected,
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
          FamilySelection.remember(id);
        },
      ),
      body: Text(location),
    );
  }

  return GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/family', builder: (_, _) => screen()),
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
