import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/features/stories/photo_strip.dart';

const _photo = Photo(
  id: 'ph1',
  storyId: 's1',
  familyId: 'f1',
  uploaderId: 'u1',
  storagePath: 'f1/s1/ph1.jpg',
  sortOrder: 0,
);

Uint8List _solidJpeg() {
  final image = img.Image(width: 8, height: 8);
  img.fill(image, color: img.ColorRgb8(200, 80, 40));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  testWidgets('thumb renders Image when preview bytes are provided',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoStrip(
          photos: const [_photo],
          previews: {'ph1': _solidJpeg()},
          onAdd: () {},
          onRemove: (_) {},
          onRetry: () {},
          uploadFailed: false,
          canAdd: true,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('photo-thumb')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.photo_outlined), findsNothing);
  });
}
