import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The e2e flow manifest check: integration_test/flows.md and the
// testWidgets names in integration_test/e2e_test.dart must agree, and every
// owning path must exist under lib/. Reads files only. Run from
// apps/tell_me_a_story (flutter test does).

const _manifestPath = 'integration_test/flows.md';
const _entryPath = 'integration_test/e2e_test.dart';
const _supportPath = 'integration_test/support';
const _flowBudget = 10;
const _maxNameLength = 64;

final _rowPattern = RegExp(r'^\| C[0-9]+ \|');
final _namePattern = RegExp(r'^C[0-9]+ [a-z0-9 ,/-]+$');
final _quotedName = RegExp(r"'(C[0-9]+ [^'\n]*)'");
final _backticked = RegExp(r'`([^`]+)`');

class _Flow {
  const _Flow(this.id, this.name, this.paths);

  final String id;
  final String name;
  final List<String> paths;
}

List<_Flow> _readFlows(String manifest) {
  final flows = <_Flow>[];
  for (final line in manifest.split('\n')) {
    if (!_rowPattern.hasMatch(line)) continue;
    // | Flow | Test name | Spec source | Owning paths |
    final cells = line.split('|');
    flows.add(
      _Flow(cells[1].trim(), cells[2].trim().replaceAll('`', ''), [
        for (final match in _backticked.allMatches(cells[4])) match.group(1)!,
      ]),
    );
  }
  return flows;
}

void main() {
  test('flows.md and e2e_test.dart agree', () {
    final manifestFile = File(_manifestPath);
    final entryFile = File(_entryPath);
    expect(
      manifestFile.existsSync(),
      isTrue,
      reason: 'missing $_manifestPath; run from apps/tell_me_a_story',
    );
    expect(entryFile.existsSync(), isTrue, reason: 'missing $_entryPath');

    final flows = _readFlows(manifestFile.readAsStringSync());
    expect(flows, isNotEmpty, reason: 'no flow rows in $_manifestPath');

    final errors = <String>[];
    final seen = <String>{};
    final duplicates = <String>{};
    for (final flow in flows) {
      if (!seen.add(flow.id)) duplicates.add(flow.id);
    }
    if (duplicates.isNotEmpty) {
      errors.add('duplicate flow ids: ${duplicates.join(' ')}');
    }
    if (flows.length > _flowBudget) {
      errors.add('${flows.length} flows is over the U4 budget of $_flowBudget');
    }

    for (final flow in flows) {
      if (!flow.name.startsWith('${flow.id} ')) {
        errors.add(
          "${flow.id}: test name '${flow.name}' does not start with "
          "'${flow.id} '",
        );
      }
      if (!_namePattern.hasMatch(flow.name)) {
        errors.add(
          "${flow.id}: test name '${flow.name}' has characters outside "
          '[a-z0-9 ,/-]',
        );
      }
      if (flow.name.length > _maxNameLength) {
        errors.add('${flow.id}: test name is over $_maxNameLength characters');
      }
      for (final path in flow.paths) {
        if (FileSystemEntity.typeSync('lib/$path') ==
            FileSystemEntityType.notFound) {
          errors.add('${flow.id}: owning path lib/$path does not exist');
        }
      }
    }

    final entry = entryFile.readAsStringSync();
    final tests = [
      for (final match in _quotedName.allMatches(entry)) match.group(1)!,
    ].where(_namePattern.hasMatch).toList()..sort();
    final want = [for (final flow in flows) flow.name]..sort();
    if (tests.join('\n') != want.join('\n')) {
      errors.add(
        'flows.md and e2e_test.dart disagree:\n'
        '  only in flows.md: ${want.where((n) => !tests.contains(n)).toList()}\n'
        '  only in e2e_test.dart: ${tests.where((n) => !want.contains(n)).toList()}',
      );
    }

    final calls = 'testWidgets('.allMatches(entry).length;
    if (calls != flows.length) {
      errors.add(
        'e2e_test.dart has $calls testWidgets calls; '
        'flows.md has ${flows.length} rows',
      );
    }

    final support = Directory(_supportPath);
    if (support.existsSync()) {
      for (final entity in support.listSync(recursive: true)) {
        if (entity is File &&
            entity.readAsStringSync().contains('testWidgets(')) {
          errors.add(
            'testWidgets( found in ${entity.path}; '
            'tests live only in e2e_test.dart',
          );
        }
      }
    }

    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
