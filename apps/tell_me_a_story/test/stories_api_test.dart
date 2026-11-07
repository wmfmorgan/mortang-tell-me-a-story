import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

final _storyId = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-000000000001',
);
final _familyId = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-000000000002',
);
final _authorId = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-000000000003',
);
final _placeId = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-000000000004',
);
final _personA = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-00000000000a',
);
final _personB = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-00000000000b',
);
final _userA = server.UuidValue.fromString(
  '0190d7a0-0000-7000-8000-0000000000aa',
);

server.StoryDto _dto({
  DateTime? dateStart,
  bool undated = false,
  server.DatePrecision? precision = server.DatePrecision.day,
  server.StoryStatus status = server.StoryStatus.published,
  List<server.StoryPersonDto> people = const [],
  List<server.PhotoRefDto> photos = const [],
  String? placeLabel,
  String? placeAddress,
  String? authorName,
  String? authorAvatarKey,
}) {
  final start = undated ? null : (dateStart ?? DateTime.utc(1987, 3, 4));
  return server.StoryDto(
    id: _storyId,
    familyId: _familyId,
    authorId: _authorId,
    title: 'Harbor',
    body: 'A day on the water',
    dateStart: start,
    dateEnd: start,
    datePrecision: undated ? null : precision,
    createdAt: DateTime.utc(2026, 1, 2, 3),
    placeId: _placeId,
    placeLabel: placeLabel,
    placeAddress: placeAddress,
    status: status,
    publishedAt: status == server.StoryStatus.published
        ? DateTime.utc(2026, 2, 3)
        : null,
    people: people,
    photos: photos,
    authorName: authorName,
    authorAvatarKey: authorAvatarKey,
    commentCount: 2,
    perspectiveCount: 1,
  );
}

void main() {
  group('Story.fromDto', () {
    test('maps ids, wire dates, precision, status and counts', () {
      final story = Story.fromDto(
        _dto(
          precision: server.DatePrecision.month,
          dateStart: DateTime.utc(1987, 3, 1),
          authorAvatarKey: 'avatars/u.jpg',
        ),
      );

      expect(story.id, _storyId.toString());
      expect(story.familyId, _familyId.toString());
      expect(story.authorId, _authorId.toString());
      expect(story.title, 'Harbor');
      expect(story.body, 'A day on the water');
      expect(story.timeframeStart, DateTime(1987, 3, 1));
      expect(story.timeframeEnd, DateTime(1987, 3, 1));
      expect(story.datePrecision, StoryDatePrecision.month);
      expect(story.status, StoryStatus.published);
      expect(story.publishedAt, DateTime.utc(2026, 2, 3));
      expect(story.createdAt, DateTime.utc(2026, 1, 2, 3));
      expect(story.placeId, _placeId.toString());
      expect(story.authorAvatarPath, 'avatars/u.jpg');
      expect(story.commentCount, 2);
      expect(story.perspectiveCount, 1);
    });

    test('an undated draft keeps null dates and the default precision', () {
      final story = Story.fromDto(
        _dto(undated: true, status: server.StoryStatus.draft),
      );

      expect(story.timeframeStart, isNull);
      expect(story.timeframeEnd, isNull);
      expect(story.datePrecision, StoryDatePrecision.day);
      expect(story.status, StoryStatus.draft);
      expect(story.publishedAt, isNull);
    });

    test('maps tagged people and links only accounts', () {
      final story = Story.fromDto(
        _dto(
          people: [
            server.StoryPersonDto(
              personId: _personA,
              name: ' Ada ',
              userId: _userA,
            ),
            server.StoryPersonDto(personId: _personB, name: '  '),
          ],
        ),
      );

      expect(story.personIds, [_personA.toString(), _personB.toString()]);
      expect(story.people, [(id: _personA.toString(), name: 'Ada')]);
      expect(story.personNames, ['Ada']);
      expect(story.personUserIds, {_personA.toString(): _userA.toString()});
    });

    test('trims place and author text and drops blanks', () {
      final story = Story.fromDto(
        _dto(
          placeLabel: ' Pier ',
          placeAddress: '  12 Dock St  ',
          authorName: ' Elena ',
        ),
      );
      expect(story.placeLabel, 'Pier');
      expect(story.placeAddress, '12 Dock St');
      expect(story.authorDisplayName, 'Elena');

      final blank = Story.fromDto(
        _dto(placeLabel: ' ', placeAddress: '', authorName: '  '),
      );
      expect(blank.placeLabel, isNull);
      expect(blank.placeAddress, isNull);
      expect(blank.authorDisplayName, isNull);
      expect(blank.authorAvatarPath, isNull);
    });

    test('photo paths are the server keys in server order', () {
      final story = Story.fromDto(
        _dto(
          photos: [
            server.PhotoRefDto(
              id: _personA,
              key: 'f/s/a.edited.jpg',
              sortOrder: 0,
            ),
            server.PhotoRefDto(id: _personB, key: 'f/s/b.jpg', sortOrder: 1),
          ],
        ),
      );

      expect(story.photoPaths, ['f/s/a.edited.jpg', 'f/s/b.jpg']);
      expect(story.photoCount, 2);
    });
  });

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

  test('compareStories sorts a null date last', () {
    final undated = Story(
      id: 'undated',
      familyId: 'f1',
      authorId: 'u1',
      status: StoryStatus.draft,
      createdAt: DateTime.utc(2020),
    );
    final dated = Story(
      id: 'dated',
      familyId: 'f1',
      authorId: 'u1',
      timeframeStart: DateTime(1980),
      timeframeEnd: DateTime(1980, 12, 31),
      datePrecision: StoryDatePrecision.year,
      status: StoryStatus.draft,
      createdAt: DateTime.utc(2020, 1, 2),
    );
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

  group('createOrUpdateExisting', () {
    test('a duplicate client id runs the update', () async {
      final calls = <String>[];
      final result = await createOrUpdateExisting<String>(
        id: 's1',
        insert: () async {
          calls.add('insert');
          throw const PostgrestException(
            message:
                'duplicate key value violates unique constraint "stories_pkey"',
            code: '23505',
          );
        },
        update: () async {
          calls.add('update');
          return 'updated';
        },
      );
      expect(result, 'updated');
      expect(calls, ['insert', 'update']);
    });

    test('without a client id the duplicate is rethrown', () async {
      await expectLater(
        createOrUpdateExisting<String>(
          id: null,
          insert: () async => throw const PostgrestException(
            message: 'duplicate key value',
            code: '23505',
          ),
          update: () async => 'updated',
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('other insert errors are rethrown', () async {
      final error = StateError('network');
      await expectLater(
        createOrUpdateExisting<String>(
          id: 's1',
          insert: () async => throw error,
          update: () async => 'updated',
        ),
        throwsA(same(error)),
      );
    });
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
