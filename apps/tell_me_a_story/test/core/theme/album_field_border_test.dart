import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';

// Ported from labs/timeline_lab/test/field_border_test.dart. The app's
// inputDecorationTheme keeps OutlineInputBorder until a slice adopts this.
void main() {
  const rect = Rect.fromLTWH(0, 0, 240, 48);
  const side = BorderSide(color: albumSageLine);

  test('the field outline has continuous corners, not square ones', () {
    const border = AlbumFieldBorder(borderSide: side);
    final outer = border.getOuterPath(rect);
    expect(outer.contains(rect.center), isTrue);
    // Edge midpoints are inside; the extreme corner is cut away.
    expect(outer.contains(const Offset(120, 0.5)), isTrue);
    expect(outer.contains(const Offset(0.5, 24)), isTrue);
    expect(outer.contains(const Offset(0.5, 0.5)), isFalse);
    expect(outer.contains(const Offset(239.5, 47.5)), isFalse);
  });

  test('the inner path sits one border width inside the outer one', () {
    const border = AlbumFieldBorder(
      borderSide: BorderSide(color: albumTerracotta, width: AlbumStroke.mark),
    );
    final inner = border.getInnerPath(rect);
    expect(inner.contains(const Offset(120, 1)), isFalse);
    expect(inner.contains(const Offset(120, 3)), isTrue);
  });

  test('focus transition lerps width, colour and radius', () {
    const from = AlbumFieldBorder(borderSide: side);
    const to = AlbumFieldBorder(
      borderSide: BorderSide(color: albumTerracotta, width: AlbumStroke.mark),
    );
    final mid = from.lerpTo(to, 0.5)! as AlbumFieldBorder;
    expect(mid.borderSide.width, closeTo(1.5, 1e-9));
    expect(mid.radius, AlbumRadius.card);
    expect(from.copyWith(borderSide: to.borderSide), isA<AlbumFieldBorder>());
  });
}
