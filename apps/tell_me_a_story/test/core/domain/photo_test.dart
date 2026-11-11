import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/photo.dart';

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
