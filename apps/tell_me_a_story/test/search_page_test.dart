import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/places_api.dart';
import 'package:tell_me_a_story/data/search_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/search/search_page.dart';
import 'package:tell_me_a_story/features/search/search_recents.dart';

const _family = 'family-1';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Invite implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) {
    throw UnimplementedError();
  }

  @override
  Future<String> createFamily(String name) async => _family;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => _family;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}

class _People implements PeopleGateway {
  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    required String relationship,
    String? email,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Person>> listPeople(String familyId) async => const [
    Person(
      id: 'clara',
      familyId: _family,
      name: 'Clara',
      relationship: 'Aunt',
      createdBy: 'u',
    ),
  ];
}

class _Places implements PlacesGateway {
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
  Future<Place?> findByMapboxPlaceId(
    String familyId,
    String mapboxPlaceId,
  ) async => null;

  @override
  Future<Place?> getPlace(String id) async => null;

  @override
  Future<List<Place>> listFavorites(String familyId) async => const [];

  @override
  Future<List<Place>> listPlaces(String familyId) async => const [
    Place(
      id: 'porch',
      familyId: _family,
      label: 'Back Porch',
      address: '12 Lane',
      lat: 1,
      lng: 2,
      isFavorite: false,
    ),
  ];

  @override
  Future<List<Place>> listRecents(String familyId, {int limit = 10}) async =>
      const [];

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
}

class _Search implements SearchGateway {
  _Search(this.rows, {this.throwOnSearch = false, this.hang = false});

  final List<SearchRecord> rows;
  final bool throwOnSearch;
  final bool hang;
  SearchRequest? last;

  @override
  Future<List<SearchRecord>> search(SearchRequest request) async {
    last = request;
    if (hang) {
      await Completer<void>().future;
    }
    if (throwOnSearch) throw StateError('search failed');
    return filterSearchRecords(rows, request);
  }
}

class _Photos implements PhotosGateway {
  _Photos(this.bytes);

  final Uint8List? bytes;

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
  }) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    final data = bytes;
    if (data == null) throw StateError('no bytes');
    return data;
  }
}

SearchRecord _hit({
  String id = 's1',
  String? title = 'Summer Afternoon',
  String? body = 'We spent hours shelling peas on the porch.',
  String? author,
  List<String> photoPaths = const [],
  int year = 1984,
}) {
  return SearchRecord(
    placeAddress: '12 Lane',
    story: Story(
      id: id,
      familyId: _family,
      authorId: 'u',
      title: title,
      body: body,
      timeframeStart: DateTime(year, 6, 1),
      placeId: 'porch',
      placeLabel: 'Back Porch',
      personIds: const ['clara'],
      personNames: const ['Clara'],
      status: StoryStatus.published,
      publishedAt: DateTime(2024, 1, 1),
      authorDisplayName: author,
      photoPaths: photoPaths,
    ),
  );
}

Widget _app({
  required SearchGateway search,
  PhotosGateway? photos,
  String initial = '/search',
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: AppRoutes.timeline,
        builder: (context, state) => const Text('timeline-home'),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => SearchPage(
          inviteApi: _Invite(),
          peopleApi: _People(),
          placesApi: _Places(),
          searchApi: search,
          photosApi: photos ?? _Photos(null),
          recents: SearchRecents(),
        ),
      ),
      GoRoute(
        path: AppRoutes.story,
        builder: (context, state) =>
            Text('reader-${state.pathParameters['storyId']}'),
      ),
    ],
  );
  return MaterialApp.router(theme: albumTheme(), routerConfig: router);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('idle keeps recents and suggestions and hides results', (
    tester,
  ) async {
    await tester.pumpWidget(_app(search: _Search([_hit()])));
    await tester.pumpAndSettle();

    expect(find.text('Matching Archive Stories (1 result)'), findsNothing);
    expect(
      find.text('No stories match. Try another person, place, or time.'),
      findsNothing,
    );
    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.text('Suggested Family Members & Places'), findsOneWidget);
    expect(find.text('Clara'), findsWidgets);
    expect(find.text('Back Porch'), findsOneWidget);
  });

  testWidgets('a query with no hits shows the locked sentence', (tester) async {
    await tester.pumpWidget(_app(search: _Search([_hit()])));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'subway');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.text('No stories match. Try another person, place, or time.'),
      findsOneWidget,
    );
    expect(find.text('Matching Archive Stories (0 results)'), findsOneWidget);
    expect(find.text('Sort by:'), findsOneWidget);
  });

  testWidgets('searching shows the locked loading copy', (tester) async {
    await tester.pumpWidget(_app(search: _Search([_hit()], hang: true)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'porch');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Searching the album…'), findsOneWidget);
  });

  testWidgets('failure shows Try again and stays on search', (tester) async {
    await tester.pumpWidget(
      _app(search: _Search([_hit()], throwOnSearch: true)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'porch');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Try again'), findsWidgets);
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.text('timeline-home'), findsNothing);
  });

  testWidgets('add person, decade span, and clear filters', (tester) async {
    await tester.pumpWidget(_app(search: _Search([_hit()])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-add-person')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clara').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-filter-person-clara')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-add-decade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1980s'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-add-decade')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1990s'));
    await tester.pumpAndSettle();
    expect(find.text('1980s–1990s'), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-filter-person-clara')), findsNothing);
    expect(find.text('1980s–1990s'), findsNothing);
    expect(find.text('Matching Archive Stories (1 result)'), findsNothing);
  });

  testWidgets('card uses the saved title, filled person, and quiet place', (
    tester,
  ) async {
    await tester.pumpWidget(_app(search: _Search([_hit(author: 'Elena')])));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'summer');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Summer Afternoon'), findsOneWidget);
    expect(find.text('Untitled'), findsNothing);
    expect(
      find.text('We spent hours shelling peas on the porch.'),
      findsOneWidget,
    );
    expect(find.text('Added by Elena'), findsOneWidget);
    expect(find.text('Sort by:'), findsOneWidget);
    expect(find.text('Most Relevant'), findsOneWidget);

    final person = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('search-card-person-Clara')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((person.decoration as BoxDecoration).color, albumTerracotta);
    final place = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const Key('search-card-place-Back Porch')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((place.decoration as BoxDecoration).color, isNot(albumTerracotta));
    expect(find.byKey(const Key('search-year-s1')), findsOneWidget);
    expect(find.byKey(const Key('search-photo-s1')), findsNothing);
  });

  testWidgets('a blank title is omitted and Member is the empty byline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        search: _Search([
          _hit(
            title: '   ',
            body: 'First line of the body stays in the excerpt.',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-field')), 'excerpt');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Untitled'), findsNothing);
    expect(
      find.text('First line of the body stays in the excerpt.'),
      findsOneWidget,
    );
    expect(find.text('Added by Member'), findsOneWidget);
  });

  testWidgets('a photo keeps the year on the image well', (tester) async {
    await tester.pumpWidget(
      _app(
        search: _Search([
          _hit(photoPaths: const ['fam/s1/p.jpg']),
        ]),
        photos: _Photos(_png),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-field')), 'summer');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-photo-s1')), findsOneWidget);
    expect(find.text('1984'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Read Story opens the reader and Close leaves search', (
    tester,
  ) async {
    await tester.pumpWidget(_app(search: _Search([_hit()])));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('search-field')), 'summer');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Read Story →'));
    await tester.pumpAndSettle();
    expect(find.text('reader-s1'), findsOneWidget);

    GoRouter.of(tester.element(find.text('reader-s1'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search-close')));
    await tester.pumpAndSettle();
    expect(find.text('timeline-home'), findsOneWidget);
  });
}
