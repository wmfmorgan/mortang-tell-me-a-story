import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/features/timeline/tree/tree_timeline_loader.dart';

import '../../../support/fakes/fake_stories_gateway.dart';
import '../../../support/tree_fixture.dart';

class _Tree extends FamiliesGateway {
  final asked = <String>[];

  @override
  Future<List<MemberFamily>> listMine() async => const [];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async {
    asked.add(familyId);
    return TreeFixture.tree;
  }
}

void main() {
  test('reads the tree and its published stories for the family', () async {
    final stories = FakeStoriesGateway(stories: TreeFixture.stories);
    final families = _Tree();
    final data = await TreeTimelineLoader(
      stories: stories,
      families: families,
    ).load(TreeFixture.bea);

    expect(families.asked, [TreeFixture.bea]);
    expect(stories.calls, ['listPublishedInTree']);
    expect(data.tree, TreeFixture.tree);
    expect(data.stories.map((s) => s.id), TreeFixture.stories.map((s) => s.id));
  });

  test('a failing read rethrows the gateway error itself', () async {
    const refused = AppException(
      code: AppErrorCode.forbidden,
      message: 'member only',
    );
    final stories = FakeStoriesGateway()..error = refused;
    await expectLater(
      TreeTimelineLoader(
        stories: stories,
        families: _Tree(),
      ).load(TreeFixture.jenkins),
      throwsA(same(refused)),
    );
  });
}
