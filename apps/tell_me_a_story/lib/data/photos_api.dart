import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/data/server/server_errors.dart';

const maxPhotosPerStory = 20;

/// A story photo. [storagePath] / [editedStoragePath] are the server's blob
/// keys, read back through `media.get`.
class Photo {
  const Photo({
    required this.id,
    required this.storyId,
    required this.familyId,
    required this.uploaderId,
    required this.storagePath,
    this.editedStoragePath,
    this.editVersion = 0,
    required this.sortOrder,
  });

  final String id;
  final String storyId;
  final String familyId;

  /// Null once the uploader's account is gone.
  final String? uploaderId;
  final String storagePath;
  final String? editedStoragePath;
  final int editVersion;
  final int sortOrder;

  String get effectiveStoragePath => editedStoragePath ?? storagePath;

  factory Photo.fromDto(server.PhotoDto dto) {
    return Photo(
      id: dto.id.toString(),
      storyId: dto.storyId.toString(),
      familyId: dto.familyId.toString(),
      uploaderId: dto.uploaderId?.toString(),
      storagePath: dto.originalKey,
      editedStoragePath: dto.editedKey,
      editVersion: dto.editVersion,
      sortOrder: dto.sortOrder,
    );
  }

  Photo copyWith({
    required String? editedStoragePath,
    int? editVersion,
    int? sortOrder,
  }) {
    return Photo(
      id: id,
      storyId: storyId,
      familyId: familyId,
      uploaderId: uploaderId,
      storagePath: storagePath,
      editedStoragePath: editedStoragePath,
      editVersion: editVersion ?? this.editVersion,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class CompressedPhoto {
  const CompressedPhoto({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });
  final Uint8List bytes;
  final String mimeType; // image/jpeg
  final String extension; // jpg
}

class StorageFailedException implements Exception {
  const StorageFailedException({this.code = 'STORAGE_FAILED', this.cause});
  final String code;
  final Object? cause;

  @override
  String toString() => 'StorageFailedException($code)';
}

/// Lowest [Photo.sortOrder] first, then id.
int comparePhotoOrder(Photo a, Photo b) {
  final order = a.sortOrder.compareTo(b.sortOrder);
  if (order != 0) return order;
  return a.id.compareTo(b.id);
}

/// Puts [heroId] first and keeps the other photos in their previous order.
/// Sort orders are rewritten to 0..n-1.
List<Photo> photosWithHeroFirst(List<Photo> photos, String heroId) {
  final sorted = [...photos]..sort(comparePhotoOrder);
  final index = sorted.indexWhere((photo) => photo.id == heroId);
  if (index > 0) {
    final chosen = sorted.removeAt(index);
    sorted.insert(0, chosen);
  }
  return [
    for (var i = 0; i < sorted.length; i++)
      sorted[i].sortOrder == i
          ? sorted[i]
          : sorted[i].copyWith(
              editedStoragePath: sorted[i].editedStoragePath,
              sortOrder: i,
            ),
  ];
}

void ensurePhotoCap(int currentCount) {
  if (currentCount >= maxPhotosPerStory) {
    throw StateError('PHOTO_CAP');
  }
}

CompressedPhoto compressStoryPhoto(
  Uint8List bytes, {
  int maxEdge = 1920,
  int quality = 80,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError.value(bytes, 'bytes', 'not a decodable image');
  }
  var out = decoded;
  if (decoded.width > maxEdge || decoded.height > maxEdge) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxEdge)
        : img.copyResize(decoded, height: maxEdge);
  }
  return CompressedPhoto(
    bytes: Uint8List.fromList(img.encodeJpg(out, quality: quality)),
    mimeType: 'image/jpeg',
    extension: 'jpg',
  );
}

abstract class PhotosGateway {
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
class PhotosApi implements PhotosGateway {
  PhotosApi({server.Client? client, PhotoUploadBinary? uploadBinary})
    : _injected = client,
      _uploadBinary = uploadBinary ?? _uploadWithFileUploader;

  final server.Client? _injected;
  final PhotoUploadBinary _uploadBinary;
  server.Client get _client => _injected ?? serverClient;

  @override
  Future<List<Photo>> listPhotos(String storyId) async {
    final rows = await withServerErrors(
      () => _client.photo.list(server.UuidValue.fromString(storyId)),
    );
    return rows.map(Photo.fromDto).toList();
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
    return Photo.fromDto(dto);
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
