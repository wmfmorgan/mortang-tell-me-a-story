import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/drafts/drafts_page.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakeInviteApi implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => _familyId;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => _familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

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

class _FakeStoriesApi implements StoriesGateway {
  _FakeStoriesApi({List<Story>? drafts, List<String>? callLog})
    : drafts = [...?drafts],
      callLog = callLog ?? [];

  final List<Story> drafts;
  final List<String> discarded = [];
  final List<String> callLog;

  @override
  Future<Story> createDraft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? title,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? title,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Story> publish(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<Story> getStory(String storyId) async {
    return drafts.firstWhere((s) => s.id == storyId);
  }

  @override
  Future<Story?> getPublished(String storyId) async => null;

  @override
  Future<List<Story>> listMyDrafts(String familyId) async {
    return drafts.where((s) => s.familyId == familyId).toList();
  }

  @override
  Future<List<Story>> listPublished(String familyId) async => const [];

  @override
  Future<void> discard(String storyId) async {
    callLog.add('discard:$storyId');
    discarded.add(storyId);
    drafts.removeWhere((s) => s.id == storyId);
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

class _StubPeopleApi implements PeopleGateway {
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    required String relationship,
    String? email,
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

class _FakePhotosApi implements PhotosGateway {
  _FakePhotosApi({List<String>? callLog}) : callLog = callLog ?? [];

  final List<String> deletedStories = [];
  final List<String> callLog;

  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePhoto(Photo photo) async {}

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {
    callLog.add('photos:$storyId');
    deletedStories.add(storyId);
  }

  @override
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);
}

Widget _drafts({required StoriesGateway stories, PhotosGateway? photos}) {
  return MaterialApp(
    home: DraftsPage(
      inviteApi: _FakeInviteApi(),
      storiesApi: stories,
      photosApi: photos ?? _FakePhotosApi(),
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
              body: 'Jam',
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

    expect(find.text('1980s'), findsWidgets);
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
              body: 'Jam',
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
      inviteApi: _FakeInviteApi(),
      peopleApi: _StubPeopleApi(),
      placesApi: _StubPlacesApi(),
      mapboxSearch: _StubMapboxSearch(),
      storiesApi: _FakeStoriesApi(
        drafts: [_draft(id: 's1', body: 'Jam')],
      ),
      photosApi: _FakePhotosApi(),
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

  testWidgets(
    'Discard calls deleteAllForStory then discard and removes the row',
    (tester) async {
      final log = <String>[];
      final api = _FakeStoriesApi(
        drafts: [_draft(id: 's1')],
        callLog: log,
      );
      final photos = _FakePhotosApi(callLog: log);
      await tester.pumpWidget(_drafts(stories: api, photos: photos));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();

      expect(photos.deletedStories, ['s1']);
      expect(api.discarded, ['s1']);
      expect(log, ['photos:s1', 'discard:s1']);
      expect(find.text('Continue writing'), findsNothing);
      expect(
        find.text(
          'No drafts yet. Stories you’re still writing will show up here.',
        ),
        findsOneWidget,
      );
    },
  );
}
