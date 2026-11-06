import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/features/photo_editing/photo_edit_model.dart';
import 'package:tell_me_a_story/features/photo_editing/photo_edit_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List jpeg(int width, int height) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(20, 40, 60));
    return Uint8List.fromList(img.encodeJpg(image));
  }

  test('a quarter turn swaps the jpeg dimensions', () async {
    final source = jpeg(8, 4);
    final document = PhotoEditDocument(
      imageWidth: 8,
      imageHeight: 4,
      quarterTurns: 1,
    );
    final baked = await const PhotoEditRenderer().bakeJpeg(
      source: source,
      document: document,
    );
    expect(baked[0], 0xff);
    expect(baked[1], 0xd8);
    final decoded = img.decodeJpg(baked)!;
    expect(decoded.width, 4);
    expect(decoded.height, 8);
  });

  test(
    'a square crop changes the output size and leaves the source bytes',
    () async {
      final source = jpeg(8, 4);
      final copy = Uint8List.fromList(source);
      final document = PhotoEditDocument(
        imageWidth: 8,
        imageHeight: 4,
        aspect: CropAspect.square,
        crop: const CropQuad(left: 0, top: 0, width: 0.5, height: 1),
      );
      final baked = await const PhotoEditRenderer().bakeJpeg(
        source: source,
        document: document,
      );
      final decoded = img.decodeJpg(baked)!;
      expect(decoded.width, 4);
      expect(decoded.height, 4);
      expect(source, copy);
    },
  );
}
