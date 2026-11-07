import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../generated/protocol.dart';
import '../media/blob_keys.dart';

/// Authorized blob reads (endpoint-contract.md §2.0): every key is resolved
/// to the row that holds it and access is checked on that row. Nobody parses
/// keys. Unknown, unreadable and missing blobs all look the same: null from
/// [get], absent from [getMany].
class MediaEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<ByteData?> get(Session session, String key) async {
    final visible = await _MediaAccess(session).visible({key});
    return visible.isEmpty ? null : _retrieve(session, key);
  }

  Future<Map<String, ByteData>> getMany(
    Session session,
    List<String> keys,
  ) async {
    final visible = await _MediaAccess(session).visible(keys.toSet());
    final result = <String, ByteData>{};
    for (final key in visible) {
      final data = await _retrieve(session, key);
      if (data != null) result[key] = data;
    }
    return result;
  }

  Future<ByteData?> _retrieve(Session session, String key) async {
    try {
      return await session.storage.retrieveFile(
        storageId: blobStorageId,
        path: key,
      );
    } on CloudStorageFileNotFoundException {
      return null;
    }
  }
}

/// Which requested keys the caller may read, decided per holding row.
class _MediaAccess {
  _MediaAccess(this.session) : authz = Authz(session);

  final Session session;
  final Authz authz;

  Future<Set<String>> visible(Set<String> keys) async {
    if (keys.isEmpty || authz.userId == null) return {};
    return {...await _photoKeys(keys)};
  }

  /// Photo originals and edits: `canReadStory` of the photo's story.
  Future<List<String>> _photoKeys(Set<String> keys) async {
    final photos = await Photo.db.find(
      session,
      where: (t) => t.originalKey.inSet(keys) | t.editedKey.inSet(keys),
    );
    final readable = <UuidValue, bool>{};
    return [
      for (final photo in photos)
        if (readable[photo.storyId] ??= await _canReadStory(photo.storyId))
          for (final key in [photo.originalKey, photo.editedKey])
            if (key != null && keys.contains(key)) key,
    ];
  }

  Future<bool> _canReadStory(UuidValue storyId) async {
    final story = await Story.db.findById(session, storyId);
    return story != null && await authz.canReadStory(story);
  }
}
