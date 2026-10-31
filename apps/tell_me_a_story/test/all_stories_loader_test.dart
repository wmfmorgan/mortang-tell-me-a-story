import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/all_stories/all_stories_loader.dart';

void main() {
  test('L-01 a root origin already in the list skips A3', () async {
    final origin = _story('origin');
    final stories = _Stories(published: [origin, _story('other')]);
    final families = _Families([_tree('F', name: 'Morgans', origin: 'origin')]);
    final data = await AllStoriesLoader(
      stories: stories,
      families: families,
    ).load('F');

    expect(stories.calls, ['listPublished']);
    expect(families.calls, ['listFamilyTree']);
    expect(data.stories.map((story) => story.id), ['origin', 'other']);
  });

  test('L-02 a child origin is appended once', () async {
    final stories = _Stories(
      published: [_story('own')],
      origin: _story('origin', familyId: 'parent'),
    );
    final families = _Families([
      _tree('parent', name: 'Hart'),
      _tree('F', name: 'Morgans', parent: 'parent', origin: 'origin'),
    ]);
    final data = await AllStoriesLoader(
      stories: stories,
      families: families,
    ).load('F');

    expect(stories.originIds, ['origin']);
    expect(data.stories.map((story) => story.id), ['own', 'origin']);
  });

  test('L-03 listPublished throws', () async {
    final stories = _Stories(publishedError: StateError('a1'));
    final families = _Families([_tree('F', name: 'Morgans')]);
    expect(
      () => AllStoriesLoader(stories: stories, families: families).load('F'),
      throwsStateError,
    );
  });

  test('L-04 listFamilyTree throws', () async {
    final stories = _Stories(published: [_story('own')]);
    final families = _Families([], error: StateError('a2'));
    expect(
      () => AllStoriesLoader(stories: stories, families: families).load('F'),
      throwsStateError,
    );
  });

  test(
    'L-05 a missing origin is omitted and a thrown origin fails the load',
    () async {
      final missing = _Stories(published: [_story('own')]);
      final families = _Families([_tree('F', name: 'Morgans', origin: 'gone')]);
      final omitted = await AllStoriesLoader(
        stories: missing,
        families: families,
      ).load('F');
      expect(omitted.stories.map((story) => story.id), ['own']);

      final broken = _Stories(
        published: [_story('own')],
        originError: StateError('a3'),
      );
      expect(
        () => AllStoriesLoader(stories: broken, families: families).load('F'),
        throwsStateError,
      );
    },
  );

  test('L-06 the loader calls only the three reads', () async {
    final stories = _Stories(
      published: [_story('own')],
      origin: _story('origin', familyId: 'parent'),
    );
    final families = _Families([
      _tree('parent', name: 'Hart'),
      _tree('F', name: 'Morgans', parent: 'parent', origin: 'origin'),
    ]);
    await AllStoriesLoader(stories: stories, families: families).load('F');
    expect(stories.calls, ['listPublished', 'getPublishedOrigin']);
    expect(families.calls, ['listFamilyTree']);
  });
}

Story _story(String id, {String familyId = 'F'}) {
  return Story(
    id: id,
    familyId: familyId,
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime(2000),
  );
}

TreeFamily _tree(
  String id, {
  required String name,
  String? parent,
  String? origin,
}) {
  return TreeFamily(
    id: id,
    name: name,
    parentFamilyId: parent,
    originStoryId: origin,
  );
}

class _Stories implements StoriesGateway {
  _Stories({
    this.published = const [],
    this.origin,
    this.publishedError,
    this.originError,
  });

  final List<Story> published;
  final Story? origin;
  final Object? publishedError;
  final Object? originError;
  final calls = <String>[];
  final originIds = <String>[];

  @override
  Future<List<Story>> listPublished(String familyId) async {
    calls.add('listPublished');
    if (publishedError != null) throw publishedError!;
    return published;
  }

  @override
  Future<Story?> getPublishedOrigin(String storyId) async {
    calls.add('getPublishedOrigin');
    originIds.add(storyId);
    if (originError != null) throw originError!;
    return origin;
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
  }) => Future<Story>.error(UnimplementedError());

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
  }) => Future<Story>.error(UnimplementedError());

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
  }) => Future<bool>.error(UnimplementedError());

  @override
  Future<Story> publish(String storyId) =>
      Future<Story>.error(UnimplementedError());

  @override
  Future<Story> getStory(String storyId) =>
      Future<Story>.error(UnimplementedError());

  @override
  Future<Story?> getPublished(String storyId) =>
      Future<Story?>.error(UnimplementedError());

  @override
  Future<List<Story>> listMyDrafts(String familyId) =>
      Future<List<Story>>.error(UnimplementedError());

  @override
  Future<List<Story>> listLatestPublished(
    String familyId, {
    int withinDays = 7,
    int limit = 3,
    DateTime? now,
  }) => Future<List<Story>>.error(UnimplementedError());

  @override
  Future<void> discard(String storyId) =>
      Future<void>.error(UnimplementedError());

  @override
  Future<void> linkPerson({
    required String storyId,
    required String personId,
  }) => Future<void>.error(UnimplementedError());
}

class _Families extends FamiliesGateway {
  _Families(this.tree, {this.error});

  final List<TreeFamily> tree;
  final Object? error;
  final calls = <String>[];

  @override
  Future<List<MemberFamily>> listMine() async => const [];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    calls.add('listFamilyTree');
    if (error != null) throw error!;
    return tree;
  }
}
