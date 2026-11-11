import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/story.dart';

part 'stories_repository.g.dart';

@Riverpod(keepAlive: true)
StoriesRepository storiesRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');

abstract class StoriesRepository {
  Future<Story> createDraft({
    String? id,
    required String familyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    bool allowUndated = false,
    List<String> personIds = const [],
  });

  /// A null [personIds] leaves the story's story_people rows as they are. A list, even an empty one, replaces them.
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  });

  /// Autosave and save-on-leave only. False when the row is no longer a draft.
  /// A null [personIds] leaves the story's story_people rows as they are. A list, even an empty one, replaces them.
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  });
  Future<Story> publish(String storyId);
  Future<Story> getStory(String storyId);
  Future<Story?> getPublished(String storyId);
  Future<List<Story>> listMyDrafts(String familyId);
  Future<List<Story>> listPublished(String familyId);

  /// Published stories of every live family in [familyId]'s tree, in
  /// timeline order. Tree readers of a live family only.
  Future<List<Story>> listPublishedInTree(String familyId);

  /// Published story by id using the published-list select. Null when not found or not readable.
  Future<Story?> getPublishedOrigin(String storyId);

  /// Published stories added in the past [withinDays], newest first, at most [limit].
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  });

  /// Deletes the caller's own story with its photos, notes and tags.
  Future<void> discard(String storyId);

  /// Tags [personId] on the story. Does not replace the story's other
  /// people; a repeat is a no-op.
  Future<void> linkPerson({required String storyId, required String personId});
}
