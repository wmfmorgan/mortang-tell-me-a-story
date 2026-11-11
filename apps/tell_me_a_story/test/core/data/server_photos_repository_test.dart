import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/data/server_photos_repository.dart';
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
  test('Photo.fromDto maps ids, keys and order', () {
    final photo = photoFromDto(_dto());
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
    final photo = photoFromDto(
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
}
