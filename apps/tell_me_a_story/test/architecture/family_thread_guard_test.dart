import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('river does not appear in family thread paths', () {
    final hits = <String>[];
    for (final file in _familyThreadFiles()) {
      final path = _libPath(file.path);
      final source = file.readAsStringSync();
      if (path.toLowerCase().contains('river')) hits.add(path);
      if (source.toLowerCase().contains('river')) hits.add('$path: content');
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('shared_preferences is imported only by the open state store', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);
    const allowed = 'lib/data/family_thread_open_state_store.dart';
    final offenders = <String>[];
    var allowedHit = false;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = _libPath(entity.path);
      if (!_importsSharedPreferences(entity)) continue;
      if (path == allowed) {
        allowedHit = true;
        continue;
      }
      offenders.add(path);
    }
    expect(
      allowedHit,
      isTrue,
      reason: '$allowed does not import shared_preferences',
    );
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no .clear( call on preferences in lib/data/family_thread_open_state_store.dart', () {
    final source = File('lib/data/family_thread_open_state_store.dart')
        .readAsStringSync();
    expect(source.contains('.clear('), isFalse);
  });

  test('getKeys appears only inside clearAll', () {
    final store = File('lib/data/family_thread_open_state_store.dart')
        .readAsStringSync();
    final body = _clearAllBody(store);
    expect(body, isNotNull, reason: 'clearAll is missing');
    expect(body, contains('getKeys('));
    final outside = <String>[];
    for (final file in _familyThreadDataFiles()) {
      final path = _libPath(file.path);
      var source = file.readAsStringSync();
      if (path == 'lib/data/family_thread_open_state_store.dart') {
        source = source.replaceFirst(body!, '');
      }
      if (source.contains('getKeys(')) outside.add(path);
    }
    expect(outside, isEmpty, reason: outside.join('\n'));
  });

  test('no logging in family_thread data paths', () {
    final hits = <String>[];
    for (final file in _familyThreadDataFiles()) {
      final path = _libPath(file.path);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('print(') ||
            line.contains('debugPrint(') ||
            line.contains('log(')) {
          hits.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}

List<File> _familyThreadDataFiles() {
  return Directory('lib/data').listSync().whereType<File>().where((file) {
    final name = file.path.split('/').last;
    return name.startsWith('family_thread_') && name.endsWith('.dart');
  }).toList();
}

List<File> _familyThreadFiles() {
  final files = _familyThreadDataFiles();
  final features = Directory('lib/features/family_thread');
  if (!features.existsSync()) return files;
  files.addAll(
    features
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  );
  return files;
}

bool _importsSharedPreferences(File file) {
  final importLine = RegExp(
    r'''^\s*(import|export)\s+['"]package:shared_preferences/''',
  );
  return file.readAsLinesSync().any(importLine.hasMatch);
}

String? _clearAllBody(String source) {
  final match = RegExp(r'clearAll\([^)]*\)\s+async\s*\{').firstMatch(source);
  if (match == null) return null;
  final start = match.end - 1;
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    if (source[i] == '{') depth += 1;
    if (source[i] == '}') {
      depth -= 1;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return null;
}

String _libPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final marker = normalized.indexOf('lib/');
  return normalized.substring(marker);
}
