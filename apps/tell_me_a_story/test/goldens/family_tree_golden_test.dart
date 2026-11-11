@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/core/data/families_repository.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/data/stories_repository.dart';
import 'package:tell_me_a_story/core/session/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_page.dart';

import '../support/fakes/fake_stories_repository.dart';
import '../support/tree_fixture.dart';

// The whole-tree page: the family tree graph (7.8, with a `+3` on Jenkins'
// 1960s) and the treemap overview, By family (7.7). macOS only:
// `just test-goldens`.

const _sizes = <String, Size>{
  'desktop': Size(1280, 800),
  'ipad_mini_portrait': Size(744, 1133),
};

class _Families extends FamiliesRepository {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(
      id: TreeFixture.jenkins,
      name: 'Jenkins',
      createdAt: DateTime.utc(2020),
    ),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async =>
      TreeFixture.tree;
}

class _Live implements TimelineLive {
  @override
  void watch({required String familyId, required void Function() onChange}) {}

  @override
  void watchStory({
    required String storyId,
    required void Function() onChange,
  }) {}

  @override
  void watchTree({
    required String familyId,
    required void Function() onChange,
  }) {}

  @override
  void dispose() {}
}

void main() {
  tearDown(FamilySelection.clear);

  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    Future<void> pumpPage(WidgetTester tester, List<Story> stories) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: albumTheme(),
          builder: albumAppBuilder,
          home: FamilyTreePage(
            familyId: TreeFixture.jenkins,
            storiesApi: FakeStoriesRepository(stories: stories),
            familiesApi: _Families(),
            live: _Live(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('family tree graph $sizeName', (tester) async {
      await pumpPage(tester, TreeFixture.crowded);

      await expectLater(
        find.byType(FamilyTreePage),
        matchesGoldenFile('family_tree_graph_$sizeName.png'),
      );
    });

    testWidgets('family tree treemap $sizeName', (tester) async {
      await pumpPage(tester, TreeFixture.stories);
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(FamilyTreePage),
        matchesGoldenFile('family_tree_treemap_$sizeName.png'),
      );
    });
  }
}
