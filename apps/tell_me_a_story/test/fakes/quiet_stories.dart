import 'package:tell_me_a_story/data/stories_api.dart';

/// Empty stories gateway so a timeline test does not open Supabase.
class QuietStories implements StoriesGateway {
  var lastDraftId = 'quiet-draft';

  Story _draft({
    required String id,
    required String familyId,
    String? title,
    String? body,
    List<String> personIds = const [],
  }) {
    return Story(
      id: id,
      familyId: familyId,
      authorId: 'quiet-user',
      title: title,
      body: body,
      status: StoryStatus.draft,
      personIds: personIds,
    );
  }

  @override
  Future<List<Story>> listPublished(String familyId) async => const [];

  @override
  Future<Story?> getPublished(String storyId) async => null;

  @override
  Future<Story?> getPublishedOrigin(String storyId) async => null;

  @override
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async => const [];

  @override
  Future<void> discard(String storyId) async {}

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {}

  @override
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
  }) async {
    lastDraftId = id ?? 'quiet-draft';
    return _draft(
      id: lastDraftId,
      familyId: familyId,
      title: title,
      body: body,
      personIds: personIds,
    );
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    return _draft(
      id: storyId,
      familyId: 'family',
      title: title,
      body: body,
      personIds: personIds ?? const [],
    );
  }

  @override
  Future<bool> autosaveDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? datePrecision,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    return true;
  }

  @override
  Future<Story> publish(String storyId) => throw UnimplementedError();

  @override
  Future<Story> getStory(String storyId) => throw UnimplementedError();
}
