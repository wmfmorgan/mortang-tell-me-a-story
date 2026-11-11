import 'dart:typed_data';

import 'package:tell_me_a_story/core/domain/photo.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';

/// In-memory [PhotosRepository] for widget tests. [photos] is the store; every
/// call is appended to [calls] as its method name. Set an `*Error` field to
/// make that call throw it. Subclass and override a method for anything else.
class FakePhotosRepository implements PhotosRepository {
  FakePhotosRepository({
    Iterable<Photo> photos = const [],
    this.userId = 'user-1',
  }) : photos = [...photos];

  /// `uploaderId` of photos this fake uploads.
  final String userId;

  final List<Photo> photos;
  final calls = <String>[];
  final uploadedBytes = <Uint8List>[];
  final deleted = <String>[];
  final heroes = <({String storyId, String photoId})>[];

  /// What [downloadBytes] returns per storage path; missing paths give
  /// empty bytes.
  final bytesByPath = <String, Uint8List>{};

  Object? uploadError;
  Object? downloadError;

  @override
  Future<List<Photo>> listPhotos(String storyId) async {
    calls.add('listPhotos');
    return [
      for (final photo in photos)
        if (photo.storyId == storyId) photo,
    ]..sort(comparePhotoOrder);
  }

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) async {
    calls.add('uploadPhoto');
    final error = uploadError;
    if (error != null) throw error;
    uploadedBytes.add(bytes);
    final id = 'photo-${uploadedBytes.length}';
    final photo = Photo(
      id: id,
      storyId: storyId,
      familyId: familyId,
      uploaderId: userId,
      storagePath: 'photos/$storyId/$id.jpg',
      sortOrder: sortOrder,
    );
    photos.add(photo);
    bytesByPath[photo.storagePath] = bytes;
    return photo;
  }

  @override
  Future<void> deletePhoto(Photo photo) async {
    calls.add('deletePhoto');
    photos.removeWhere((existing) => existing.id == photo.id);
    deleted.add(photo.id);
  }

  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {
    calls.add('setHeroPhoto');
    heroes.add((storyId: storyId, photoId: photoId));
    final ordered = photosWithHeroFirst(await listPhotos(storyId), photoId);
    photos
      ..removeWhere((photo) => photo.storyId == storyId)
      ..addAll(ordered);
  }

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    calls.add('downloadBytes');
    final error = downloadError;
    if (error != null) throw error;
    return bytesByPath[storagePath] ?? Uint8List(0);
  }
}
