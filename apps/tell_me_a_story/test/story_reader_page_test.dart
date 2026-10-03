import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/data/comments_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart'
    hide displayNameOrMember;
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/perspectives/add_perspective_page.dart';
import 'package:tell_me_a_story/features/places/place_picker_modal.dart';
import 'package:tell_me_a_story/features/stories/photo_strip.dart';
import 'package:tell_me_a_story/features/stories/story_reader_page.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';
const _storyId = 's1';

const _ada = Person(
  id: 'p1',
  familyId: _familyId,
  name: 'Ada',
  relationship: 'Aunt',
  createdBy: 'u1',
);

const _bob = Person(
  id: 'p2',
  familyId: _familyId,
  name: 'Bob',
  relationship: 'Uncle',
  createdBy: 'u1',
);

final _park = Place(
  id: 'pl1',
  familyId: _familyId,
  label: 'Central Park',
  address: 'New York, NY',
  lat: 40.78,
  lng: -73.96,
  isFavorite: true,
);

Story _published({
  String id = _storyId,
  String? title,
  String? body = 'Picnic at the lake\nWe brought pie.',
  DateTime? timeframeStart,
  DateTime? timeframeEnd,
  List<String> personIds = const ['p1'],
  String? placeId = 'pl1',
  StoryStatus status = StoryStatus.published,
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
    status: status,
    personIds: personIds,
    publishedAt: DateTime(2026, 9, 27),
  );
}

class _FakeStoriesApi implements StoriesGateway {
  _FakeStoriesApi({this.story, this.throwOnGet = false, this.getDelay});

  Story? story;
  var throwOnGet = false;
  Future<void>? getDelay;

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
    if (getDelay != null) await getDelay;
    if (throwOnGet) throw StateError('missing $storyId');
    final existing = story;
    if (existing == null || existing.id != storyId) {
      throw StateError('missing $storyId');
    }
    return existing;
  }

  @override
  Future<Story?> getPublished(String storyId) async {
    if (getDelay != null) await getDelay;
    if (throwOnGet) throw StateError('network $storyId');
    final existing = story;
    if (existing == null || existing.id != storyId) return null;
    if (existing.status != StoryStatus.published) return null;
    return existing;
  }

  @override
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async => const [];

  @override
  Future<void> discard(String storyId) async {}
}

class _FakePeopleApi implements PeopleGateway {
  _FakePeopleApi({List<Person>? seed}) : rows = [...?seed];

  final List<Person> rows;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    return rows.where((p) => p.familyId == familyId).toList();
  }

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

class _FakePlacesApi implements PlacesGateway {
  _FakePlacesApi({List<Place>? seed}) : rows = [...?seed];

  final List<Place> rows;

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
  Future<Place?> getPlace(String id) async {
    for (final p in rows) {
      if (p.id == id) return p;
    }
    return null;
  }
}

final _tinyJpeg = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

class _FakePicker {
  _FakePicker({Uint8List? bytes}) : bytes = bytes ?? _tinyJpeg;

  final Uint8List bytes;
  var calls = 0;

  Future<Uint8List?> call() async {
    calls++;
    return bytes;
  }
}

class _FakePhotosApi implements PhotosGateway {
  _FakePhotosApi({
    List<Photo>? seed,
    this.failUpload = false,
    this.failDecode = false,
  }) : rows = [...?seed];

  final List<Photo> rows;
  var failUpload = false;
  var failDecode = false;
  var uploadCalls = 0;
  String? lastFamilyId;
  String? lastStoryId;
  int? lastSortOrder;
  final List<Photo> deleted = [];

  @override
  Future<List<Photo>> listPhotos(String storyId) async {
    return rows.where((p) => p.storyId == storyId).toList();
  }

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) async {
    uploadCalls++;
    lastFamilyId = familyId;
    lastStoryId = storyId;
    lastSortOrder = sortOrder;
    if (failDecode) {
      throw ArgumentError.value(bytes, 'bytes', 'not a decodable image');
    }
    if (failUpload) {
      throw const StorageFailedException();
    }
    final photo = Photo(
      id: 'ph$uploadCalls',
      storyId: storyId,
      familyId: familyId,
      uploaderId: 'u-member',
      storagePath: '$familyId/$storyId/ph$uploadCalls.jpg',
      sortOrder: sortOrder,
    );
    rows.add(photo);
    return photo;
  }

  @override
  Future<void> deletePhoto(Photo photo) async {
    deleted.add(photo);
    rows.removeWhere((p) => p.id == photo.id);
  }

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async => Uint8List(0);
}

class _FakeCommentsApi implements CommentsGateway {
  _FakeCommentsApi({
    List<Comment>? seed,
    this.throwOnList = false,
    this.throwOnCreate = false,
    this.throwOnDelete = false,
    this.authorId = 'u1',
  }) : rows = [...?seed];

  final List<Comment> rows;
  final bool throwOnList;
  final bool throwOnCreate;
  final bool throwOnDelete;
  final String authorId;
  var createCalls = 0;
  var deleteCalls = 0;
  var _seq = 0;

  @override
  Future<List<Comment>> listForStory(String storyId) async {
    if (throwOnList) throw StateError('comments failed');
    return rows.where((c) => c.storyId == storyId).toList();
  }

  @override
  Future<Comment> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    createCalls++;
    if (throwOnCreate) throw StateError('create failed');
    ensureValidCommentBody(body);
    final comment = Comment(
      id: 'new${++_seq}',
      storyId: storyId,
      familyId: familyId,
      authorId: authorId,
      body: body.trim(),
      createdAt: DateTime.utc(2026, 9, 27, 12),
      authorDisplayName: 'Me',
    );
    rows.add(comment);
    return comment;
  }

  @override
  Future<void> update({required String id, required String body}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    if (throwOnDelete) throw StateError('delete failed');
    rows.removeWhere((c) => c.id == id);
  }
}

class _FakePerspectivesApi implements PerspectivesGateway {
  _FakePerspectivesApi({List<Perspective>? seed, this.throwOnCreate = false})
    : rows = [...?seed];

  final List<Perspective> rows;
  final bool throwOnCreate;
  var listCalls = 0;
  var createCalls = 0;
  var _seq = 0;

  @override
  Future<List<Perspective>> listForStory(String storyId) async {
    listCalls++;
    return rows.where((p) => p.storyId == storyId).toList();
  }

  @override
  Future<Perspective> create({
    required String storyId,
    required String familyId,
    required String body,
  }) async {
    createCalls++;
    if (throwOnCreate) throw StateError('create failed');
    ensureValidPerspectiveBody(body);
    final row = Perspective(
      id: 'v-new${++_seq}',
      storyId: storyId,
      familyId: familyId,
      authorId: 'u1',
      body: body.trim(),
      createdAt: DateTime.utc(2026, 9, 27, 12),
      authorDisplayName: 'Me',
    );
    rows.add(row);
    return row;
  }

  @override
  Future<void> update({required String id, required String body}) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String id) async {}
}

Widget _defaultStubMap({double? lat, double? lng}) {
  return const SizedBox(key: Key('stub-map'), height: 120);
}

Widget _readerApp({
  required StoriesGateway stories,
  PeopleGateway? people,
  PlacesGateway? places,
  PhotosGateway? photos,
  CommentsGateway? comments,
  PerspectivesGateway? perspectives,
  Future<Uint8List?> Function()? pickImageBytes,
  String storyId = _storyId,
  String? currentUserId,
  bool? hasMapboxToken,
  PlaceMapBuilder? mapBuilder,
}) {
  final perspectivesApi = perspectives ?? _FakePerspectivesApi();
  final router = GoRouter(
    initialLocation: AppRoutes.storyPath(storyId),
    routes: [
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) =>
            const Scaffold(body: Text('timeline-dest')),
      ),
      GoRoute(
        path: AppRoutes.storyPerspective,
        builder: (context, state) {
          final extra = state.extra;
          return AddPerspectivePage(
            storyId: state.pathParameters['storyId']!,
            familyId: extra is String ? extra : _familyId,
            perspectivesApi: perspectivesApi,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.story,
        builder: (context, state) => StoryReaderPage(
          storyId: state.pathParameters['storyId']!,
          storiesApi: stories,
          peopleApi: people ?? _FakePeopleApi(),
          placesApi: places ?? _FakePlacesApi(),
          photosApi: photos ?? _FakePhotosApi(),
          commentsApi: comments ?? _FakeCommentsApi(),
          perspectivesApi: perspectivesApi,
          pickImageBytes: pickImageBytes,
          currentUserId: currentUserId,
          hasMapboxToken: hasMapboxToken ?? true,
          mapBuilder: mapBuilder ?? _defaultStubMap,
        ),
      ),
    ],
  );
  return TellMeAStoryApp(router: router);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('storyHeadline uses first non-empty line else Untitled', () {
    expect(
      storyHeadline('Picnic at the lake\nWe brought pie.'),
      'Picnic at the lake',
    );
    expect(storyHeadline('\n  \nThe picnic'), 'The picnic');
    expect(storyHeadline('  Hello  '), 'Hello');
    expect(storyHeadline(null), 'Untitled');
    expect(storyHeadline(''), 'Untitled');
    expect(storyHeadline('   \n  '), 'Untitled');
  });

  test('readerHeadline uses a saved title and keeps the full body', () {
    expect(
      readerHeadline(
        title: 'Making Blackberry Jam on the Back Porch',
        body: 'Picnic at the lake\nWe brought pie.',
      ),
      'Making Blackberry Jam on the Back Porch',
    );
    expect(
      readerArticleBody(
        title: 'Making Blackberry Jam on the Back Porch',
        body: 'Picnic at the lake\nWe brought pie.',
      ),
      'Picnic at the lake\nWe brought pie.',
    );
    expect(
      readerHeadline(title: '   ', body: 'Picnic at the lake\nWe brought pie.'),
      'Picnic at the lake',
    );
    expect(
      readerArticleBody(
        title: '   ',
        body: 'Picnic at the lake\nWe brought pie.',
      ),
      'We brought pie.',
    );
    expect(readerHeadline(title: null, body: null), 'Untitled');
  });

  testWidgets('published story renders body, people, place, sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        people: _FakePeopleApi(seed: const [_ada, _bob]),
        places: _FakePlacesApi(seed: [_park]),
        photos: _FakePhotosApi(
          seed: const [
            Photo(
              id: 'ph1',
              storyId: _storyId,
              familyId: _familyId,
              uploaderId: 'u1',
              storagePath: 'f/s/ph1.jpg',
              sortOrder: 0,
            ),
          ],
        ),
        comments: _FakeCommentsApi(
          seed: [
            Comment(
              id: 'c1',
              storyId: _storyId,
              familyId: _familyId,
              authorId: 'u1',
              body: 'I remember the pie.',
              createdAt: DateTime.utc(2026, 9, 27),
              authorDisplayName: 'Aunt Clara',
            ),
          ],
        ),
        perspectives: _FakePerspectivesApi(
          seed: [
            Perspective(
              id: 'v1',
              storyId: _storyId,
              familyId: _familyId,
              authorId: 'u2',
              body: 'From the porch it looked different.',
              createdAt: DateTime.utc(2026, 9, 26),
              authorDisplayName: 'Uncle Ben',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Timeline'), findsOneWidget);
    expect(find.text('Picnic at the lake'), findsOneWidget);
    expect(find.textContaining('We brought pie.'), findsOneWidget);
    expect(find.text('1980s'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.text('Central Park'), findsOneWidget);
    expect(find.byKey(const Key('stub-map')), findsOneWidget);
    expect(find.byType(PhotoStrip), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
    expect(find.text('Perspectives'), findsOneWidget);
    expect(find.text('+ Add your perspective'), findsOneWidget);
    expect(find.text('From the porch it looked different.'), findsOneWidget);
    expect(find.text('Uncle Ben'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('+ Add comment'), findsOneWidget);
    expect(find.byKey(const Key('comment-composer')), findsNothing);
    expect(find.text('I remember the pie.'), findsOneWidget);
    expect(find.text('Aunt Clara'), findsOneWidget);
    expect(find.text('Not found'), findsNothing);
  });

  testWidgets('+ Add comment reveals the composer', (tester) async {
    await tester.pumpWidget(
      _readerApp(stories: _FakeStoriesApi(story: _published())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comment-composer')), findsNothing);

    await tester.ensureVisible(find.text('+ Add comment'));
    await tester.tap(find.text('+ Add comment'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comment-composer')), findsOneWidget);
    expect(find.text('Share a short memory or note...'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Post'), findsOneWidget);
  });

  testWidgets('draft id shows Not found without body text', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(
          story: _published(
            body: 'DRAFT_SECRET_BODY',
            status: StoryStatus.draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(find.text('Not found'), findsOneWidget);
    expect(find.text('DRAFT_SECRET_BODY'), findsNothing);
    expect(find.textContaining('DRAFT_SECRET_BODY'), findsNothing);
    expect(find.text('Perspectives'), findsNothing);
    expect(find.text('Comments'), findsNothing);
    expect(find.text('Add photos'), findsNothing);
  });

  testWidgets('missing story shows Not found without loading comments', (
    tester,
  ) async {
    await tester.pumpWidget(_readerApp(stories: _FakeStoriesApi()));
    await tester.pumpAndSettle();

    expect(find.text('Not found'), findsOneWidget);
    expect(find.text('Picnic at the lake'), findsNothing);
    expect(find.text('Perspectives'), findsNothing);
  });

  testWidgets('throwing getPublished shows SnackBar, not Not found', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(stories: _FakeStoriesApi(throwOnGet: true)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Not found'), findsNothing);
    expect(find.text('Picnic at the lake'), findsNothing);
    expect(find.text('Perspectives'), findsNothing);
  });

  testWidgets('empty comments and perspectives still show headers and CTAs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(stories: _FakeStoriesApi(story: _published())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perspectives'), findsOneWidget);
    expect(find.text('+ Add your perspective'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('+ Add comment'), findsOneWidget);
  });

  testWidgets('blank author display name falls back to Member', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        comments: _FakeCommentsApi(
          seed: [
            Comment(
              id: 'c1',
              storyId: _storyId,
              familyId: _familyId,
              authorId: 'u1',
              body: 'Unsigned note',
              createdAt: DateTime.utc(2026, 9, 27),
            ),
          ],
        ),
        perspectives: _FakePerspectivesApi(
          seed: [
            Perspective(
              id: 'v1',
              storyId: _storyId,
              familyId: _familyId,
              authorId: 'u2',
              body: 'Unsigned telling',
              createdAt: DateTime.utc(2026, 9, 26),
              authorDisplayName: '   ',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unsigned note'), findsOneWidget);
    expect(find.text('Unsigned telling'), findsOneWidget);
    expect(find.text('Member'), findsNWidgets(2));
  });

  testWidgets('saved title is the headline and the full body stays', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(
          story: _published(
            title: 'Making Blackberry Jam on the Back Porch',
            body: 'Picnic at the lake\nWe brought pie.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Making Blackberry Jam on the Back Porch'),
      findsOneWidget,
    );
    expect(find.textContaining('Picnic at the lake'), findsOneWidget);
    expect(find.textContaining('We brought pie.'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
  });

  testWidgets('empty body headline is Untitled', (tester) async {
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published(body: '   ')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Untitled'), findsOneWidget);
  });

  testWidgets('loading shows a spinner before the published body', (
    tester,
  ) async {
    final delay = Completer<void>();
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published(), getDelay: delay.future),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Picnic at the lake'), findsNothing);

    delay.complete();
    await tester.pumpAndSettle();
    expect(find.text('Picnic at the lake'), findsOneWidget);
  });

  testWidgets('ancillary load error shows SnackBar and keeps the story', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        comments: _FakeCommentsApi(throwOnList: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Picnic at the lake'), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
  });

  testWidgets('Timeline back goes to /timeline', (tester) async {
    await tester.pumpWidget(
      _readerApp(stories: _FakeStoriesApi(story: _published())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Timeline'));
    await tester.pumpAndSettle();

    expect(find.text('timeline-dest'), findsOneWidget);
    expect(find.byKey(const Key('story-reader')), findsNothing);
  });

  testWidgets('+ Add your perspective pushes the overlay route', (
    tester,
  ) async {
    await tester.pumpWidget(
      _readerApp(stories: _FakeStoriesApi(story: _published())),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ Add your perspective'));
    await tester.tap(find.text('+ Add your perspective'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-perspective')), findsOneWidget);
  });

  testWidgets('published perspective is listed after overlay pops', (
    tester,
  ) async {
    final perspectives = _FakePerspectivesApi();
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        perspectives: perspectives,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ Add your perspective'));
    await tester.tap(find.text('+ Add your perspective'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('perspective-body')),
      'From the porch it looked different.',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Publish perspective'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Publish perspective'));
    await tester.pumpAndSettle();

    expect(perspectives.createCalls, 1);
    expect(find.byKey(const Key('add-perspective')), findsNothing);
    expect(find.byKey(const Key('story-reader')), findsOneWidget);
    expect(find.text('From the porch it looked different.'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(perspectives.listCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('Post with text creates a comment and shows the body', (
    tester,
  ) async {
    final comments = _FakeCommentsApi();
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        comments: comments,
        currentUserId: 'u1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ Add comment'));
    await tester.tap(find.text('+ Add comment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  I remember the pie.  ');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Post'));
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(comments.createCalls, 1);
    expect(find.text('I remember the pie.'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.byKey(const Key('comment-composer')), findsNothing);
  });

  testWidgets('empty Post does not create a comment', (tester) async {
    final comments = _FakeCommentsApi();
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        comments: comments,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ Add comment'));
    await tester.tap(find.text('+ Add comment'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Post'));
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(comments.createCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('comment-composer')), findsOneWidget);
    expect(find.text('Comments'), findsOneWidget);
  });

  testWidgets('failed Post shows Try again and does not add a row', (
    tester,
  ) async {
    final comments = _FakeCommentsApi(throwOnCreate: true);
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        comments: comments,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('+ Add comment'));
    await tester.tap(find.text('+ Add comment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Did not save');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Post'));
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(comments.createCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Did not save',
    );
  });

  testWidgets('own comment row can delete; other author has no menu', (
    tester,
  ) async {
    final comments = _FakeCommentsApi(
      seed: [
        Comment(
          id: 'mine',
          storyId: _storyId,
          familyId: _familyId,
          authorId: 'u1',
          body: 'My note',
          createdAt: DateTime.utc(2026, 9, 27),
          authorDisplayName: 'Me',
        ),
        Comment(
          id: 'theirs',
          storyId: _storyId,
          familyId: _familyId,
          authorId: 'u2',
          body: 'Their note',
          createdAt: DateTime.utc(2026, 9, 27),
          authorDisplayName: 'Aunt Clara',
        ),
      ],
    );
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        comments: comments,
        currentUserId: 'u1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('comment-menu-mine')), findsOneWidget);
    expect(find.byKey(const Key('comment-menu-theirs')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('comment-menu-mine')));
    await tester.tap(find.byKey(const Key('comment-menu-mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(comments.deleteCalls, 1);
    expect(find.text('My note'), findsNothing);
    expect(find.text('Their note'), findsOneWidget);
  });

  testWidgets('member Add photos with injected bytes calls uploadPhoto', (
    tester,
  ) async {
    final photos = _FakePhotosApi();
    final picker = _FakePicker(bytes: _tinyJpeg);
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        photos: photos,
        pickImageBytes: picker.call,
        currentUserId: 'u-member',
      ),
    );
    await tester.pumpAndSettle();

    final add = find.widgetWithText(TextButton, 'Add photos');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(photos.uploadCalls, 1);
    expect(photos.lastFamilyId, _familyId);
    expect(photos.lastStoryId, _storyId);
    expect(photos.lastSortOrder, 0);
    expect(find.byKey(const Key('photo-thumb')), findsOneWidget);
  });

  testWidgets('at 20 photos add is disabled or hidden', (tester) async {
    final seed = List<Photo>.generate(
      maxPhotosPerStory,
      (i) => Photo(
        id: 'ph$i',
        storyId: _storyId,
        familyId: _familyId,
        uploaderId: 'u1',
        storagePath: 'f/s/ph$i.jpg',
        sortOrder: i,
      ),
    );
    final photos = _FakePhotosApi(seed: seed);
    final picker = _FakePicker();
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        photos: photos,
        pickImageBytes: picker.call,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('photo-add')), findsNothing);
    expect(find.byKey(const Key('photo-thumb')), findsNWidgets(20));
    final addCta = find.widgetWithText(TextButton, 'Add photos');
    if (addCta.evaluate().isNotEmpty) {
      expect(tester.widget<TextButton>(addCta).onPressed, isNull);
    }
    expect(picker.calls, 0);
    expect(photos.uploadCalls, 0);
  });

  testWidgets('STORAGE_FAILED shows retry; Try again re-uploads', (
    tester,
  ) async {
    final photos = _FakePhotosApi(failUpload: true);
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        photos: photos,
        pickImageBytes: _FakePicker().call,
      ),
    );
    await tester.pumpAndSettle();

    final add = find.widgetWithText(TextButton, 'Add photos');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(photos.uploadCalls, 1);
    expect(
      find.text(
        'Couldn’t upload the photo. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('photo-thumb')), findsNothing);

    photos.failUpload = false;
    final retry = find.text('Try again');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(photos.uploadCalls, 2);
    expect(find.byKey(const Key('photo-thumb')), findsOneWidget);
    expect(
      find.text(
        'Couldn’t upload the photo. Check your connection and try again.',
      ),
      findsNothing,
    );
  });

  testWidgets('photo remove calls deletePhoto', (tester) async {
    final photos = _FakePhotosApi(
      seed: const [
        Photo(
          id: 'ph1',
          storyId: _storyId,
          familyId: _familyId,
          uploaderId: 'u1',
          storagePath: 'f/s/ph1.jpg',
          sortOrder: 0,
        ),
      ],
    );
    await tester.pumpWidget(
      _readerApp(
        stories: _FakeStoriesApi(story: _published()),
        photos: photos,
      ),
    );
    await tester.pumpAndSettle();

    final remove = find.byKey(const Key('photo-remove'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(photos.deleted, isNotEmpty);
    expect(find.byKey(const Key('photo-thumb')), findsNothing);
  });
}
