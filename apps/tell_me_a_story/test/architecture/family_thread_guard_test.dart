import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _river = RegExp(r'\briver', caseSensitive: false);
final _logCall = RegExp(r'\b(print|debugPrint|log)\s*\(');

void main() {
  test('river does not appear in family thread paths', () {
    final hits = <String>[];
    for (final file in _familyThreadFiles()) {
      final path = _libPath(file.path);
      final source = file.readAsStringSync();
      if (_river.hasMatch(path)) hits.add(path);
      if (_river.hasMatch(source)) hits.add('$path: content');
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
  test('shared_preferences is imported only by the open state store', () {
    const allowed = 'lib/data/family_thread_open_state_store.dart';
    final importers = [
      for (final entity in Directory('lib').listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            _importsSharedPreferences(entity))
          _libPath(entity.path),
    ];
    expect(importers, [allowed]);
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
  test('no logging in family_thread paths', () {
    final hits = <String>[];
    for (final file in _familyThreadFiles()) {
      final path = _libPath(file.path);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_logCall.hasMatch(line)) {
          hits.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
  test('no signed or public URL calls in family_thread', () {
    final banned = RegExp(r'\b(createSignedUrl|getPublicUrl)\s*\(');
    final hits = <String>[];
    for (final file in _featureFiles()) {
      final path = _libPath(file.path);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('$path:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
  test('family_thread imports no supabase_flutter or shared_preferences', () {
    final importLine = RegExp(
      r'''^\s*(import|export)\s+['"]package:(supabase_flutter|shared_preferences)/''',
    );
    final hits = <String>[];
    for (final file in _featureFiles()) {
      final path = _libPath(file.path);
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (importLine.hasMatch(lines[i])) hits.add('$path:${i + 1}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
  test('beat model does not import thread_row_metrics or flutter painting', () {
    final banned = RegExp(
      'thread_row_metrics|package:flutter/(painting|widgets|material)\\.dart',
    );
    const files = [
      'lib/features/family_thread/thread_beat_model.dart',
      'lib/features/family_thread/thread_beat.dart',
      'lib/features/family_thread/decade_beat.dart',
      'lib/features/family_thread/year_beat.dart',
      'lib/features/family_thread/story_beat.dart',
    ];
    final hits = [
      for (final path in files)
        if (banned.hasMatch(File(path).readAsStringSync())) path,
    ];
    expect(hits, isEmpty);
  });
  test('driver and showDialog do not trip the guard', () {
    expect(_river.hasMatch('driver'), isFalse);
    expect(_river.hasMatch('river'), isTrue);
    expect(_logCall.hasMatch('showDialog('), isFalse);
    expect(_logCall.hasMatch('log('), isTrue);
  });
}

List<File> _familyThreadDataFiles() {
  return Directory('lib/data').listSync().whereType<File>().where((file) {
    final name = file.path.split('/').last;
    return name.startsWith('family_thread_') && name.endsWith('.dart');
  }).toList();
}

List<File> _familyThreadFiles() {
  return [..._familyThreadDataFiles(), ..._featureFiles()];
}

List<File> _featureFiles() {
  final features = Directory('lib/features/family_thread');
  if (!features.existsSync()) return const [];
  return features
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
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
  var depth = 0;
  for (var i = match.end - 1; i < source.length; i++) {
    if (source[i] == '{') depth += 1;
    if (source[i] == '}') depth -= 1;
    if (depth == 0) return source.substring(match.end - 1, i + 1);
  }
  return null;
}

String _libPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.indexOf('lib/'));
}
