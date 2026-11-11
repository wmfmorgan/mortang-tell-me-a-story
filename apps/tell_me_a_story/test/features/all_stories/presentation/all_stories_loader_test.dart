import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_logic.dart';
import 'package:tell_me_a_story/features/all_stories/presentation/all_stories_loader.dart';

import '../../../support/fakes/fake_stories_repository.dart';

void main() {
  test('L-01 a root origin already in the list skips A3', () async {
    final origin = _story('origin');
    final stories = _Stories(published: [origin, _story('other')]);
    final families = _Families([_tree('F', name: 'Morgans', origin: 'origin')]);
    final data = await _load(stories, families);

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
    final data = await _load(stories, families);

    expect(stories.originIds, ['origin']);
    expect(data.stories.map((story) => story.id), ['own', 'origin']);
  });

  test('L-03 listPublished throws', () async {
    final stories = _Stories(publishedError: StateError('a1'));
    final families = _Families([_tree('F', name: 'Morgans')]);
    await expectLater(() => _load(stories, families), throwsStateError);
  });

  test('L-04 listFamilyTree throws', () async {
    final stories = _Stories(published: [_story('own')]);
    final families = _Families([], error: StateError('a2'));
    await expectLater(() => _load(stories, families), throwsStateError);
  });

  test(
    'L-05 a missing origin is omitted and a thrown origin fails the load',
    () async {
      final missing = _Stories(published: [_story('own')]);
      final families = _Families([_tree('F', name: 'Morgans', origin: 'gone')]);
      final omitted = await _load(missing, families);
      expect(omitted.stories.map((story) => story.id), ['own']);

      final broken = _Stories(
        published: [_story('own')],
        originError: StateError('a3'),
      );
      await expectLater(() => _load(broken, families), throwsStateError);
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
    await _load(stories, families);
    expect(stories.calls, ['listPublished', 'getPublishedOrigin']);
    expect(families.calls, ['listFamilyTree']);
  });
}

/// A1–A3 through [allStoriesDataProvider] with [stories] and [families].
Future<AllStoriesData> _load(
  FakeStoriesRepository stories,
  FamiliesRepository families,
) {
  final container = ProviderContainer(
    overrides: [
      storiesRepositoryProvider.overrideWithValue(stories),
      familiesRepositoryProvider.overrideWithValue(families),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(allStoriesDataProvider('F'), (_, _) {});
  addTearDown(subscription.close);
  return container.read(allStoriesDataProvider('F').future);
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

class _Stories extends FakeStoriesRepository {
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
}

class _Families extends FamiliesRepository {
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
