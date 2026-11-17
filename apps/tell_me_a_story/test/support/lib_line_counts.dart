import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Counts [pattern] on non-comment lines under lib/. Paths are `lib/...`.
Map<String, int> libLineCounts(RegExp pattern) {
  final libDir = Directory('lib');
  expect(libDir.existsSync(), isTrue, reason: 'run from apps/tell_me_a_story');
  final counts = <String, int>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.split('lib/').last;
    final path = 'lib/$relative';
    var count = 0;
    for (final line in entity.readAsLinesSync()) {
      if (line.trimLeft().startsWith('//')) continue;
      if (pattern.hasMatch(line)) count++;
    }
    if (count > 0) counts[path] = count;
  }
  return Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
