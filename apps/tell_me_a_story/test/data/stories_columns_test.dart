import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stories columns in lib/data match the checked-in list', () {
    final expected = _checkedInStoriesColumns();
    final sources = _dataSources();
    final model = _storyModelColumns(sources['stories_api.dart']!);
    final queried = _queriedStoriesColumns(sources);

    expect(model, expected, reason: 'Story.fromJson');
    expect(
      queried.difference(expected),
      isEmpty,
      reason: 'lib/data stories queries',
    );
  });
}

final _columnName = RegExp(r'^[a-z][a-z0-9_]*$');

Set<String> _checkedInStoriesColumns() {
  final lines = File('../../supabase/tests/stories_columns.txt')
      .readAsLinesSync()
      .map((line) => line.trim())
      .toList();
  expect(lines, isNotEmpty);
  expect(lines.toSet().length, lines.length, reason: 'duplicate column');
  expect(lines.every(_columnName.hasMatch), isTrue);
  return lines.toSet();
}

Map<String, String> _dataSources() {
  final dir = Directory('lib/data');
  return {
    for (final entity in dir.listSync())
      if (entity is File && entity.path.endsWith('.dart'))
        entity.uri.pathSegments.last: entity.readAsStringSync(),
  };
}

Set<String> _storyModelColumns(String source) {
  final start = source.indexOf('factory Story.fromJson');
  final end = source.indexOf('\n  }\n', start);
  final body = source.substring(start, end);
  return RegExp(r"json\['([a-z][a-z0-9_]*)'\](?=\s*(==|!=|as\s))")
      .allMatches(body)
      .map((match) => match.group(1)!)
      .toSet();
}

Set<String> _queriedStoriesColumns(Map<String, String> sources) {
  final columns = <String>{};
  for (final source in sources.values) {
    if (!source.contains(".from('stories')")) continue;
    columns.addAll(_columnsInStoriesFile(source));
  }
  return columns;
}

Set<String> _columnsInStoriesFile(String source) {
  final columns = <String>{};
  for (final statement in source.split(';')) {
    if (!statement.contains(".from('stories')")) continue;
    columns.addAll(_selectColumns(statement, source));
    columns.addAll(_inlineMapKeys(statement));
    columns.addAll(_filterColumns(statement));
  }
  columns.addAll(_assignedMapKeys(source, 'payload'));
  columns.addAll(_indexKeys(source, 'payload'));
  columns.addAll(_indexKeys(source, 'patch'));
  return columns;
}

Set<String> _selectColumns(String statement, String source) {
  final columns = <String>{};
  final inline = _inlineSelect(statement);
  if (inline != null) columns.addAll(_topLevelFields(inline));
  for (final name in _selectIdentifiers(statement)) {
    final value = _constString(source, name);
    if (value != null) columns.addAll(_topLevelFields(value));
  }
  return columns;
}

String? _inlineSelect(String statement) {
  final start = statement.indexOf('.select(');
  if (start < 0) return null;
  final region = _balanced(statement, start + '.select'.length);
  final parts = RegExp(r"'([^']*)'")
      .allMatches(region)
      .map((match) => match.group(1)!);
  if (parts.isEmpty) return null;
  return parts.join();
}

Set<String> _selectIdentifiers(String statement) {
  return RegExp(r'\.select\(\s*([A-Za-z_][A-Za-z0-9_]*)')
      .allMatches(statement)
      .map((match) => match.group(1)!)
      .toSet();
}

String? _constString(String source, String name) {
  final match = RegExp("static const $name =\\s*((?:'[^']*'\\s*)+);")
      .firstMatch(source);
  if (match == null) return null;
  return RegExp(r"'([^']*)'")
      .allMatches(match.group(1)!)
      .map((match) => match.group(1)!)
      .join();
}

Set<String> _topLevelFields(String select) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final char in select.split('')) {
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
    } else if (char == ',' && depth == 0) {
      fields.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  fields.add(buffer.toString());
  return {
    for (final field in fields)
      if (_columnName.hasMatch(field.trim())) field.trim(),
  };
}

String _balanced(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(openParen, i + 1);
    }
  }
  return source.substring(openParen);
}

Set<String> _inlineMapKeys(String statement) {
  final columns = <String>{};
  for (final kind in ['.update(', '.insert(']) {
    final start = statement.indexOf(kind);
    if (start < 0) continue;
    final brace = statement.indexOf('{', start);
    if (brace < 0 || brace > start + kind.length + 2) continue;
    final end = statement.indexOf('}', brace);
    columns.addAll(_literalKeys(statement.substring(brace, end)));
  }
  return columns;
}

Set<String> _assignedMapKeys(String source, String variable) {
  final marker = 'final $variable = <String, dynamic>{';
  final start = source.indexOf(marker);
  if (start < 0) return {};
  final end = source.indexOf('};', start);
  return _literalKeys(source.substring(start, end));
}

Set<String> _literalKeys(String body) {
  return RegExp(r"'([a-z][a-z0-9_]*)'\s*:")
      .allMatches(body)
      .map((match) => match.group(1)!)
      .toSet();
}

Set<String> _indexKeys(String source, String variable) {
  return RegExp("$variable\\['([a-z][a-z0-9_]*)'\\]")
      .allMatches(source)
      .map((match) => match.group(1)!)
      .toSet();
}

Set<String> _filterColumns(String statement) {
  return RegExp(r"\.(?:eq|order|gte|inFilter)\(\s*'([a-z][a-z0-9_]*)'")
      .allMatches(statement)
      .map((match) => match.group(1)!)
      .toSet();
}
