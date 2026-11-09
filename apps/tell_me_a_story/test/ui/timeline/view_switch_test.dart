import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/ui/timeline/view_switch.dart';

enum _View { graph, overview }

Widget _host(Widget child) => MaterialApp(
  theme: albumTheme(),
  builder: albumAppBuilder,
  home: Scaffold(body: child),
);

Key _segmentKey(_View v) => Key('view-${v.name}');

void main() {
  testWidgets('reports the tapped value and marks it selected', (tester) async {
    final handle = tester.ensureSemantics();
    var selected = _View.graph;
    final changes = <_View>[];
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => ViewSwitch<_View>(
            key: const Key('view-switch'),
            label: 'View',
            values: _View.values,
            labelOf: (v) => v.name,
            segmentKeyOf: _segmentKey,
            selected: selected,
            onChanged: (v) => setState(() {
              changes.add(v);
              selected = v;
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ViewSwitch<_View> view() =>
        tester.widget<ViewSwitch<_View>>(find.byKey(const Key('view-switch')));
    void expectSelected(_View v, bool on) => expect(
      tester.getSemantics(find.byKey(_segmentKey(v))),
      isSemantics(isSelected: on),
    );
    expect(view().selected, _View.graph);
    expectSelected(_View.graph, true);
    expectSelected(_View.overview, false);

    await tester.tap(find.byKey(_segmentKey(_View.overview)));
    await tester.pumpAndSettle();
    expect(changes, [_View.overview]);
    expect(view().selected, _View.overview);
    expectSelected(_View.overview, true);
    expectSelected(_View.graph, false);
    handle.dispose();
  });

  testWidgets('tapping the selected segment does not report a change', (
    tester,
  ) async {
    final changes = <_View>[];
    await tester.pumpWidget(
      _host(
        ViewSwitch<_View>(
          values: _View.values,
          labelOf: (v) => v.name,
          segmentKeyOf: _segmentKey,
          selected: _View.graph,
          onChanged: changes.add,
        ),
      ),
    );
    await tester.tap(find.byKey(_segmentKey(_View.graph)));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(find.text('View'), findsNothing);
  });

  testWidgets('leading widgets come before the segments', (tester) async {
    await tester.pumpWidget(
      _host(
        ViewSwitch<_View>(
          leading: const [Text('first', key: Key('lead'))],
          values: _View.values,
          labelOf: (v) => v.name,
          segmentKeyOf: _segmentKey,
          selected: _View.graph,
          onChanged: (_) {},
        ),
      ),
    );
    expect(
      tester.getTopRight(find.byKey(const Key('lead'))).dx,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(_segmentKey(_View.graph))).dx,
      ),
    );
  });

  testWidgets('scrolls sideways instead of overflowing when narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        ViewSwitch<_View>(
          label: 'View',
          values: _View.values,
          labelOf: (v) => '${v.name} with a long label',
          selected: _View.graph,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
