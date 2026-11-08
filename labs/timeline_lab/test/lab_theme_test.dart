import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timeline_lab/theme/lab_theme.dart';

import 'support/contrast.dart';

void main() {
  group('text contrast ≥ 4.5:1', () {
    final pairs = <String, (Color, Color)>{
      'ink on parchment': (labInk, labParchment),
      'dimmed ink on parchment': (labDimmedInk, labParchment),
      'dimmed ink on pill fill': (labDimmedInk, labPillFill),
      'terracotta date on parchment': (labTerracotta, labParchment),
      'selected segment label': (labParchment, labTerracotta),
      'selected chip label': (labInk, over(labSageTint, labParchment)),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () => expect(contrast(fg, bg), greaterThanOrEqualTo(4.5)));
    }
  });

  group('marker graphics ≥ 3:1 on parchment', () {
    test('terracotta dot and hollow ring', () {
      expect(contrast(labTerracotta, labParchment), greaterThanOrEqualTo(3));
    });
    test('moss origin ring', () {
      expect(contrast(labMoss, labParchment), greaterThanOrEqualTo(3));
    });
  });

  test('selected segment is terracotta with a parchment label', () {
    final style = labTheme(useGoogleFonts: false).segmentedButtonTheme.style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.selected}),
      labTerracotta,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.selected}),
      labParchment,
    );
  });
}
