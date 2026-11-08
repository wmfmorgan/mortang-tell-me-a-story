import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/router/app_routes.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
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
    String? personId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => _family;

  @override
  Future<void> sendInviteEmail({
    required String inviteId,
    required String token,
  }) async {}
}

class _People extends PeopleGateway {
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

  /// Chips come from search facets, never from the family's people list.
  @override
  Future<List<Person>> listPeople(String familyId) async => const [];
}

class _Search implements SearchGateway {
  _Search(
    this.rows, {
    this.decades = const [1980, 1990],
    this.throwOnSearch = false,
    this.hang = false,
  });

  final List<Story> rows;
  final List<int> decades;
  final bool throwOnSearch;
  final bool hang;
  SearchRequest? last;
  final facetLoads = <String>[];

  @override
  Future<List<Story>> search(SearchRequest request) async {
    last = request;
    if (hang && request.text.trim().isNotEmpty) {
      await Completer<void>().future;
    }
    if (throwOnSearch) throw StateError('search failed');
    final needle = request.text.trim().toLowerCase();
    return [
      for (final story in rows)
        if ('${story.title} ${story.body}'.toLowerCase().contains(needle))
          story,
    ];
  }

  @override
  Future<SearchFacets> facets(String familyId) async {
    facetLoads.add(familyId);
    return SearchFacets(
      decades: decades,
      people: const [(id: 'clara', name: 'Clara')],
      places: const [(id: 'porch', label: 'Back Porch')],
    );
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
  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {}

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    final data = bytes;
    if (data == null) throw StateError('no bytes');
    return data;
  }
}

Story _hit({
  String id = 's1',
  String? title = 'Summer Afternoon',
  String? body = 'We spent hours shelling peas on the porch.',
  String? author,
  List<String> photoPaths = const [],
  int year = 1984,
}) {
  return Story(
    id: id,
    familyId: _family,
    authorId: 'u',
    title: title,
    body: body,
    timeframeStart: DateTime(year, 6, 1),
    placeId: 'porch',
    placeLabel: 'Back Porch',
    placeAddress: '12 Lane',
    personIds: const ['clara'],
    personNames: const ['Clara'],
    status: StoryStatus.published,
    publishedAt: DateTime(2024, 1, 1),
    authorDisplayName: author,
    photoPaths: photoPaths,
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

  testWidgets('idle keeps recents and suggests the family facets', (
    tester,
  ) async {
    final search = _Search([_hit()], decades: const [1980]);
    await tester.pumpWidget(_app(search: search));
    await tester.pumpAndSettle();

    expect(search.facetLoads, [_family]);
    expect(find.text('Matching Archive Stories (1 result)'), findsNothing);
    expect(
      find.text('No stories match. Try another person, place, or time.'),
      findsNothing,
    );
    expect(find.text('Recent Searches'), findsOneWidget);
    expect(find.byKey(const Key('header-avatar')), findsNothing);
    expect(find.text('Family Members'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Decades'), findsOneWidget);
    expect(find.text('1980s'), findsOneWidget);
    expect(find.text('1990s'), findsNothing);
    expect(
      find.byKey(const Key('search-suggest-person-clara')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('search-suggest-place-porch')), findsOneWidget);
    expect(find.text('Back Porch'), findsOneWidget);
  });

  testWidgets('the decade picker offers only decades with stories', (
    tester,
  ) async {
    await tester.pumpWidget(_app(search: _Search([_hit()])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-add-decade')));
    await tester.pumpAndSettle();

    // The picker's decades are TextButtons; the suggestions are ActionChips.
    Finder pick(String label) => find.widgetWithText(TextButton, label);
    expect(pick('1980s'), findsOneWidget);
    expect(pick('1990s'), findsOneWidget);
    expect(pick('1900s'), findsNothing);
    expect(pick('2020s'), findsNothing);
  });

  testWidgets('the Decade pill hides once no decade is left to pick', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(search: _Search([_hit()], decades: const [1980])),
    );
    await tester.pumpAndSettle();

    final addDecade = find.byKey(const Key('search-add-decade'));
    await tester.tap(addDecade);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '1980s'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-filter-decade')), findsOneWidget);
    expect(addDecade, findsNothing);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();
    expect(addDecade, findsOneWidget);
  });

  testWidgets('no Decade pill when the family has no decades', (tester) async {
    await tester.pumpWidget(_app(search: _Search([_hit()], decades: const [])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-add-person')), findsOneWidget);
    expect(find.byKey(const Key('search-add-decade')), findsNothing);
  });

  testWidgets('a suggested name filters like a suggested place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final search = _Search([_hit()]);
    await tester.pumpWidget(_app(search: search));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-suggest-person-clara')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('search-filter-person-clara')), findsOneWidget);
    expect(search.last?.personIds, ['clara']);
    expect(find.byKey(const Key('search-suggest-person-clara')), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('search-suggest-decade-1980')),
    );
    await tester.tap(find.byKey(const Key('search-suggest-decade-1980')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-filter-decade')), findsOneWidget);
    expect(find.text('1980s'), findsOneWidget);
    expect(find.byKey(const Key('search-suggest-decade-1980')), findsNothing);
    expect(search.last?.decades, [1980]);
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
    final search = _Search([_hit()]);
    await tester.pumpWidget(_app(search: search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'porch');
    await tester.pump(const Duration(milliseconds: 350));
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
    expect(search.last?.decades, [1980, 1990]);
    expect(search.last?.rangeStart, isNull);
    expect(search.last?.rangeEnd, isNull);

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-filter-person-clara')), findsNothing);
    expect(find.text('1980s–1990s'), findsNothing);
    expect(find.text('Matching Archive Stories (1 result)'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('search-field')))
          .controller
          ?.text,
      isEmpty,
    );
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
    expect(find.text('June 1, 1984'), findsOneWidget);
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
