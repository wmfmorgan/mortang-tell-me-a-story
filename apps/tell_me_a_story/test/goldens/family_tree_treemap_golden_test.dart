@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/tree/family_tree_page.dart';

import '../support/fakes/fake_stories_gateway.dart';
import '../support/tree_fixture.dart';

// The whole-tree page (7.7): the treemap overview, By family. macOS only:
// `just test-goldens`.

const _sizes = <String, Size>{
  'desktop': Size(1280, 800),
  'ipad_mini_portrait': Size(744, 1133),
};

class _Families extends FamiliesGateway {
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
    testWidgets('family tree treemap $sizeName', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: albumTheme(),
          home: FamilyTreePage(
            familyId: TreeFixture.jenkins,
            storiesApi: FakeStoriesGateway(stories: TreeFixture.stories),
            familiesApi: _Families(),
            live: _Live(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(FamilyTreePage),
        matchesGoldenFile('family_tree_treemap_$sizeName.png'),
      );
    });
  }
}
