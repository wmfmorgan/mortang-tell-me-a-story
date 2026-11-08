import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

import '../../support/contrast.dart';

// Ported from the timeline lab's lab_theme_test.dart (Q5 visual system).
void main() {
  group('text contrast ≥ 4.5:1', () {
    final pairs = <String, (Color, Color)>{
      'ink on parchment': (albumInk, albumParchment),
      'dim ink on parchment': (albumDimInk, albumParchment),
      'dim ink on pill fill': (albumDimInk, albumPillFill),
      'terracotta date on parchment': (albumTerracotta, albumParchment),
      'selected segment label': (albumParchment, albumTerracotta),
      'selected chip label': (albumInk, over(albumSageTint, albumParchment)),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      test(name, () => expect(contrast(fg, bg), greaterThanOrEqualTo(4.5)));
    }
  });

  test('the selected segment label reads 5.18:1', () {
    expect(contrast(albumParchment, albumTerracotta), closeTo(5.18, 0.01));
  });

  group('marker graphics ≥ 3:1 on parchment', () {
    test('terracotta dot and hollow ring', () {
      expect(
        contrast(albumTerracotta, albumParchment),
        greaterThanOrEqualTo(3),
      );
    });
    test('moss origin ring', () {
      expect(contrast(branchMoss, albumParchment), greaterThanOrEqualTo(3));
    });
  });
}
