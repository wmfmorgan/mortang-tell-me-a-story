import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Grandfathered raw-error reads. Key is `path: pattern`. The count is exact.
const temporaryErrorTextReads = <String, int>{
  'data/invite_api.dart: e.details': 1,
  'data/manage_families_api.dart: e.details': 1,
  'features/auth/invite_sign_in_page.dart: e.message': 2,
  'features/auth/magic_link_page.dart: e.message': 2,
  'features/family/start_timeline_dialog.dart: code ==': 2,
  'features/people/edit_person_dialog.dart: \$error': 1,
};

const _rawCatchTypes = <String>{
  'Object',
  'Exception',
  'PostgrestException',
  'FunctionException',
  'AuthException',
  'StorageException',
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
    final found = <String, int>{};
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = _libRelative(entity.path);
      final source = entity.readAsStringSync();
      if (relative == 'data/rpc_error.dart') {
        _merge(found, relative, _rpcContainsOutside(source));
        continue;
      }
      _merge(found, relative, _errorTextReadCounts(source));
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

    const ownType = '''
void f() {
  try {
    work();
  } on ManageFamiliesException catch (e) {
    print(e.message);
  }
}
''';
    expect(_errorTextReadPatterns(ownType), isEmpty);

    const auth = '''
void f() {
  try {
    work();
  } on AuthException catch (e) {
    print(e.message);
  }
}
''';
    expect(_errorTextReadPatterns(auth), {'e.message'});

    const untyped = '''
void f() {
  try {
    work();
  } catch (e) {
    print(e.message);
  }
}
''';
    expect(_errorTextReadPatterns(untyped), {'e.message'});

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
    expect(_rpcContainsOutside(outside), {'.contains(': 1});
  });
}

void _merge(Map<String, int> found, String path, Map<String, int> counts) {
  for (final entry in counts.entries) {
    found['$path: ${entry.key}'] = entry.value;
  }
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
  return _errorTextReadCounts(source).keys.toSet();
}

Map<String, int> _errorTextReadCounts(String source) {
  final scan = _Scan();
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    _scanLine(line, scan);
    _fileWide(line, scan.hits);
  }
  return scan.hits;
}

void _fileWide(String line, Map<String, int> hits) {
  _add(hits, '.toString().contains(', _occurs(line, '.toString().contains('));
  _add(hits, 'message.contains(', _occurs(line, 'message.contains('));
  final codes = RegExp(r'(?<![\w])code ==').allMatches(line).length;
  _add(hits, 'code ==', codes);
}

void _add(Map<String, int> hits, String pattern, int count) {
  if (count == 0) return;
  hits[pattern] = (hits[pattern] ?? 0) + count;
}

int _occurs(String line, String needle) {
  var count = 0;
  var start = 0;
  while (true) {
    final at = line.indexOf(needle, start);
    if (at < 0) return count;
    count++;
    start = at + needle.length;
  }
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
    final structure = _structureAt(line, i, scan);
    if (structure != null) {
      i = structure;
      continue;
    }
    final catchName = _catchAt(line, i);
    if (catchName != null) {
      scan.pending = catchName.name;
      scan.pendingChecks = _checksText(scan);
      scan.onType = null;
      scan.wantOnType = false;
      i = catchName.end;
      continue;
    }
    final ident = _identAt(line, i);
    if (ident != null && _takeOnType(scan, ident)) {
      i += ident.length;
      continue;
    }
    i = _propertyAt(line, i, scan);
  }
}

int? _structureAt(String line, int i, _Scan scan) {
  if (line.startsWith('{', i)) {
    scan.depth++;
    if (scan.pending != null) {
      _openCatch(scan);
    } else {
      _clearOn(scan);
    }
    return i + 1;
  }
  if (line.startsWith(';', i) || line.startsWith('}', i)) {
    if (line.startsWith('}', i)) {
      scan.depth--;
      scan.active.removeWhere((bound) => bound.depth > scan.depth);
    } else {
      _clearOn(scan);
    }
    return i + 1;
  }
  return null;
}

void _clearOn(_Scan scan) {
  scan.onType = null;
  scan.wantOnType = false;
}

void _openCatch(_Scan scan) {
  final name = scan.pending;
  if (name == null) return;
  scan.active.add(_Bound(name, scan.depth, scan.pendingChecks));
  scan.pending = null;
}

bool _checksText(_Scan scan) {
  if (scan.wantOnType) return false;
  final type = scan.onType;
  if (type == null) return true;
  return _rawCatchTypes.contains(type);
}

bool _takeOnType(_Scan scan, String ident) {
  if (scan.wantOnType) {
    scan.onType = ident;
    scan.wantOnType = false;
    return true;
  }
  if (ident == 'on') {
    scan.wantOnType = true;
    scan.onType = null;
    return true;
  }
  return false;
}

int _propertyAt(String line, int i, _Scan scan) {
  for (final bound in scan.active) {
    if (!bound.checksText) continue;
    final name = bound.name;
    for (final field in _fields) {
      final token = '$name.$field';
      if (!line.startsWith(token, i)) continue;
      if (_wordAfter(line, i + token.length)) continue;
      _add(scan.hits, token, 1);
      return i + token.length;
    }
    final call = '$name.toString(';
    if (line.startsWith(call, i)) {
      _add(scan.hits, '$name.toString(', 1);
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
    if (!bound.checksText) continue;
    if (line.startsWith('\${$name}', i) || _simpleInterp(line, i, name)) {
      final pattern = line.startsWith('\${', i) ? '\${$name}' : '\$$name';
      _add(scan.hits, pattern, 1);
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

String? _identAt(String line, int i) {
  if (!_identStart(line, i)) return null;
  return RegExp(r'[A-Za-z_]\w*').matchAsPrefix(line, i)?.group(0);
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

Map<String, int> _rpcContainsOutside(String source) {
  final hits = <String, int>{};
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
    _add(hits, '.contains(', inConstraint ? 0 : _occurs(line, '.contains('));
  }
  return hits;
}

class _Scan {
  int depth = 0;
  String? pending;
  bool pendingChecks = false;
  String? onType;
  bool wantOnType = false;
  String? quote;
  bool triple = false;
  bool raw = false;
  final active = <_Bound>[];
  final hits = <String, int>{};
}

class _Bound {
  _Bound(this.name, this.depth, this.checksText);
  final String name;
  final int depth;
  final bool checksText;
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
