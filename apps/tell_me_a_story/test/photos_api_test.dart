import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tell_me_a_story/data/photos_api.dart';

void main() {
  test('storyPhotoStoragePath uses family/story/photo.ext', () {
    expect(
      storyPhotoStoragePath(
        familyId: 'f',
        storyId: 's',
        photoId: 'p',
        ext: 'JPG',
      ),
      'f/s/p.jpg',
    );
  });

  test('storyPhotoStoragePath rejects gif', () {
    expect(
      () => storyPhotoStoragePath(
        familyId: 'f',
        storyId: 's',
        photoId: 'p',
        ext: 'gif',
      ),
      throwsArgumentError,
    );
  });

  test('compressStoryPhoto emits jpeg under max edge', () {
    final src = _solidPng(2000, 1000); // test helper
    final out = compressStoryPhoto(src);
    expect(out.mimeType, 'image/jpeg');
    expect(out.extension, 'jpg');
    final decoded = img.decodeJpg(out.bytes)!;
    expect(decoded.width <= 1920, isTrue);
    expect(decoded.height <= 1920, isTrue);
  });

  test('uploadPhoto refuses a 21st image', () async {
    final fake = SupabaseClient('http://127.0.0.1', 'anon-key');
    final api = PhotosApi(client: fake, maxCountLoader: () async => 20);
    expect(
      () => api.uploadPhoto(
        familyId: 'f',
        storyId: 's',
        bytes: Uint8List(0),
        sortOrder: 20,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Photo.fromJson maps DDL columns', () {
    final photo = Photo.fromJson({
      'id': 'ph1',
      'story_id': 's1',
      'family_id': 'f1',
      'uploader_id': 'u1',
      'storage_path': 'f1/s1/ph1.jpg',
      'sort_order': 2,
    });
    expect(photo.id, 'ph1');
    expect(photo.storyId, 's1');
    expect(photo.familyId, 'f1');
    expect(photo.uploaderId, 'u1');
    expect(photo.storagePath, 'f1/s1/ph1.jpg');
    expect(photo.sortOrder, 2);
  });

  test('ensurePhotoCap throws PHOTO_CAP at 20', () {
    expect(() => ensurePhotoCap(19), returnsNormally);
    expect(
      () => ensurePhotoCap(20),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'PHOTO_CAP'),
      ),
    );
  });

  test(
    'uploadPhoto maps storage throw to STORAGE_FAILED without insert',
    () async {
      var inserted = false;
      final api = PhotosApi(
        client: SupabaseClient('http://127.0.0.1', 'anon-key'),
        maxCountLoader: () async => 0,
        photoIdFactory: () => 'photo-1',
        uploaderId: 'u1',
        uploadBinary:
            ({
              required String path,
              required Uint8List bytes,
              required String contentType,
            }) async {
              throw Exception('network');
            },
        insertPhoto: (row) async {
          inserted = true;
          return row;
        },
      );

      await expectLater(
        () => api.uploadPhoto(
          familyId: 'f',
          storyId: 's',
          bytes: _solidPng(8, 8),
          sortOrder: 0,
        ),
        throwsA(
          isA<StorageFailedException>().having(
            (e) => e.code,
            'code',
            'STORAGE_FAILED',
          ),
        ),
      );
      expect(inserted, isFalse);
    },
  );

  test('uploadPhoto removes storage object when photos insert fails', () async {
    final removed = <List<String>>[];
    final api = PhotosApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      maxCountLoader: () async => 1,
      photoIdFactory: () => 'photo-1',
      uploaderId: 'u1',
      uploadBinary: ({
        required String path,
        required Uint8List bytes,
        required String contentType,
      }) async {},
      insertPhoto: (row) async {
        throw Exception('rls');
      },
      removeObjects: (paths) async {
        removed.add(paths);
      },
    );

    await expectLater(
      () => api.uploadPhoto(
        familyId: 'f',
        storyId: 's',
        bytes: _solidPng(8, 8),
        sortOrder: 1,
      ),
      throwsA(isA<Exception>()),
    );
    expect(removed, [
      ['f/s/photo-1.jpg'],
    ]);
  });
}

Uint8List _solidPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 40));
  return Uint8List.fromList(img.encodePng(image));
}
