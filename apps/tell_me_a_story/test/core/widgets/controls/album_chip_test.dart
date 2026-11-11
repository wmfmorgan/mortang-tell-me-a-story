import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/widgets/controls/album_chip.dart';

Widget _host(Widget child) => MaterialApp(
  theme: albumTheme(),
  builder: albumAppBuilder,
  home: Scaffold(body: Center(child: child)),
);

Color? _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(AlbumChip),
      matching: find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
      ),
    ),
  );
  return (box.decoration as ShapeDecoration).color;
}

void main() {
  testWidgets('selected chips fill sage, others blush', (tester) async {
    await tester.pumpWidget(
      _host(const AlbumChip(label: 'Ann', selected: true)),
    );
    expect(_fill(tester), albumSageTint);
    await tester.pumpWidget(_host(const AlbumChip(label: 'Ann')));
    expect(_fill(tester), albumBlushPale);
  });

  testWidgets('tapping calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AlbumChip(label: 'Ann', onTap: () => taps++)),
    );
    await tester.tap(find.text('Ann'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('tappable chips are at least 44 pt tall', (tester) async {
    await tester.pumpWidget(_host(AlbumChip(label: 'Ann', onTap: () {})));
    expect(
      tester.getSize(find.byType(AlbumChip)).height,
      greaterThanOrEqualTo(AlbumTarget.min),
    );
    await tester.pumpWidget(_host(const AlbumChip(label: 'Ann')));
    expect(
      tester.getSize(find.byType(AlbumChip)).height,
      lessThan(AlbumTarget.min),
    );
  });
}
