import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/compressed_photo.dart';
import 'package:tell_me_a_story/core/domain/photo.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';

/// [dto] as an app [Photo].
Photo photoFromDto(server.PhotoDto dto) => Photo(
  id: dto.id.toString(),
  storyId: dto.storyId.toString(),
  familyId: dto.familyId.toString(),
  uploaderId: dto.uploaderId?.toString(),
  storagePath: dto.originalKey,
  editedStoragePath: dto.editedKey,
  editVersion: dto.editVersion,
  sortOrder: dto.sortOrder,
);

/// Sends [bytes] to the upload [uploadDescription] from `photo.startUpload`;
/// false means the store refused it.
typedef PhotoUploadBinary = Future<bool> Function(
  String uploadDescription,
  Uint8List bytes,
);

Future<bool> _uploadWithFileUploader(String description, Uint8List bytes) =>
    server.FileUploader(description)
        .uploadByteData(ByteData.sublistView(bytes));

/// Story photos on the `photo` endpoint; bytes through `media.get`.
class ServerPhotosRepository implements PhotosRepository {
  ServerPhotosRepository({
    server.Client? client,
    PhotoUploadBinary? uploadBinary,
  }) : _injected = client,
       _uploadBinary = uploadBinary ?? _uploadWithFileUploader;

  final server.Client? _injected;
  final PhotoUploadBinary _uploadBinary;
  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Photo>> listPhotos(String storyId) async {
    final rows = await withServerErrors(
      () => _client.photo.list(server.UuidValue.fromString(storyId)),
    );
    return rows.map(photoFromDto).toList();
  }

  /// Compresses to JPEG, then start → upload → finish. The server enforces
  /// the cap (`StateError('PHOTO_CAP')`); a refused upload is
  /// [StorageFailedException]. [familyId] is the story's; the server derives
  /// it.
  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) async {
    final compressed = compressStoryPhoto(bytes);
    final story = server.UuidValue.fromString(storyId);
    final ticket = await withServerErrors(
      () => _client.photo.startUpload(
        story,
        compressed.mimeType,
        compressed.bytes.length,
      ),
    );
    final bool uploaded;
    try {
      uploaded = await _uploadBinary(
        ticket.uploadDescription,
        compressed.bytes,
      );
    } catch (e) {
      throw StorageFailedException(cause: e);
    }
    if (!uploaded) throw const StorageFailedException();
    final dto = await withServerErrors(
      () => _client.photo.finishUpload(story, ticket.photoId, sortOrder),
    );
    return photoFromDto(dto);
  }

  /// One server transaction rewrites the story's order with [photoId] first.
  @override
  Future<void> setHeroPhoto({
    required String storyId,
    required String photoId,
  }) async {
    await withServerErrors(
      () => _client.photo.setHero(
        server.UuidValue.fromString(storyId),
        server.UuidValue.fromString(photoId),
      ),
    );
  }

  /// Deletes the row; the server queues its original and edited blobs.
  @override
  Future<void> deletePhoto(Photo photo) async {
    await withServerErrors(
      () => _client.photo.delete(server.UuidValue.fromString(photo.id)),
    );
  }

  /// The blob at [storagePath]. Missing or unreadable is
  /// [StorageFailedException] with code `NOT_FOUND`.
  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    final data = await withServerErrors(() => _client.media.get(storagePath));
    if (data == null) throw const StorageFailedException(code: 'NOT_FOUND');
    return Uint8List.sublistView(data);
  }
}
