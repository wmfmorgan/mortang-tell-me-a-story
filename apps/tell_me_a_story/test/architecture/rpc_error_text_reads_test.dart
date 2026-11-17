import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hits already on main. One `path: pattern` entry. The list only shrinks.
const temporaryErrorTextReads = <String>{
  'data/invite_api.dart: e.details',
  'data/manage_families_api.dart: e.details',
  'features/auth/invite_sign_in_page.dart: e.message',
  'features/auth/magic_link_page.dart: e.message',
  'features/family/family_landing_page.dart: error.message',
  'features/family/manage_families_page.dart: e.message',
  'features/family/manage_family_page.dart: e.message',
  'features/family/start_family_dialog.dart: e.message',
  'features/family/start_timeline_dialog.dart: code ==',
  'features/invites/invite_modal.dart: error.message',
  'features/people/edit_person_dialog.dart: \$error',
  'features/stories/story_reader_page.dart: error.message',
};

const _fields = <String>['message', 'code', 'details', 'hint'];

void main() {
  test('rpc error text reads match the shrink-only list', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run from apps/tell_me_a_story',
    );
    final found = <String>{};
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = _libRelative(entity.path);
      final source = entity.readAsStringSync();
      if (relative == 'data/rpc_error.dart') {
        found.addAll(_prefix(relative, _rpcContainsOutside(source)));
        continue;
      }
      found.addAll(_prefix(relative, _errorTextReadPatterns(source)));
    }
    expect(found, temporaryErrorTextReads);
  });

  test('banned catch reads are caught and lookalikes pass', () {
    const banned = r'''
void f() {
  try {
    work();
  } on AuthException catch (e, st) {
    print(e.message);
    print(e.code);
    print(e.details);
    print(e.hint);
    print(e.toString());
    print('$e');
    print('${e}');
  }
  print(thing.toString().contains('x'));
  if (message.contains('x')) {}
  if (code == 'x') {}
}
''';
    expect(_errorTextReadPatterns(banned), {
      'e.message',
      'e.code',
      'e.details',
      'e.hint',
      'e.toString(',
      r'$e',
      r'${e}',
      '.toString().contains(',
      'message.contains(',
      'code ==',
    });

    const lookalikes = r'''
void f() {
  try {
    work();
  } catch (e) {
    print(e.messageId);
    print(items.contains(e));
  }
  final items = <String>['a'];
  if (items.contains('a')) {}
  if (statusCode == 404) {}
}
''';
    expect(_errorTextReadPatterns(lookalikes), isEmpty);

    const inside = '''
bool rpcConstraintViolation(Object error, String sqlstate, String constraint) {
  return error.message.contains(constraint);
}
''';
    expect(_rpcContainsOutside(inside), isEmpty);

    const outside = '''
String? mapRpcError(Object error) {
  return error.message.contains('x') ? 'no' : null;
}
''';
    expect(_rpcContainsOutside(outside), {'.contains('});
  });
}

Set<String> _prefix(String path, Set<String> patterns) {
  return {for (final pattern in patterns) '$path: $pattern'};
}

String _libRelative(String path) {
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('lib/')) return normalized.substring(4);
  const marker = '/lib/';
  final index = normalized.lastIndexOf(marker);
  if (index == -1) fail('dart path is not under lib/: $path');
  return normalized.substring(index + marker.length);
}

/// Banned error-text forms in [source], ignoring `//` lines.
Set<String> _errorTextReadPatterns(String source) {
  final scan = _Scan();
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    _scanLine(line, scan);
    _fileWide(line, scan.hits);
  }
  return scan.hits;
}

void _fileWide(String line, Set<String> hits) {
  if (line.contains('.toString().contains(')) hits.add('.toString().contains(');
  if (line.contains('message.contains(')) hits.add('message.contains(');
  if (RegExp(r'(?<![\w])code ==').hasMatch(line)) hits.add('code ==');
}

void _scanLine(String line, _Scan scan) {
  var i = 0;
  while (i < line.length) {
    if (scan.quote != null) {
      i = _inString(line, i, scan);
      continue;
    }
    final quoteAt = _quoteAt(line, i);
    if (quoteAt != null) {
      scan.quote = quoteAt.quote;
      scan.triple = quoteAt.triple;
      scan.raw = quoteAt.raw;
      i = quoteAt.end;
      continue;
    }
    if (line.startsWith('{', i)) {
      scan.depth++;
      _openCatch(scan);
      i++;
      continue;
    }
    if (line.startsWith('}', i)) {
      scan.depth--;
      scan.active.removeWhere((bound) => bound.depth > scan.depth);
      i++;
      continue;
    }
    final catchName = _catchAt(line, i);
    if (catchName != null) {
      scan.pending = catchName.name;
      i = catchName.end;
      continue;
    }
    i = _propertyAt(line, i, scan);
  }
}

void _openCatch(_Scan scan) {
  final name = scan.pending;
  if (name == null) return;
  scan.active.add(_Bound(name, scan.depth));
  scan.pending = null;
}

int _propertyAt(String line, int i, _Scan scan) {
  for (final bound in scan.active) {
    final name = bound.name;
    for (final field in _fields) {
      final token = '$name.$field';
      if (!line.startsWith(token, i)) continue;
      if (_wordAfter(line, i + token.length)) continue;
      scan.hits.add(token);
      return i + token.length;
    }
    final call = '$name.toString(';
    if (line.startsWith(call, i)) {
      scan.hits.add('$name.toString(');
      return i + call.length;
    }
  }
  return i + 1;
}

int _inString(String line, int i, _Scan scan) {
  final quote = scan.quote!;
  if (!scan.raw && line.startsWith(r'$', i)) {
    _interpolation(line, i, scan);
  }
  if (line.startsWith(r'\', i)) {
    return i + 2 > line.length ? line.length : i + 2;
  }
  if (scan.triple && line.startsWith(quote * 3, i)) {
    scan.quote = null;
    return i + 3;
  }
  if (!scan.triple && line.startsWith(quote, i)) {
    scan.quote = null;
    return i + 1;
  }
  return i + 1;
}

void _interpolation(String line, int i, _Scan scan) {
  for (final bound in scan.active) {
    final name = bound.name;
    if (line.startsWith('\${$name}', i) || _simpleInterp(line, i, name)) {
      scan.hits.add(line.startsWith('\${', i) ? '\${$name}' : '\$$name');
    }
  }
}

bool _simpleInterp(String line, int i, String name) {
  if (!line.startsWith('\$$name', i)) return false;
  return !_wordAfter(line, i + 1 + name.length);
}

bool _wordAfter(String line, int index) {
  if (index >= line.length) return false;
  return RegExp(r'\w').hasMatch(line[index]);
}

_CatchHit? _catchAt(String line, int i) {
  if (!_identStart(line, i) || !line.startsWith('catch', i)) return null;
  final match = RegExp(r'catch\s*\(\s*([A-Za-z_]\w*)').matchAsPrefix(line, i);
  if (match == null) return null;
  return _CatchHit(match.group(1)!, match.end);
}

bool _identStart(String line, int i) {
  if (i == 0) return true;
  return !RegExp(r'\w').hasMatch(line[i - 1]);
}

_Quote? _quoteAt(String line, int i) {
  final raw = i > 0 && line[i - 1] == 'r' && _identStart(line, i - 1);
  final start = i;
  if (line.startsWith("'''", start) || line.startsWith('"""', start)) {
    return _Quote(line[start], triple: true, raw: raw, end: start + 3);
  }
  if (line.startsWith("'", start) || line.startsWith('"', start)) {
    return _Quote(line[start], triple: false, raw: raw, end: start + 1);
  }
  return null;
}

Set<String> _rpcContainsOutside(String source) {
  final hits = <String>{};
  var depth = 0;
  var fnDepth = 0;
  var inConstraint = false;
  var pending = false;
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    if (!inConstraint && line.contains('rpcConstraintViolation')) {
      pending = true;
    }
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '{') {
        depth++;
        if (pending) {
          inConstraint = true;
          fnDepth = depth;
          pending = false;
        }
      } else if (line[i] == '}') {
        if (inConstraint && depth == fnDepth) inConstraint = false;
        depth--;
      }
    }
    if (!inConstraint && line.contains('.contains(')) hits.add('.contains(');
  }
  return hits;
}

class _Scan {
  int depth = 0;
  String? pending;
  String? quote;
  bool triple = false;
  bool raw = false;
  final active = <_Bound>[];
  final hits = <String>{};
}

class _Bound {
  _Bound(this.name, this.depth);
  final String name;
  final int depth;
}

class _CatchHit {
  _CatchHit(this.name, this.end);
  final String name;
  final int end;
}

class _Quote {
  _Quote(
    this.quote, {
    required this.triple,
    required this.raw,
    required this.end,
  });
  final String quote;
  final bool triple;
  final bool raw;
  final int end;
}
