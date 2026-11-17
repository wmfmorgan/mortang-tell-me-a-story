import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when lib/ uses `on Error` or `on AssertionError` catch clauses.
void main() {
  test('lib/ has no on Error or on AssertionError catch clauses', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );
    final offenders = <String>[];
    final errorCatch = RegExp(r'\bon\s+Error\s+catch\b');
    final assertionCatch = RegExp(r'\bon\s+AssertionError\s+catch\b');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceFirst('lib/', 'lib/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (errorCatch.hasMatch(line) || assertionCatch.hasMatch(line)) {
          offenders.add('$relative:${i + 1}: $line');
        }
      }
    }
    offenders.sort();
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
