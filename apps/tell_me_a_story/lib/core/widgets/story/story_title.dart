import 'package:tell_me_a_story/core/domain/story.dart';

/// [story]'s trimmed title, or 'Untitled'.
String storyTitle(Story story) {
  final title = story.title?.trim() ?? '';
  return title.isEmpty ? 'Untitled' : title;
}
