import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/tree/family_tree_page.dart';
import 'package:tell_me_a_story/features/timeline/tree/treemap_view.dart';

import '../../../support/fakes/fake_stories_gateway.dart';
import '../../../support/tree_fixture.dart';

class _Families extends FamiliesGateway {
  _Families({this.tree = TreeFixture.tree});

  final List<TreeFamily> tree;

  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(
      id: TreeFixture.jenkins,
      name: 'Jenkins',
      createdAt: DateTime.utc(2020),
    ),
    MemberFamily(
      id: TreeFixture.bea,
      name: 'Bea',
      parentFamilyId: TreeFixture.jenkins,
      branchYear: 1975,
      createdAt: DateTime.utc(2021),
    ),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async => tree;
}

class _Live implements TimelineLive {
  final watched = <String>[];
  void Function()? onTreeChange;

  @override
  void watch({required String familyId, required void Function() onChange}) {}

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  @override
  void watchTree({
    required String familyId,
    required void Function() onChange,
  }) {
    watched.add(familyId);
    onTreeChange = onChange;
  }

  var disposed = false;

  @override
  void dispose() => disposed = true;
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FamilySelection.clear();
  });
  tearDown(FamilySelection.clear);

  late FakeStoriesGateway stories;
  late _Live live;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    String familyId = TreeFixture.bea,
    _Families? families,
    Size size = const Size(1280, 800),
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: AppRoutes.familyTreePath(familyId),
      routes: [
        GoRoute(
          path: AppRoutes.familyTree,
          builder: (context, state) => FamilyTreePage(
            familyId: state.pathParameters['id']!,
            storiesApi: stories,
            familiesApi: families ?? _Families(),
            live: live,
          ),
        ),
        GoRoute(
          path: AppRoutes.story,
          builder: (context, state) => const Text('reader-landed'),
        ),
        GoRoute(
          path: AppRoutes.timeline,
          builder: (context, state) => const Text('timeline-landed'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: albumTheme(), routerConfig: router),
    );
    if (settle) await tester.pumpAndSettle();
  }

  setUp(() {
    stories = FakeStoriesGateway(stories: TreeFixture.stories);
    live = _Live();
  });

  testWidgets('loads the whole tree under the root family heading', (
    tester,
  ) async {
    await pump(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('family-tree-page')), findsOneWidget);
    expect(find.text('Jenkins family tree'), findsOneWidget);
    expect(find.byType(TreemapView), findsOneWidget);
    for (final f in TreeFixture.tree) {
      expect(find.byKey(Key('treemap-group-${f.id}')), findsOneWidget);
    }
    expect(stories.calls, ['listPublishedInTree']);
    expect(live.watched, [TreeFixture.bea]);
    expect(FamilySelection.id, TreeFixture.bea);
  });

  testWidgets('a live tree event refetches without a spinner', (tester) async {
    await pump(tester);
    expect(find.text('Cal · 2'), findsOneWidget);

    final added = TreeFixture.story(
      'c1995',
      TreeFixture.cal,
      'Third shop',
      DateTime(1995, 5, 5),
      const [],
    );
    stories.stories[added.id] = added;
    live.onTreeChange!();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TreemapView), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Cal · 3'), findsOneWidget);
    expect(stories.calls, ['listPublishedInTree', 'listPublishedInTree']);
  });

  testWidgets('a story tile opens the reader', (tester) async {
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('treemap-cell-${TreeFixture.bea}/1970')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('treemap-story-b1977')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.storyPath('b1977'));
    expect(find.text('reader-landed'), findsOneWidget);
  });

  testWidgets('a family opens its timeline from the drilled view', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('treemap-group-${TreeFixture.cal}')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.familyTreePath(TreeFixture.bea));
    await tester.tap(find.text('Open Cal timeline'));
    await tester.pumpAndSettle();

    expect(FamilySelection.id, TreeFixture.cal);
    expect(router.state.uri.path, AppRoutes.timeline);
    expect(find.text('timeline-landed'), findsOneWidget);
  });

  testWidgets('an empty tree shows C9', (tester) async {
    stories = FakeStoriesGateway();
    await pump(tester);
    expect(find.text('No stories in this family tree yet.'), findsOneWidget);
    expect(find.text('Jenkins family tree'), findsOneWidget);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    stories.error = const AppException(
      code: AppErrorCode.forbidden,
      message: 'offline',
    );
    await pump(tester);
    expect(find.text("Couldn't load stories."), findsOneWidget);
    expect(find.byType(TreemapView), findsNothing);

    stories.error = null;
    await tester.tap(find.byKey(const Key('family-tree-retry')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load stories."), findsNothing);
    expect(find.text('Jenkins family tree'), findsOneWidget);
  });

  testWidgets('the heading falls back to the current family', (tester) async {
    await pump(
      tester,
      familyId: TreeFixture.bea,
      families: _Families(
        tree: const [TreeFamily(id: TreeFixture.bea, name: 'Bea')],
      ),
    );
    expect(find.text('Bea family tree'), findsOneWidget);
  });

  group('iPad sweep', () {
    for (final size in const [
      Size(744, 1133),
      Size(1133, 744),
      Size(1024, 1366),
      Size(1366, 1024),
      Size(320, 568),
    ]) {
      testWidgets('${size.width.toInt()} × ${size.height.toInt()}', (
        tester,
      ) async {
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
        final map = tester.getRect(find.byType(TreemapLayout).first);
        final switcher = tester.getRect(find.byKey(const Key('treemap-by')));
        expect(map.top, greaterThan(switcher.bottom));
        expect(map.bottom, closeTo(size.height - AlbumSpace.l, 1));
        // The treemap takes most of the window, even at 320 pt.
        expect(map.height, greaterThan(size.height * 0.4));
      });
    }
  });
}
