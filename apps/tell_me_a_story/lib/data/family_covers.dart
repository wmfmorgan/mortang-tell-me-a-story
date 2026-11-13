import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'photos_api.dart';

const familyCoversBucket = 'family-covers';

const familyCoverMaxBytes = 5242880;

const familyCoverExtensions = ['jpg', 'jpeg', 'png', 'webp'];

final _familyIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Object key `{familyId}/cover.{ext}` in [familyCoversBucket].
String familyCoverObjectPath(String familyId, String extension) {
  final id = familyId.trim().toLowerCase();
  final ext = extension.trim().toLowerCase();
  if (!_familyIdPattern.hasMatch(id) || !familyCoverExtensions.contains(ext)) {
    throw CoverPhotoException('Couldn’t save the family photo. Try again.');
  }
  return '$id/cover.$ext';
}

class CoverPhotoException implements Exception {
  CoverPhotoException(this.message);

  final String message;
}

/// Upload, download, and delete for `family-covers`.
abstract class FamilyCoverClient {
  Future<Uint8List?> download(String? path);

  Future<String> save({required String familyId, required Uint8List bytes});

  Future<void> clear({required String familyId, required String? path});
}

class FamilyCoversApi implements FamilyCoverClient {
  FamilyCoversApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Uint8List?> download(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage.from(familyCoversBucket).download(path);
    } on StorageException {
      return null;
    }
  }

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
    final path = familyCoverObjectPath(familyId, compressed.extension);
    await _client.storage
        .from(familyCoversBucket)
        .uploadBinary(
          path,
          compressed.bytes,
          fileOptions: FileOptions(
            contentType: compressed.mimeType,
            upsert: true,
          ),
        );
    return path;
  }

  @override
  Future<void> clear({required String familyId, required String? path}) async {
    final prefix = familyId.trim().toLowerCase();
    if (!_familyIdPattern.hasMatch(prefix)) {
      throw CoverPhotoException('Couldn’t save the family photo. Try again.');
    }
    final listed = await _client.storage
        .from(familyCoversBucket)
        .list(path: prefix);
    final names = <String>[
      for (final object in listed)
        if (object.name.isNotEmpty) '$prefix/${object.name}',
    ];
    if (path != null && path.isNotEmpty && !names.contains(path)) {
      names.add(path);
    }
    if (names.isNotEmpty) {
      await _client.storage.from(familyCoversBucket).remove(names);
    }
  }
}
