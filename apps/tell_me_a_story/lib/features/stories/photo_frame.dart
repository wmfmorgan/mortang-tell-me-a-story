import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/album_theme.dart';

/// Width / height of the frame that shows [imageAspect] whole.
///
/// A panorama wider than 16:9 letterboxes inside 16:9. A scan taller than
/// 3:4 letterboxes inside 3:4. Anything in between uses the photo's own shape.
double framedPhotoAspect(double imageAspect) {
  if (!imageAspect.isFinite || imageAspect <= 0) return 16 / 9;
  return imageAspect.clamp(3 / 4, 16 / 9);
}

/// Height of a single-photo card well. The photo is contained, never cropped.
double cardPhotoHeight({
  required double width,
  required double imageAspect,
  required bool focused,
}) {
  const minHeight = 112.0;
  final maxHeight = focused ? 280.0 : 160.0;
  if (!width.isFinite || width <= 0) return minHeight;
  final raw = width / framedPhotoAspect(imageAspect);
  return raw.clamp(minHeight, maxHeight);
}

/// Shared row when a card shows two photos side by side.
double cardPhotoRowHeight({required bool focused}) {
  return focused ? 160 : 112;
}

/// Width / height from a PNG or JPEG header. Null when the bytes are not one.
double? encodedPhotoAspect(Uint8List bytes) {
  final png = _pngSize(bytes);
  if (png != null) return png.$1 / png.$2;
  final jpeg = _jpegSize(bytes);
  if (jpeg != null) return jpeg.$1 / jpeg.$2;
  return null;
}

(int, int)? _pngSize(Uint8List bytes) {
  if (bytes.length < 24) return null;
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) return null;
  }
  final width = _u32(bytes, 16);
  final height = _u32(bytes, 20);
  if (width <= 0 || height <= 0) return null;
  return (width, height);
}

(int, int)? _jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
  var i = 2;
  while (i + 8 < bytes.length) {
    if (bytes[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = bytes[i + 1];
    if (marker == 0xD8 || marker == 0xD9 || marker == 0x01) {
      i += 2;
      continue;
    }
    if (marker >= 0xD0 && marker <= 0xD7) {
      i += 2;
      continue;
    }
    if (i + 3 >= bytes.length) return null;
    final length = (bytes[i + 2] << 8) | bytes[i + 3];
    if (length < 2) return null;
    final isStartOfFrame =
        marker == 0xC0 ||
        marker == 0xC1 ||
        marker == 0xC2 ||
        marker == 0xC3 ||
        marker == 0xC5 ||
        marker == 0xC6 ||
        marker == 0xC7 ||
        marker == 0xC9 ||
        marker == 0xCA ||
        marker == 0xCB ||
        marker == 0xCD ||
        marker == 0xCE ||
        marker == 0xCF;
    if (isStartOfFrame && i + 8 < bytes.length) {
      final height = (bytes[i + 5] << 8) | bytes[i + 6];
      final width = (bytes[i + 7] << 8) | bytes[i + 8];
      if (width <= 0 || height <= 0) return null;
      return (width, height);
    }
    i += 2 + length;
  }
  return null;
}

int _u32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

/// Shows a photo whole, letterboxed on parchment, between 3:4 and 16:9.
class FramedPhoto extends StatelessWidget {
  const FramedPhoto({super.key, required this.bytes, this.borderRadius = 12});

  final Uint8List? bytes;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final encoded = bytes == null ? null : encodedPhotoAspect(bytes!);
    return AspectRatio(
      aspectRatio: framedPhotoAspect(encoded ?? (16 / 9)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: ColoredBox(
          color: albumParchment,
          child: bytes == null
              ? const SizedBox.expand()
              : Image.memory(
                  bytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.expand(),
                ),
        ),
      ),
    );
  }
}
