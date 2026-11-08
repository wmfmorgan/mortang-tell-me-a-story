import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Import rules for lib/. Layers: app (main.dart, app/), core, data, ui and
// features/<name>. See AGENTS.md "Layout". Run from apps/tell_me_a_story.

/// Features may import only features of a lower rank.
const featureRank = <String, int>{
  'auth': 0,
  'comments': 0,
  'invites': 0,
  'people': 0,
  'perspectives': 0,
  'places': 0,
  'family': 1,
  'all_stories': 2,
  'drafts': 2,
  'search': 2,
  'settings': 2,
  'stories': 2,
  'timeline': 2,
};

/// Packages that only app (main.dart, app/), core/server/ and data/ may import.
const serverPackages = <String>[
  'package:tell_me_a_story_client/',
  'package:serverpod',
];

/// Flutter UI libraries that data/ may not import.
const uiLibraries = <String>[
  'package:flutter/material.dart',
  'package:flutter/widgets.dart',
  'package:flutter/cupertino.dart',
];

const _appPackage = 'package:tell_me_a_story/';

final _directive = RegExp(
  r'''^(?:import|export)\s+['"]([^'"]+)['"](?:\s+if\s*\([^)]*\)\s*['"]([^'"]+)['"])?''',
  multiLine: true,
);

String layerOf(String path) {
  if (path == 'main.dart' || path.startsWith('app/')) return 'app';
  final parts = path.split('/');
  switch (parts.first) {
    case 'core' || 'data' || 'ui':
      return parts.first;
    case 'features' when parts.length > 2:
      return 'features/${parts[1]}';
  }
  return 'unknown';
}

bool allowed(String from, String to) {
  if (from == to || from == 'app') return true;
  final inShared = to == 'core' || to == 'data' || to == 'ui';
  switch (from) {
    case 'core':
      return to == 'core';
    case 'data':
      return to == 'core' || to == 'data';
    case 'ui':
      return inShared;
  }
  if (inShared) return true;
  if (!to.startsWith('features/')) return false;
  final fromRank = featureRank[from.substring('features/'.length)];
  final toRank = featureRank[to.substring('features/'.length)];
  return fromRank != null && toRank != null && toRank < fromRank;
}

/// Every import/export target of [source], as written.
Iterable<String> targetsOf(String source) sync* {
  for (final match in _directive.allMatches(source)) {
    yield match.group(1)!;
    final conditional = match.group(2);
    if (conditional != null) yield conditional;
  }
}

/// [target] as a path relative to lib/, or null for another package or dart:.
String? libPath(String file, String target) {
  if (target.startsWith(_appPackage)) {
    return target.substring(_appPackage.length);
  }
  if (target.contains(':')) return null;
  return Uri.parse(file).resolve(target).path;
}

void main() {
  test('lib/ imports follow the layer rules', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );

    final found = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final file = entity.path.replaceAll('\\', '/').substring('lib/'.length);
      final from = layerOf(file);
      if (from == 'unknown') {
        found.add('$file is outside app/, core/, data/, ui/ and features/');
        continue;
      }
      if (from.startsWith('features/') &&
          !featureRank.containsKey(from.substring('features/'.length))) {
        found.add('$file: add its feature to featureRank');
        continue;
      }
      for (final target in targetsOf(entity.readAsStringSync())) {
        if (serverPackages.any(target.startsWith) &&
            from != 'app' &&
            from != 'data' &&
            !file.startsWith('core/server/')) {
          found.add('$file -> $target');
          continue;
        }
        if (from == 'data' && uiLibraries.contains(target)) {
          found.add('$file -> $target');
          continue;
        }
        final path = libPath(file, target);
        if (path == null) continue;
        if (!allowed(from, layerOf(path))) found.add('$file -> $path');
      }
    }

    found.sort();
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
