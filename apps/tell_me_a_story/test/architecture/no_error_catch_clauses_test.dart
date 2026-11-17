import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fails when lib/ catches `Object` or an `Error` type.
///
/// Allowlisted files:
/// `lib/core/supabase/auth_user_id.dart` returns null when Supabase asserts
/// before initialize. `lib/features/all_stories/all_stories_loader.dart`
/// unwraps ParallelWaitError and rethrows the original gateway error.
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
      if (path == 'lib/features/all_stories/all_stories_loader.dart') continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (errorCatch.hasMatch(line)) {
          offenders.add('$path:${i + 1}: $line');
        }
      }
    }
    offenders.sort();
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
