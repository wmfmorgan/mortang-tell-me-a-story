@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/member_family.dart';
import 'package:tell_me_a_story/core/domain/steward_family.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/tree_family.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/features/timeline/presentation/tree/family_tree_page.dart';

import '../support/fakes/fake_stories_repository.dart';
import '../support/pump_app.dart';
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

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    Future<void> pumpPage(WidgetTester tester, List<Story> stories) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // Not pumpApp: the golden keeps the debug banner off.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...defaultTestOverrides,
            storiesRepositoryProvider.overrideWithValue(
              FakeStoriesRepository(stories: stories),
            ),
            familiesRepositoryProvider.overrideWithValue(_Families()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: albumTheme(),
            builder: albumAppBuilder,
            home: const FamilyTreePage(familyId: TreeFixture.jenkins),
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
