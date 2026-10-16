import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const temporaryHardcodedColorSkipPaths = <String>{
  'core/theme/album_chrome.dart',
  'core/theme/album_header.dart',
  'core/theme/profile_avatar.dart',
  'features/auth/invite_sign_in_page.dart',
  'features/auth/magic_link_page.dart',
  'features/comments/comment_composer.dart',
  'features/drafts/drafts_page.dart',
  'features/family/add_co_owner_dialog.dart',
  'features/family/family_blur_dialog.dart',
  'features/family/family_role.dart',
  'features/family/manage_families_page.dart',
  'features/family/manage_family_page.dart',
  'features/family/start_family_dialog.dart',
  'features/family/start_timeline_dialog.dart',
  'features/invites/invite_modal.dart',
  'features/perspectives/add_perspective_page.dart',
  'features/places/place_picker_modal.dart',
  'features/search/search_page.dart',
  'features/settings/settings_page.dart',
  'features/stories/new_story_page.dart',
  'features/stories/photo_strip.dart',
  'features/stories/story_reader_page.dart',
  'features/timeline/timeline_page.dart',
};

const _albumThemePath = 'core/theme/album_theme.dart';

void main() {
  test('dart files under lib keep Color(0x and Colors. in album_theme.dart', () {
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
    expect(
      report,
      <String>[],
      reason: report.join('\n'),
    );
  });
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
