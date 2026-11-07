import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import '../core/server/server_client.dart';
import 'photos_api.dart';
import 'server/server_errors.dart';

const familyCoverMaxBytes = 5242880;

class CoverPhotoException implements Exception {
  CoverPhotoException(this.message);

  final String message;
}

/// Download, upload, and clear for family covers.
abstract class FamilyCoverClient {
  Future<Uint8List?> download(String? path);

  Future<String> save({required String familyId, required Uint8List bytes});

  Future<void> clear({required String familyId, required String? path});
}

class FamilyCoversApi implements FamilyCoverClient {
  FamilyCoversApi({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  /// The cover bytes at [path], or null when there is none.
  @override
  Future<Uint8List?> download(String? path) async {
    if (path == null || path.isEmpty) return null;
    final data = await withServerErrors(() => _client.media.get(path));
    return data == null ? null : Uint8List.sublistView(data);
  }

  /// Compresses [bytes] to JPEG, uploads it and makes it the cover.
  /// Returns the new cover key.
  @override
  Future<String> save({
    required String familyId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw CoverPhotoException('Couldn’t save the family photo. Try again.');
    }
    final CompressedPhoto compressed;
    try {
      compressed = compressStoryPhoto(bytes, maxEdge: 1920, quality: 80);
    } on ArgumentError {
      throw CoverPhotoException('Couldn’t save the family photo. Try again.');
    }
    if (compressed.bytes.length > familyCoverMaxBytes) {
      throw CoverPhotoException('Couldn’t save the family photo. Try again.');
    }
    final id = server.UuidValue.fromString(familyId);
    return withServerErrors(() async {
      final ticket = await _client.family.startCoverUpload(
        id,
        'image/jpeg',
        compressed.bytes.length,
      );
      final uploaded = await server.FileUploader(ticket.uploadDescription)
          .uploadByteData(ByteData.sublistView(compressed.bytes));
      if (!uploaded) throw const StorageFailedException();
      return _client.family.finishCoverUpload(id, ticket.key);
    });
  }

  /// Clears the cover; the server deletes its object. [path] is not used.
  @override
  Future<void> clear({required String familyId, required String? path}) {
    return withServerErrors(
      () => _client.family.clearCover(server.UuidValue.fromString(familyId)),
    );
  }
}
