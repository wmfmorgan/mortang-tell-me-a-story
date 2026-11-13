import 'package:tell_me_a_story/data/stories_api.dart';

/// Case-insensitive substring match of trimmed [query] on title, body, personNames.
/// Empty trimmed query => true. Never matches place label/address or decade.
bool matchesSearch(Story story, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  if (_contains(story.title, needle) || _contains(story.body, needle)) {
    return true;
  }
  for (final name in story.personNames) {
    if (nameMatches(name, query)) return true;
  }
  return false;
}

bool nameMatches(String name, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return false;
  return name.toLowerCase().contains(needle);
}

bool _contains(String? value, String needle) {
  if (value == null) return false;
  return value.toLowerCase().contains(needle);
}
