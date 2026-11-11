import 'dart:typed_data';

import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/cover_photo_exception.dart';
import 'package:tell_me_a_story/core/domain/family_covers_repository.dart';
import 'package:tell_me_a_story/core/data/photos_repository.dart';
import 'package:tell_me_a_story/core/data/server/server_errors.dart';

const familyCoverMaxBytes = 5242880;

const _coverFailed = 'Couldn’t save the family photo. Try again.';

/// Runs a cover call through [withServerErrors] and shows any server
/// refusal as the cover copy, never raw server text.
/// [StorageFailedException] passes through.
Future<T> withCoverErrors<T>(Future<T> Function() call) async {
  try {
    return await withServerErrors(call);
  } on AppException catch (_, stackTrace) {
    Error.throwWithStackTrace(CoverPhotoException(_coverFailed), stackTrace);
  }
}

class ServerFamilyCoversRepository implements FamilyCoversRepository {
  ServerFamilyCoversRepository({server.Client? client}) : _injected = client;

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
      throw CoverPhotoException(_coverFailed);
    }
    final CompressedPhoto compressed;
    try {
      compressed = compressStoryPhoto(bytes, maxEdge: 1920, quality: 80);
    } on ArgumentError {
      throw CoverPhotoException(_coverFailed);
    }
    if (compressed.bytes.length > familyCoverMaxBytes) {
      throw CoverPhotoException(_coverFailed);
    }
    final id = server.UuidValue.fromString(familyId);
    return withCoverErrors(() async {
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
    return withCoverErrors(
      () => _client.family.clearCover(server.UuidValue.fromString(familyId)),
    );
  }
}
