import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the SDK's Roboto and Material Icons so goldens show real glyphs
/// instead of the Ahem test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _loadFonts();
  await testMain();
}

Directory? _materialFontsDir() {
  const rel = 'bin/cache/artifacts/material_fonts';
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/$rel');
    if (dir.existsSync()) return dir;
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    final candidate = Directory('${dir.path}/$rel');
    if (candidate.existsSync()) return candidate;
    if (dir.parent.path == dir.path) return null;
    dir = dir.parent;
  }
}

Future<void> _loadFonts() async {
  final dir = _materialFontsDir();
  if (dir == null) {
    // ignore: avoid_print
    print('timeline_lab: SDK fonts not found; goldens render with test font');
    return;
  }
  Future<ByteData> bytes(String name) async =>
      ByteData.sublistView(await File('${dir.path}/$name').readAsBytes());

  final roboto = FontLoader('Roboto')
    ..addFont(bytes('Roboto-Regular.ttf'))
    ..addFont(bytes('Roboto-Medium.ttf'))
    ..addFont(bytes('Roboto-Bold.ttf'));
  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await Future.wait([roboto.load(), icons.load()]);
}
