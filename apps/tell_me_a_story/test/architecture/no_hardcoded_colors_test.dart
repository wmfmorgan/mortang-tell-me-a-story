import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const temporaryHardcodedColorSkipPaths = <String>{
  'features/auth/presentation/invite_sign_in_page.dart',
  'features/comments/presentation/comment_composer.dart',
  'features/drafts/presentation/drafts_page.dart',
  'features/family/presentation/add_co_owner_dialog.dart',
  'features/family/presentation/manage_families_page.dart',
  'features/family/presentation/manage_family_page.dart',
  'features/family/presentation/start_family_dialog.dart',
  'features/family/presentation/start_timeline_dialog.dart',
  'features/invites/presentation/invite_modal.dart',
  'features/perspectives/presentation/add_perspective_page.dart',
  'features/places/presentation/place_picker_modal.dart',
  'features/search/presentation/search_page.dart',
  'features/settings/presentation/settings_page.dart',
  'features/stories/presentation/new_story_page.dart',
  'features/stories/presentation/photo_strip.dart',
  'features/stories/presentation/story_reader_page.dart',
};

/// The skip list only shrinks: lower this when a file leaves the list.
const _skipListCeiling = 16;

const _albumThemePath = 'core/theme/album_theme.dart';

void main() {
  test('the hardcoded-color skip list never grows', () {
    expect(
      temporaryHardcodedColorSkipPaths.length,
      lessThanOrEqualTo(_skipListCeiling),
    );
  });

  test(
    'dart files under lib keep Color(0x and Colors. in album_theme.dart',
    () {
      expect(
        File('lib/$_albumThemePath').existsSync(),
        isTrue,
        reason: 'run this test from apps/tell_me_a_story',
      );

      final offenders = <String>[];
      final skipHits = <String, int>{
        for (final path in temporaryHardcodedColorSkipPaths) path: 0,
      };

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final path = entity.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart')) {
          continue;
        }
        final relative = _libRelativePath(path);
        if (relative == _albumThemePath) {
          continue;
        }
        final lines = entity.readAsLinesSync();
        var hits = 0;
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.contains('Color(0x') && !line.contains('Colors.')) {
            continue;
          }
          hits++;
          if (!temporaryHardcodedColorSkipPaths.contains(relative)) {
            offenders.add('$relative:${i + 1}');
          }
        }
        if (skipHits.containsKey(relative)) {
          skipHits[relative] = hits;
        }
      }

      final missing = <String>[];
      final clean = <String>[];
      for (final path in skipHits.keys) {
        final file = File('lib/$path');
        if (!file.existsSync()) {
          missing.add(path);
          continue;
        }
        if (skipHits[path] == 0) {
          clean.add(path);
        }
      }
      missing.sort();
      clean.sort();
      offenders.sort();

      final report = <String>[
        for (final path in missing) 'missing skip $path',
        for (final path in clean) 'skip has no hit $path',
        ...offenders,
      ];
      expect(report, <String>[], reason: report.join('\n'));
    },
  );
}

String _libRelativePath(String path) {
  const prefix = 'lib/';
  if (path.startsWith(prefix)) {
    return path.substring(prefix.length);
  }
  const marker = '/lib/';
  final index = path.lastIndexOf(marker);
  if (index == -1) {
    fail('dart path is not under lib/: $path');
  }
  return path.substring(index + marker.length);
}
