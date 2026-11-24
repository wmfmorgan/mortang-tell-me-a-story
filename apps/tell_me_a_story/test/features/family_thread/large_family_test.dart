import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/features/family_thread/thread_photo_cache.dart';
import 'package:tell_me_a_story/features/family_thread/thread_view.dart';

import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    '600 stories: only on-screen beats build and no off-screen downloads',
    (tester) async {
      final photos = _Photos();
      final stories = [
        for (var i = 0; i < 600; i++)
          _story('s$i', 1400 + i, 'S$i', 'p/$i.jpg'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: albumTheme(),
          home: Scaffold(
            body: ThreadView(
              stories: stories,
              photos: () => photos,
              photoCache: ThreadPhotoCache(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('S300', skipOffstage: false), findsNothing);
      expect(find.text('S599'), findsOneWidget);
      expect(photos.calls, isNot(contains('p/300.jpg')));
      expect(photos.calls, contains('p/599.jpg'));
      // The test surface is 600pt tall and browse rows are 64pt, so one
      // screen is 10 beats. The bound covers that screen, the list head
      // built before centering, the focused neighborhood, and the list
      // cache, and stays far below the 600-story library.
      const browseRowPx = 64.0;
      const surfaceHeightPx = 600.0;
      final onScreen = (surfaceHeightPx / browseRowPx).ceil();
      expect(photos.calls.length, lessThan(onScreen * 4));
    },
  );
}

Story _story(String id, int year, String title, String path) {
  return Story(
    id: id,
    familyId: 'family',
    authorId: 'author',
    status: StoryStatus.published,
    timeframeStart: DateTime.utc(year, 6, 1),
    datePrecision: StoryDatePrecision.year,
    title: title,
    photoPaths: [path],
    photoEditVersions: const [0],
  );
}

class _Photos extends QuietPhotos {
  final calls = <String>[];

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    calls.add(storagePath);
    return _png;
  }
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AA'
  'AAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);
