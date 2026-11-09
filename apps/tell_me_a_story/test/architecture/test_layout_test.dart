import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Unit and widget tests mirror lib/'s folders: every test file outside live/
// (tag live), goldens/ (tag golden, macOS only), architecture/ (guards) and
// support/ (shared fakes) ends in _test.dart, sits in a folder that also
// exists under lib/, and is not named for a milestone (m<N>_...). File names
// are not matched to lib/ files. Run from apps/tell_me_a_story.

const _ownFolders = {'architecture', 'goldens', 'live', 'support'};
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
      if (parts.first == 'goldens' &&
          path.endsWith('_test.dart') &&
          !entity.readAsStringSync().startsWith("@Tags(['golden'])")) {
        problems.add("$path: a golden test starts with @Tags(['golden'])");
      }
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
