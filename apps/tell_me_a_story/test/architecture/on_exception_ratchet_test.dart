import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Exact `on Exception` counts under lib/. The map only shrinks: a higher
/// count fails, and a lower count fails until this entry is updated.
/// A file absent from the map must have zero. lib/data entries may exist
/// only for the files listed in [dataOnExceptionCeiling], at or under that
/// ceiling. A new `on Exception` in lib/data fails even if this map grows.
const onExceptionAllowlist = <String, int>{
  'lib/core/navigation/leave_story_dialog.dart': 1,
  'lib/core/router/app_router.dart': 3,
  'lib/data/families_api.dart': 2,
  'lib/data/photos_api.dart': 2,
  'lib/data/profile_session.dart': 1,
  'lib/features/all_stories/all_stories_page.dart': 2,
  'lib/features/auth/invite_sign_in_page.dart': 3,
  'lib/features/auth/magic_link_page.dart': 1,
  'lib/features/comments/comment_composer.dart': 1,
  'lib/features/drafts/drafts_page.dart': 3,
  'lib/features/family/family_landing_page.dart': 6,
  'lib/features/family/manage_families_page.dart': 1,
  'lib/features/family/manage_family_page.dart': 1,
  'lib/features/family/start_family_dialog.dart': 1,
  'lib/features/family/start_timeline_dialog.dart': 2,
  'lib/features/invites/invite_modal.dart': 7,
  'lib/features/people/add_person_modal.dart': 3,
  'lib/features/people/edit_person_dialog.dart': 2,
  'lib/features/people/person_profile_dialog.dart': 6,
  'lib/features/perspectives/add_perspective_page.dart': 2,
  'lib/features/places/place_picker_modal.dart': 5,
  'lib/features/search/search_page.dart': 3,
  'lib/features/settings/settings_page.dart': 3,
  'lib/features/stories/new_story_page.dart': 13,
  'lib/features/stories/story_reader_page.dart': 20,
  'lib/features/timeline/timeline_page.dart': 7,
};

/// Frozen data ceiling from this ratchet. Do not add a file or raise a count.
const dataOnExceptionCeiling = <String, int>{
  'lib/data/families_api.dart': 2,
  'lib/data/photos_api.dart': 2,
  'lib/data/profile_session.dart': 1,
};

void main() {
  test('on Exception counts match the shrink-only allowlist', () {
    final counts = _counts(RegExp(r'\bon\s+Exception\b'));
    expect(counts, onExceptionAllowlist);
    for (final entry in onExceptionAllowlist.entries) {
      if (!entry.key.startsWith('lib/data/')) continue;
      final ceiling = dataOnExceptionCeiling[entry.key];
      expect(ceiling, isNotNull, reason: '${entry.key} is a new data catch');
      expect(entry.value <= ceiling!, isTrue);
    }
    for (final path in counts.keys) {
      if (!path.startsWith('lib/data/')) continue;
      expect(dataOnExceptionCeiling.containsKey(path), isTrue);
    }
  });
}

Map<String, int> _counts(RegExp pattern) {
  final libDir = Directory('lib');
  expect(libDir.existsSync(), isTrue, reason: 'run from apps/tell_me_a_story');
  final counts = <String, int>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.split('lib/').last;
    final path = 'lib/$relative';
    var count = 0;
    for (final line in entity.readAsLinesSync()) {
      if (pattern.hasMatch(line)) count++;
    }
    if (count > 0) counts[path] = count;
  }
  return Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
