import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const maxPhotosPerStory = 20;
const storyPhotosBucket = 'story-photos';

const _photoSelect =
    'id, story_id, family_id, uploader_id, storage_path, sort_order';

/// Family-scoped story photo row (private `story-photos` object + `photos` table).
class Photo {
  const Photo({
    required this.id,
    required this.storyId,
    required this.familyId,
    required this.uploaderId,
    required this.storagePath,
    required this.sortOrder,
  });

  final String id;
  final String storyId;
  final String familyId;
  final String uploaderId;
  final String storagePath;
  final int sortOrder;

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'] as String,
      storyId: json['story_id'] as String,
      familyId: json['family_id'] as String,
      uploaderId: json['uploader_id'] as String,
      storagePath: json['storage_path'] as String,
      sortOrder: json['sort_order'] as int,
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

String storyPhotoStoragePath({
  required String familyId,
  required String storyId,
  required String photoId,
  required String ext,
}) {
  final e = ext.toLowerCase();
  if (e != 'jpg' && e != 'jpeg' && e != 'png' && e != 'webp') {
    throw ArgumentError.value(ext, 'ext');
  }
  return '$familyId/$storyId/$photoId.$e';
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
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  });
}

typedef PhotoUploadBinary = Future<void> Function({
  required String path,
  required Uint8List bytes,
  required String contentType,
});

/// Storage + PostgREST gateway for story photos (compress, cap, private bucket).
class PhotosApi implements PhotosGateway {
  PhotosApi({
    SupabaseClient? client,
    Future<int> Function()? maxCountLoader,
    String Function()? photoIdFactory,
    String? uploaderId,
    PhotoUploadBinary? uploadBinary,
    Future<void> Function(List<String> paths)? removeObjects,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> row)?
    insertPhoto,
  }) : _client = client ?? Supabase.instance.client,
       _maxCountLoader = maxCountLoader,
       _photoIdFactory = photoIdFactory,
       _uploaderId = uploaderId,
       _uploadBinary = uploadBinary,
       _removeObjects = removeObjects,
       _insertPhoto = insertPhoto;

  final SupabaseClient _client;
  final Future<int> Function()? _maxCountLoader;
  final String Function()? _photoIdFactory;
  final String? _uploaderId;
  final PhotoUploadBinary? _uploadBinary;
  final Future<void> Function(List<String> paths)? _removeObjects;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> row)?
  _insertPhoto;

  @override
  Future<List<Photo>> listPhotos(String storyId) async {
    final rows = await _client
        .from('photos')
        .select(_photoSelect)
        .eq('story_id', storyId)
        .order('sort_order');
    return rows.map(Photo.fromJson).toList();
  }

  @override
  Future<Photo> uploadPhoto({
    required String familyId,
    required String storyId,
    required Uint8List bytes,
    required int sortOrder,
  }) async {
    ensurePhotoCap(await _countPhotos(storyId));
    final photoId = _photoIdFactory?.call() ?? const Uuid().v4();
    final compressed = compressStoryPhoto(bytes);
    final path = storyPhotoStoragePath(
      familyId: familyId,
      storyId: storyId,
      photoId: photoId,
      ext: compressed.extension,
    );
    try {
      await _upload(path, compressed);
    } catch (e) {
      throw StorageFailedException(code: 'STORAGE_FAILED', cause: e);
    }
    final payload = <String, dynamic>{
      'id': photoId,
      'story_id': storyId,
      'family_id': familyId,
      'uploader_id': _uid(),
      'storage_path': path,
      'sort_order': sortOrder,
    };
    try {
      final row = await _insert(payload);
      return Photo.fromJson(row);
    } catch (e) {
      await _remove([path]);
      rethrow;
    }
  }

  @override
  Future<void> deletePhoto(Photo photo) async {
    await _remove([photo.storagePath]);
    await _client.from('photos').delete().eq('id', photo.id);
  }

  @override
  Future<void> deleteAllForStory({
    required String familyId,
    required String storyId,
  }) async {
    final prefix = '$familyId/$storyId';
    // storage_client list() takes a named [path], not a positional folder.
    final objects = await _client.storage
        .from(storyPhotosBucket)
        .list(path: prefix);
    if (objects.isEmpty) return;
    await _remove([for (final object in objects) '$prefix/${object.name}']);
  }

  Future<int> _countPhotos(String storyId) async {
    if (_maxCountLoader != null) return _maxCountLoader();
    final rows = await _client
        .from('photos')
        .select('id')
        .eq('story_id', storyId);
    return rows.length;
  }

  String _uid() => _uploaderId ?? _client.auth.currentUser!.id;

  Future<void> _upload(String path, CompressedPhoto compressed) async {
    if (_uploadBinary != null) {
      await _uploadBinary(
        path: path,
        bytes: compressed.bytes,
        contentType: compressed.mimeType,
      );
      return;
    }
    await _client.storage
        .from(storyPhotosBucket)
        .uploadBinary(
          path,
          compressed.bytes,
          fileOptions: FileOptions(
            contentType: compressed.mimeType,
            upsert: false,
          ),
        );
  }

  Future<Map<String, dynamic>> _insert(Map<String, dynamic> payload) {
    if (_insertPhoto != null) return _insertPhoto(payload);
    return _client.from('photos').insert(payload).select(_photoSelect).single();
  }

  Future<void> _remove(List<String> paths) async {
    if (_removeObjects != null) {
      await _removeObjects(paths);
      return;
    }
    await _client.storage.from(storyPhotosBucket).remove(paths);
  }
}
