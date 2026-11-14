import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Enforces AGENTS.md § Architecture and layers, item 1 (import rules block).

const temporaryImportBoundaryViolations = <String>{
  'core/navigation/leave_story_dialog.dart -> features/family/family_blur_dialog.dart',
  'core/theme/album_chrome.dart -> features/family/family_blur_dialog.dart',
  'core/theme/album_header.dart -> data/families_api.dart',
  'core/theme/album_header.dart -> data/family_selection.dart',
  'core/theme/album_header.dart -> data/manage_families_api.dart',
  'core/theme/album_header.dart -> data/profile_session.dart',
  'core/theme/album_header.dart -> features/family/family_role.dart',
  'core/theme/album_header.dart -> features/family/family_tree_order.dart',
};

const _knownCoreAreas = <String>{
  'config',
  'navigation',
  'router',
  'supabase',
  'theme',
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

      final structural = _structuralViolations(libDir);
      final offenders = <String>[];
      final allowHits = {
        for (final entry in temporaryImportBoundaryViolations) entry: false,
      };

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final importer = _libRelativePath(entity.path);
        if (_importerZone(importer) == _ImporterZone.unknown) {
          structural.add('unknown lib path $importer');
          continue;
        }
        for (final target in _libUrisFromFile(entity, importer)) {
          if (!_violatesImportRule(importer, target)) {
            continue;
          }
          final entry = '$importer -> $target';
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
      structural.sort();
      offenders.sort();
      stale.sort();

      final report = <String>[...structural, ...stale, ...offenders];
      expect(report, <String>[], reason: report.join('\n'));
    },
  );
}

List<String> _structuralViolations(Directory libDir) {
  final report = <String>[];
  if (Directory('lib/state').existsSync()) {
    report.add('lib/state/ must not exist');
  }
  for (final entity in libDir.listSync()) {
    final name = entity.path.replaceAll('\\', '/').split('/').last;
    if (entity is File && name.endsWith('.dart')) {
      if (name != 'main.dart' && name != 'app.dart') {
        report.add('unknown lib path $name');
      }
      continue;
    }
    if (entity is! Directory) {
      continue;
    }
    if (name == 'core' || name == 'data' || name == 'features') {
      if (name == 'core') {
        report.addAll(_unknownCoreChildren(entity));
      }
      continue;
    }
    report.add('unknown lib path $name/');
  }
  return report;
}

List<String> _unknownCoreChildren(Directory coreDir) {
  final unknown = <String>[];
  for (final child in coreDir.listSync()) {
    final name = child.path.replaceAll('\\', '/').split('/').last;
    if (child is! Directory) {
      unknown.add('unknown lib path core/$name');
      continue;
    }
    if (!_knownCoreAreas.contains(name)) {
      unknown.add('unknown lib path core/$name/');
    }
  }
  return unknown;
}

enum _ImporterZone { root, coreRouter, coreRest, data, features, unknown }

_ImporterZone _importerZone(String relative) {
  if (relative == 'main.dart' || relative == 'app.dart') {
    return _ImporterZone.root;
  }
  if (relative.startsWith('core/router/')) {
    return _ImporterZone.coreRouter;
  }
  if (relative.startsWith('core/config/') ||
      relative.startsWith('core/supabase/') ||
      relative.startsWith('core/theme/') ||
      relative.startsWith('core/navigation/')) {
    return _ImporterZone.coreRest;
  }
  if (relative.startsWith('data/')) {
    return _ImporterZone.data;
  }
  if (relative.startsWith('features/')) {
    return _ImporterZone.features;
  }
  return _ImporterZone.unknown;
}

bool _violatesImportRule(String importer, String target) {
  if (target == 'state' || target.startsWith('state/')) {
    return true;
  }
  switch (_importerZone(importer)) {
    case _ImporterZone.root:
      return false;
    case _ImporterZone.coreRouter:
      return !target.startsWith('core/') &&
          !target.startsWith('data/') &&
          !target.startsWith('features/');
    case _ImporterZone.coreRest:
      return !target.startsWith('core/');
    case _ImporterZone.data:
      return !target.startsWith('data/') &&
          !target.startsWith('core/config/') &&
          !target.startsWith('core/supabase/');
    case _ImporterZone.features:
      return false;
    case _ImporterZone.unknown:
      return true;
  }
}

Iterable<String> _libUrisFromFile(File file, String importer) sync* {
  for (final line in file.readAsLinesSync()) {
    final target = _resolveLibUri(importer, line);
    if (target != null) {
      yield target;
    }
  }
}

String? _resolveLibUri(String importer, String line) {
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
    return null;
  }
  final uri = _quotedUri(trimmed);
  if (uri == null) {
    return null;
  }
  if (uri.startsWith('package:tell_me_a_story/')) {
    return uri.substring('package:tell_me_a_story/'.length);
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return null;
  }
  return _normalizeRelativeImport(importer, uri);
}

String? _quotedUri(String trimmed) {
  const quotes = ["'", '"'];
  for (final quote in quotes) {
    final start = trimmed.indexOf(quote);
    if (start == -1) {
      continue;
    }
    final end = trimmed.indexOf(quote, start + 1);
    if (end == -1) {
      continue;
    }
    return trimmed.substring(start + 1, end);
  }
  return null;
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
