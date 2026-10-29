import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/features/stories/photo_frame.dart';

void main() {
  test('framed aspect keeps a photo between 3:4 and 16:9', () {
    expect(framedPhotoAspect(16 / 9), closeTo(16 / 9, 0.001));
    expect(framedPhotoAspect(1), 1);
    expect(framedPhotoAspect(3 / 4), closeTo(3 / 4, 0.001));
    expect(framedPhotoAspect(9 / 16), closeTo(3 / 4, 0.001));
    expect(framedPhotoAspect(2.4), closeTo(16 / 9, 0.001));
    expect(framedPhotoAspect(0), closeTo(16 / 9, 0.001));
  });

  test('a portrait card grows toward 280 and a wide card stays short', () {
    final portrait = cardPhotoHeight(
      width: 600,
      imageAspect: 3 / 4,
      focused: true,
    );
    expect(portrait, 280);

    final wide = cardPhotoHeight(
      width: 300,
      imageAspect: 16 / 9,
      focused: true,
    );
    expect(wide, closeTo(300 * 9 / 16, 0.1));
    expect(wide, lessThan(192));

    expect(
      cardPhotoHeight(width: 600, imageAspect: 3 / 4, focused: false),
      160,
    );
    expect(cardPhotoRowHeight(focused: true), 160);
    expect(cardPhotoRowHeight(focused: false), 112);
  });

  testWidgets('a portrait frame is 3:4 and a wide frame is 16:9', (
    tester,
  ) async {
    final portrait = _pngOf(30, 40);
    final wide = _pngOf(32, 18);
    expect(encodedPhotoAspect(portrait), closeTo(30 / 40, 0.001));
    expect(encodedPhotoAspect(wide), closeTo(32 / 18, 0.001));

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 300, child: FramedPhoto(bytes: portrait)),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(FramedPhoto)).aspectRatio,
      closeTo(3 / 4, 0.02),
    );
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(width: 300, child: FramedPhoto(bytes: wide)),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(FramedPhoto)).aspectRatio,
      closeTo(16 / 9, 0.02),
    );
  });
}

Uint8List _pngOf(int width, int height) {
  final bytes = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, //
  ]);
  bytes[16] = (width >> 24) & 0xff;
  bytes[17] = (width >> 16) & 0xff;
  bytes[18] = (width >> 8) & 0xff;
  bytes[19] = width & 0xff;
  bytes[20] = (height >> 24) & 0xff;
  bytes[21] = (height >> 16) & 0xff;
  bytes[22] = (height >> 8) & 0xff;
  bytes[23] = height & 0xff;
  return bytes;
}
