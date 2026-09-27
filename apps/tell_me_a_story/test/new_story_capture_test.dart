import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/mapbox_search.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/places/place_picker_modal.dart';
import 'package:tell_me_a_story/features/stories/new_story_page.dart';
import 'package:tell_me_a_story/features/stories/photo_strip.dart';
import 'package:tell_me_a_story/features/stories/timeframe_chips.dart';

const _familyId = '00000000-0000-0000-0000-000000000001';

class _FakeInviteApi implements InviteGateway {
  _FakeInviteApi({this.familyId = _familyId});

  final String? familyId;

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
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
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
  }) async {
    throw UnimplementedError();
  }
}

class _FakePlacesApi implements PlacesGateway {
  _FakePlacesApi({List<Place>? seed}) : rows = [...?seed];

  final List<Place> rows;

  @override
  Future<List<Place>> listFavorites(String familyId) async {
    return rows.where((p) => p.familyId == familyId && p.isFavorite).toList();
  }

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async {
    return rows
        .where((p) => p.familyId == familyId && p.lastUsedAt != null)
        .take(limit)
        .toList();
  }

  @override
  Future<Place> createPlace({
    required String familyId,
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? mapboxPlaceId,
    bool isFavorite = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Place> markUsed(String placeId) async {
    return rows.firstWhere((p) => p.id == placeId);
  }

  @override
  Future<Place> setFavorite({
    required String placeId,
    required bool isFavorite,
  }) async {
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

class _FakeMapboxSearch implements MapboxSearchGateway {
  @override
  Future<List<MapboxSearchHit>> search(String query, {int limit = 5}) async =>
      const [];
}

class _FakeStoriesApi implements StoriesGateway {
  _FakeStoriesApi({this.story, this.throwOnCreate = false});

  Story? story;
  var throwOnCreate = false;
  var createDraftCalls = 0;
  var updateDraftCalls = 0;
  var publishCalls = 0;
  String? lastUpdatedStoryId;
  DateTime? lastTimeframeStart;
  DateTime? lastTimeframeEnd;
  String? lastBody;
  String? lastPlaceId;
  List<String> lastPersonIds = const [];

  Story _draft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String> personIds = const [],
    String id = 's1',
  }) {
    return Story(
      id: id,
      familyId: familyId,
      authorId: 'u1',
      body: body,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      placeId: placeId,
      status: StoryStatus.draft,
      personIds: personIds,
    );
  }

  @override
  Future<Story> createDraft({
    required String familyId,
    required DateTime timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String> personIds = const [],
  }) async {
    if (throwOnCreate) {
      throw StateError('save failed');
    }
    createDraftCalls++;
    lastTimeframeStart = timeframeStart;
    lastTimeframeEnd = timeframeEnd;
    lastBody = body;
    lastPlaceId = placeId;
    lastPersonIds = personIds;
    story = _draft(
      familyId: familyId,
      timeframeStart: timeframeStart,
      timeframeEnd: timeframeEnd,
      body: body,
      placeId: placeId,
      personIds: personIds,
    );
    return story!;
  }

  @override
  Future<Story> updateDraft({
    required String storyId,
    DateTime? timeframeStart,
    DateTime? timeframeEnd,
    String? body,
    String? placeId,
    List<String>? personIds,
  }) async {
    updateDraftCalls++;
    lastUpdatedStoryId = storyId;
    lastTimeframeStart = timeframeStart ?? lastTimeframeStart;
    lastTimeframeEnd = timeframeEnd ?? lastTimeframeEnd;
    lastBody = body ?? lastBody;
    lastPlaceId = placeId ?? lastPlaceId;
    lastPersonIds = personIds ?? lastPersonIds;
    story = _draft(
      id: storyId,
      familyId: story?.familyId ?? _familyId,
      timeframeStart: lastTimeframeStart ?? DateTime(1980, 1, 1),
      timeframeEnd: lastTimeframeEnd,
      body: lastBody,
      placeId: lastPlaceId,
      personIds: lastPersonIds,
    );
    return story!;
  }

  @override
  Future<Story> publish(String storyId) async {
    publishCalls++;
    return story ?? await getStory(storyId);
  }

  @override
  Future<Story> getStory(String storyId) async {
    final existing = story;
    if (existing == null || existing.id != storyId) {
      throw StateError('missing $storyId');
    }
    return existing;
  }

  @override
  Future<List<Story>> listMyDrafts(String familyId) async => const [];

  @override
  Future<List<Story>> listPublished(String familyId) async => const [];

  @override
  Future<void> discard(String storyId) async {}
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
    this.failUpload = false,
    this.failDecode = false,
    List<Photo>? seed,
  }) : rows = [...?seed];

  var failUpload = false;
  var failDecode = false;
  var uploadCalls = 0;
  final List<Photo> rows;
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
      uploaderId: 'u1',
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

const _ada = Person(
  id: 'p1',
  familyId: _familyId,
  name: 'Ada',
  relationship: 'Aunt',
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

Widget _captureShell({
  StoriesGateway? stories,
  PeopleGateway? people,
  PlacesGateway? places,
  PhotosGateway? photos,
  Future<Uint8List?> Function()? picker,
  String? draftId,
}) {
  return MaterialApp(
    home: NewStoryPage(
      inviteApi: _FakeInviteApi(),
      peopleApi: people ?? _FakePeopleApi(seed: const [_ada]),
      placesApi: places ?? _FakePlacesApi(seed: [_park]),
      mapboxSearch: _FakeMapboxSearch(),
      storiesApi: stories ?? _FakeStoriesApi(),
      photosApi: photos ?? _FakePhotosApi(),
      pickImageBytes: picker ?? (() async => null),
      hasMapboxToken: true,
      mapBuilder: _defaultStubMap,
      draftId: draftId,
    ),
  );
}

Widget _defaultStubMap({double? lat, double? lng}) {
  return const SizedBox(key: Key('stub-map'), height: 120);
}

Future<void> _tapAddPhoto(WidgetTester tester) async {
  final add = find.byKey(const Key('photo-add'));
  await tester.ensureVisible(add);
  await tester.pumpAndSettle();
  await tester.tap(add);
}

bool _hasTerracottaBorder(Widget widget) {
  if (widget is! Container) return false;
  final decoration = widget.decoration;
  if (decoration is! BoxDecoration) return false;
  final border = decoration.border;
  if (border is! Border) return false;
  return border.top.color == const Color(0xFF8B5E4B);
}

void main() {
  test('1980s decade maps to 1980-01-01..1989-12-31', () {
    const decade = DecadeRange(1980);
    expect(decade.label, '1980s');
    expect(decade.start, DateTime(1980, 1, 1));
    expect(decade.end, DateTime(1989, 12, 31));
  });

  test('decadeChips span 1900s through 2020s', () {
    expect(decadeChips.map((d) => d.startYear).toList(), [
      1900,
      1910,
      1920,
      1930,
      1940,
      1950,
      1960,
      1970,
      1980,
      1990,
      2000,
      2010,
      2020,
    ]);
  });

  testWidgets('shows Save draft and Publish', (tester) async {
    await tester.pumpWidget(_captureShell());
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Publish story'), findsOneWidget);
    expect(find.text('Capture fields arrive in M4.'), findsNothing);
  });

  testWidgets('Save draft disabled until a decade is selected', (tester) async {
    await tester.pumpWidget(_captureShell());
    await tester.pumpAndSettle();
    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save draft'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('blocked Publish shows banner and stays on form', (tester) async {
    await tester.pumpWidget(_captureShell());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pumpAndSettle();
    expect(
      find.text('Finish the highlighted fields to publish.'),
      findsOneWidget,
    );
    expect(find.text('New story'), findsOneWidget);
  });

  testWidgets('Save draft with timeframe calls createDraft', (tester) async {
    final stories = _FakeStoriesApi();
    await tester.pumpWidget(_captureShell(stories: stories));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();
    expect(stories.createDraftCalls, 1);
    expect(stories.lastTimeframeStart, DateTime(1980, 1, 1));
    expect(stories.lastTimeframeEnd, DateTime(1989, 12, 31));
    expect(find.text('Draft saved'), findsOneWidget);
  });

  testWidgets('shows decade chips from 1900s to 2020s', (tester) async {
    await tester.pumpWidget(_captureShell());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '1900s'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '1980s'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '2020s'), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('blocked Publish paints terracotta on missing sections', (
    tester,
  ) async {
    await tester.pumpWidget(_captureShell());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish story'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .any(_hasTerracottaBorder),
      isTrue,
    );
  });

  testWidgets('complete form shows Ready to publish', (tester) async {
    await tester.pumpWidget(_captureShell());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add person'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ada'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Choose place'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Central Park'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'We made jam.');
    await tester.pumpAndSettle();

    expect(find.text('Ready to publish'), findsOneWidget);
  });

  testWidgets('second Save draft updates the existing row', (tester) async {
    final stories = _FakeStoriesApi();
    await tester.pumpWidget(_captureShell(stories: stories));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Second pass');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();

    expect(stories.createDraftCalls, 1);
    expect(stories.updateDraftCalls, 1);
    expect(stories.lastBody, 'Second pass');
  });

  testWidgets('hydrates draft id into capture fields', (tester) async {
    final stories = _FakeStoriesApi(
      story: Story(
        id: 'draft-1',
        familyId: _familyId,
        authorId: 'u1',
        body: 'Jam at the park',
        timeframeStart: DateTime(1980, 1, 1),
        timeframeEnd: DateTime(1989, 12, 31),
        placeId: 'pl1',
        status: StoryStatus.draft,
        personIds: const ['p1'],
      ),
    );

    await tester.pumpWidget(
      _captureShell(stories: stories, draftId: 'draft-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jam at the park'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Ada'), findsOneWidget);
    expect(find.text('Central Park'), findsOneWidget);
    expect(find.text('Ready to publish'), findsOneWidget);

    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save draft'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('hydrate getStory failure does not bind draft id', (
    tester,
  ) async {
    final stories = _FakeStoriesApi();
    await tester.pumpWidget(
      _captureShell(stories: stories, draftId: 'draft-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn’t load draft. Try again.'), findsOneWidget);
    expect(find.text('Jam at the park'), findsNothing);
    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save draft'),
    );
    expect(save.onPressed, isNull);
    expect(stories.updateDraftCalls, 0);
    expect(stories.createDraftCalls, 0);

    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();

    expect(stories.updateDraftCalls, 0);
    expect(stories.lastUpdatedStoryId, isNull);
    expect(stories.createDraftCalls, 1);
    expect(stories.story?.id, isNot('draft-1'));
  });

  testWidgets('Save draft throw does not show Draft saved', (tester) async {
    final stories = _FakeStoriesApi(throwOnCreate: true);
    await tester.pumpWidget(_captureShell(stories: stories));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('Draft saved'), findsNothing);
    expect(find.text('Couldn’t save draft. Try again.'), findsOneWidget);
    expect(stories.createDraftCalls, 0);
    expect(stories.updateDraftCalls, 0);
  });

  testWidgets('Add photo without timeframe does not pick', (tester) async {
    final picker = _FakePicker();
    await tester.pumpWidget(_captureShell(picker: picker.call));
    await tester.pumpAndSettle();
    await _tapAddPhoto(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Finish the highlighted fields to publish.'),
      findsNothing,
    );
    expect(picker.calls, 0);
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .any(_hasTerracottaBorder),
      isTrue,
    );
    expect(find.byKey(const Key('photo-thumb')), findsNothing);
  });

  testWidgets('Add photo after decade uploads via gateway', (tester) async {
    final photos = _FakePhotosApi();
    final stories = _FakeStoriesApi();
    final picker = _FakePicker(bytes: _tinyJpeg);
    await tester.pumpWidget(
      _captureShell(stories: stories, photos: photos, picker: picker.call),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await _tapAddPhoto(tester);
    await tester.pumpAndSettle();
    expect(stories.createDraftCalls, 1);
    expect(photos.uploadCalls, 1);
    expect(find.byKey(const Key('photo-thumb')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('photo-thumb')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('upload failure shows retry copy', (tester) async {
    final photos = _FakePhotosApi(failUpload: true);
    await tester.pumpWidget(
      _captureShell(photos: photos, picker: _FakePicker().call),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await _tapAddPhoto(tester);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Couldn’t upload the photo. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('photo-thumb')), findsNothing);
  });

  testWidgets('decode failure shows photo retry copy', (tester) async {
    final photos = _FakePhotosApi(failDecode: true);
    await tester.pumpWidget(
      _captureShell(photos: photos, picker: _FakePicker().call),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await _tapAddPhoto(tester);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Couldn’t upload the photo. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('photo-thumb')), findsNothing);
  });

  testWidgets('Try again re-uploads pending bytes', (tester) async {
    final photos = _FakePhotosApi(failUpload: true);
    await tester.pumpWidget(
      _captureShell(photos: photos, picker: _FakePicker().call),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await _tapAddPhoto(tester);
    await tester.pumpAndSettle();

    photos.failUpload = false;
    final retry = find.text('Try again');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
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

  testWidgets('author remove calls deletePhoto', (tester) async {
    final photos = _FakePhotosApi();
    await tester.pumpWidget(
      _captureShell(photos: photos, picker: _FakePicker().call),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    await _tapAddPhoto(tester);
    await tester.pumpAndSettle();

    final remove = find.byKey(const Key('photo-remove'));
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();

    expect(photos.deleted, isNotEmpty);
    expect(find.byKey(const Key('photo-thumb')), findsNothing);
  });

  testWidgets('hides add tile at 20 photos', (tester) async {
    final photos = List<Photo>.generate(
      maxPhotosPerStory,
      (i) => Photo(
        id: 'ph$i',
        storyId: 's1',
        familyId: _familyId,
        uploaderId: 'u1',
        storagePath: 'f/s/ph$i.jpg',
        sortOrder: i,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoStrip(
            photos: photos,
            onAdd: () {},
            onRemove: (_) {},
            onRetry: () {},
            uploadFailed: false,
            canAdd: false,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('photo-add')), findsNothing);
    expect(find.byKey(const Key('photo-thumb')), findsNWidgets(20));
  });
}
