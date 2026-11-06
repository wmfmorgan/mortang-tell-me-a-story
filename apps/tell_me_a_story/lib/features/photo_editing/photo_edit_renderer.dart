import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import '../../core/theme/album_theme.dart';
import 'photo_edit_model.dart';

/// Client bake. The server never renders the edit.
class PhotoEditRenderer {
  const PhotoEditRenderer();

  Future<Uint8List> bakeJpeg({
    required Uint8List source,
    required PhotoEditDocument document,
    int quality = 90,
  }) async {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw ArgumentError.value(source, 'source', 'not a decodable image');
    }
    var oriented = decoded;
    final turns = document.quarterTurns % 4;
    if (turns != 0) {
      oriented = img.copyRotate(decoded, angle: 90.0 * turns);
    }
    final crop = document.crop.clamp();
    final left = (crop.left * oriented.width).round();
    final top = (crop.top * oriented.height).round();
    final width = (crop.width * oriented.width).round().clamp(
      1,
      oriented.width - left,
    );
    final height = (crop.height * oriented.height).round().clamp(
      1,
      oriented.height - top,
    );
    var cropped = img.copyCrop(
      oriented,
      x: left,
      y: top,
      width: width,
      height: height,
    );
    cropped = _adjust(cropped, document.brightness, document.contrast);
    final jpeg = Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
    if (document.layers.isEmpty) return jpeg;
    return _paintLayers(jpeg, document);
  }

  img.Image _adjust(img.Image source, int brightness, int contrast) {
    if (brightness == 0 && contrast == 0) return source;
    final out = source.clone();
    final shift = brightness / 100 * 255;
    final factor = (100 + contrast) / 100;
    for (final pixel in out) {
      pixel
        ..r = _channel(pixel.r.toDouble(), shift, factor)
        ..g = _channel(pixel.g.toDouble(), shift, factor)
        ..b = _channel(pixel.b.toDouble(), shift, factor);
    }
    return out;
  }

  num _channel(double value, double shift, double factor) {
    final next = (value - 128) * factor + 128 + shift;
    return next.clamp(0, 255).round();
  }

  Future<Uint8List> _paintLayers(
    Uint8List jpeg,
    PhotoEditDocument document,
  ) async {
    final codec = await ui.instantiateImageCodec(jpeg);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    for (final layer in document.layers) {
      _paintLayer(
        canvas,
        Size(image.width.toDouble(), image.height.toDouble()),
        layer,
      );
    }
    final width = image.width;
    final height = image.height;
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width, height);
    final bytes = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    rendered.dispose();
    if (bytes == null) {
      throw StateError('bake produced no pixels');
    }
    final raster = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: bytes.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return Uint8List.fromList(img.encodeJpg(raster, quality: 90));
  }

  void _paintLayer(Canvas canvas, Size size, PhotoEditLayer layer) {
    final style = GoogleFonts.literata(
      fontSize: layer.fontSize,
      color: _swatch(layer.color),
      height: 1.2,
    );
    final painter = TextPainter(
      text: TextSpan(text: layer.text.isEmpty ? ' ' : layer.text, style: style),
      textDirection: TextDirection.ltr,
      textWidthBasis: TextWidthBasis.longestLine,
    );
    final maxWidth = size.width * 0.8;
    painter.layout(maxWidth: maxWidth);
    final origin = Offset(
      layer.nx * size.width - painter.width / 2,
      layer.ny * size.height - painter.height / 2,
    );
    final backing = _swatch(layer.color) == albumInk
        ? albumParchment
        : albumInk;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        origin & Size(painter.width, painter.height),
        const Radius.circular(2),
      ),
      Paint()..color = backing,
    );
    painter.paint(canvas, origin);
  }

  Color _swatch(TextSwatch swatch) {
    return switch (swatch) {
      TextSwatch.parchment => albumParchment,
      TextSwatch.ink => albumInk,
      TextSwatch.terracotta => albumTerracotta,
      TextSwatch.sage => albumSage,
      TextSwatch.branchMoss => branchMoss,
    };
  }
}
