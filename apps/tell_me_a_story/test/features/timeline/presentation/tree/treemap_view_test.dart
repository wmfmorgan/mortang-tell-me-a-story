import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_layout.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/treemap_view.dart';
import 'package:tell_me_a_story/core/widgets/timeline/view_switch.dart';

import '../../../../support/tree_fixture.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  final opened = <String>[];
  final families = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    List<Story>? stories,
    Size size = const Size(1280, 800),
  }) async {
    opened.clear();
    families.clear();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        builder: albumAppBuilder,
        home: Scaffold(
          body: TreemapView(
            title: 'Jenkins family tree',
            stories: stories ?? TreeFixture.stories,
            tree: TreeFixture.tree,
            onStory: opened.add,
            onFamily: families.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ViewSwitch<TreemapBy> switcher(WidgetTester tester) =>
      tester.widget<ViewSwitch<TreemapBy>>(find.byKey(const Key('treemap-by')));

  Future<void> groupBy(WidgetTester tester, TreemapBy by) async {
    final segment = find.text(treemapByLabel(by));
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  Finder storyTiles() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('treemap-story-'),
  );

  testWidgets('overview: one group per family under the heading', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Jenkins family tree'), findsOneWidget);
    for (final f in TreeFixture.tree) {
      expect(find.byKey(Key('treemap-group-${f.id}')), findsOneWidget);
    }
    expect(find.text('By family'), findsOneWidget);
    expect(find.text('By decade'), findsOneWidget);
    expect(find.text('By person'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('By family')).dx,
      lessThan(tester.getTopLeft(find.text('By decade')).dx),
    );
    expect(
      tester.getTopLeft(find.text('By decade')).dx,
      lessThan(tester.getTopLeft(find.text('By person')).dx),
    );
    expect(switcher(tester).selected, TreemapBy.family);
    expect(find.text('Group by'), findsNothing);
    expect(find.byKey(const Key('treemap-crumb-group')), findsNothing);
    expect(storyTiles(), findsNothing);
  });

  testWidgets('By decade: drill into a group, a cell, then open a story', (
    tester,
  ) async {
    await pump(tester);
    await groupBy(tester, TreemapBy.decade);
    expect(switcher(tester).selected, TreemapBy.decade);

    await tester.tap(find.byKey(const Key('treemap-group-1970')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('treemap-crumb-group')), findsOneWidget);
    expect(find.text('1970s'), findsOneWidget);
    expect(find.byKey(const Key('treemap-open-family')), findsNothing);

    await tester.tap(find.byKey(const Key('treemap-cell-1970/1975')));
    await tester.pumpAndSettle();
    expect(storyTiles(), findsOneWidget);
    expect(find.text('August 9, 1975\nBea moves north'), findsOneWidget);

    await tester.tap(find.byKey(const Key('treemap-story-s1975')));
    await tester.pumpAndSettle();
    expect(opened, ['s1975']);

    await tester.tap(find.byKey(const Key('treemap-crumb-group')));
    await tester.pumpAndSettle();
    expect(storyTiles(), findsNothing);
    expect(find.byKey(const Key('treemap-cell-1970/1975')), findsOneWidget);

    await tester.tap(find.byKey(const Key('treemap-crumb-root')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('treemap-crumb-group')), findsNothing);
    expect(find.byKey(const Key('treemap-group-1970')), findsOneWidget);
  });

  testWidgets('By family: the header drills in; the action opens the family', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('treemap-open-family')), findsNothing);
    await tester.tap(find.byKey(const Key('treemap-group-${TreeFixture.bea}')));
    await tester.pumpAndSettle();
    expect(families, isEmpty);
    expect(find.byKey(const Key('treemap-crumb-group')), findsOneWidget);
    expect(
      find.byKey(const Key('treemap-cell-${TreeFixture.bea}/1980')),
      findsOneWidget,
    );
    expect(find.text(openFamilyTimelineLabel('Bea')), findsOneWidget);
    expect(openFamilyTimelineLabel('Bea'), 'Open Bea timeline');

    await tester.tap(
      find.byKey(const Key('treemap-cell-${TreeFixture.bea}/1980')),
    );
    await tester.pumpAndSettle();
    expect(storyTiles(), findsOneWidget);
    expect(find.byKey(const Key('treemap-story-b1982')), findsOneWidget);
    expect(families, isEmpty);

    await tester.tap(find.byKey(const Key('treemap-open-family')));
    await tester.pumpAndSettle();
    expect(families, [TreeFixture.bea]);
  });

  testWidgets('By person: groups by tagged person, untagged last', (
    tester,
  ) async {
    await pump(tester);
    await groupBy(tester, TreemapBy.person);
    expect(find.byKey(const Key('treemap-group-p-ada')), findsOneWidget);
    expect(
      find.byKey(const Key('treemap-group-$noOneTaggedGroup')),
      findsOneWidget,
    );
    expect(find.textContaining('No one tagged'), findsOneWidget);
  });

  group('small cells', () {
    // 1952 holds 200 stories and 1958 one, so the 1958 cell is a sliver.
    final crowded = [
      for (var i = 0; i < 200; i++)
        TreeFixture.story(
          'c$i',
          TreeFixture.jenkins,
          'Story $i',
          DateTime(1952, 1, 1 + i % 28),
          const [],
        ),
      TreeFixture.story(
        'lone',
        TreeFixture.jenkins,
        'Lone',
        DateTime(1958, 2, 2),
        const [],
      ),
    ];
    const lone = Key('treemap-cell-1950/1958');

    testWidgets('a finger on a sub-44 pt cell opens its group', (tester) async {
      await pump(tester, stories: crowded);
      await groupBy(tester, TreemapBy.decade);
      final size = tester.getSize(find.byKey(lone));
      expect(size.shortestSide, lessThan(AlbumTarget.min));
      await tester.tap(find.byKey(lone));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('treemap-crumb-group')), findsOneWidget);
      expect(storyTiles(), findsNothing);
      expect(find.byKey(lone), findsOneWidget);
    });

    testWidgets('a mouse on the same cell opens the cell', (tester) async {
      await pump(tester, stories: crowded);
      await groupBy(tester, TreemapBy.decade);
      await tester.tap(find.byKey(lone), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(storyTiles(), findsOneWidget);
      expect(find.byKey(const Key('treemap-story-lone')), findsOneWidget);
    });
  });

  testWidgets('switching grouping while drilled returns to the overview', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.byKey(const Key('treemap-cell-${TreeFixture.jenkins}/1950')),
    );
    await tester.pumpAndSettle();
    expect(storyTiles(), findsNWidgets(2));
    await groupBy(tester, TreemapBy.decade);
    expect(storyTiles(), findsNothing);
    expect(find.byKey(const Key('treemap-crumb-group')), findsNothing);
    expect(find.byKey(const Key('treemap-group-1950')), findsOneWidget);
  });

  testWidgets('cells read their label and story count', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);
    await groupBy(tester, TreemapBy.decade);
    expect(find.bySemanticsLabel('1975, 1 story'), findsOneWidget);
    await groupBy(tester, TreemapBy.family);
    expect(find.bySemanticsLabel('1950s, 2 stories'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an empty tree shows C9 and no switch', (tester) async {
    await pump(tester, stories: const []);
    expect(find.byKey(const Key('empty-timeline')), findsOneWidget);
    expect(find.text('No stories in this family tree yet.'), findsOneWidget);
    expect(find.text('Jenkins family tree'), findsOneWidget);
    expect(find.byKey(const Key('treemap-by')), findsNothing);
  });

  Color? fillOf(WidgetTester tester, Key cell) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(of: find.byKey(cell), matching: find.byType(DecoratedBox))
          .first,
    );
    return (box.decoration as ShapeDecoration).color;
  }

  testWidgets('By family: cells take their family tint', (tester) async {
    await pump(tester);
    final tints = treemapFamilyTints(TreeFixture.tree);
    expect(
      fillOf(tester, const Key('treemap-cell-${TreeFixture.jenkins}/1950')),
      tints[TreeFixture.jenkins],
    );
    expect(
      fillOf(tester, const Key('treemap-cell-${TreeFixture.bea}/1970')),
      tints[TreeFixture.bea],
    );
    expect(tints[TreeFixture.jenkins], isNot(tints[TreeFixture.bea]));
  });

  testWidgets('By decade: a cell takes its dominant family tint', (
    tester,
  ) async {
    await pump(tester);
    await groupBy(tester, TreemapBy.decade);
    final tints = treemapFamilyTints(TreeFixture.tree);
    expect(
      fillOf(tester, const Key('treemap-cell-1970/1975')),
      tints[TreeFixture.jenkins],
    );
    expect(
      fillOf(tester, const Key('treemap-cell-1970/1977')),
      tints[TreeFixture.bea],
    );
  });

  testWidgets('group frames use the strong rule', (tester) async {
    await pump(tester);
    final frame = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byKey(const Key('treemap-group-${TreeFixture.bea}')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final shape = (frame.decoration as ShapeDecoration).shape as OutlinedBorder;
    expect(shape.side.color, albumRuleStrong);
  });

  testWidgets('the count scales with the cell and the label is bolder', (
    tester,
  ) async {
    // Small enough that Cal's cells sit below the 32 pt cap.
    await pump(tester, size: const Size(700, 500));
    Text countIn(String key) => tester.widget<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byKey(const Key('treemap-count')),
      ),
    );
    final big = countIn('treemap-cell-${TreeFixture.jenkins}/1950');
    final small = countIn('treemap-cell-${TreeFixture.cal}/1990');
    expect(big.style!.fontSize, greaterThan(small.style!.fontSize!));
    expect(big.style!.color, albumInk);
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('treemap-cell-${TreeFixture.jenkins}/1950')),
        matching: find.text('1950s'),
      ),
    );
    expect(label.style!.fontWeight, FontWeight.w600);
  });

  Color? swatchOf(WidgetTester tester, String familyId) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(Key('treemap-key-$familyId')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (box.decoration as ShapeDecoration).color;
  }

  testWidgets('the colour key lists every family with its tint', (
    tester,
  ) async {
    await pump(tester);
    final tints = treemapFamilyTints(TreeFixture.tree);
    for (final by in TreemapBy.values) {
      await groupBy(tester, by);
      final key = find.byKey(const Key('treemap-family-key'));
      expect(key, findsOneWidget);
      expect(
        tester.getTopLeft(key).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(const Key('treemap-by'))).dy,
        ),
      );
      var previousX = -1.0;
      for (final f in TreeFixture.tree) {
        final item = find.byKey(Key('treemap-key-${f.id}'));
        expect(
          find.descendant(of: item, matching: find.text(f.name)),
          findsOneWidget,
        );
        expect(swatchOf(tester, f.id), tints[f.id]);
        final x = tester.getTopLeft(item).dx;
        expect(x, greaterThan(previousX));
        previousX = x;
      }
    }
  });

  testWidgets('the colour key wraps on iPad mini portrait and at 320 pt', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 8; i++)
        TreeFamily(id: 'f$i', name: 'The long family name $i'),
    ];
    for (final size in const [Size(744, 1133), Size(320, 568)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: albumTheme(),
          builder: albumAppBuilder,
          home: Scaffold(
            body: TreemapView(
              title: 'Jenkins family tree',
              stories: [
                for (final f in many)
                  TreeFixture.story('s${f.id}', f.id, 'Story', DateTime(1960), [
                    TreeFixture.ada,
                  ]),
              ],
              tree: many,
              onStory: (_) {},
              onFamily: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.byKey(const Key('treemap-key-f0')));
      final last = tester.getRect(find.byKey(const Key('treemap-key-f7')));
      expect(last.top, greaterThan(first.top));
      expect(last.right, lessThanOrEqualTo(size.width));
    }
  });

  testWidgets('fits a 320 pt wide window without overflow', (tester) async {
    await pump(tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await groupBy(tester, TreemapBy.person);
    expect(tester.takeException(), isNull);
  });
}
