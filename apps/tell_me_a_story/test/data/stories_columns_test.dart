import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _embeds = {
  'story_people',
  'photos',
  'places',
  'profiles',
  'comments',
  'perspectives',
};

void main() {
  test('stories columns in lib/data match the checked-in list', () {
    final columns = _checkedInStoriesColumns();
    final sources = _dataSources();
    final storyApi = sources['stories_api.dart'];
    expect(
      storyApi,
      isNotNull,
      reason: 'lib/data/stories_api.dart moved or was renamed',
    );
    if (storyApi == null) return;
    final model = _quotedTokens(_fromJsonBody(storyApi)).difference(_embeds);
    final queried = _queriedTokens(sources).difference(_embeds);
    expect(model, isNotEmpty, reason: 'Story.fromJson names no column');
    expect(queried, isNotEmpty, reason: 'no stories query names a column');
    expect(
      model.difference(columns),
      isEmpty,
      reason: 'Story.fromJson names a column outside stories_columns.txt',
    );
    expect(
      queried.difference(columns),
      isEmpty,
      reason: 'a stories query names a column outside stories_columns.txt',
    );
  });
}

Set<String> _checkedInStoriesColumns() {
  final file = File('../../supabase/tests/stories_columns.txt');
  expect(
    file.existsSync(),
    isTrue,
    reason: 'stories_columns.txt moved from supabase/tests',
  );
  if (!file.existsSync()) return {};
  final lines = [
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty) line.trim(),
  ];
  expect(lines.toSet().length, lines.length, reason: 'duplicate column');
  return lines.toSet();
}

Map<String, String> _dataSources() {
  final dir = Directory('lib/data');
  expect(dir.existsSync(), isTrue, reason: 'lib/data moved');
  if (!dir.existsSync()) return {};
  return {
    for (final entity in dir.listSync())
      if (entity is File && entity.path.endsWith('.dart'))
        entity.uri.pathSegments.last: entity.readAsStringSync(),
  };
}

String _fromJsonBody(String source) {
  final start = source.indexOf('factory Story.fromJson');
  expect(start, greaterThanOrEqualTo(0), reason: 'Story.fromJson moved');
  if (start < 0) return '';
  final end = source.indexOf('\n  }\n', start);
  expect(end, greaterThan(start), reason: 'Story.fromJson brace moved');
  if (end < 0) return '';
  return source.substring(start, end);
}

Set<String> _queriedTokens(Map<String, String> sources) {
  final tokens = <String>{};
  for (final source in sources.values) {
    if (!source.contains(".from('stories')")) continue;
    for (final statement in source.split(';')) {
      if (!statement.contains(".from('stories')")) continue;
      tokens.addAll(_quotedTokens(statement));
      for (final select in _selectTexts(statement, source)) {
        tokens.addAll(_topLevelFields(select));
      }
    }
  }
  return tokens;
}

Set<String> _quotedTokens(String region) {
  final tokens = <String>{};
  for (final match in RegExp(
    r"\.([A-Za-z_][A-Za-z0-9_]*)\(\s*'([a-z][a-z0-9_]*)'",
  ).allMatches(region)) {
    if (match.group(1) != 'from') _add(tokens, match.group(2));
  }
  for (final match in RegExp(
    r"'([a-z][a-z0-9_]*)'\s*:|json\['([a-z][a-z0-9_]*)'\]",
  ).allMatches(region)) {
    _add(tokens, match.group(1) ?? match.group(2));
  }
  return tokens;
}

void _add(Set<String> tokens, String? value) {
  if (value != null) tokens.add(value);
}

Set<String> _selectTexts(String statement, String source) {
  final texts = <String>{};
  for (final match in RegExp(r'\.select\(\s*').allMatches(statement)) {
    final rest = statement.substring(match.end);
    if (rest.startsWith("'")) {
      texts.add(_adjacentStrings(rest));
      continue;
    }
    final name = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*')
        .matchAsPrefix(rest)
        ?.group(0);
    expect(
      name,
      isNotNull,
      reason: 'a stories .select( is not a string or a name',
    );
    if (name == null) continue;
    final direct = _constText(source, name);
    if (direct != null) {
      texts.add(direct);
      continue;
    }
    for (final constName in _passedConsts(source, name)) {
      final text = _constText(source, constName);
      expect(
        text,
        isNotNull,
        reason: '.select($name) passed $constName, which moved',
      );
      if (text != null) texts.add(text);
    }
  }
  return texts;
}

String? _constText(String source, String name) {
  final body = RegExp("static const $name =\\s*((?:'[^']*'\\s*)+);")
      .firstMatch(source)
      ?.group(1);
  if (body == null) return null;
  return RegExp(r"'([^']*)'")
      .allMatches(body)
      .map((m) => m.group(1) ?? '')
      .join();
}

Set<String> _passedConsts(String source, String param) {
  final names = <String>{};
  final headers = RegExp(
    '([A-Za-z0-9_]+)\\([^,()]*,\\s*(?:[A-Za-z0-9_<>?]+\\s+)?'
    '$param\\b[^)]*\\)\\s*(?:async\\s*)?\\{',
  );
  for (final header in headers.allMatches(source)) {
    final fn = header.group(1);
    if (fn == null) continue;
    final calls = RegExp(
      '\\b$fn\\(\\s*[^,()]+,\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*\\)',
    );
    for (final call in calls.allMatches(source)) {
      _add(names, call.group(1));
    }
  }
  expect(names, isNotEmpty, reason: '.select($param) column list moved');
  return names;
}

String _adjacentStrings(String rest) {
  final parts = <String>[];
  var slice = rest.trimLeft();
  while (true) {
    final match = RegExp(r"^'([^']*)'\s*").firstMatch(slice);
    final part = match?.group(1);
    if (match == null || part == null) return parts.join();
    parts.add(part);
    slice = slice.substring(match.end).trimLeft();
  }
}

Set<String> _topLevelFields(String select) {
  final names = <String>{};
  final buffer = StringBuffer();
  var depth = 0;
  void take() {
    _add(
      names,
      RegExp(r'^[a-z][a-z0-9_]*')
          .firstMatch(buffer.toString().trim())
          ?.group(0),
    );
    buffer.clear();
  }

  for (final char in select.split('')) {
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;
    } else if (char == ',' && depth == 0) {
      take();
      continue;
    }
    buffer.write(char);
  }
  take();
  return names;
}
