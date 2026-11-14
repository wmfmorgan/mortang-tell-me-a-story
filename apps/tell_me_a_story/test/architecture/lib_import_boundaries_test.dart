import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// AGENTS.md § Architecture and layers, item 1 (verbatim):
//
// `lib/main.dart` calls `initSupabase()` in `lib/core/supabase/supabase_init.dart`.
// That function builds the anon client from `Env` in `lib/core/config/env.dart`. It
// does not read the service role key. `lib/app.dart` holds the router widget.
// `lib/core/` holds config, navigation, the router, Supabase init, and theme.
// `lib/data/` holds `*_api.dart` gateways and session helpers.
// `lib/features/<feature>/` holds screens. There is no `lib/state/`. Session state
// lives in `lib/data/`.
//
// Import boundaries read only from that item:
// - Nothing under `lib/` may import `lib/state/`.
// - `lib/data/` holds gateways and session helpers, not screens: it must not import
//   `lib/features/`.
// - `lib/features/<feature>/` holds screens: it may import `lib/data/` and `lib/core/`.
// - `lib/core/` holds config, navigation, the router, Supabase init, and theme: paths
//   under `lib/core/router/` may import `lib/features/` and `lib/data/` to wire routes;
//   other paths under `lib/core/` must not import `lib/features/` or `lib/data/`.
// - `lib/main.dart` and `lib/app.dart` may import any `lib/` layer.

const temporaryImportBoundaryViolations = <String>{
  'core/navigation/leave_story_dialog.dart:5 -> features/family/family_blur_dialog.dart',
  'core/theme/album_chrome.dart:4 -> features/family/family_blur_dialog.dart',
  'core/theme/album_header.dart:8 -> data/families_api.dart',
  'core/theme/album_header.dart:9 -> data/family_selection.dart',
  'core/theme/album_header.dart:10 -> data/manage_families_api.dart',
  'core/theme/album_header.dart:11 -> data/profile_session.dart',
  'core/theme/album_header.dart:12 -> features/family/family_role.dart',
  'core/theme/album_header.dart:13 -> features/family/family_tree_order.dart',
};

void main() {
  test(
    'lib import boundaries match AGENTS.md § Architecture and layers item 1',
    () {
      final libDir = Directory('lib');
      expect(
        libDir.existsSync(),
        isTrue,
        reason: 'run this test from apps/tell_me_a_story',
      );

      final offenders = <String>[];
      final allowHits = {
        for (final entry in temporaryImportBoundaryViolations) entry: false,
      };

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final relative = _libRelativePath(entity.path);
        final importerLayer = _layerOf(relative);
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final target = _resolveLibImport(relative, line);
          if (target == null) {
            continue;
          }
          if (!_isForbiddenImport(importerLayer, relative, target)) {
            continue;
          }
          final entry = '$relative:${i + 1} -> $target';
          if (temporaryImportBoundaryViolations.contains(entry)) {
            allowHits[entry] = true;
            continue;
          }
          offenders.add(entry);
        }
      }

      final stale = allowHits.entries
          .where((hit) => !hit.value)
          .map((hit) => 'allowlist has no hit ${hit.key}')
          .toList();
      offenders.sort();
      stale.sort();

      final report = <String>[...stale, ...offenders];
      expect(report, <String>[], reason: report.join('\n'));
    },
  );
}

String _libRelativePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  const prefix = 'lib/';
  if (normalized.startsWith(prefix)) {
    return normalized.substring(prefix.length);
  }
  const marker = '/lib/';
  final index = normalized.lastIndexOf(marker);
  if (index == -1) {
    fail('dart path is not under lib/: $path');
  }
  return normalized.substring(index + marker.length);
}

String _layerOf(String relativePath) {
  if (relativePath == 'main.dart' || relativePath == 'app.dart') {
    return 'root';
  }
  final top = relativePath.split('/').first;
  switch (top) {
    case 'core':
      return 'core';
    case 'data':
      return 'data';
    case 'features':
      return 'features';
    case 'state':
      return 'state';
    default:
      return 'unknown';
  }
}

String? _resolveLibImport(String importer, String line) {
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
    return null;
  }
  final quoteStart = trimmed.indexOf("'");
  if (quoteStart == -1) {
    return null;
  }
  final quoteEnd = trimmed.indexOf("'", quoteStart + 1);
  if (quoteEnd == -1) {
    return null;
  }
  final uri = trimmed.substring(quoteStart + 1, quoteEnd);
  if (uri.startsWith('package:tell_me_a_story/')) {
    return uri.substring('package:tell_me_a_story/'.length);
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return null;
  }
  return _normalizeRelativeImport(importer, uri);
}

String? _normalizeRelativeImport(String importer, String uri) {
  final dirParts = importer.split('/')..removeLast();
  final combined = <String>[...dirParts, ...uri.split('/')];
  final out = <String>[];
  for (final segment in combined) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (out.isEmpty) {
        return null;
      }
      out.removeLast();
      continue;
    }
    out.add(segment);
  }
  return out.join('/');
}

bool _isForbiddenImport(String importerLayer, String importer, String target) {
  if (target == 'state' || target.startsWith('state/')) {
    return true;
  }
  if (importerLayer == 'root') {
    return false;
  }
  if (importerLayer == 'data') {
    return target.startsWith('features/');
  }
  if (importerLayer == 'core' && !importer.startsWith('core/router/')) {
    return target.startsWith('features/') || target.startsWith('data/');
  }
  return false;
}
