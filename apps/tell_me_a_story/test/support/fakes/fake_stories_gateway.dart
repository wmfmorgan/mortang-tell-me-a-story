import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

/// In-memory [StoriesGateway] for widget tests. [stories] is the store,
/// keyed by id; every call is appended to [calls] as its method name. Set
/// [error] to make every call throw it. Subclass and override a method for
/// anything else.
class FakeStoriesGateway implements StoriesGateway {
  FakeStoriesGateway({
    Iterable<Story> stories = const [],
    this.userId = 'user-1',
    DateTime? now,
  }) : now = now ?? DateTime.utc(2026, 11, 1) {
    for (final story in stories) {
      this.stories[story.id] = story;
    }
  }

  /// Author of drafts this fake creates; [listMyDrafts] filters on it.
  final String userId;

  /// Clock for `publishedAt` and [listLatestPublished].
  final DateTime now;

  final stories = <String, Story>{};
  final calls = <String>[];
  final discarded = <String>[];
  final linkedPeople = <({String storyId, String personId})>[];
  Object? error;

  void _record(String call) {
    calls.add(call);
    final thrown = error;
    if (thrown != null) throw thrown;
  }

  Story _require(String storyId) {
    final story = stories[storyId];
    if (story == null) {
      throw const AppException(
        code: AppErrorCode.notFound,
        message: 'Story not found.',
      );
    }
    return story;
  }

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
    _record('createDraft');
    final story = Story(
      id: id ?? 'story-${stories.length + 1}',
      familyId: familyId,
      authorId: userId,
      title: title,
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: storyDatePrecisionFrom(datePrecision),
      createdAt: now,
      placeId: placeId,
      status: StoryStatus.draft,
      personIds: personIds,
    );
    stories[story.id] = story;
    return story;
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
    _record('updateDraft');
    return stories[storyId] = rebuildStory(
      _require(storyId),
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: datePrecision,
      title: title,
      body: body,
      placeId: placeId,
      personIds: personIds,
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
    _record('autosaveDraft');
    final story = stories[storyId];
    if (story == null || story.status != StoryStatus.draft) return false;
    stories[storyId] = rebuildStory(
      story,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      datePrecision: datePrecision,
      title: title,
      body: body,
      placeId: placeId,
      personIds: personIds,
    );
    return true;
  }

  @override
  Future<Story> publish(String storyId) async {
    _record('publish');
    return stories[storyId] = rebuildStory(
      _require(storyId),
      status: StoryStatus.published,
      publishedAt: now,
    );
  }

  @override
  Future<Story> getStory(String storyId) async {
    _record('getStory');
    return _require(storyId);
  }

  @override
  Future<Story?> getPublished(String storyId) async {
    _record('getPublished');
    final story = stories[storyId];
    return story?.status == StoryStatus.published ? story : null;
  }

  @override
  Future<List<Story>> listMyDrafts(String familyId) async {
    _record('listMyDrafts');
    return [
      for (final story in stories.values)
        if (story.familyId == familyId &&
            story.authorId == userId &&
            story.status == StoryStatus.draft)
          story,
    ];
  }

  @override
  Future<List<Story>> listPublished(String familyId) async {
    _record('listPublished');
    return _published(familyId);
  }

  /// The store stands for one tree: every published story, in timeline
  /// order (`compareStories`).
  @override
  Future<List<Story>> listPublishedInTree(String familyId) async {
    _record('listPublishedInTree');
    return [
      for (final story in stories.values)
        if (story.status == StoryStatus.published) story,
    ]..sort(compareStories);
  }

  @override
  Future<Story?> getPublishedOrigin(String storyId) async {
    _record('getPublishedOrigin');
    final story = stories[storyId];
    return story?.status == StoryStatus.published ? story : null;
  }

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) async {
    _record('listLatestPublished');
    final since = (now ?? this.now).subtract(Duration(days: withinDays));
    final latest = [
      for (final story in _published(familyId))
        if (story.publishedAt != null && story.publishedAt!.isAfter(since))
          story,
    ]..sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    return latest.take(limit).toList();
  }

  @override
  Future<void> discard(String storyId) async {
    _record('discard');
    stories.remove(storyId);
    discarded.add(storyId);
  }

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) async {
    _record('linkPerson');
    linkedPeople.add((storyId: storyId, personId: personId));
    final story = _require(storyId);
    if (!story.personIds.contains(personId)) {
      stories[storyId] = rebuildStory(
        story,
        personIds: [...story.personIds, personId],
      );
    }
  }

  List<Story> _published(String familyId) => [
    for (final story in stories.values)
      if (story.familyId == familyId && story.status == StoryStatus.published)
        story,
  ];
}

/// [story] with the given fields replaced; a null argument keeps the field.
Story rebuildStory(
  Story story, {
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
  String? datePrecision,
  String? title,
  String? body,
  String? placeId,
  List<String>? personIds,
  StoryStatus? status,
  DateTime? publishedAt,
}) {
  return Story(
    id: story.id,
    familyId: story.familyId,
    authorId: story.authorId,
    title: title ?? story.title,
    body: body ?? story.body,
    timeframeStart: timeframeStart ?? story.timeframeStart,
    timeframeEnd: timeframeEnd ?? story.timeframeEnd,
    datePrecision: datePrecision == null
        ? story.datePrecision
        : storyDatePrecisionFrom(datePrecision),
    createdAt: story.createdAt,
    placeId: placeId ?? story.placeId,
    status: status ?? story.status,
    publishedAt: publishedAt ?? story.publishedAt,
    personIds: personIds ?? story.personIds,
    photoCount: story.photoCount,
    placeLabel: story.placeLabel,
    people: story.people,
    personNames: story.personNames,
    authorDisplayName: story.authorDisplayName,
    authorAvatarPath: story.authorAvatarPath,
    commentCount: story.commentCount,
    perspectiveCount: story.perspectiveCount,
    photoPaths: story.photoPaths,
    placeAddress: story.placeAddress,
    personUserIds: story.personUserIds,
  );
}
