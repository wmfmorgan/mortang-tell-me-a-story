import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/timeline_fixture.dart';

// 7.4 touch: a finger gets AlbumTarget.fingerRadius (22 pt) around a dot,
// pointers keep their precise targets, and a finger that covers several
// Decades dots gets the story chooser.

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Offset _dot(WidgetTester tester, String id) =>
    tester.getCenter(find.byKey(Key('timeline-dot-$id')));

void main() {
  testWidgets('a finger 18 pt from a lone Decades dot opens it; a mouse '
      'does not', (tester) async {
    _desktop(tester);
    await pumpFixtureTimeline(tester, stories: fixtureStacked);
    final near = _dot(tester, 's1984') + const Offset(18, 0);

    await tester.tapAt(near, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('story s1984'), findsNothing);

    await tester.tapAt(near);
    await tester.pumpAndSettle();
    expect(find.text('story s1984'), findsOneWidget);
  });

  testWidgets('a finger between stacked 1961 dots opens the chooser', (
    tester,
  ) async {
    _desktop(tester);
    await pumpFixtureTimeline(tester, stories: fixtureStacked);
    final ids = ['s1961', 's1961b', 's1961c'];
    final centres = {for (final id in ids) id: _dot(tester, id)};
    final ordered = ids.toList()
      ..sort((a, b) => centres[a]!.dx.compareTo(centres[b]!.dx));
    final first = centres[ordered[0]]!;
    final second = centres[ordered[1]]!;

    await tester.tapAt(Offset.lerp(first, second, 0.5)!);
    await tester.pumpAndSettle();
    expect(find.text('Stories here'), findsOneWidget);
    expect(find.byKey(Key('chooser-${ordered[0]}')), findsOneWidget);
    expect(find.byKey(Key('chooser-${ordered[1]}')), findsOneWidget);
    expect(find.byKey(Key('chooser-${ordered[2]}')), findsNothing);

    await tester.tap(find.byKey(Key('chooser-${ordered[1]}')));
    await tester.pumpAndSettle();
    expect(find.text('story ${ordered[1]}'), findsOneWidget);
  });

  testWidgets('a mouse click on one stacked dot opens it directly', (
    tester,
  ) async {
    _desktop(tester);
    await pumpFixtureTimeline(tester, stories: fixtureStacked);
    await tester.tapAt(_dot(tester, 's1961b'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Stories here'), findsNothing);
    expect(find.text('story s1961b'), findsOneWidget);
  });

  testWidgets('a finger 18 pt from a Years node opens Days on it', (
    tester,
  ) async {
    _desktop(tester);
    await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-mid');
    final node = tester.getCenter(
      find.byKey(const Key('timeline-mid-node-s1984')),
    );
    await tester.tapAt(node + const Offset(18, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-full-dot-s1984')), findsOneWidget);
  });

  testWidgets('a mouse 18 pt from a Years node misses it', (tester) async {
    _desktop(tester);
    await pumpFixtureTimeline(tester, zoomKey: 'timeline-zoom-mid');
    final node = tester.getCenter(
      find.byKey(const Key('timeline-mid-node-s1984')),
    );
    await tester.tapAt(
      node + const Offset(18, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-full-dot-s1984')), findsNothing);
  });
}
