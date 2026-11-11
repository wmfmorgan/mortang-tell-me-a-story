import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/story.dart';

part 'story_thumbs.g.dart';

/// First-photo thumbnail bytes per story id. Missing or unreadable photos are
/// absent from the map.
typedef StoryThumbsLoader = Future<Map<String, Uint8List>> Function(
  List<Story> stories,
);

@Riverpod(keepAlive: true)
StoryThumbsLoader storyThumbsLoader(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
