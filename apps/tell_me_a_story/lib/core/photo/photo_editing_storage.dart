import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/photos_api.dart';

/// Why a save or reset stopped. The page maps these to locked copy.
enum PhotoEditFailureKind { conflict, forbidden, validation, transport }

class PhotoEditException implements Exception {
  const PhotoEditException(this.kind, this.message);

  final PhotoEditFailureKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Row the save and reset RPCs return. [previousPath] is the old edited object.
class PhotoEditResult {
  const PhotoEditResult({
    required this.editVersion,
    required this.previousPath,
  });

  final int editVersion;
  final String? previousPath;
}

/// Storage and RPC port. Tests inject a fake. There is no global singleton.
abstract class PhotoEditingGateway {
  Future<void> uploadJpeg({
    required String path,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  });

  Future<PhotoEditResult> savePhotoEdit({
    required String photoId,
    required int expectedVersion,
    required String editedPath,
  });

  Future<PhotoEditResult> resetPhotoEdit({
    required String photoId,
    required int expectedVersion,
  });

  Future<void> remove(List<String> paths);

  Future<Photo> readPhoto(String photoId);

  Future<Uint8List> download(String path);
}

/// Maps a PostgREST failure onto the four editor outcomes.
PhotoEditException mapPhotoEditError(Object error) {
  final text = error is PostgrestException ? error.message : error.toString();
  if (text.contains('CONFLICT:')) {
    return const PhotoEditException(
      PhotoEditFailureKind.conflict,
      'CONFLICT: photo edit version',
    );
  }
  if (text.contains('FORBIDDEN:')) {
    return const PhotoEditException(
      PhotoEditFailureKind.forbidden,
      'FORBIDDEN: photo edit denied',
    );
  }
  if (text.contains('VALIDATION:')) {
    return const PhotoEditException(
      PhotoEditFailureKind.validation,
      'VALIDATION: invalid edited path',
    );
  }
  return PhotoEditException(PhotoEditFailureKind.transport, text);
}

/// Exact object name the save RPC accepts for [nextVersion].
String editedPhotoPath(Photo photo, int nextVersion) {
  final family = photo.familyId.toLowerCase();
  final story = photo.storyId.toLowerCase();
  final id = photo.id.toLowerCase();
  return '$family/$story/$id.edited.$nextVersion.jpg';
}

/// Upload, compare-and-swap, and best-effort cleanup of unreferenced objects.
class PhotoEditingApi {
  PhotoEditingApi(this._gateway);

  final PhotoEditingGateway _gateway;
  final List<String> _pendingDeletes = [];

  List<String> get pendingDeletes => List.unmodifiable(_pendingDeletes);

  Future<String> uploadCandidate(
    Photo photo,
    Uint8List bytes,
    int nextVersion, {
    void Function(double progress)? onProgress,
  }) async {
    final path = editedPhotoPath(photo, nextVersion);
    onProgress?.call(0);
    try {
      await _gateway.uploadJpeg(
        path: path,
        bytes: bytes,
        onProgress: onProgress,
      );
    } catch (error) {
      throw mapPhotoEditError(error);
    }
    onProgress?.call(1);
    return path;
  }

  Future<PhotoEditResult> savePhotoEdit(
    String photoId,
    int expectedVersion,
    String editedPath,
  ) async {
    await _retryDeletes(protected: {editedPath});
    try {
      final result = await _gateway.savePhotoEdit(
        photoId: photoId,
        expectedVersion: expectedVersion,
        editedPath: editedPath,
      );
      final previous = result.previousPath;
      if (previous != null && previous != editedPath) {
        await _deleteBestEffort(previous);
      }
      return result;
    } catch (error) {
      await _deleteBestEffort(editedPath);
      if (error is PhotoEditException) throw error;
      throw mapPhotoEditError(error);
    }
  }

  Future<PhotoEditResult> resetPhotoEdit(
    String photoId,
    int expectedVersion,
  ) async {
    await _retryDeletes();
    try {
      final result = await _gateway.resetPhotoEdit(
        photoId: photoId,
        expectedVersion: expectedVersion,
      );
      final previous = result.previousPath;
      if (previous != null) await _deleteBestEffort(previous);
      return result;
    } catch (error) {
      if (error is PhotoEditException) throw error;
      throw mapPhotoEditError(error);
    }
  }

  Future<Photo> readPhoto(String photoId) => _gateway.readPhoto(photoId);

  Future<Uint8List> download(String path) => _gateway.download(path);

  /// Next save or reset retries these. [protected] paths stay on the row.
  Future<void> retryCleanup({Set<String> protected = const {}}) {
    return _retryDeletes(protected: protected);
  }

  Future<void> _deleteBestEffort(String path) async {
    if (_pendingDeletes.contains(path)) return;
    try {
      await _gateway.remove([path]);
    } catch (_) {
      _pendingDeletes.add(path);
    }
  }

  Future<void> _retryDeletes({Set<String> protected = const {}}) async {
    final pending = List<String>.of(_pendingDeletes);
    for (final path in pending) {
      if (protected.contains(path)) continue;
      try {
        await _gateway.remove([path]);
        _pendingDeletes.remove(path);
      } catch (_) {
        // The next save or reset tries again.
      }
    }
  }
}

class SupabasePhotoEditingGateway implements PhotoEditingGateway {
  SupabasePhotoEditingGateway(this._client);

  final SupabaseClient _client;

  static const _select =
      'id, story_id, family_id, uploader_id, storage_path, edited_storage_path, edit_version, sort_order';

  @override
  Future<void> uploadJpeg({
    required String path,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    await _client.storage
        .from(storyPhotosBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    onProgress?.call(1);
  }

  @override
  Future<PhotoEditResult> savePhotoEdit({
    required String photoId,
    required int expectedVersion,
    required String editedPath,
  }) {
    return _rpc('save_photo_edit', {
      'p_photo_id': photoId,
      'p_expected_version': expectedVersion,
      'p_edited_path': editedPath,
    });
  }

  @override
  Future<PhotoEditResult> resetPhotoEdit({
    required String photoId,
    required int expectedVersion,
  }) {
    return _rpc('reset_photo_edit', {
      'p_photo_id': photoId,
      'p_expected_version': expectedVersion,
    });
  }

  @override
  Future<void> remove(List<String> paths) {
    return _client.storage.from(storyPhotosBucket).remove(paths);
  }

  @override
  Future<Photo> readPhoto(String photoId) async {
    final row = await _client
        .from('photos')
        .select(_select)
        .eq('id', photoId)
        .single();
    return Photo.fromJson(row);
  }

  @override
  Future<Uint8List> download(String path) {
    return _client.storage.from(storyPhotosBucket).download(path);
  }

  Future<PhotoEditResult> _rpc(String name, Map<String, dynamic> params) async {
    try {
      final data = await _client.rpc(name, params: params);
      return _result(data);
    } on PostgrestException catch (error) {
      throw mapPhotoEditError(error);
    }
  }

  PhotoEditResult _result(dynamic data) {
    final row = data is List ? (data.isEmpty ? null : data.first) : data;
    if (row is! Map) {
      throw const PhotoEditException(
        PhotoEditFailureKind.conflict,
        'CONFLICT: photo edit version',
      );
    }
    final version = row['edit_version'];
    return PhotoEditResult(
      editVersion: version is int ? version : int.parse('$version'),
      previousPath: row['previous_path'] as String?,
    );
  }
}
