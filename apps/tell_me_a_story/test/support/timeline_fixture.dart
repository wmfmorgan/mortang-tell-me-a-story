import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tell_me_a_story/core/theme/album_forui_theme.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/timeline_live.dart';
import 'package:tell_me_a_story/features/timeline/timeline_page.dart';

import 'fakes/fake_invite_gateway.dart';
import 'fakes/fake_stories_gateway.dart';

// The Jenkins family with a Bea branch from its 1975 story: the golden
// fixture, shared by the rail widget tests and the iPad sweep.

const jenkinsId = '00000000-0000-0000-0000-000000000001';
const beaId = '00000000-0000-0000-0000-0000000000be';

Story fixtureStory(
  String id,
  String title,
  DateTime start, {
  List<({String id, String name})>? people,
  ({String id, String label})? place,
}) {
  return Story(
    id: id,
    familyId: jenkinsId,
    authorId: 'u1',
    title: title,
    body: 'Told at the kitchen table.',
    timeframeStart: start,
    timeframeEnd: start,
    placeId: place?.id ?? 'pl',
    placeLabel: place?.label ?? 'Harbour Street',
    status: StoryStatus.published,
    personIds: people == null ? const ['p'] : [for (final p in people) p.id],
    people: people ?? const [],
    personNames: people == null
        ? const ['Ada Jenkins']
        : [for (final p in people) p.name],
    publishedAt: DateTime.utc(2026, 9, 27),
    createdAt: DateTime.utc(2026, 9, 27),
  );
}

final fixturePublished = <Story>[
  fixtureStory('s1952', 'The flood year', DateTime(1952, 3, 14)),
  fixtureStory('s1961', 'First car', DateTime(1961, 6, 2)),
  fixtureStory('s1975', 'Bea moves north', DateTime(1975, 8, 9)),
  fixtureStory('s1978', 'Summer at the lake', DateTime(1978, 7, 1)),
  fixtureStory('s1984', 'The new kitchen', DateTime(1984, 1, 20)),
  fixtureStory('s1999', 'Millennium eve', DateTime(1999, 12, 31)),
];

/// [fixturePublished] plus two more 1961 stories, so the 1960s decade holds
/// a stacked year of three dots.
final fixtureStacked = <Story>[
  ...fixturePublished,
  fixtureStory('s1961b', 'Summer fair', DateTime(1961, 7, 9)),
  fixtureStory('s1961c', 'Lake trip', DateTime(1961, 8, 20)),
];

const fixtureAda = (id: 'p-ada', name: 'Ada Jenkins');
const fixtureTom = (id: 'p-tom', name: 'Tom Jenkins');
const fixtureBea = (id: 'p-bea', name: 'Bea Jenkins');
const fixtureHarbour = (id: 'pl-harbour', label: 'Harbour Street');
const fixtureMill = (id: 'pl-mill', label: 'Mill Lane');
const fixtureNorthgate = (id: 'pl-north', label: 'Northgate');

/// The same six stories (same ids, dates and titles, so the Bea branch
/// still starts at s1975) with several people and places: the filter
/// fixture (7.5).
final fixtureVaried = <Story>[
  fixtureStory(
    's1952',
    'The flood year',
    DateTime(1952, 3, 14),
    people: const [fixtureAda],
    place: fixtureHarbour,
  ),
  fixtureStory(
    's1961',
    'First car',
    DateTime(1961, 6, 2),
    people: const [fixtureTom],
    place: fixtureMill,
  ),
  fixtureStory(
    's1975',
    'Bea moves north',
    DateTime(1975, 8, 9),
    people: const [fixtureBea, fixtureAda],
    place: fixtureNorthgate,
  ),
  fixtureStory(
    's1978',
    'Summer at the lake',
    DateTime(1978, 7, 1),
    people: const [fixtureTom],
    place: fixtureMill,
  ),
  fixtureStory(
    's1984',
    'The new kitchen',
    DateTime(1984, 1, 20),
    people: const [fixtureAda],
    place: fixtureHarbour,
  ),
  fixtureStory(
    's1999',
    'Millennium eve',
    DateTime(1999, 12, 31),
    people: const [fixtureBea],
    place: fixtureNorthgate,
  ),
];

class FixtureStories extends FakeStoriesGateway {
  FixtureStories(this.published);

  final List<Story> published;

  @override
  Future<List<Story>> listPublished(String familyId) async =>
      published.where((s) => s.familyId == familyId).toList();

  @override
  Future<Story?> getPublished(String storyId) async {
    for (final s in published) {
      if (s.id == storyId) return s;
    }
    return null;
  }
}

class FixtureFamilies extends FamiliesGateway {
  @override
  Future<List<MemberFamily>> listMine() async => [
    MemberFamily(id: jenkinsId, name: 'Jenkins', createdAt: DateTime.utc(2020)),
  ];

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];

  @override
  Future<List<TreeFamily>> listFamilyTree(String familyId) async => const [
    TreeFamily(id: jenkinsId, name: 'Jenkins'),
    TreeFamily(
      id: beaId,
      name: 'Bea',
      parentFamilyId: jenkinsId,
      originStoryId: 's1975',
      branchYear: 1975,
    ),
  ];
}

class FixtureLive implements TimelineLive {
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

TimelinePage fixturePage(List<Story> stories) => TimelinePage(
  api: FakeInviteGateway(familyId: jenkinsId),
  storiesApi: FixtureStories(stories),
  familiesApi: FixtureFamilies(),
  live: FixtureLive(),
);

/// The timeline in a router, so opening a story lands on a page that reads
/// `story <id>`.
Future<void> pumpFixtureTimeline(
  WidgetTester tester, {
  List<Story>? stories,
  String? zoomKey,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => fixturePage(stories ?? fixturePublished),
      ),
      GoRoute(
        path: '/stories/:id',
        builder: (_, state) =>
            Scaffold(body: Text('story ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: albumTheme(),
      builder: albumAppBuilder,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  if (zoomKey != null) {
    await tester.tap(find.byKey(Key(zoomKey)));
    await tester.pumpAndSettle();
  }
}
