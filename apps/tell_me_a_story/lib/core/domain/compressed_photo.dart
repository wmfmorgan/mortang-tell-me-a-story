import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image/image.dart' as img;

part 'compressed_photo.freezed.dart';

@freezed
abstract class CompressedPhoto with _$CompressedPhoto {
  const factory CompressedPhoto({
    required Uint8List bytes,
    required String mimeType, // image/jpeg
    required String extension, // jpg
  }) = _CompressedPhoto;
}

CompressedPhoto compressStoryPhoto(
  Uint8List bytes, {
  int maxEdge = 1920,
  int quality = 80,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError.value(bytes, 'bytes', 'not a decodable image');
  }
  var out = decoded;
  if (decoded.width > maxEdge || decoded.height > maxEdge) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxEdge)
        : img.copyResize(decoded, height: maxEdge);
  }
  return CompressedPhoto(
    bytes: Uint8List.fromList(img.encodeJpg(out, quality: quality)),
    mimeType: 'image/jpeg',
    extension: 'jpg',
  );
}
