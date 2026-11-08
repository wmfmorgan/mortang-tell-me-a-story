@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

import '../support/fakes/fake_invite_gateway.dart';
import '../support/fakes/fake_stories_gateway.dart';

// The three timeline rails as they look today. Phase 7 splits
// timeline_page.dart against these unchanged (7.3), then restyles them on
// purpose (7.4). macOS only: `just test-goldens`.

const _jenkins = '00000000-0000-0000-0000-000000000001';
const _bea = '00000000-0000-0000-0000-0000000000be';

const _sizes = <String, Size>{
  'desktop': Size(1280, 800),
  'ipad_mini_portrait': Size(744, 1133),
};

const _zooms = <String, String?>{
  'decades': null,
  'years': 'timeline-zoom-mid',
  'days': 'timeline-zoom-full',
};

Story _story(String id, String title, DateTime start, {List<String>? people}) {
  return Story(
    id: id,
    familyId: _jenkins,
    authorId: 'u1',
    title: title,
    body: 'Told at the kitchen table.',
    timeframeStart: start,
    timeframeEnd: start,
    placeId: 'pl',
    placeLabel: 'Harbour Street',
    status: StoryStatus.published,
    personIds: const ['p'],
    personNames: people ?? const ['Ada Jenkins'],
    publishedAt: DateTime.utc(2026, 9, 27),
    createdAt: DateTime.utc(2026, 9, 27),
  );
}

final _published = <Story>[
  _story('s1952', 'The flood year', DateTime(1952, 3, 14)),
  _story('s1961', 'First car', DateTime(1961, 6, 2)),
  _story('s1975', 'Bea moves north', DateTime(1975, 8, 9)),
  _story('s1978', 'Summer at the lake', DateTime(1978, 7, 1)),
  _story('s1984', 'The new kitchen', DateTime(1984, 1, 20)),
  _story('s1999', 'Millennium eve', DateTime(1999, 12, 31)),
];

class _Stories extends FakeStoriesGateway {
  @override
  Future<List<Story>> listPublished(String familyId) async =>
      _published.where((s) => s.familyId == familyId).toList();

  @override
  Future<Story?> getPublished(String storyId) async {
    for (final s in _published) {
      if (s.id == storyId) return s;
    }
    return null;
  }
}

class _Families extends FamiliesGateway {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(id: _jenkins, name: 'Jenkins', createdAt: DateTime.utc(2020)),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async => const [
    TreeFamily(id: _jenkins, name: 'Jenkins'),
    TreeFamily(
      id: _bea,
      name: 'Bea',
      parentFamilyId: _jenkins,
      originStoryId: 's1975',
      branchYear: 1975,
    ),
  ];
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
  void dispose() {}
}

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final MapEntry(key: zoomName, value: zoomKey) in _zooms.entries) {
      testWidgets('timeline $zoomName $sizeName', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: albumTheme(),
            home: TimelinePage(
              api: FakeInviteGateway(familyId: _jenkins),
              storiesApi: _Stories(),
              familiesApi: _Families(),
              live: _Live(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (zoomKey != null) {
          await tester.tap(find.byKey(Key(zoomKey)));
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(TimelinePage),
          matchesGoldenFile('timeline/${zoomName}_$sizeName.png'),
        );
      });
    }
  }
}
