import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_page.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/tree_graph_view.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_view.dart';
import 'package:tell_me_a_story/core/widgets/timeline/view_switch.dart';

import '../../../../support/fakes/fake_stories_repository.dart';
import '../../../../support/pump_app.dart';
import '../../../../support/tree_fixture.dart';
import '../../../../support/ipad.dart';

class _Families extends FamiliesRepository {
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
  });

  String? selectedFamily(WidgetTester tester) =>
      containerOf(tester).read(familySelectionProvider);

  late FakeStoriesRepository stories;
  late _Live live;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    String familyId = TreeFixture.bea,
    _Families? families,
    Size size = const Size(1280, 800),
    bool settle = true,
    bool ipad = false,
  }) async {
    if (ipad) {
      setIpadView(tester, size);
    } else {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    router = GoRouter(
      initialLocation: AppRoutes.familyTreePath(familyId),
      routes: [
        GoRoute(
          path: AppRoutes.familyTree,
          builder: (context, state) =>
              FamilyTreePage(familyId: state.pathParameters['id'] ?? ''),
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
    await pumpRouterApp(
      tester,
      router,
      overrides: [
        storiesRepositoryProvider.overrideWithValue(stories),
        familiesRepositoryProvider.overrideWithValue(families ?? _Families()),
        timelineLiveProvider.overrideWithValue(live),
      ],
    );
    if (settle) await tester.pumpAndSettle();
  }

  setUp(() {
    stories = FakeStoriesRepository(stories: TreeFixture.stories);
    live = _Live();
  });

  final viewSwitch = find.byKey(const Key('family-tree-view'));

  ViewSwitch<FamilyTreeView> switchButton(WidgetTester tester) =>
      tester.widget<ViewSwitch<FamilyTreeView>>(viewSwitch);

  Future<void> openOverview(WidgetTester tester) async {
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
  }

  /// Taps the graph node [id] with a mouse, after scrolling it on screen.
  Future<void> tapGraphNode(WidgetTester tester, String id) async {
    final canvas = find.byKey(const Key('tree-graph-canvas'));
    final layout =
        (tester.widget<CustomPaint>(canvas).painter! as TreeGraphPainter)
            .layout;
    final local =
        layout.positions[layout.nodes.singleWhere((n) => n.id == id)]!;
    final v = Scrollable.of(
      tester.element(canvas),
      axis: Axis.vertical,
    ).position;
    v.jumpTo((local.dy - 200).clamp(0, v.maxScrollExtent));
    await tester.pump();
    await tester.tapAt(
      tester.getTopLeft(canvas) + local,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads the whole tree under the root family heading', (
    tester,
  ) async {
    await pump(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('family-tree-page')), findsOneWidget);
    expect(find.text('Jenkins family tree'), findsOneWidget);
    expect(stories.calls, ['listPublishedInTree']);
    expect(live.watched, [TreeFixture.bea]);
    expect(selectedFamily(tester), TreeFixture.bea);
  });

  testWidgets('opens on Family tree: C3 · C4, no label, the graph shows', (
    tester,
  ) async {
    await pump(tester);
    expect(switchButton(tester).selected, FamilyTreeView.graph);
    expect(switchButton(tester).label, isNull);
    expect(
      [
        for (final v in switchButton(tester).values)
          switchButton(tester).labelOf(v),
      ],
      ['Family tree', 'Overview'],
    );
    expect(find.byType(TreeGraphView), findsOneWidget);
    expect(find.byType(TreemapView), findsNothing);
    expect(find.text('Jenkins family tree'), findsOneWidget);
  });

  testWidgets('Overview shows the treemap; the switch stays put', (
    tester,
  ) async {
    await pump(tester);
    final onGraph = tester.getTopLeft(viewSwitch);

    await openOverview(tester);
    expect(switchButton(tester).selected, FamilyTreeView.overview);
    expect(find.byType(TreemapView), findsOneWidget);
    expect(find.byType(TreeGraphView), findsNothing);
    for (final f in TreeFixture.tree) {
      expect(find.byKey(Key('treemap-group-${f.id}')), findsOneWidget);
    }
    final onTreemap = tester.getTopLeft(viewSwitch);
    expect(onTreemap.dx, closeTo(onGraph.dx, 1));
    expect(onTreemap.dy, closeTo(onGraph.dy, 1));
    // One row: the grouping switch follows the view switch.
    final grouping = tester.getRect(find.byKey(const Key('treemap-by')));
    expect(
      grouping.left,
      greaterThanOrEqualTo(tester.getRect(viewSwitch).right),
    );
    expect(grouping.center.dy, closeTo(tester.getCenter(viewSwitch).dy, 1));

    await tester.tap(find.text('Family tree'));
    await tester.pumpAndSettle();
    expect(find.byType(TreeGraphView), findsOneWidget);
    expect(find.byType(TreemapView), findsNothing);
  });

  testWidgets('a live tree event refetches without a spinner', (tester) async {
    await pump(tester);
    await openOverview(tester);
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

    // The reload keeps the selected view.
    expect(switchButton(tester).selected, FamilyTreeView.overview);
    expect(find.text('Cal · 3'), findsOneWidget);
    expect(stories.calls, ['listPublishedInTree', 'listPublishedInTree']);
  });

  testWidgets('a live tree event redraws the graph', (tester) async {
    await pump(tester);
    stories.stories['c1995'] = TreeFixture.story(
      'c1995',
      TreeFixture.cal,
      'Third shop',
      DateTime(1995, 5, 5),
      const [],
    );
    live.onTreeChange!();
    await tester.pumpAndSettle();
    expect(find.byType(TreeGraphView), findsOneWidget);
    final layout =
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const Key('tree-graph-canvas')),
                    )
                    .painter!
                as TreeGraphPainter)
            .layout;
    expect(layout.storyNodes, contains('c1995'));
  });

  testWidgets('a graph story opens the reader', (tester) async {
    await pump(tester);
    await tapGraphNode(tester, 's:b1977');
    expect(router.state.uri.path, AppRoutes.storyPath('b1977'));
    expect(find.text('reader-landed'), findsOneWidget);
  });

  testWidgets('a graph family, then C19, opens its timeline', (tester) async {
    await pump(tester);
    await tapGraphNode(tester, 'f-${TreeFixture.cal}');
    expect(router.state.uri.path, AppRoutes.familyTreePath(TreeFixture.bea));
    await tester.tap(find.text('Open Cal timeline'));
    await tester.pumpAndSettle();

    expect(selectedFamily(tester), TreeFixture.cal);
    expect(router.state.uri.path, AppRoutes.timeline);
    expect(find.text('timeline-landed'), findsOneWidget);
  });

  testWidgets('a story tile opens the reader', (tester) async {
    await pump(tester);
    await openOverview(tester);
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
    await openOverview(tester);
    await tester.tap(find.byKey(const Key('treemap-group-${TreeFixture.cal}')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.familyTreePath(TreeFixture.bea));
    await tester.tap(find.text('Open Cal timeline'));
    await tester.pumpAndSettle();

    expect(selectedFamily(tester), TreeFixture.cal);
    expect(router.state.uri.path, AppRoutes.timeline);
    expect(find.text('timeline-landed'), findsOneWidget);
  });

  testWidgets('an empty tree shows C9 and no switch', (tester) async {
    stories = FakeStoriesRepository();
    await pump(tester);
    expect(find.text('No stories in this family tree yet.'), findsOneWidget);
    expect(find.text('Jenkins family tree'), findsOneWidget);
    expect(viewSwitch, findsNothing);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    stories.error = const AppException(
      code: AppErrorCode.forbidden,
      message: 'offline',
    );
    await pump(tester);
    expect(find.text("Couldn't load stories."), findsOneWidget);
    expect(find.byType(TreemapView), findsNothing);
    expect(find.byType(TreeGraphView), findsNothing);

    stories.error = null;
    await tester.tap(find.byKey(const Key('empty-action')));
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
    for (final MapEntry(key: name, value: size) in ipadSizes.entries) {
      testWidgets('$name, both views', (tester) async {
        stories = FakeStoriesRepository(stories: TreeFixture.crowded);
        final errors = await collectFlutterErrors(() async {
          await pump(tester, size: size, ipad: true);

          // The graph: under the switch, down to the window bottom.
          final pan = tester.getRect(find.byKey(const Key('tree-graph-pan')));
          expect(
            pan.top,
            greaterThanOrEqualTo(tester.getRect(viewSwitch).bottom),
          );
          expect(pan.bottom, closeTo(size.height, 1));
          expect(pan.height, greaterThan(size.height * 0.5));

          await openOverview(tester);
          final map = tester.getRect(find.byType(TreemapLayout).first);
          final grouping = tester.getRect(find.byKey(const Key('treemap-by')));
          expect(map.top, greaterThan(grouping.bottom));
          expect(map.bottom, closeTo(size.height - AlbumSpace.l, 1));
          // As 7.7: over half the window on iPad, over a third when narrow.
          expect(
            map.height,
            greaterThan(size.height * (size.width < 700 ? 0.35 : 0.5)),
          );
        });
        expect(errors, isEmpty);
      }, variant: ios);
    }
  });
}
