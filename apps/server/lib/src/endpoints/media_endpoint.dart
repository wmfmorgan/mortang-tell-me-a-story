import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../authz/authz.dart';
import '../errors.dart';
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

  /// At most [mediaManyMaxKeys] keys per call, else VALIDATION.
  Future<Map<String, ByteData>> getMany(
    Session session,
    List<String> keys,
  ) async {
    if (keys.length > mediaManyMaxKeys) throw validation('too many keys');
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
    return {
      ...await _photoKeys(keys),
      ...await _coverKeys(keys),
      ...await _personAvatarKeys(keys),
      ...await _userAvatarKeys(keys),
    };
  }

  /// Family covers: live member of that family (D6b: not while deleted).
  Future<List<String>> _coverKeys(Set<String> keys) async {
    final families = await Family.db.find(
      session,
      where: (t) => t.coverKey.inSet(keys),
    );
    return [
      for (final family in families)
        if (await authz.isLiveMember(family.id!)) family.coverKey!,
    ];
  }

  /// Person avatars: member of a live family in the person's tree (D8).
  Future<List<String>> _personAvatarKeys(Set<String> keys) async {
    final people = await Person.db.find(
      session,
      where: (t) => t.avatarKey.inSet(keys),
    );
    final readable = <UuidValue, bool>{};
    return [
      for (final person in people)
        if (readable[person.treeId] ??= await authz.isTreeMemberOf(
          person.treeId,
        ))
          person.avatarKey!,
    ];
  }

  /// User avatars: the user themself, or a co-member of a live family.
  Future<List<String>> _userAvatarKeys(Set<String> keys) async {
    final users = await AppUser.db.find(
      session,
      where: (t) => t.avatarKey.inSet(keys),
    );
    return [
      for (final user in users)
        if (user.authUserId == authz.userId ||
            await _sharesLiveFamily(user.authUserId))
          user.avatarKey!,
    ];
  }

  Set<UuidValue>? _myLiveFamilies;

  Future<bool> _sharesLiveFamily(UuidValue other) async {
    final mine = _myLiveFamilies ??= await _liveFamiliesOf(authz.userId!);
    if (mine.isEmpty) return false;
    final shared = await Membership.db.count(
      session,
      where: (t) => t.userId.equals(other) & t.familyId.inSet(mine),
    );
    return shared > 0;
  }

  Future<Set<UuidValue>> _liveFamiliesOf(UuidValue user) async {
    final memberships = await Membership.db.find(
      session,
      where: (t) => t.userId.equals(user),
    );
    if (memberships.isEmpty) return {};
    final live = await Family.db.find(
      session,
      where: (t) =>
          t.id.inSet(<UuidValue>{for (final m in memberships) m.familyId}) &
          t.deletedAt.equals(null),
    );
    return {for (final family in live) family.id!};
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
