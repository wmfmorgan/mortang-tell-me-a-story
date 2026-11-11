import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/data/server_stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story.dart';
import 'package:tell_me_a_story/core/domain/story_date_precision.dart';
import 'package:tell_me_a_story/core/domain/story_status.dart';

import '../../support/fakes/fake_photos_repository.dart';

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
  group('storyFromDto', () {
    test('maps ids, wire dates, precision, status and counts', () {
      final story = storyFromDto(
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
      final story = storyFromDto(
        _dto(undated: true, status: server.StoryStatus.draft),
      );

      expect(story.timeframeStart, isNull);
      expect(story.timeframeEnd, isNull);
      expect(story.datePrecision, StoryDatePrecision.day);
      expect(story.status, StoryStatus.draft);
      expect(story.publishedAt, isNull);
    });

    test('maps tagged people and links only accounts', () {
      final story = storyFromDto(
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
      final story = storyFromDto(
        _dto(
          placeLabel: ' Pier ',
          placeAddress: '  12 Dock St  ',
          authorName: ' Elena ',
        ),
      );
      expect(story.placeLabel, 'Pier');
      expect(story.placeAddress, '12 Dock St');
      expect(story.authorDisplayName, 'Elena');

      final blank = storyFromDto(
        _dto(placeLabel: ' ', placeAddress: '', authorName: '  '),
      );
      expect(blank.placeLabel, isNull);
      expect(blank.placeAddress, isNull);
      expect(blank.authorDisplayName, isNull);
      expect(blank.authorAvatarPath, isNull);
    });

    test('photo paths are the server keys in server order', () {
      final story = storyFromDto(
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

  group('storyWriteDto', () {
    test('sends wire dates, the precision, text, place and people', () {
      final dto = storyWriteDto(
        timeframeStart: DateTime(1987, 3, 1),
        timeframeEnd: DateTime(1987, 3, 31),
        datePrecision: 'month',
        title: 'Harbor',
        body: 'A day on the water',
        placeId: _placeId.toString(),
        personIds: [_personA.toString(), _personB.toString()],
      );

      expect(dto.dateStart, DateTime.utc(1987, 3, 1));
      expect(dto.dateEnd, DateTime.utc(1987, 3, 31));
      expect(dto.datePrecision, server.DatePrecision.month);
      expect(dto.title, 'Harbor');
      expect(dto.body, 'A day on the water');
      expect(dto.placeId, _placeId);
      expect(dto.clearPlace, isFalse);
      expect(dto.personIds, [_personA, _personB]);
    });

    test('null fields stay null so the server keeps them', () {
      final dto = storyWriteDto();

      expect(dto.dateStart, isNull);
      expect(dto.dateEnd, isNull);
      expect(dto.datePrecision, isNull);
      expect(dto.title, isNull);
      expect(dto.body, isNull);
      expect(dto.placeId, isNull);
      expect(dto.clearPlace, isFalse);
      expect(dto.personIds, isNull);
    });

    test('an empty place id clears the place', () {
      final dto = storyWriteDto(placeId: '');

      expect(dto.placeId, isNull);
      expect(dto.clearPlace, isTrue);
    });

    test('an empty person list replaces the tags with none', () {
      expect(storyWriteDto(personIds: const []).personIds, isEmpty);
    });
  });

  test('createDraft refuses a missing date before calling the server', () {
    expect(
      ServerStoriesRepository().createDraft(
        familyId: _familyId.toString(),
        title: 'Jam',
      ),
      throwsArgumentError,
    );
  });

  test('downloadFirstThumbs without photos asks nobody', () async {
    final thumbs = await downloadFirstThumbs([_storyWithPaths(const [])], null);

    expect(thumbs, isEmpty);
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

  test(
    'downloadFirstThumbs on the server fetches in bounded batches',
    () async {
      final client = _MediaClient();
      final stories = [
        for (var i = 0; i < 20; i++)
          _storyWithPaths(['f/s/p$i.jpg'], id: 's$i'),
      ];

      final thumbs = await downloadFirstThumbs(stories, null, client: client);

      expect(client.recording.calls.length, greaterThan(1));
      for (final call in client.recording.calls) {
        expect(call.length, lessThanOrEqualTo(8));
      }
      expect(thumbs.keys, [for (final story in stories) story.id]);
      expect(thumbs['s19'], [1, 2, 3]);
    },
  );

  group('listPublishedInTree', () {
    test(
      'asks the tree read for the family and keeps the server order',
      () async {
        final client = _StoryClient();
        final later = server.UuidValue.fromString(
          '0190d7a0-0000-7000-8000-0000000000bb',
        );
        client.recording.tree = [
          _dto(dateStart: DateTime.utc(1990)).copyWith(id: later),
          _dto(dateStart: DateTime.utc(1950)),
        ];

        final stories = await ServerStoriesRepository(client: client)
            .listPublishedInTree(_familyId.toString());

        expect(client.recording.treeCalls, [_familyId]);
        expect(stories.map((s) => s.id), [
          later.toString(),
          _storyId.toString(),
        ]);
        expect(stories.first.timeframeStart, DateTime(1990));
      },
    );

    test('a server refusal comes out as the app error', () async {
      final client = _StoryClient();
      client.recording.error = server.AppException(
        code: server.AppErrorCode.forbidden,
        message: 'forbidden',
      );

      await expectLater(
        ServerStoriesRepository(client: client)
            .listPublishedInTree(_familyId.toString()),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.forbidden,
          ),
        ),
      );
    });
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

class _RecordingPhotos extends FakePhotosRepository {
  _RecordingPhotos({required this.onDownload});

  final Future<Uint8List> Function(String path) onDownload;

  @override
  Future<Uint8List> downloadBytes(String storagePath) =>
      onDownload(storagePath);
}

class _RecordingStory extends server.EndpointStory {
  _RecordingStory(super.caller);

  var tree = <server.StoryDto>[];
  final treeCalls = <server.UuidValue>[];
  Object? error;

  @override
  Future<List<server.StoryDto>> listPublishedInTree(
    server.UuidValue familyId,
  ) async {
    treeCalls.add(familyId);
    final thrown = error;
    if (thrown != null) throw thrown;
    return tree;
  }
}

class _StoryClient extends server.Client {
  _StoryClient() : super('http://127.0.0.1:1/');

  late final recording = _RecordingStory(this);

  @override
  server.EndpointStory get story => recording;
}

class _RecordingMedia extends server.EndpointMedia {
  _RecordingMedia(super.caller);

  final calls = <List<String>>[];

  @override
  Future<Map<String, ByteData>> getMany(List<String> keys) async {
    calls.add(List.of(keys));
    return {
      for (final key in keys)
        key: ByteData.sublistView(Uint8List.fromList([1, 2, 3])),
    };
  }
}

class _MediaClient extends server.Client {
  _MediaClient() : super('http://127.0.0.1:1/');

  late final recording = _RecordingMedia(this);

  @override
  server.EndpointMedia get media => recording;
}
