@Tags(['live'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/data/photos_repository.dart';

import 'support/live_server.dart';
import 'support/story_fixture.dart';

Uint8List _png(int r) {
  final image = img.Image(width: 64, height: 48);
  img.fill(image, color: img.ColorRgb8(r, 40, 40));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  setUpAll(waitForLiveServer);

  test('upload, list, hero, download and delete round trip', () async {
    final owner = await signInLive(freshEmail('photos'));
    final (familyId, storyId) = await liveFamilyStory(owner);
    final api = ServerPhotosRepository();

    final first = await api.uploadPhoto(
      familyId: familyId,
      storyId: storyId,
      bytes: _png(200),
      sortOrder: 0,
    );
    final second = await api.uploadPhoto(
      familyId: familyId,
      storyId: storyId,
      bytes: _png(20),
      sortOrder: 1,
    );
    expect(first.storyId, storyId);
    expect(first.familyId, familyId);
    expect(first.uploaderId, isNotNull);

    expect((await api.listPhotos(storyId)).map((p) => p.id), [
      first.id,
      second.id,
    ]);

    await api.setHeroPhoto(storyId: storyId, photoId: second.id);
    final reordered = await api.listPhotos(storyId);
    expect(reordered.map((p) => p.id), [second.id, first.id]);
    expect(reordered.map((p) => p.sortOrder), [0, 1]);

    final bytes = await api.downloadBytes(reordered.first.effectiveStoragePath);
    expect(img.decodeJpg(bytes)?.width, 64);

    await api.deletePhoto(reordered.first);
    expect((await api.listPhotos(storyId)).map((p) => p.id), [first.id]);
  });

  test(
    'a refused upload is StorageFailedException and adds no photo',
    () async {
      final owner = await signInLive(freshEmail('photos-refused'));
      final (familyId, storyId) = await liveFamilyStory(owner);
      final api = ServerPhotosRepository(uploadBinary: (_, _) async => false);

      await expectLater(
        api.uploadPhoto(
          familyId: familyId,
          storyId: storyId,
          bytes: _png(90),
          sortOrder: 0,
        ),
        throwsA(isA<StorageFailedException>()),
      );
      expect(await ServerPhotosRepository().listPhotos(storyId), isEmpty);
    },
  );

  test('downloading an unknown key is StorageFailedException', () async {
    await signInLive(freshEmail('photos-missing'));
    await expectLater(
      ServerPhotosRepository().downloadBytes('photos/none.jpg'),
      throwsA(
        isA<StorageFailedException>().having(
          (e) => e.code,
          'code',
          'NOT_FOUND',
        ),
      ),
    );
  });
}
