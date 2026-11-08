import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/ui/timeline/view_switch.dart';

enum _View { graph, overview }

void main() {
  testWidgets('a segmented switch reporting the tapped value', (tester) async {
    var selected = _View.graph;
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ViewSwitch<_View>(
              switchKey: const Key('view-switch'),
              label: 'View',
              values: _View.values,
              labelOf: (v) => v.name,
              selected: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      ),
    );
    SegmentedButton<_View> button() => tester.widget<SegmentedButton<_View>>(
      find.byKey(const Key('view-switch')),
    );
    expect(button().selected, {_View.graph});
    expect(button().showSelectedIcon, isFalse);
    await tester.tap(find.text('overview'));
    await tester.pumpAndSettle();
    expect(button().selected, {_View.overview});
  });

  testWidgets('with no label, only the segments show', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: ViewSwitch<_View>(
            switchKey: const Key('view-switch'),
            values: _View.values,
            labelOf: (v) => v.name,
            selected: _View.graph,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final row = find.descendant(
      of: find.byType(ViewSwitch<_View>),
      matching: find.byType(Row),
    );
    final children = tester.widget<Row>(row.first).children;
    expect(children, hasLength(1));
    expect(children.single, isA<SegmentedButton<_View>>());
  });

  testWidgets('scrolls sideways instead of overflowing when narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Scaffold(
          body: ViewSwitch<_View>(
            switchKey: const Key('view-switch'),
            label: 'View',
            values: _View.values,
            labelOf: (v) => '${v.name} with a long label',
            selected: _View.graph,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
