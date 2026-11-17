import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard complement: bare `catch (` without an `on` clause under lib/.
void main() {
  test('lib/ has no bare catch clauses', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );
    final bareCatch = RegExp(r'\}\s*catch\s*\(');
    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.split('lib/').last;
      final path = 'lib/$relative';
      if (path == 'lib/core/supabase/auth_user_id.dart') continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (bareCatch.hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    offenders.sort();
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
