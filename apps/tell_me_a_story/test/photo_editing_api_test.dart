import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/photo/photo_editing_storage.dart';
import 'package:tell_me_a_story/data/photos_api.dart';

class _FakeGateway implements PhotoEditingGateway {
  _FakeGateway(this.photo);

  Photo photo;
  final uploads = <String, Uint8List>{};
  final removed = <String>[];
  Object? saveError;
  Object? removeError;
  int saves = 0;

  @override
  Future<void> uploadJpeg({
    required String path,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1);
    uploads[path] = bytes;
  }

  @override
  Future<PhotoEditResult> savePhotoEdit({
    required String photoId,
    required int expectedVersion,
    required String editedPath,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    saves += 1;
    final previous = photo.editedStoragePath;
    photo = photo.copyWith(
      editedStoragePath: editedPath,
      editVersion: expectedVersion + 1,
    );
    return PhotoEditResult(
      editVersion: photo.editVersion,
      previousPath: previous,
    );
  }

  @override
  Future<PhotoEditResult> resetPhotoEdit({
    required String photoId,
    required int expectedVersion,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    final previous = photo.editedStoragePath;
    photo = photo.copyWith(
      editedStoragePath: null,
      editVersion: expectedVersion + 1,
    );
    return PhotoEditResult(
      editVersion: photo.editVersion,
      previousPath: previous,
    );
  }

  @override
  Future<void> remove(List<String> paths) async {
    final error = removeError;
    if (error != null) throw error;
    removed.addAll(paths);
  }

  @override
  Future<Photo> readPhoto(String photoId) async => photo;

  @override
  Future<Uint8List> download(String path) async =>
      Uint8List.fromList([1, 2, 3]);
}

Photo _photo({String? edited, int version = 2}) {
  return Photo(
    id: 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE',
    storyId: '11111111-1111-1111-1111-111111111111',
    familyId: '22222222-2222-2222-2222-222222222222',
    uploaderId: 'user',
    storagePath: '22222222-2222-2222-2222-222222222222/11111111-1111-1111-1111-111111111111/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.jpg',
    editedStoragePath: edited,
    editVersion: version,
    sortOrder: 0,
  );
}

void main() {
  test(
    'upload uses the next version path and upsert is not a row write',
    () async {
      final photo = _photo();
      final gateway = _FakeGateway(photo);
      final api = PhotoEditingApi(gateway);
      final path = await api.uploadCandidate(photo, Uint8List.fromList([9]), 3);
      expect(
        path,
        '22222222-2222-2222-2222-222222222222/'
        '11111111-1111-1111-1111-111111111111/'
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.edited.3.jpg',
      );
      expect(gateway.uploads[path], Uint8List.fromList([9]));
      expect(gateway.saves, 0);
    },
  );

  test('save maps conflict and removes the unused candidate', () async {
    final gateway = _FakeGateway(_photo());
    gateway.saveError = Exception('CONFLICT: photo edit version');
    final api = PhotoEditingApi(gateway);
    final path = await api.uploadCandidate(
      _photo(),
      Uint8List.fromList([1]),
      3,
    );
    await expectLater(
      api.savePhotoEdit(_photo().id, 2, path),
      throwsA(
        isA<PhotoEditException>().having(
          (error) => error.kind,
          'kind',
          PhotoEditFailureKind.conflict,
        ),
      ),
    );
    expect(gateway.removed, contains(path));
  });

  test('a failed cleanup is retried and a referenced path is kept', () async {
    final gateway = _FakeGateway(_photo(edited: 'old.jpg', version: 2));
    gateway.removeError = Exception('storage');
    final api = PhotoEditingApi(gateway);
    final path = await api.uploadCandidate(
      gateway.photo,
      Uint8List.fromList([1]),
      3,
    );
    await api.savePhotoEdit(gateway.photo.id, 2, path);
    expect(api.pendingDeletes, contains('old.jpg'));
    gateway.removeError = null;
    await api.retryCleanup(protected: {path});
    expect(gateway.removed, contains('old.jpg'));
    expect(gateway.removed, isNot(contains(path)));
  });

  test('forbidden and validation keep their prefixes', () {
    expect(
      mapPhotoEditError(Exception('FORBIDDEN: photo edit denied')).kind,
      PhotoEditFailureKind.forbidden,
    );
    expect(
      mapPhotoEditError(Exception('VALIDATION: invalid edited path')).message,
      'VALIDATION: invalid edited path',
    );
  });
}
