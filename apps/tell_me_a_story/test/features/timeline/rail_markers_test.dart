import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/origin_banner.dart';
import 'package:tell_me_a_story/ui/timeline/story_marker.dart';

import '../../support/timeline_fixture.dart';

// 7.4 restyle: one marker system (StoryDot), continuous card corners and
// one spine on every rail. The Jenkins fixture has a Bea branch from s1975.

const _desktop = Size(1280, 800);
const _narrow = Size(744, 1133);

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

MarkerSpec _specUnder(WidgetTester tester, String key) {
  final dots = find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(StoryDot),
  );
  expect(dots, findsOneWidget, reason: key);
  return tester.widget<StoryDot>(dots).spec;
}

bool _anyShadowUnder(String key) => find
    .descendant(
      of: find.byKey(Key(key)),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false),
      ),
    )
    .evaluate()
    .isNotEmpty;

bool _isCardShape(ShapeBorder? shape) =>
    shape is RoundedSuperellipseBorder &&
    shape.borderRadius == BorderRadius.circular(AlbumRadius.card);

const _ids = ['s1952', 's1961', 's1975', 's1978', 's1984', 's1999'];

void main() {
  group('markers', () {
    testWidgets('Decades dots are filled StoryDots; the branch dot is never '
        'ringed in terracotta', (tester) async {
      _setView(tester, _desktop);
      await pumpFixtureTimeline(tester);
      // The centred 1970s highlights the branch story, which takes no
      // terracotta ring; step to the 1980s to see a plain highlight.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      var selected = 0;
      for (final id in _ids) {
        final spec = _specUnder(tester, 'timeline-dot-$id');
        expect(spec.matched, isTrue, reason: id);
        if (spec.selected) selected++;
      }
      expect(selected, 1);
      final branch = _specUnder(tester, 'timeline-dot-s1975');
      expect(branch.selected, isFalse);
      expect(branch.origin, isFalse, reason: 'the callout draws the ring');
      expect(_anyShadowUnder('timeline-dot-s1975'), isFalse);
    });

    testWidgets('the focused Years node is the selected StoryDot', (
      tester,
    ) async {
      _setView(tester, _desktop);
      await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-mid');
      final built = [
        for (final id in _ids)
          if (find.byKey(Key('timeline-mid-node-$id')).evaluate().isNotEmpty)
            id,
      ];
      expect(built.length, greaterThan(1));
      final selected = [
        for (final id in built)
          if (_specUnder(tester, 'timeline-mid-node-$id').selected) id,
      ];
      expect(selected, hasLength(1));
      expect(selected.single, isNot('s1975'));
      for (final id in built) {
        expect(_specUnder(tester, 'timeline-mid-node-$id').matched, isTrue);
      }
    });

    for (final MapEntry(key: name, value: size) in {
      'wide': _desktop,
      'narrow': _narrow,
    }.entries) {
      testWidgets('Days dots are StoryDots with no halo ($name)', (
        tester,
      ) async {
        _setView(tester, size);
        await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-full');
        final selected = <String>[];
        for (final id in _ids) {
          final key = 'timeline-full-dot-$id';
          if (find.byKey(Key(key)).evaluate().isEmpty) continue;
          final spec = _specUnder(tester, key);
          expect(spec.matched, isTrue);
          if (spec.selected) selected.add(id);
          expect(_anyShadowUnder(key), isFalse, reason: id);
        }
        expect(selected, hasLength(1));
        expect(selected.single, isNot('s1975'));
      });
    }
  });

  group('corners', () {
    testWidgets('Years cards use the continuous card shape', (tester) async {
      _setView(tester, _desktop);
      await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-mid');
      final shapes = find
          .descendant(
            of: find.byKey(const Key('timeline-stub-s1975')),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .map((e) => (e.widget as DecoratedBox).decoration)
          .whereType<ShapeDecoration>()
          .map((d) => d.shape);
      expect(shapes.any(_isCardShape), isTrue);
    });

    testWidgets('Days cards use the continuous card shape', (tester) async {
      _setView(tester, _desktop);
      await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-full');
      for (final id in _ids) {
        final card = find.byKey(Key('timeline-card-$id'));
        if (card.evaluate().isEmpty) continue;
        final material = tester.widget<Material>(
          find.ancestor(of: card, matching: find.byType(Material)).first,
        );
        expect(_isCardShape(material.shape), isTrue, reason: id);
      }
    });

    testWidgets('the origin banner uses the continuous card shape', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: albumTheme(),
          builder: albumAppBuilder,
          home: Scaffold(
            body: OriginBanner(
              familyName: 'Bea',
              parentName: 'Jenkins',
              onChoose: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      final banner = tester.widget<DecoratedBox>(
        find.byKey(const Key('timeline-origin-banner')),
      );
      final decoration = banner.decoration as ShapeDecoration;
      expect(_isCardShape(decoration.shape), isTrue);
    });
  });

  group('one spine', () {
    for (final MapEntry(key: zoom, value: zoomKey) in {
      'decades': null,
      'years': 'timeline-zoom-mid',
      'days': 'timeline-zoom-full',
    }.entries) {
      testWidgets('$zoom has one 2 pt albumRule spine at the centre', (
        tester,
      ) async {
        _setView(tester, _desktop);
        await pumpFixtureTimeline(tester, zoomKey: zoomKey);
        final spine = find.byKey(const Key('timeline-spine'));
        expect(spine, findsOneWidget);
        final colored = tester.widget<ColoredBox>(
          find.descendant(of: spine, matching: find.byType(ColoredBox)),
        );
        expect(colored.color, albumRule);
        final rect = tester.getRect(
          find.descendant(of: spine, matching: find.byType(ColoredBox)),
        );
        expect(rect.width, AlbumStroke.mark);
        expect(rect.center.dx, closeTo(_desktop.width / 2, 1));
        // It runs the full height of the rail, not a zero-height stub.
        expect(rect.height, greaterThan(_desktop.height / 2));
      });
    }

    testWidgets('narrow Days spine runs through every dot', (tester) async {
      _setView(tester, _narrow);
      await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-full');
      final line = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('timeline-spine')),
          matching: find.byType(ColoredBox),
        ),
      );
      var checked = 0;
      for (final id in _ids) {
        final dot = find.byKey(Key('timeline-full-dot-$id'));
        if (dot.evaluate().isEmpty) continue;
        expect(
          tester.getCenter(dot).dx,
          closeTo(line.center.dx, 1),
          reason: id,
        );
        checked++;
      }
      expect(checked, greaterThan(1));
    });
  });
}
