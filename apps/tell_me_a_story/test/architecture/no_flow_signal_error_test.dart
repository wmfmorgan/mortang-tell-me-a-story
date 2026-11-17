import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `throw StateError(` counts. The map only shrinks.
const stateErrorAllowlist = <String, int>{
  'lib/core/config/env.dart': 3,
  'lib/data/people_api.dart': 1,
};

void main() {
  test('throw StateError counts match the shrink-only allowlist', () {
    expect(_counts(RegExp(r'throw\s+StateError\s*\(')), stateErrorAllowlist);
  });

  test('lib/ has no throw ArgumentError of an upper-case code', () {
    final counts = _counts(
      RegExp(r'''throw\s+ArgumentError\(\s*['"][A-Z0-9_]+['"]'''),
    );
    expect(counts, isEmpty);
  });
}

Map<String, int> _counts(RegExp pattern) {
  final libDir = Directory('lib');
  expect(libDir.existsSync(), isTrue, reason: 'run from apps/tell_me_a_story');
  final counts = <String, int>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.split('lib/').last;
    final path = 'lib/$relative';
    var count = 0;
    for (final line in entity.readAsLinesSync()) {
      if (pattern.hasMatch(line)) count++;
    }
    if (count > 0) counts[path] = count;
  }
  return Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
