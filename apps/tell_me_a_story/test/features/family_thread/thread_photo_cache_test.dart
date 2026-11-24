import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tell_me_a_story/core/theme/album_theme.dart';
import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/features/family_thread/family_thread_page.dart';
import 'package:tell_me_a_story/features/family_thread/thread_photo_cache.dart';

import '../../support/family_thread_surface.dart';
import '../../support/quiet_gateways.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(FamilySelection.clear);

  test('evicts least recently used past capacity', () {
    final cache = ThreadPhotoCache(capacity: 2);
    cache.put('a#1', _bytes(1));
    cache.put('b#1', _bytes(2));
    expect(cache.read('a#1'), _bytes(1));

    cache.put('c#1', _bytes(3));

    expect(cache.read('b#1'), isNull);
    expect(cache.read('a#1'), _bytes(1));
    expect(cache.read('c#1'), _bytes(3));
    expect(cache.length, 2);
  });

  test('same path with a new edit_version is a cache miss', () {
    final cache = ThreadPhotoCache(capacity: 4);
    final first = ThreadPhotoCache.keyFor('stories/a.jpg', 1);
    cache.put(first, _bytes(1));

    expect(cache.read(ThreadPhotoCache.keyFor('stories/a.jpg', 2)), isNull);
    expect(cache.read(first), _bytes(1));
    expect(first, 'stories/a.jpg#1');
  });

  testWidgets('page dispose empties the cache', (tester) async {
    final cache = ThreadPhotoCache();
    cache.put(ThreadPhotoCache.keyFor('stories/a.jpg', 1), _bytes(1));
    await tester.pumpWidget(_page(cache));
    await tester.pumpAndSettle();
    expect(cache.length, 1);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(cache.length, 0);
  });
}

Uint8List _bytes(int n) => Uint8List.fromList([n]);

Widget _page(ThreadPhotoCache cache) {
  return MaterialApp(
    theme: albumTheme(),
    home: FamilyThreadPage(
      storiesApi: ThreadStories([threadStory('a', 1990, 'Ada')]),
      familiesApi: TestFamilies.member(),
      currentUserId: () => 'user-1',
      live: FakeTimelineLive(),
      photoCache: cache,
    ),
  );
}
