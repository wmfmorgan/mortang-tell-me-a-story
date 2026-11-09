import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../media/blob_outbox.dart';

/// How long a soft-deleted family stays recoverable.
const purgeAfter = Duration(days: 60);

/// Runs inside a purge transaction after the keys are queued and before any
/// row is deleted. Tests throw from it to prove the purge fails closed.
typedef PurgeFault = Future<void> Function(Family family);

/// Hard-deletes every family soft-deleted before `now - 60 days`, one
/// transaction per family (schema-design.md §4.3, D6c). Returns how many
/// families were purged. A family whose transaction fails is logged and
/// stays; nothing is queued for it, and the next run retries it.
Future<int> purgeExpiredFamilies(
  Session session, {
  DateTime? now,
  PurgeFault? beforeDelete,
}) async {
  final cutoff = (now ?? DateTime.now()).toUtc().subtract(purgeAfter);
  final doomed = await Family.db.find(
    session,
    where: (t) => t.deletedAt < cutoff,
    orderByList: (t) => [t.deletedAt.asc(), t.id.asc()],
  );
  var purged = 0;
  for (final candidate in doomed) {
    try {
      final done = await session.db.transaction(
        (t) => _purgeOne(session, candidate.id!, cutoff, t, beforeDelete),
      );
      if (done) purged++;
    } catch (e, stackTrace) {
      session.log(
        'family purge failed: ${candidate.id}',
        level: LogLevel.error,
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
  return purged;
}

Future<bool> _purgeOne(
  Session session,
  UuidValue familyId,
  DateTime cutoff,
  Transaction t,
  PurgeFault? beforeDelete,
) async {
  // Re-read under lock: a recover or an earlier purge may have won.
  final family = await Family.db.findById(
    session,
    familyId,
    transaction: t,
    lockMode: LockMode.forUpdate,
  );
  final deletedAt = family?.deletedAt;
  if (family == null || deletedAt == null || !deletedAt.isBefore(cutoff)) {
    return false;
  }

  final stories = await Story.db.find(
    session,
    where: (s) => s.familyId.equals(familyId),
    transaction: t,
  );
  final photos = stories.isEmpty
      ? const <Photo>[]
      : await Photo.db.find(
          session,
          where: (p) => p.storyId.inSet(stories.map((s) => s.id!).toSet()),
          transaction: t,
        );
  final keys = <String?>[
    family.coverKey,
    for (final photo in photos) ...[photo.originalKey, photo.editedKey],
  ];

  final others = await Family.db.find(
    session,
    where: (f) => f.treeId.equals(family.treeId) & f.id.notEquals(familyId),
    transaction: t,
  );

  if (others.isEmpty) {
    // Last family in its tree: the tree and its people go too.
    final people = await Person.db.find(
      session,
      where: (p) => p.treeId.equals(family.treeId),
      transaction: t,
    );
    keys.addAll(people.map((p) => p.avatarKey));
    await queueBlobDeletions(session, keys, transaction: t);
    await beforeDelete?.call(family);
    await Person.db.deleteWhere(
      session,
      where: (p) => p.treeId.equals(family.treeId),
      transaction: t,
    );
    await Family.db.deleteRow(session, family, transaction: t);
    await Tree.db.deleteWhere(
      session,
      where: (tr) => tr.id.equals(family.treeId),
      transaction: t,
    );
    return true;
  }

  // Successor: live before deleted, then oldest, then lowest id.
  others.sort((a, b) {
    final byDeleted = (a.deletedAt == null ? 0 : 1).compareTo(
      b.deletedAt == null ? 0 : 1,
    );
    if (byDeleted != 0) return byDeleted;
    final byCreated = a.createdAt.compareTo(b.createdAt);
    if (byCreated != 0) return byCreated;
    return a.id!.uuid.compareTo(b.id!.uuid);
  });
  final successor = others.first;
  await Person.db.updateWhere(
    session,
    columnValues: (p) => [p.homeFamilyId(successor.id!)],
    where: (p) => p.homeFamilyId.equals(familyId),
    transaction: t,
  );
  await queueBlobDeletions(session, keys, transaction: t);
  await beforeDelete?.call(family);
  await Family.db.deleteRow(session, family, transaction: t);
  return true;
}
