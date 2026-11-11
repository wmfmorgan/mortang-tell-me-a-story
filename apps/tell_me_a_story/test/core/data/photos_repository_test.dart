import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/data/photos_repository.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

const _photoId = '0190d7a0-0000-7000-8000-0000000000d1';
const _storyId = '0190d7a0-0000-7000-8000-0000000000a1';
const _familyId = '0190d7a0-0000-7000-8000-0000000000f1';
const _uploaderId = '0190d7a0-0000-7000-8000-0000000000b1';

server.PhotoDto _dto({
  String? uploaderId = _uploaderId,
  String? editedKey,
  int editVersion = 0,
}) => server.PhotoDto(
  id: server.UuidValue.fromString(_photoId),
  storyId: server.UuidValue.fromString(_storyId),
  familyId: server.UuidValue.fromString(_familyId),
  uploaderId: uploaderId == null
      ? null
      : server.UuidValue.fromString(uploaderId),
  originalKey: 'photos/ph1.jpg',
  editedKey: editedKey,
  editVersion: editVersion,
  sortOrder: 2,
);

void main() {
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

  test('compressStoryPhoto emits jpeg under max edge', () {
    final src = _solidPng(2000, 1000); // test helper
    final out = compressStoryPhoto(src);
    expect(out.mimeType, 'image/jpeg');
    expect(out.extension, 'jpg');
    final decoded = img.decodeJpg(out.bytes)!;
    expect(decoded.width <= 1920, isTrue);
    expect(decoded.height <= 1920, isTrue);
  });

  test('Photo.fromDto maps ids, keys and order', () {
    final photo = Photo.fromDto(_dto());
    expect(photo.id, _photoId);
    expect(photo.storyId, _storyId);
    expect(photo.familyId, _familyId);
    expect(photo.uploaderId, _uploaderId);
    expect(photo.storagePath, 'photos/ph1.jpg');
    expect(photo.editedStoragePath, isNull);
    expect(photo.editVersion, 0);
    expect(photo.effectiveStoragePath, 'photos/ph1.jpg');
    expect(photo.sortOrder, 2);
  });

  test('Photo.fromDto prefers the edited key and keeps a gone uploader', () {
    final photo = Photo.fromDto(
      _dto(
        uploaderId: null,
        editedKey: 'photos/ph1.edited.3.jpg',
        editVersion: 3,
      ),
    );
    expect(photo.uploaderId, isNull);
    expect(photo.editedStoragePath, 'photos/ph1.edited.3.jpg');
    expect(photo.editVersion, 3);
    expect(photo.effectiveStoragePath, 'photos/ph1.edited.3.jpg');
    expect(photo.storagePath, 'photos/ph1.jpg');
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

    expect(ordered.map((row) => row.id).toList(), ['a', 'b', 'c']);
    expect(ordered.map((row) => row.sortOrder).toList(), [0, 1, 2]);
    expect(ordered[0].editedStoragePath, 'f/s/a.edited.4.jpg');
    expect(ordered[0].editVersion, 4);
    expect(ordered[0].effectiveStoragePath, 'f/s/a.edited.4.jpg');
    expect(ordered[1].editedStoragePath, 'f/s/b.edited.1.jpg');
    expect(ordered[1].editVersion, 1);
    expect(ordered[2].editedStoragePath, isNull);
    expect(ordered[2].effectiveStoragePath, 'f/s/c.jpg');
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
    final reordered = photo.copyWith(
      editedStoragePath: photo.editedStoragePath,
      sortOrder: 0,
    );
    expect(reordered.effectiveStoragePath, 'f/s/ph1.edited.2.jpg');
    expect(reordered.editVersion, 2);
    expect(reordered.sortOrder, 0);
    final reset = photo.copyWith(editedStoragePath: null, editVersion: 3);
    expect(reset.editedStoragePath, isNull);
    expect(reset.editVersion, 3);
    expect(reset.effectiveStoragePath, photo.storagePath);
  });
}

Uint8List _solidPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 40));
  return Uint8List.fromList(img.encodePng(image));
}
