import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Golden tests only (this file applies to test/goldens/ and below).
///
/// google_fonts names each variant `<Family>_<variant>` (`Newsreader_500`,
/// `Literata_italic`) and tests can't fetch fonts, so text would render in
/// the test font's boxes. This registers the Flutter SDK's Roboto under every
/// variant name the album theme can ask for, plus Material Icons. Goldens
/// then show real glyphs (Roboto shapes, not the brand faces). macOS only:
/// `just test-goldens`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await _loadFonts();
  await testMain();
}

const _googleFamilies = ['Newsreader', 'Literata', 'SourceSans3'];

Directory _materialFontsDir() {
  const rel = 'bin/cache/artifacts/material_fonts';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && Directory('$root/$rel').existsSync()) {
    return Directory('$root/$rel');
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    final candidate = Directory('${dir.path}/$rel');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'Flutter SDK material_fonts not found; run flutter precache',
  );
}

/// google_fonts' variant suffix: `regular`, `italic`, `500`, `500italic`.
String _variant(int weight, {required bool italic}) {
  if (weight == 400) return italic ? 'italic' : 'regular';
  return italic ? '${weight}italic' : '$weight';
}

String _robotoFile(int weight, {required bool italic}) {
  final bold = weight >= 600;
  if (italic) return bold ? 'Roboto-BoldItalic.ttf' : 'Roboto-Italic.ttf';
  if (bold) return 'Roboto-Bold.ttf';
  return weight == 500 ? 'Roboto-Medium.ttf' : 'Roboto-Regular.ttf';
}

Future<void> _loadFonts() async {
  final dir = _materialFontsDir();
  final cache = <String, Future<ByteData>>{};
  Future<ByteData> bytes(String name) => cache.putIfAbsent(
    name,
    () async =>
        ByteData.sublistView(await File('${dir.path}/$name').readAsBytes()),
  );

  final loaders = <FontLoader>[
    for (final family in _googleFamilies)
      for (var weight = 100; weight <= 900; weight += 100)
        for (final italic in [false, true])
          FontLoader('${family}_${_variant(weight, italic: italic)}')
            ..addFont(bytes(_robotoFile(weight, italic: italic))),
    FontLoader('MaterialIcons')..addFont(bytes('MaterialIcons-Regular.otf')),
  ];
  await Future.wait([for (final loader in loaders) loader.load()]);
}
