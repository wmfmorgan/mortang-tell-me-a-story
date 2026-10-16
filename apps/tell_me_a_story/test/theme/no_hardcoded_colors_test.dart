import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const temporaryHardcodedColorSkipFileNames = <String>{};

void main() {
  test('dart files under lib keep Color(0x and Colors. in album_theme.dart', () {
    final theme = File('lib/core/theme/album_theme.dart');
    expect(
      theme.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final path = entity.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart')) {
        continue;
      }
      if (path.endsWith('lib/core/theme/album_theme.dart')) {
        continue;
      }
      final name = path.split('/').last;
      if (temporaryHardcodedColorSkipFileNames.contains(name)) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('Color(0x') || line.contains('Colors.')) {
          offenders.add('$path:${i + 1}');
        }
      }
    }

    offenders.sort();
    expect(
      offenders,
      <String>[],
      reason:
          'Hardcoded Color(0x or Colors. outside album_theme.dart:\n'
          '${offenders.join('\n')}',
    );
  });
}
