import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when lib/ catches `Object` or an `Error` type.
///
/// `lib/core/supabase/auth_user_id.dart` is the only allowlisted file.
void main() {
  test('lib/ has no on Error or on AssertionError catch clauses', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );
    final offenders = <String>[];
    final errorCatch = RegExp(r'\bon\s+(Object|\w*Error)\b');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.split('lib/').last;
      final path = 'lib/$relative';
      if (path == 'lib/core/supabase/auth_user_id.dart') continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!errorCatch.hasMatch(line)) continue;
        // ParallelWaitError extends Error. `.wait` unwrap cannot use on Exception.
        if (line.contains('ParallelWaitError')) continue;
        offenders.add('$path:${i + 1}: $line');
      }
    }
    offenders.sort();
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
