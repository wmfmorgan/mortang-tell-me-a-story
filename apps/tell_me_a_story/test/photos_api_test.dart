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

  test('photosWithHeroFirst moves the chosen photo to sort order 0', () {
    Photo photo(String id, int sortOrder) {
      return Photo(
        id: id,
        storyId: 's',
        familyId: 'f',
        uploaderId: 'u',
        storagePath: 'f/s/$id.jpg',
        sortOrder: sortOrder,
      );
    }

    final ordered = photosWithHeroFirst([
      photo('b', 0),
      photo('c', 2),
      photo('a', 1),
    ], 'a');

    expect(ordered.map((photo) => photo.id).toList(), ['a', 'b', 'c']);
    expect(ordered.map((photo) => photo.sortOrder).toList(), [0, 1, 2]);
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

  test('Photo.fromJson keeps the original when the edit is absent', () {
    final photo = Photo.fromJson({
      'id': 'ph1',
      'story_id': 's1',
      'family_id': 'f1',
      'uploader_id': 'u1',
      'storage_path': 'f1/s1/ph1.jpg',
      'edited_storage_path': null,
      'edit_version': null,
      'sort_order': 0,
    });
    expect(photo.editedStoragePath, isNull);
    expect(photo.editVersion, 0);
    expect(photo.effectiveStoragePath, 'f1/s1/ph1.jpg');
  });

  test('Photo.fromJson prefers the edited object and reads the version', () {
    final photo = Photo.fromJson({
      'id': 'ph1',
      'story_id': 's1',
      'family_id': 'f1',
      'uploader_id': 'u1',
      'storage_path': 'f1/s1/ph1.jpg',
      'edited_storage_path': 'f1/s1/ph1.edited.3.jpg',
      'edit_version': 3,
      'sort_order': 1,
    });
    expect(photo.editedStoragePath, 'f1/s1/ph1.edited.3.jpg');
    expect(photo.editVersion, 3);
    expect(photo.effectiveStoragePath, 'f1/s1/ph1.edited.3.jpg');
    expect(photo.storagePath, 'f1/s1/ph1.jpg');
  });

  test('photosWithHeroFirst keeps edited metadata and the same order', () {
    Photo photo(String id, int sortOrder, {String? edited, int version = 0}) {
      return Photo(
        id: id,
        storyId: 's',
        familyId: 'f',
        uploaderId: 'u',
        storagePath: 'f/s/$id.jpg',
        editedStoragePath: edited,
        editVersion: version,
        sortOrder: sortOrder,
      );
    }

    final ordered = photosWithHeroFirst([
      photo('b', 0, edited: 'f/s/b.edited.1.jpg', version: 1),
      photo('a', 2, edited: 'f/s/a.edited.4.jpg', version: 4),
      photo('c', 1),
    ], 'a');

    expect(ordered.map((row) => row.id).toList(), ['a', 'c', 'b']);
    expect(ordered.map((row) => row.sortOrder).toList(), [0, 1, 2]);
    expect(ordered[0].editedStoragePath, 'f/s/a.edited.4.jpg');
    expect(ordered[0].editVersion, 4);
    expect(ordered[0].effectiveStoragePath, 'f/s/a.edited.4.jpg');
    expect(ordered[2].editedStoragePath, 'f/s/b.edited.1.jpg');
    expect(ordered[2].editVersion, 1);
    expect(ordered[1].editedStoragePath, isNull);
    expect(ordered[1].effectiveStoragePath, 'f/s/c.jpg');
  });

  test('copyWith refreshes sort order and can clear the edited path', () {
    const photo = Photo(
      id: 'ph1',
      storyId: 's',
      familyId: 'f',
      uploaderId: 'u',
      storagePath: 'f/s/ph1.jpg',
      editedStoragePath: 'f/s/ph1.edited.2.jpg',
      editVersion: 2,
      sortOrder: 1,
    );
    final reordered = photo.copyWith(sortOrder: 0);
    expect(reordered.effectiveStoragePath, 'f/s/ph1.edited.2.jpg');
    expect(reordered.editVersion, 2);
    expect(reordered.sortOrder, 0);
    final reset = photo.copyWith(editedStoragePath: null, editVersion: 3);
    expect(reset.editedStoragePath, isNull);
    expect(reset.editVersion, 3);
    expect(reset.effectiveStoragePath, photo.storagePath);
  });

  test('deletePhoto removes original and edited objects before the row', () async {
    final removed = <List<String>>[];
    final deletedIds = <String>[];
    final api = PhotosApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      removeObjects: (paths) async {
        removed.add(paths);
      },
      deletePhotoRow: (photoId) async {
        deletedIds.add(photoId);
      },
    );
    const photo = Photo(
      id: 'ph1',
      storyId: 's',
      familyId: 'f',
      uploaderId: 'u',
      storagePath: 'f/s/ph1.jpg',
      editedStoragePath: 'f/s/ph1.edited.2.jpg',
      editVersion: 2,
      sortOrder: 0,
    );

    await api.deletePhoto(photo);

    expect(removed, [
      ['f/s/ph1.jpg', 'f/s/ph1.edited.2.jpg'],
    ]);
    expect(deletedIds, ['ph1']);
  });

  test('deletePhoto leaves the row when storage removal fails', () async {
    final deletedIds = <String>[];
    final api = PhotosApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      removeObjects: (paths) async {
        throw Exception('storage');
      },
      deletePhotoRow: (photoId) async {
        deletedIds.add(photoId);
      },
    );
    const photo = Photo(
      id: 'ph1',
      storyId: 's',
      familyId: 'f',
      uploaderId: 'u',
      storagePath: 'f/s/ph1.jpg',
      editedStoragePath: 'f/s/ph1.edited.1.jpg',
      editVersion: 1,
      sortOrder: 0,
    );

    await expectLater(api.deletePhoto(photo), throwsA(isA<Exception>()));
    expect(deletedIds, isEmpty);
  });

  test('deletePhoto removes only the original when the photo is unedited', () async {
    final removed = <List<String>>[];
    final api = PhotosApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      removeObjects: (paths) async {
        removed.add(paths);
      },
      deletePhotoRow: (photoId) async {},
    );
    const photo = Photo(
      id: 'ph1',
      storyId: 's',
      familyId: 'f',
      uploaderId: 'u',
      storagePath: 'f/s/ph1.jpg',
      sortOrder: 0,
    );

    await api.deletePhoto(photo);

    expect(removed, [
      ['f/s/ph1.jpg'],
    ]);
  });

  test('deleteAllForStory removes original and edited names under the prefix', () async {
    final removed = <List<String>>[];
    final api = PhotosApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      listStoryObjects: (prefix) async {
        expect(prefix, 'f/s');
        return ['ph1.jpg', 'ph1.edited.2.jpg', 'ph2.png'];
      },
      removeObjects: (paths) async {
        removed.add(paths);
      },
    );

    await api.deleteAllForStory(familyId: 'f', storyId: 's');

    expect(removed, [
      ['f/s/ph1.jpg', 'f/s/ph1.edited.2.jpg', 'f/s/ph2.png'],
    ]);
  });

  test('deleteAllForStory does not remove objects when listing fails', () async {
    final removed = <List<String>>[];
    final api = PhotosApi(
      client: SupabaseClient('http://127.0.0.1', 'anon-key'),
      listStoryObjects: (prefix) async {
        throw Exception('storage');
      },
      removeObjects: (paths) async {
        removed.add(paths);
      },
    );

    await expectLater(
      api.deleteAllForStory(familyId: 'f', storyId: 's'),
      throwsA(isA<Exception>()),
    );
    expect(removed, isEmpty);
  });
}

Uint8List _solidPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 40));
  return Uint8List.fromList(img.encodePng(image));
}
