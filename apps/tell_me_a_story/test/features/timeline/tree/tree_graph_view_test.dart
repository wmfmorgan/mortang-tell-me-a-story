import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/timeline/tree/tree_graph_layout.dart';
import 'package:tell_me_a_story/features/timeline/tree/tree_graph_view.dart';
import 'package:tell_me_a_story/features/timeline/tree/treemap_layout.dart';
import 'package:tell_me_a_story/ui/story/story_date.dart';

import '../../../support/tree_fixture.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  final opened = <String>[];
  final families = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    List<Story>? stories,
    List<TreeFamily> tree = TreeFixture.tree,
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
        home: Scaffold(
          body: TreeGraphView(
            title: 'Jenkins family tree',
            stories: stories ?? TreeFixture.crowded,
            tree: tree,
            onStory: opened.add,
            onFamily: families.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final canvas = find.byKey(const Key('tree-graph-canvas'));

  TreeGraphPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(canvas).painter! as TreeGraphPainter;

  TreeNode node(WidgetTester tester, String id) =>
      painter(tester).layout.nodes.singleWhere((n) => n.id == id);

  /// Scrolls [n] on screen; returns its global centre.
  Future<Offset> reveal(WidgetTester tester, TreeNode n) async {
    final local = painter(tester).layout.positions[n]!;
    final v = Scrollable.of(
      tester.element(canvas),
      axis: Axis.vertical,
    ).position;
    v.jumpTo((local.dy - 200).clamp(0, v.maxScrollExtent));
    final h = Scrollable.of(
      tester.element(canvas),
      axis: Axis.horizontal,
    ).position;
    h.jumpTo((local.dx - 200).clamp(0, h.maxScrollExtent));
    await tester.pump();
    return tester.getTopLeft(canvas) + local;
  }

  Future<void> tapNode(
    WidgetTester tester,
    String id, {
    Offset offset = Offset.zero,
    PointerDeviceKind kind = PointerDeviceKind.mouse,
  }) async {
    final at = await reveal(tester, node(tester, id));
    await tester.tapAt(at + offset, kind: kind);
    await tester.pumpAndSettle();
  }

  testWidgets('heading and one painted graph; a story dot opens the story', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Jenkins family tree'), findsOneWidget);
    expect(canvas, findsOneWidget);
    expect(painter(tester).layout.root.id, 'f-${TreeFixture.jenkins}');

    await tapNode(tester, 's:s1952');
    expect(opened, ['s1952']);
  });

  testWidgets('a finger reaches a dot 12 pt away; a mouse does not', (
    tester,
  ) async {
    await pump(tester);
    await tapNode(tester, 's:s1952', offset: const Offset(0, 12));
    expect(opened, isEmpty);
    await tapNode(
      tester,
      's:s1952',
      offset: const Offset(0, 12),
      kind: PointerDeviceKind.touch,
    );
    expect(opened, ['s1952']);
  });

  testWidgets('+N expands its decade; the decade collapses it again', (
    tester,
  ) async {
    await pump(tester);
    const sixties = 'f-${TreeFixture.jenkins}-d-1960';
    expect(node(tester, sixties).children, hasLength(6));
    final more = node(tester, 'more:$sixties');
    expect(more.label, '+3');

    await tapNode(tester, more.id);
    expect(node(tester, sixties).children, hasLength(8));
    expect(node(tester, sixties).children.map((c) => c.kind).toSet(), {
      TreeNodeKind.story,
    });
    expect(opened, isEmpty);

    await tapNode(tester, sixties);
    expect(node(tester, sixties).children, hasLength(6));
  });

  testWidgets('the whole +N pill is a target, not just its anchor', (
    tester,
  ) async {
    await pump(tester);
    const sixties = 'f-${TreeFixture.jenkins}-d-1960';
    final more = node(tester, 'more:$sixties');
    final pill = painter(tester).overflowRect(more);
    final anchor = painter(tester).layout.positions[more]!;
    // The pill's far end is beyond the precise radius of its anchor.
    final end = Offset(pill.right - 2, pill.center.dy);
    expect((end - anchor).distance, greaterThan(10));

    await tapNode(tester, more.id, offset: end - anchor);
    expect(node(tester, sixties).children, hasLength(8));
  });

  testWidgets('a family tap selects it and offers its timeline (C19)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('tree-graph-open-family')), findsNothing);

    await tapNode(tester, 'f-${TreeFixture.bea}');
    expect(families, isEmpty);
    expect(painter(tester).selectedFamilyId, TreeFixture.bea);
    expect(find.text('Open Bea timeline'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tree-graph-open-family')));
    expect(families, [TreeFixture.bea]);

    await tapNode(tester, 'f-${TreeFixture.jenkins}');
    expect(find.text('Open Bea timeline'), findsNothing);
    expect(find.text('Open Jenkins timeline'), findsOneWidget);
  });

  testWidgets('the whole family name chip selects the family', (tester) async {
    await pump(tester);
    final bea = node(tester, 'f-${TreeFixture.bea}');
    final chip = painter(tester).familyChipRect(bea);
    final anchor = painter(tester).layout.positions[bea]!;
    // Every corner and the middle of the chip, each beyond the dot's
    // precise radius, with a mouse and a finger.
    final points = [
      chip.topLeft + const Offset(1, 1),
      chip.topRight + const Offset(-1, 1),
      chip.bottomLeft + const Offset(1, -1),
      chip.bottomRight + const Offset(-1, -1),
      chip.center,
    ];
    for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
      for (final at in points) {
        await tapNode(tester, 'f-${TreeFixture.jenkins}');
        expect(painter(tester).selectedFamilyId, TreeFixture.jenkins);
        await tapNode(tester, bea.id, offset: at - anchor, kind: kind);
        expect(
          painter(tester).selectedFamilyId,
          TreeFixture.bea,
          reason: '$kind at ${at - anchor}',
        );
      }
    }
    expect(opened, isEmpty);
    // Just outside the chip's right edge, level with its middle: nothing.
    await tapNode(tester, 'f-${TreeFixture.jenkins}');
    await tapNode(
      tester,
      bea.id,
      offset: Offset(chip.right + 4, chip.center.dy) - anchor,
    );
    expect(painter(tester).selectedFamilyId, TreeFixture.jenkins);
  });

  testWidgets('VoiceOver: one node per family, covering dot and chip', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final bea = node(tester, 'f-${TreeFixture.bea}');
    final family = find.semantics.byLabel('Bea (1975), 3 stories');
    expect(family, findsOne);
    final rect = family.evaluate().single.rect;
    final chip = painter(tester).familyChipRect(bea);
    final dot = painter(tester).layout.rectOf(bea);
    expect(rect, chip.expandToInclude(dot));
    expect(find.semantics.byLabel('Bea (1975)'), findsNothing);

    tester.semantics.tap(family);
    await tester.pumpAndSettle();
    expect(painter(tester).selectedFamilyId, TreeFixture.bea);
    handle.dispose();
  });

  testWidgets('families wear their treemap tints', (tester) async {
    await pump(tester);
    expect(painter(tester).tints, treemapFamilyTints(TreeFixture.tree));
  });

  testWidgets('semantics: stories, +N, families and decades', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    final flood = TreeFixture.crowded.firstWhere((s) => s.id == 's1952');
    final story = find.semantics.byLabel(
      'The flood year, ${storyDateLabelFor(flood)}',
    );
    expect(story, findsOne);
    expect(
      story.evaluate().single.getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    expect(find.semantics.byLabel('3 more stories'), findsOne);
    expect(find.semantics.byLabel('Bea (1975), 3 stories'), findsOne);
    expect(find.semantics.byLabel('1960s, 8 stories'), findsOne);

    tester.semantics.tap(story);
    await tester.pumpAndSettle();
    expect(opened, ['s1952']);

    tester.semantics.tap(find.semantics.byLabel('3 more stories'));
    await tester.pumpAndSettle();
    expect(
      node(tester, 'f-${TreeFixture.jenkins}-d-1960').children,
      hasLength(8),
    );
    handle.dispose();
  });

  testWidgets('the graph pans on both axes over its full height', (
    tester,
  ) async {
    await pump(tester, size: const Size(744, 1133));
    final viewport = tester.getRect(find.byKey(const Key('tree-graph-pan')));
    expect(viewport.bottom, closeTo(1133, 1));
    final h = Scrollable.of(
      tester.element(canvas),
      axis: Axis.horizontal,
    ).position;
    expect(h.maxScrollExtent, greaterThan(0));
    // Below the last node, where the graph has no dots, a drag still pans.
    await tester.dragFrom(
      Offset(viewport.center.dx, viewport.bottom - 20),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(h.pixels, greaterThan(0));
  });

  testWidgets('no stories: C9 under the heading', (tester) async {
    await pump(tester, stories: const []);
    expect(find.text('No stories in this family tree yet.'), findsOneWidget);
    expect(canvas, findsNothing);
  });

  testWidgets('1 000 stories build their first frame (sanity check)', (
    tester,
  ) async {
    final (:stories, :tree) = TreeFixture.synthetic(1000);
    final watch = Stopwatch()..start();
    await pump(tester, stories: stories, tree: tree);
    watch.stop();
    expect(tester.takeException(), isNull);
    expect(painter(tester).layout.storyNodes, hasLength(1000));
    // Debug-mode test harness, not a device: a loose bound. 7.M decides.
    expect(watch.elapsedMilliseconds, lessThan(3000));
  });
}
