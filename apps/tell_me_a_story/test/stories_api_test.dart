import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';

void main() {
  test('storedStoryTitle trims and clears blank titles', () {
    expect(storedStoryTitle(null), isNull);
    expect(storedStoryTitle(''), isNull);
    expect(storedStoryTitle('   '), isNull);
    expect(
      storedStoryTitle('  Making Blackberry Jam on the Back Porch  '),
      'Making Blackberry Jam on the Back Porch',
    );
  });

  test('ensureValidDraftSave rejects missing timeframe', () {
    expect(
      () => ensureValidDraftSave(timeframeStart: null),
      throwsArgumentError,
    );
  });

  test('publishReadiness requires title, body, timeframe, person, place', () {
    final r = publishReadiness(
      title: '  ',
      body: '  ',
      timeframeStart: DateTime(1980, 1, 1),
      personIds: const [],
      placeId: null,
    );
    expect(r.canPublish, isFalse);
    expect(r.hasTitle, isFalse);
    expect(r.hasBody, isFalse);
    expect(r.hasTimeframe, isTrue);
    expect(r.hasPerson, isFalse);
    expect(r.hasPlace, isFalse);

    final ready = publishReadiness(
      title: 'Making Blackberry Jam on the Back Porch',
      body: 'We made jam.',
      timeframeStart: DateTime(1980, 1, 1),
      personIds: const ['p1'],
      placeId: 'pl1',
    );
    expect(ready.canPublish, isTrue);
    expect(ready.hasTitle, isTrue);
  });

  test('Story.fromJson maps draft status and nested person ids', () {
    final s = Story.fromJson({
      'id': 's1',
      'family_id': 'f1',
      'author_id': 'u1',
      'title': null,
      'body': 'Jam',
      'timeframe_start': '1980-01-01',
      'timeframe_end': '1989-12-31',
      'place_id': 'p1',
      'status': 'draft',
      'published_at': null,
      'story_people': [
        {'person_id': 'a'},
        {'person_id': 'b'},
      ],
      'photos': [
        {'id': 'ph1'},
      ],
    });
    expect(s.status, StoryStatus.draft);
    expect(s.personIds, ['a', 'b']);
    expect(s.photoCount, 1);
    expect(s.timeframeStart, DateTime(1980, 1, 1));
  });

  test('Story.fromJson tolerates a null timeframe', () {
    final story = Story.fromJson({
      'id': 's-null',
      'family_id': 'f1',
      'author_id': 'u1',
      'title': 'Undated',
      'body': 'Still writing',
      'timeframe_start': null,
      'timeframe_end': null,
      'date_precision': null,
      'status': 'draft',
    });
    expect(story.timeframeStart, isNull);
    expect(story.timeframeEnd, isNull);
    expect(story.status, StoryStatus.draft);
  });

  test('compareStories sorts a null date last', () {
    final undated = Story.fromJson({
      'id': 'undated',
      'family_id': 'f1',
      'author_id': 'u1',
      'timeframe_start': null,
      'timeframe_end': null,
      'date_precision': null,
      'status': 'draft',
      'created_at': '2020-01-01T00:00:00Z',
    });
    final dated = Story.fromJson({
      'id': 'dated',
      'family_id': 'f1',
      'author_id': 'u1',
      'timeframe_start': '1980-01-01',
      'timeframe_end': '1980-12-31',
      'date_precision': 'year',
      'status': 'draft',
      'created_at': '2020-01-02T00:00:00Z',
    });
    final rows = [undated, dated]..sort(compareStories);
    expect(rows.map((story) => story.id).toList(), ['dated', 'undated']);
  });

  test('publishedStart returns the start date and rejects a null one', () {
    final dated = Story(
      id: 'dated',
      familyId: 'f1',
      authorId: 'u1',
      timeframeStart: DateTime(1980, 6, 1),
      status: StoryStatus.published,
    );
    expect(dated.publishedStart, DateTime(1980, 6, 1));

    final undated = Story(
      id: 'undated',
      familyId: 'f1',
      authorId: 'u1',
      status: StoryStatus.draft,
    );
    expect(() => undated.publishedStart, throwsA(isA<StateError>()));
  });

  test('lib does not force a story start date with timeframeStart!', () {
    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('timeframeStart!')) {
        hits.add(entity.path);
      }
    }
    expect(hits, isEmpty);
  });

  test('isDuplicateStoryKey matches a stories primary key collision', () {
    expect(
      isDuplicateStoryKey(
        const PostgrestException(
          message:
              'duplicate key value violates unique constraint "stories_pkey"',
          code: '23505',
        ),
      ),
      isTrue,
    );
    expect(isDuplicateStoryKey(StateError('network')), isFalse);
  });

  test('lean story select resolves original, edited, and reset photos', () {
    final source = File('lib/data/stories_api.dart').readAsStringSync();
    final select = RegExp(r"static const _storySelect =\s*'([^']+)'")
        .firstMatch(source)!
        .group(1)!;
    final columns = RegExp(r'photos\(([^)]+)\)')
        .firstMatch(select)!
        .group(1)!
        .split(',')
        .map((column) => column.trim())
        .toSet();

    Map<String, Object?> photo({
      required String id,
      required int sortOrder,
      required String storagePath,
      required String? editedStoragePath,
      required int editVersion,
    }) {
      final full = <String, Object?>{
        'id': id,
        'storage_path': storagePath,
        'edited_storage_path': editedStoragePath,
        'edit_version': editVersion,
        'sort_order': sortOrder,
      };
      return {
        for (final column in columns)
          if (full.containsKey(column)) column: full[column],
      };
    }

    final story = Story.fromJson({
      'id': 's1',
      'family_id': 'f1',
      'author_id': 'u1',
      'status': 'draft',
      'photos': [
        photo(
          id: 'orig',
          sortOrder: 0,
          storagePath: 'f/s/orig.jpg',
          editedStoragePath: null,
          editVersion: 0,
        ),
        photo(
          id: 'edit',
          sortOrder: 1,
          storagePath: 'f/s/edit.jpg',
          editedStoragePath: 'f/s/edit.edited.2.jpg',
          editVersion: 2,
        ),
        photo(
          id: 'reset',
          sortOrder: 2,
          storagePath: 'f/s/reset.jpg',
          editedStoragePath: null,
          editVersion: 4,
        ),
      ],
    });

    expect(story.photoPaths, [
      'f/s/orig.jpg',
      'f/s/edit.edited.2.jpg',
      'f/s/reset.jpg',
    ]);
  });

  test('Story.photoPaths prefers the edited object and keeps hero order', () {
    final story = Story.fromJson({
      'id': 's1',
      'family_id': 'f1',
      'author_id': 'u1',
      'status': 'published',
      'timeframe_start': '1980-01-01',
      'photos': [
        {
          'id': 'b',
          'storage_path': 'f1/s1/b.jpg',
          'edited_storage_path': null,
          'sort_order': 1,
        },
        {
          'id': 'a',
          'storage_path': 'f1/s1/a.jpg',
          'edited_storage_path': 'f1/s1/a.edited.2.jpg',
          'edit_version': 2,
          'sort_order': 0,
        },
      ],
    });

    expect(story.photoPaths, ['f1/s1/a.edited.2.jpg', 'f1/s1/b.jpg']);
    expect(story.id, 's1');
  });

  test('Story.photoPaths falls back to the original after a reset', () {
    final story = Story.fromJson({
      'id': 's1',
      'family_id': 'f1',
      'author_id': 'u1',
      'status': 'published',
      'photos': [
        {
          'id': 'a',
          'storage_path': 'f1/s1/a.jpg',
          'edited_storage_path': null,
          'edit_version': 3,
          'sort_order': 0,
        },
      ],
    });

    expect(story.photoPaths, ['f1/s1/a.jpg']);
  });

  test('downloadFirstThumbs requests each effective path once', () async {
    final requested = <String>[];
    final gateway = _RecordingPhotos(
      onDownload: (path) async {
        requested.add(path);
        return Uint8List.fromList([1, 2, 3]);
      },
    );
    final edited = _storyWithPaths(['f/s/a.edited.1.jpg']);
    final shared = _storyWithPaths(['f/s/a.edited.1.jpg'], id: 's2');
    final original = _storyWithPaths(['f/s/b.jpg'], id: 's3');

    final thumbs = await downloadFirstThumbs([
      edited,
      shared,
      original,
    ], gateway);

    expect(requested, ['f/s/a.edited.1.jpg', 'f/s/b.jpg']);
    expect(thumbs.keys, ['s1', 's2', 's3']);
    expect(thumbs['s1'], thumbs['s2']);
  });
}

Story _storyWithPaths(List<String> paths, {String id = 's1'}) {
  return Story(
    id: id,
    familyId: 'f',
    authorId: 'u',
    status: StoryStatus.published,
    photoPaths: paths,
  );
}

class _RecordingPhotos implements PhotosGateway {
  _RecordingPhotos({required this.onDownload});

  final Future<Uint8List> Function(String path) onDownload;

  @override
  Future<Uint8List> downloadBytes(String storagePath) =>
      onDownload(storagePath);

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {}

  @override
  Future<void> deletePhoto(Photo photo) async {}

  @override
  Future<List<Photo>> listPhotos(String storyId) async => const [];

  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {}

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) {
    throw UnimplementedError();
  }
}
