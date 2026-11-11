import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Import rules for lib/ (ctx flutter preset layout; see AGENTS.md and
// .context/engineering-guide.md "Boundaries"). Run from apps/tell_me_a_story.
//
// Areas: app (main.dart, app.dart), core/<area> and features/<f>/<layer>
// where <layer> is data, domain or presentation.
// - core never imports features.
// - data never imports Flutter UI libraries, widgets or presentation.
// - A feature never imports another feature's data/.
// - Features import other features only of a lower rank (no cycles).
// - Only app, core/server, core/data, core/session and features/*/data
//   import the generated client or serverpod.

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

const featureLayers = {'data', 'domain', 'presentation'};

/// Packages only server-facing areas may import.
const serverPackages = <String>[
  'package:tell_me_a_story_client/',
  'package:serverpod',
];

/// Flutter UI libraries that data layers may not import.
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

/// A file's area: `app`, `core/<area>`, `features/<f>/<layer>`, or `unknown`.
String areaOf(String path) {
  if (path == 'main.dart' || path == 'app.dart') return 'app';
  final parts = path.split('/');
  if (parts.first == 'core' && parts.length > 1) {
    return parts.length == 2
        ? 'core/${parts[1].replaceAll('.dart', '')}'
        : 'core/${parts[1]}';
  }
  if (parts.first == 'features' &&
      parts.length > 3 &&
      featureLayers.contains(parts[2])) {
    return 'features/${parts[1]}/${parts[2]}';
  }
  return 'unknown';
}

bool isData(String area) =>
    area == 'core/data' ||
    (area.startsWith('features/') && area.endsWith('/data'));

bool talksToServer(String area) =>
    area == 'app' ||
    area == 'core/server' ||
    area == 'core/data' ||
    area == 'core/session' ||
    isData(area);

String? featureOf(String area) =>
    area.startsWith('features/') ? area.split('/')[1] : null;

/// Null when allowed, else the broken rule.
String? violation(String from, String to) {
  // The router is the composition root for routes: it imports screens.
  if (from == 'app' || from == 'core/router') return null;
  if (from.startsWith('core/') && to.startsWith('features/')) {
    return 'core never imports features';
  }
  if (isData(from) && to.endsWith('/presentation')) {
    return 'data never imports presentation';
  }
  final fromFeature = featureOf(from);
  final toFeature = featureOf(to);
  if (fromFeature == null || toFeature == null || fromFeature == toFeature) {
    return null;
  }
  if (isData(to)) return "a feature never imports another feature's data";
  final fromRank = featureRank[fromFeature];
  final toRank = featureRank[toFeature];
  if (fromRank == null || toRank == null || toRank >= fromRank) {
    return 'features import only lower-rank features';
  }
  return null;
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
      if (file.endsWith('.g.dart') || file.endsWith('.freezed.dart')) continue;
      final from = areaOf(file);
      if (from == 'unknown') {
        found.add(
          '$file is outside main.dart, app.dart, core/ and '
          'features/<f>/{data,domain,presentation}/',
        );
        continue;
      }
      final feature = featureOf(from);
      if (feature != null && !featureRank.containsKey(feature)) {
        found.add('$file: add its feature to featureRank');
        continue;
      }
      for (final target in targetsOf(entity.readAsStringSync())) {
        if (serverPackages.any(target.startsWith) && !talksToServer(from)) {
          found.add('$file -> $target: only server-facing areas import it');
          continue;
        }
        if (isData(from) && uiLibraries.contains(target)) {
          found.add('$file -> $target: data never imports Flutter UI');
          continue;
        }
        final path = libPath(file, target);
        if (path == null) continue;
        final rule = violation(from, areaOf(path));
        if (rule != null) found.add('$file -> $path: $rule');
      }
    }

    found.sort();
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
