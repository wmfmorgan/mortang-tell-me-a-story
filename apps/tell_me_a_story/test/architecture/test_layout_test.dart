import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Unit and widget tests mirror lib/: the test for lib/<dir>/<name>.dart is
// test/<dir>/<name>_test.dart (or <name>_<aspect>_test.dart). live/ (tag
// live), architecture/ (guards) and support/ (shared fakes) are the only
// other folders. Run from apps/tell_me_a_story.

const _ownFolders = {'architecture', 'live', 'support'};
final _milestoneName = RegExp(r'^m\d+(_\d+)*_');

void main() {
  test('test files mirror lib/ and are named for their subject', () {
    expect(
      Directory('lib').existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );
    final problems = <String>[];
    for (final entity in Directory('test').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/').substring('test/'.length);
      final parts = path.split('/');
      if (_ownFolders.contains(parts.first)) continue;
      final name = parts.last;
      if (!name.endsWith('_test.dart')) {
        problems.add('$path: shared test code goes in test/support/');
        continue;
      }
      if (_milestoneName.hasMatch(name)) {
        problems.add('$path: name the subject, not the milestone');
      }
      if (parts.length == 1) {
        problems.add('$path: move it under the lib/ folder it tests');
        continue;
      }
      final folder = parts.sublist(0, parts.length - 1).join('/');
      if (!Directory('lib/$folder').existsSync()) {
        problems.add('$path: lib/$folder does not exist');
      }
    }
    problems.sort();
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
