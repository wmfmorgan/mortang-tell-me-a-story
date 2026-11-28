import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/photo_cover.dart';
import 'package:tell_me_a_story/features/family_thread/photo_fan.dart';
import 'package:tell_me_a_story/features/family_thread/thread_photo.dart';
import 'package:tell_me_a_story/features/family_thread/story_card.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat.dart';
import 'package:tell_me_a_story/features/family_thread/thread_beat_tile.dart';
import 'package:tell_me_a_story/features/family_thread/thread_photo_cache.dart';

import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('one photo renders a 4:3 cover', (tester) async {
    final photos = _Photos();
    await tester.pumpWidget(
      _card(
        _story('s', 1996, 'Picnic', paths: const ['picnic.jpg']),
        photos: () => photos,
        cache: ThreadPhotoCache(),
      ),
    );
    await tester.pumpAndSettle();

    final size = tester.getSize(find.byType(AspectRatio));
    expect(size.width / size.height, closeTo(4 / 3, 0.02));
    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      4 / 3,
    );
    expect(find.byType(Image), findsOneWidget);
    expect(photos.calls, ['picnic.jpg']);
  });

  testWidgets('two photos render two prints and no chip', (tester) async {
    await _pumpFan(tester, 2);

    expect(find.byType(Image), findsNWidgets(2));
    expect(find.byKey(const Key('photo-fan-chip')), findsNothing);
  });

  testWidgets('five photos render three prints and +2', (tester) async {
    await _pumpFan(tester, 5);

    expect(find.byType(Image), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('fan alt reads Picnic, 5 photos', (tester) async {
    await _pumpFan(tester, 5);

    expect(find.bySemanticsLabel('Picnic, 5 photos'), findsOneWidget);
  });

  testWidgets('no photo renders quote card with first line', (tester) async {
    await tester.pumpWidget(
      _card(_story('s', 1996, 'Picnic', body: 'Rain on the roof\nThen quiet')),
    );

    expect(find.byKey(const Key('quote-card')), findsOneWidget);
    expect(find.text('Rain on the roof'), findsOneWidget);
    expect(find.text('“'), findsOneWidget);
  });

  testWidgets('single-line body not repeated under quote', (tester) async {
    await tester.pumpWidget(
      _card(_story('s', 1996, 'Picnic', body: 'Only the roof'), showBody: true),
    );

    expect(find.text('Only the roof'), findsOneWidget);
  });

  testWidgets('multi-line body keeps lines after the quote', (tester) async {
    await tester.pumpWidget(
      _card(
        _story(
          's',
          1996,
          'Picnic',
          body: 'Rain on the roof\nThen quiet\nAnd more',
        ),
        showBody: true,
      ),
    );

    expect(find.text('Rain on the roof'), findsOneWidget);
    expect(find.text('Then quiet\nAnd more'), findsOneWidget);
  });

  testWidgets('loaded cover keeps the full body', (tester) async {
    final photos = _Photos();
    await tester.pumpWidget(
      _card(
        _story(
          's',
          1996,
          'Picnic',
          body: 'Rain on the roof\nThen quiet',
          paths: const ['ok.jpg'],
        ),
        photos: () => photos,
        cache: ThreadPhotoCache(),
        showBody: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('quote-card')), findsNothing);
    expect(find.text('Rain on the roof\nThen quiet'), findsOneWidget);
  });

  testWidgets('failed cover shows its line once when the body is open', (
    tester,
  ) async {
    final photos = _Photos(fail: {'gone.jpg'});
    await tester.pumpWidget(
      _card(
        _story(
          's',
          1996,
          'Picnic',
          body: 'The first line',
          paths: const ['gone.jpg'],
        ),
        photos: () => photos,
        cache: ThreadPhotoCache(),
        showBody: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quote-card')), findsOneWidget);
    expect(find.text('The first line'), findsOneWidget);
  });

  testWidgets('failed cover stays one line when the story is replaced', (
    tester,
  ) async {
    final photos = _Photos(fail: {'gone.jpg'});
    final cache = ThreadPhotoCache();
    await tester.pumpWidget(
      _card(
        _story(
          's',
          1996,
          'Picnic',
          body: 'The first line',
          paths: const ['gone.jpg'],
        ),
        photos: () => photos,
        cache: cache,
        showBody: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _card(
        _story(
          's',
          1996,
          'Supper',
          body: 'The first line',
          paths: const ['gone.jpg'],
        ),
        photos: () => photos,
        cache: cache,
        showBody: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supper'), findsOneWidget);
    expect(find.byKey(const Key('quote-card')), findsOneWidget);
    expect(find.text('The first line'), findsOneWidget);
  });

  testWidgets('two photos with a gateway render a fan', (tester) async {
    final photos = _Photos();
    await tester.pumpWidget(
      _card(
        _story('s', 1996, 'Picnic', paths: const ['a.jpg', 'b.jpg']),
        photos: () => photos,
        cache: ThreadPhotoCache(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhotoFan), findsOneWidget);
    expect(find.byKey(const Key('quote-card')), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('photos with a null gateway or cache render the quote card', (
    tester,
  ) async {
    final story = _story(
      's',
      1996,
      'Picnic',
      body: 'Kept',
      paths: const ['a.jpg'],
    );

    await tester.pumpWidget(_card(story, photos: () => _Photos()));
    expect(find.byKey(const Key('quote-card')), findsOneWidget);
    expect(find.byType(PhotoFan), findsNothing);
    expect(find.byType(PhotoCover), findsNothing);

    await tester.pumpWidget(_card(story, cache: ThreadPhotoCache()));
    expect(find.byKey(const Key('quote-card')), findsOneWidget);
    expect(find.byType(PhotoFan), findsNothing);
    expect(find.byType(PhotoCover), findsNothing);
  });

  testWidgets('failed photo falls back to quote card', (tester) async {
    final photos = _Photos(fail: {'gone.jpg'});
    await tester.pumpWidget(
      _card(
        _story(
          's',
          1996,
          'Picnic',
          body: 'The first line',
          paths: const ['gone.jpg'],
        ),
        photos: () => photos,
        cache: ThreadPhotoCache(),
      ),
    );
    await tester.pumpAndSettle();

    expect(photos.calls, ['gone.jpg']);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('quote-card')), findsOneWidget);
    expect(find.text('The first line'), findsOneWidget);
  });

  testWidgets('beat label includes 3 photos and 1 photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: albumTheme(),
        home: Column(
          children: [
            _tile(
              _story(
                'a',
                1996,
                'Ada',
                paths: const ['a.jpg', 'b.jpg', 'c.jpg'],
              ),
            ),
            _tile(_story('b', 1997, 'Bea', paths: const ['bea.jpg'])),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('1996, Ada, 3 photos'), findsOneWidget);
    expect(find.bySemanticsLabel('1997, Bea, 1 photo'), findsOneWidget);
  });

  test('photo version is the edit version at that index, else 0', () {
    final story = _story(
      's',
      1996,
      'Picnic',
      paths: const ['a.jpg', 'b.jpg'],
      versions: const [4, 9],
    );

    expect(threadPhotoVersion(story, 0), 4);
    expect(threadPhotoVersion(story, 1), 9);
    expect(threadPhotoVersion(story, 2), 0);
  });
}

Future<void> _pumpFan(WidgetTester tester, int count) async {
  final photos = _Photos();
  await tester.pumpWidget(
    MaterialApp(
      theme: albumTheme(),
      home: Scaffold(
        body: Center(
          child: PhotoFan(
            story: _story(
              's',
              1996,
              'Picnic',
              paths: [for (var i = 0; i < count; i++) 'p/$i.jpg'],
            ),
            photos: () => photos,
            cache: ThreadPhotoCache(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _card(
  Story story, {
  bool showBody = false,
  PhotosGateway Function()? photos,
  ThreadPhotoCache? cache,
}) {
  return MaterialApp(
    theme: albumTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 124,
          width: 480,
          child: StoryCard(
            story: story,
            columnWidth: 480,
            ink: albumInk,
            semanticsLabel: 'card',
            showBody: showBody,
            photos: photos,
            cache: cache,
          ),
        ),
      ),
    ),
  );
}

Widget _tile(Story story) {
  return SizedBox(
    height: 80,
    child: ThreadBeatTile(
      beat: StoryBeat(story: story),
      focusStoryId: 'other',
      distance: 1,
    ),
  );
}

Story _story(
  String id,
  int year,
  String title, {
  String? body,
  List<String> paths = const [],
  List<int>? versions,
}) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    body: body,
    photoPaths: paths,
    photoEditVersions: versions ?? [for (final _ in paths) 0],
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
