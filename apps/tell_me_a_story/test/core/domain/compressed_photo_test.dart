import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/domain/compressed_photo.dart';

void main() {
  test('compressStoryPhoto emits jpeg under max edge', () {
    final src = _solidPng(2000, 1000); // test helper
    final out = compressStoryPhoto(src);
    expect(out.mimeType, 'image/jpeg');
    expect(out.extension, 'jpg');
    final decoded = img.decodeJpg(out.bytes)!;
    expect(decoded.width <= 1920, isTrue);
    expect(decoded.height <= 1920, isTrue);
  });
}

Uint8List _solidPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 40));
  return Uint8List.fromList(img.encodePng(image));
}
