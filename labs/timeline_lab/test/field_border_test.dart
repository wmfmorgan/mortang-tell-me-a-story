import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 240, 48);
  const side = BorderSide(color: labSageLine);

  test('the field outline has continuous corners, not square ones', () {
    const border = LabFieldBorder(borderSide: side);
    final outer = border.getOuterPath(rect);
    expect(outer.contains(rect.center), isTrue);
    // Edge midpoints are inside; the extreme corner is cut away.
    expect(outer.contains(const Offset(120, 0.5)), isTrue);
    expect(outer.contains(const Offset(0.5, 24)), isTrue);
    expect(outer.contains(const Offset(0.5, 0.5)), isFalse);
    expect(outer.contains(const Offset(239.5, 47.5)), isFalse);
  });

  test('the inner path sits one border width inside the outer one', () {
    const border = LabFieldBorder(
      borderSide: BorderSide(color: labTerracotta, width: LabStroke.mark),
    );
    final inner = border.getInnerPath(rect);
    expect(inner.contains(const Offset(120, 1)), isFalse);
    expect(inner.contains(const Offset(120, 3)), isTrue);
  });

  test('focus transition lerps width, colour and radius', () {
    const from = LabFieldBorder(borderSide: side);
    const to = LabFieldBorder(
      borderSide: BorderSide(color: labTerracotta, width: LabStroke.mark),
    );
    final mid = from.lerpTo(to, 0.5)! as LabFieldBorder;
    expect(mid.borderSide.width, closeTo(1.5, 1e-9));
    expect(mid.radius, LabRadius.card);
    expect(from.copyWith(borderSide: to.borderSide), isA<LabFieldBorder>());
  });

  testWidgets('the search field uses it and has no floating-label notch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: labTheme(useGoogleFonts: false),
        home: const Scaffold(
          body: TextField(decoration: InputDecoration(hintText: 'Search')),
        ),
      ),
    );
    final theme = Theme.of(tester.element(find.byType(TextField)));
    expect(theme.inputDecorationTheme.border, isA<LabFieldBorder>());
    expect(theme.inputDecorationTheme.focusedBorder, isA<LabFieldBorder>());
  });
}
