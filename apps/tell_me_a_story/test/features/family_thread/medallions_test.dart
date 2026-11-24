import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_thread_density.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/decade_mosaic.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat.dart';
import 'package:tell_me_a_story/features/family_thread/thread_filter.dart';
import 'package:tell_me_a_story/features/family_thread/thread_photo.dart';
import 'package:tell_me_a_story/features/family_thread/thread_photo_cache.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';
import 'package:tell_me_a_story/features/family_thread/year_medallion.dart';

import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('failed download renders the fallback', (tester) async {
    final photos = _Photos(fail: {'gone.jpg'});
    await tester.pumpWidget(
      _app(
        YearMedallion(
          beat: YearBeat(
            year: 1996,
            stories: [_story('a', 1996, 'Ada', path: 'gone.jpg')],
          ),
          filter: ThreadFilter.cleared,
          photos: () => photos,
          cache: ThreadPhotoCache(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(photos.calls, ['gone.jpg']);
    expect(find.byType(Image), findsNothing);
    expect(find.text('A'), findsOneWidget);
    expect(_blush(), findsOneWidget);
  });

  testWidgets('off-screen beats trigger no download', (tester) async {
    final photos = _Photos();
    final stories = [
      for (var year = 1700; year < 2000; year++)
        _story('s$year', year, 'S$year', path: 'p/$year'),
    ];
    await tester.pumpWidget(
      _thread(stories, photos: () => photos, cache: ThreadPhotoCache()),
    );
    await tester.pumpAndSettle();

    expect(photos.calls, isNotEmpty);
    expect(photos.calls.length, lessThan(stories.length));
    expect(photos.calls, isNot(contains('p/1850')));
  });

  testWidgets('year medallion uses the first story with a photo', (
    tester,
  ) async {
    final photos = _Photos();
    await tester.pumpWidget(
      _app(
        YearMedallion(
          beat: YearBeat(
            year: 1996,
            stories: [
              _story('a', 1996, 'Ada'),
              _story('b', 1996, 'Bea', path: 'bea.jpg', version: 4),
              _story('c', 1996, 'Cy', path: 'cy.jpg', version: 1),
            ],
          ),
          filter: ThreadFilter.cleared,
          photos: () => photos,
          cache: ThreadPhotoCache(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(photos.calls, ['bea.jpg']);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('year medallion falls back to initial on albumBlush', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        YearMedallion(
          beat: YearBeat(
            year: 1996,
            stories: [_story('a', 1996, 'bea'), _story('b', 1996, 'Ada')],
          ),
          filter: ThreadFilter.cleared,
        ),
      ),
    );

    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    expect(_blush(), findsOneWidget);
  });

  testWidgets('mosaic tiles for 1, 3, 4 and 6 stories with +2', (tester) async {
    await _pumpMosaic(tester, 1);
    expect(find.byKey(const Key('decade-mosaic-tile')), findsOneWidget);
    expect(find.byKey(const Key('decade-mosaic-more')), findsNothing);

    await _pumpMosaic(tester, 3);
    expect(find.byKey(const Key('decade-mosaic-tile')), findsNWidgets(3));
    expect(find.byKey(const Key('decade-mosaic-more')), findsNothing);

    await _pumpMosaic(tester, 4);
    expect(find.byKey(const Key('decade-mosaic-tile')), findsNWidgets(4));
    expect(find.byKey(const Key('decade-mosaic-more')), findsNothing);

    await _pumpMosaic(tester, 6);
    expect(find.byKey(const Key('decade-mosaic-tile')), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('images fade to 100, 60 and 30 by distance', (tester) async {
    await tester.pumpWidget(
      _thread(_fadeStories(), density: FamilyThreadDensity.overview),
    );
    await tester.pumpAndSettle();

    expect(_opacity(tester, 'S'), 1);
    expect(_opacity(tester, 'R'), 0.6);
    expect(_opacity(tester, 'Q'), 0.3);
  });

  testWidgets('no fade with reduced motion', (tester) async {
    await tester.pumpWidget(
      _thread(
        _fadeStories(),
        density: FamilyThreadDensity.overview,
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(_opacity(tester, 'S'), 1);
    expect(_opacity(tester, 'R'), 1);
    expect(_opacity(tester, 'Q'), 1);
  });

  testWidgets('year medallion skips a photo the active filter rejects', (
    tester,
  ) async {
    final photos = _Photos();
    await tester.pumpWidget(
      _app(
        YearMedallion(
          beat: YearBeat(
            year: 1996,
            stories: [
              _story(
                'a',
                1996,
                'Ada',
                path: 'ada.jpg',
                personIds: const ['no'],
              ),
              _story(
                'b',
                1996,
                'Bea',
                path: 'bea.jpg',
                personIds: const ['yes'],
              ),
            ],
          ),
          filter: const ThreadFilter(personIds: {'yes'}),
          photos: () => photos,
          cache: ThreadPhotoCache(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(photos.calls, ['bea.jpg']);
  });

  testWidgets('a second ThreadPhoto hits the shared cache', (tester) async {
    final photos = _Photos();
    final cache = ThreadPhotoCache();
    await tester.pumpWidget(_photo(photos, cache, 'a.jpg', 1));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _photoHost(
        Row(
          children: [
            _photoChild(photos, cache, 'a.jpg', 1),
            _photoChild(photos, cache, 'a.jpg', 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(photos.calls, ['a.jpg']);
  });

  testWidgets('a new edit version or path downloads again', (tester) async {
    final photos = _Photos();
    final cache = ThreadPhotoCache();
    await tester.pumpWidget(_photo(photos, cache, 'a.jpg', 1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_photo(photos, cache, 'a.jpg', 2));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_photo(photos, cache, 'b.jpg', 2));
    await tester.pumpAndSettle();

    expect(photos.calls, ['a.jpg', 'a.jpg', 'b.jpg']);
  });

  testWidgets('a new photos gateway downloads when the cache misses', (
    tester,
  ) async {
    final first = _Photos();
    final cache = ThreadPhotoCache();
    await tester.pumpWidget(_photo(first, cache, 'a.jpg', 1));
    await tester.pumpAndSettle();
    cache.clear();
    final second = _Photos();
    await tester.pumpWidget(_photo(second, cache, 'a.jpg', 1));
    await tester.pumpAndSettle();

    expect(first.calls, ['a.jpg']);
    expect(second.calls, ['a.jpg']);
  });
}

Future<void> _pumpMosaic(WidgetTester tester, int count) {
  return tester.pumpWidget(
    _app(
      DecadeMosaic(
        stories: [for (var i = 0; i < count; i++) _story('$i', 1990, 'S$i')],
        filter: ThreadFilter.cleared,
      ),
    ),
  );
}

List<Story> _fadeStories() {
  return [
    _story('q', 1982, 'Quill'),
    _story('r', 1994, 'Reed'),
    _story('s', 2004, 'Sage'),
  ];
}

Widget _thread(
  List<Story> stories, {
  FamilyThreadDensity density = FamilyThreadDensity.browse,
  bool reduced = false,
  PhotosGateway Function()? photos,
  ThreadPhotoCache? cache,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: Builder(
      builder: (context) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(disableAnimations: reduced),
          child: Scaffold(
            body: ThreadView(
              stories: stories,
              density: density,
              photos: photos,
              photoCache: cache,
            ),
          ),
        );
      },
    ),
  );
}

double _opacity(WidgetTester tester, String letter) {
  final initial = find.descendant(
    of: find.byType(DecadeMosaic),
    matching: find.text(letter),
  );
  final fade = find
      .ancestor(of: initial, matching: find.byType(FadeTransition))
      .first;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

Finder _blush() {
  return find.descendant(
    of: find.byType(YearMedallion),
    matching: find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color == albumBlush,
    ),
  );
}

Widget _photo(
  PhotosGateway photos,
  ThreadPhotoCache cache,
  String path,
  int version,
) {
  return _photoHost(_photoChild(photos, cache, path, version));
}

Widget _photoHost(Widget child) {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(body: child),
  );
}

Widget _photoChild(
  PhotosGateway photos,
  ThreadPhotoCache cache,
  String path,
  int version,
) {
  return SizedBox(
    width: 64,
    height: 64,
    child: ThreadPhoto(
      photos: photos,
      cache: cache,
      path: path,
      editVersion: version,
      displayPx: 64,
      fallback: (_) => const Text('A'),
    ),
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 112, height: 112, child: child)),
    ),
  );
}

Story _story(
  String id,
  int year,
  String title, {
  String? path,
  int version = 0,
  List<String> personIds = const [],
}) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    personIds: personIds,
    photoPaths: path == null ? const [] : [path],
    photoEditVersions: path == null ? const [] : [version],
  );
}

class _Photos extends QuietPhotos {
  _Photos({this.fail = const {}});

  final Set<String> fail;
  final calls = <String>[];

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    calls.add(storagePath);
    if (fail.contains(storagePath)) {
      throw const StorageException('missing', statusCode: '404');
    }
    return _png;
  }
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AA'
  'AAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);
