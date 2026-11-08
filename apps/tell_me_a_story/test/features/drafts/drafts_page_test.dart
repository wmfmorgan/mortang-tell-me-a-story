import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/app/app.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/app/app_router.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/data/auth_refresh.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/drafts/drafts_page.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';

import '../../support/fakes/fake_invite_gateway.dart';
import '../../support/fakes/fake_photos_gateway.dart';
import '../../support/fakes/fake_stories_gateway.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

Story _draft({
  String id = 's1',
  String? title,
  String? body,
  List<String> personIds = const [],
  String? placeId,
  int photoCount = 0,
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
}) {
  return Story(
    id: id,
    familyId: _familyId,
    authorId: 'u1',
    title: title,
    body: body,
    timeframeStart: timeframeStart ?? DateTime(1980, 1, 1),
    timeframeEnd: timeframeEnd ?? DateTime(1989, 12, 31),
    placeId: placeId,
    status: StoryStatus.draft,
    personIds: personIds,
    photoCount: photoCount,
  );
}

class _FakeStoriesApi extends FakeStoriesGateway {
  _FakeStoriesApi({List<Story>? drafts})
    : super(stories: drafts ?? const [], userId: 'u1');

  var failDiscard = false;
  final familyLoads = <String>[];

  @override
  Future<List<Story>> listMyDrafts(String familyId) async {
    familyLoads.add(familyId);
    return (await super.listMyDrafts(familyId))..sort(compareStories);
  }

  @override
  Future<void> discard(String storyId) async {
    if (failDiscard) throw Exception('storage');
    await super.discard(storyId);
  }
}

class _ThrowingListStoriesApi extends _FakeStoriesApi {
  @override
  Future<List<Story>> listMyDrafts(String familyId) async {
    throw StateError('network');
  }
}

class _SlowStoriesApi extends _FakeStoriesApi {
  _SlowStoriesApi() {
    _pending = Completer<List<Story>>();
  }

  late final Completer<List<Story>> _pending;

  @override
  Future<List<Story>> listMyDrafts(String familyId) => _pending.future;
}

class _StubPeopleApi extends PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) {
    throw UnimplementedError();
  }
}

class _StubPlacesApi implements PlacesGateway {
  @override
  Future<List<Place>> listFavorites(String familyId) async => const [];

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      const [];

  @override
  Future<List<Place>> listPlaces(String familyId) async => const [];

  @override
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Place> markUsed(String placeId) {
    throw UnimplementedError();
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async => null;
}

class _StubMapboxSearch implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}

Widget _drafts({required StoriesGateway stories, FamiliesGateway? families}) {
  return MaterialApp(
    home: DraftsPage(
      inviteApi: FakeInviteGateway(
        familyId: _familyId,
        createdFamilyId: _familyId,
        acceptedFamilyId: 'f',
      ),
      storiesApi: stories,
      familiesApi: families,
    ),
  );
}

void main() {
  testWidgets('empty drafts copy', (tester) async {
    await tester.pumpWidget(_drafts(stories: _FakeStoriesApi(drafts: [])));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No drafts yet. Stories you’re still writing will show up here.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('header-avatar')), findsOneWidget);
  });

  testWidgets('list load failure is not empty copy', (tester) async {
    await tester.pumpWidget(_drafts(stories: _ThrowingListStoriesApi()));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load drafts. Try again.'), findsOneWidget);
    expect(
      find.text(
        'No drafts yet. Stories you’re still writing will show up here.',
      ),
      findsNothing,
    );
  });

  testWidgets('loading copy', (tester) async {
    await tester.pumpWidget(_drafts(stories: _SlowStoriesApi()));
    await tester.pump();
    expect(find.text('Loading drafts…'), findsOneWidget);
  });

  testWidgets('missing-field chips and Ready to publish', (tester) async {
    await tester.pumpWidget(
      _drafts(
        stories: _FakeStoriesApi(
          drafts: [
            _draft(body: null, personIds: [], placeId: null),
            _draft(
              id: 's2',
              title: 'Jam',
              body: 'We made jam on the porch.',
              personIds: const ['p'],
              placeId: 'pl',
              photoCount: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Missing text'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Missing people'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Missing place'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Missing photos'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Ready to publish'), findsOneWidget);

    expect(find.text('January 1, 1980'), findsWidgets);
    expect(find.text('Untitled'), findsOneWidget);
    expect(find.text('Jam'), findsOneWidget);
    expect(find.text('Missing text'), findsWidgets);
    expect(find.text('Missing people'), findsWidgets);
    expect(find.text('Missing place'), findsWidgets);
    expect(find.text('Ready to publish'), findsWidgets);
  });

  testWidgets('filter chips hide non-matching rows', (tester) async {
    await tester.pumpWidget(
      _drafts(
        stories: _FakeStoriesApi(
          drafts: [
            _draft(id: 's1', body: null, personIds: [], placeId: null),
            _draft(
              id: 's2',
              title: 'Jam',
              body: 'We made jam on the porch.',
              personIds: const ['p'],
              placeId: 'pl',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Ready to publish'));
    await tester.pumpAndSettle();

    expect(find.text('Jam'), findsOneWidget);
    expect(find.text('Untitled'), findsNothing);
    expect(find.text('Continue writing'), findsOneWidget);
  });

  testWidgets('draft card prefers a saved title', (tester) async {
    await tester.pumpWidget(
      _drafts(
        stories: _FakeStoriesApi(
          drafts: [
            _draft(
              id: 's3',
              title: 'Making Blackberry Jam on the Back Porch',
              body: 'We spent the afternoon.',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Making Blackberry Jam on the Back Porch'),
      findsOneWidget,
    );
    expect(find.text('We spent the afternoon.'), findsNothing);
  });

  testWidgets('Continue writing goes to /stories/new?draft=id', (tester) async {
    final auth = AuthRefresh(initiallySignedIn: true);
    addTearDown(auth.dispose);
    final router = createAppRouter(
      authRefresh: auth,
      inviteApi: FakeInviteGateway(
        familyId: _familyId,
        createdFamilyId: _familyId,
        acceptedFamilyId: 'f',
      ),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
      storiesApi: _FakeStoriesApi(
        drafts: [_draft(id: 's1', body: 'Jam')],
      ),
      photosApi: FakePhotosGateway(),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(TellMeAStoryApp(router: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.drafts);
    await tester.pumpAndSettle();

    final continueWriting = find.widgetWithText(
      FilledButton,
      'Continue writing',
    );
    expect(continueWriting, findsOneWidget);
    tester.widget<FilledButton>(continueWriting).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NewStoryPage), findsOneWidget);
    expect(
      tester.widget<NewStoryPage>(find.byType(NewStoryPage)).draftId,
      's1',
    );
    final locations = router.routerDelegate.currentConfiguration.matches
        .map((m) => m.matchedLocation)
        .toList();
    expect(locations, contains(AppRoutes.newStory));
  });

  testWidgets('Discard calls discard and removes the row', (tester) async {
    final api = _FakeStoriesApi(drafts: [_draft(id: 's1')]);
    await tester.pumpWidget(_drafts(stories: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();

    expect(api.discarded, ['s1']);
    expect(find.text('Continue writing'), findsNothing);
    expect(
      find.text(
        'No drafts yet. Stories you’re still writing will show up here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed discard keeps the draft row', (tester) async {
    final api = _FakeStoriesApi(drafts: [_draft(id: 's1')])..failDiscard = true;
    await tester.pumpWidget(_drafts(stories: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();

    expect(api.discarded, isEmpty);
    expect(find.text('Continue writing'), findsOneWidget);
    expect(find.text('Couldn’t discard draft. Try again.'), findsOneWidget);
  });

  testWidgets('drafts bar keeps Drafts and switches the family list', (
    tester,
  ) async {
    addTearDown(FamilySelection.clear);
    const otherId = '00000000-0000-0000-0000-000000000002';
    final stories = _FakeStoriesApi(drafts: [_draft()]);
    await tester.pumpWidget(
      _drafts(
        stories: stories,
        families: _FakeFamilies([
          MemberFamily(
            id: _familyId,
            name: 'Ada',
            createdAt: DateTime.utc(2020),
          ),
          MemberFamily(id: otherId, name: 'Bea', createdAt: DateTime.utc(2021)),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Draft Stories'), findsOneWidget);
    expect(find.byKey(const Key('header-underline-drafts')), findsOneWidget);
    expect(find.byKey(const Key('timeline-search')), findsOneWidget);
    expect(find.byKey(const Key('header-invite')), findsNothing);
    expect(find.text('New story'), findsOneWidget);
    await tester.tap(find.byKey(const Key('family-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('family-menu-invite')), findsOneWidget);
    expect(find.byKey(const Key('family-menu-start-timeline')), findsOneWidget);
    expect(stories.familyLoads, [_familyId]);

    await tester.tap(find.text('Bea').last);
    await tester.pumpAndSettle();

    expect(stories.familyLoads.last, otherId);
    expect(find.text('Draft Stories'), findsOneWidget);
  });

  testWidgets('a null date renders as No date yet and sorts last', (
    tester,
  ) async {
    final undated = Story(
      id: 'undated',
      familyId: _familyId,
      authorId: 'u1',
      title: 'Undated',
      status: StoryStatus.draft,
      createdAt: DateTime.utc(2020),
    );
    final dated = Story(
      id: 'dated',
      familyId: _familyId,
      authorId: 'u1',
      title: 'Dated',
      timeframeStart: DateTime(1980),
      timeframeEnd: DateTime(1980),
      status: StoryStatus.draft,
      createdAt: DateTime.utc(2020, 6),
    );
    await tester.pumpWidget(
      _drafts(stories: _FakeStoriesApi(drafts: [undated, dated])),
    );
    await tester.pumpAndSettle();

    expect(find.text('No date yet'), findsOneWidget);
    final datedAt = tester.getTopLeft(find.byKey(const Key('draft-row-dated')));
    final undatedAt = tester.getTopLeft(
      find.byKey(const Key('draft-row-undated')),
    );
    final datedFirst =
        datedAt.dy < undatedAt.dy ||
        (datedAt.dy == undatedAt.dy && datedAt.dx < undatedAt.dx);
    expect(datedFirst, isTrue);
    expect(
      tester.widget<Text>(find.text('No date yet')).style?.color,
      albumInk.withValues(alpha: 0.55),
    );
  });
}

class _FakeFamilies extends FamiliesGateway {
  _FakeFamilies(this.rows);

  final List<MemberFamily> rows;

  @override
  Future<List<MemberFamily>> listMine() async => rows;

  @override
  Future<List<StewardFamily>> listStewarded() async => const [];
}
