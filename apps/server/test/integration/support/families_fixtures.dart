import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:tell_me_a_story_server/src/media/blob_keys.dart';

import 'fixtures.dart';

/// Smallest byte strings [sniffImageMime] recognizes.
final jpegBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0];
final pngBytes = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0];
final svgBytes = '<svg xmlns="http://www.w3.org/2000/svg"/>'.codeUnits;

ByteData byteData(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

/// A unique email, so tests never collide on the email-account index.
String uniqueEmail([String local = 'user']) =>
    '$local-${const Uuid().v4()}@example.com';

/// Builders for slice 3a (families, places, profile).
extension FamiliesFx on Fx {
  /// What a client upload through a `createUploadDescription` URL leaves in
  /// the dev database storage: an unverified file at [key].
  Future<void> upload(String key, List<int> bytes) =>
      (s.server.serverpod.storage[blobStorageId]! as DatabaseCloudStorage)
          .storeUnverifiedFile(
            session: s,
            path: key,
            byteData: byteData(bytes),
          );

  Future<Set<String>> queuedBlobKeys() async => {
    for (final row in await BlobDeletion.db.find(s)) row.key,
  };

  Future<Family> reload(Family family) async =>
      (await Family.db.findById(s, family.id!))!;

  Future<MembershipRole?> roleOf(Family family, UuidValue user) async =>
      (await Membership.db.findFirstRow(
        s,
        where: (t) => t.familyId.equals(family.id!) & t.userId.equals(user),
      ))?.role;

  Future<List<Person>> linkedPeople(UuidValue treeId, UuidValue user) =>
      Person.db.find(
        s,
        where: (t) => t.treeId.equals(treeId) & t.userId.equals(user),
      );

  /// A root family in a new tree with [owner] as owner.
  Future<Family> rootOwnedBy(UuidValue owner, {String name = 'Root'}) async {
    final family = await this.family(await tree(), name: name);
    await join(family, owner, MembershipRole.owner);
    return family;
  }

  /// A live child of [parent] in the same tree, owned by [owner].
  Future<Family> childOf(
    Family parent, {
    UuidValue? owner,
    String name = 'Child',
    int branchYear = 1990,
    DateTime? deletedAt,
  }) async {
    final child = await Family.db.insertRow(
      s,
      Family(
        treeId: parent.treeId,
        parentId: parent.id,
        name: name,
        branchYear: branchYear,
        deletedAt: deletedAt,
      ),
    );
    if (owner != null) await join(child, owner, MembershipRole.owner);
    return child;
  }

  Future<Family> setOriginRow(Family family, Story? story) =>
      Family.db.updateRow(
        s,
        family.copyWith(originStoryId: story?.id),
        columns: (c) => [c.originStoryId],
      );

  Future<Family> setDeletedAt(Family family, DateTime? deletedAt) =>
      Family.db.updateRow(
        s,
        family.copyWith(deletedAt: deletedAt),
        columns: (c) => [c.deletedAt],
      );

  Future<Story> setStatus(Story story, StoryStatus status) =>
      Story.db.updateRow(
        s,
        story.copyWith(
          status: status,
          publishedAt: status == StoryStatus.published
              ? DateTime.now().toUtc()
              : null,
        ),
        columns: (c) => [c.status, c.publishedAt],
      );
}
