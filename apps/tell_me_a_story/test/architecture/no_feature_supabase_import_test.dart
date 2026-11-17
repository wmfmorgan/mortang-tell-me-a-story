import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/features/` and non-router `lib/core/` must not import
/// `package:supabase_flutter`. The allowlist only shrinks.
const supabaseImportAllowlist = <String>{
  'lib/core/supabase/auth_user_id.dart',
  'lib/core/supabase/supabase_init.dart',
  'lib/core/theme/album_header.dart',
  'lib/features/auth/invite_sign_in_page.dart',
  'lib/features/auth/magic_link_page.dart',
  'lib/features/search/search_page.dart',
  'lib/features/stories/new_story_page.dart',
  'lib/features/timeline/card_photos.dart',
};

void main() {
  test('features and non-router core do not import supabase_flutter', () {
    final libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'run this test from apps/tell_me_a_story',
    );

    final offenders = <String>[];
    final allowHits = {
      for (final entry in supabaseImportAllowlist) entry: false,
    };
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = _libPath(entity.path);
      if (path == null || !_isBannedZone(path)) continue;
      if (!_importsSupabase(entity)) continue;
      if (supabaseImportAllowlist.contains(path)) {
        allowHits[path] = true;
        continue;
      }
      offenders.add(path);
    }

    final stale = [
      for (final hit in allowHits.entries)
        if (!hit.value) 'allowlist has no hit ${hit.key}',
    ];
    offenders.sort();
    stale.sort();
    final report = [...stale, ...offenders];
    expect(report, isEmpty, reason: report.join('\n'));
  });
}

String? _libPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final marker = normalized.indexOf('lib/');
  if (marker < 0) return null;
  return normalized.substring(marker);
}

bool _isBannedZone(String path) {
  if (path.startsWith('lib/features/')) return true;
  if (!path.startsWith('lib/core/')) return false;
  return !path.startsWith('lib/core/router/');
}

bool _importsSupabase(File file) {
  final importLine = RegExp(
    r'''^\s*(import|export)\s+['"]package:supabase_flutter/''',
  );
  for (final line in file.readAsLinesSync()) {
    if (importLine.hasMatch(line)) return true;
  }
  return false;
}
