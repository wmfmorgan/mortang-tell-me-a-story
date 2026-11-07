import 'dart:async';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/live/live_events.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';

import 'fixtures.dart';

/// Bytes whose magic numbers `sniffImageMime` recognizes.
ByteData jpegBytes() => _bytes(const [0xFF, 0xD8, 0xFF, 0xE0, 0, 16, 1, 2]);
ByteData pngBytes() =>
    _bytes(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]);
ByteData textBytes() => _bytes('not an image'.codeUnits);

ByteData _bytes(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

List<int> bytesOf(ByteData data) => Uint8List.sublistView(data).toList();

/// Slice 3d builders on top of [Fx].
extension PhotoFx on Fx {
  /// Stores [data] (default: JPEG bytes) at [key] as a verified blob.
  Future<void> blob(String key, [ByteData? data]) => s.storage.storeFile(
    storageId: blobStorageId,
    path: key,
    byteData: data ?? jpegBytes(),
  );

  /// Leaves [data] at [key] the way the client's `FileUploader` does: present
  /// but unverified until `finishUpload` calls `verifyUpload`.
  Future<void> clientUpload(String key, ByteData data) =>
      DatabaseCloudStorage(blobStorageId).storeUnverifiedFile(
        session: s,
        path: key,
        byteData: data,
      );

  Future<bool> blobExists(String key) =>
      s.storage.fileExists(storageId: blobStorageId, path: key);

  /// A JPEG photo row on [story] with its blob stored; [edited] adds a stored
  /// edited version 1.
  Future<Photo> photo(
    Story story, {
    UuidValue? uploaderId,
    int sortOrder = 0,
    bool edited = false,
  }) async {
    final id = const Uuid().v7obj();
    final original = photoOriginalKey(
      familyId: story.familyId,
      storyId: story.id!,
      photoId: id,
      mimeType: 'image/jpeg',
    );
    await blob(original);
    String? editedKey;
    if (edited) {
      editedKey = photoEditedKey(
        familyId: story.familyId,
        storyId: story.id!,
        photoId: id,
        editVersion: 1,
      );
      await blob(editedKey, pngBytes());
    }
    return Photo.db.insertRow(
      s,
      Photo(
        id: id,
        storyId: story.id!,
        uploaderId: uploaderId,
        originalKey: original,
        editedKey: editedKey,
        editVersion: edited ? 1 : 0,
        sortOrder: sortOrder,
      ),
    );
  }

  /// A live branch of [parent] in the same tree whose origin is [origin].
  Future<Family> branch(Family parent, Story origin) async {
    final child = await family(
      Tree(id: parent.treeId),
      parentId: parent.id,
      name: 'Branch',
    );
    return Family.db.updateRow(s, child.copyWith(originStoryId: origin.id));
  }

  /// Gives [target] a stored cover blob and returns its key.
  Future<String> cover(Family target) async {
    final key = familyCoverKey(familyId: target.id!, mimeType: 'image/jpeg');
    await blob(key);
    await Family.db.updateRow(s, target.copyWith(coverKey: key));
    return key;
  }

  /// Gives [person] a stored avatar blob and returns its key.
  Future<String> personAvatar(Person person) async {
    final key = personAvatarKey(treeId: person.treeId, personId: person.id!);
    await blob(key);
    await Person.db.updateRow(s, person.copyWith(avatarKey: key));
    return key;
  }

  /// Gives [user]'s app profile a stored avatar blob and returns its key.
  Future<String> userAvatar(UuidValue user) async {
    final key = userAvatarKey(authUserId: user);
    await blob(key);
    final appUser = await AppUser.db.findFirstRow(
      s,
      where: (t) => t.authUserId.equals(user),
    );
    await AppUser.db.updateRow(s, appUser!.copyWith(avatarKey: key));
    return key;
  }

  Future<void> softDelete(Family target) => Family.db.updateRow(
    s,
    target.copyWith(deletedAt: DateTime.now().toUtc()),
  );

  /// The keys among [keys] that are queued in `blob_deletions`.
  Future<Set<String>> queued(Iterable<String?> keys) async {
    final wanted = {for (final key in keys) ?key};
    final rows = await BlobDeletion.db.find(
      s,
      where: (t) => t.key.inSet(wanted),
    );
    return {for (final row in rows) row.key};
  }

  /// The live events posted on [family]'s channel while [action] runs.
  Future<List<LiveEventDto>> eventsDuring(
    Family family,
    Future<void> Function() action,
  ) async {
    final events = <LiveEventDto>[];
    final sub = s.messages
        .createStream<LiveEventDto>(familyChannel(family.id!))
        .listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await action();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    return events;
  }
}
