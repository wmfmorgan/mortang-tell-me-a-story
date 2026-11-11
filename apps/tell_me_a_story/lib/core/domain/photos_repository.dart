import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/photo.dart';

part 'photos_repository.g.dart';

abstract class PhotosRepository {
  Future<List<Photo>> listPhotos(String storyId);
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  });
  Future<void> deletePhoto(Photo photo);

  /// Makes [photoId] the first photo for [storyId]. Reader hero and story
  /// cards use that first photo.
  Future<void> setHeroPhoto({required String storyId, required String photoId});

  Future<Uint8List> downloadBytes(String storagePath);
}

@Riverpod(keepAlive: true)
PhotosRepository photosRepository(Ref ref) =>
    throw UnimplementedError('Overridden in main.dart');
