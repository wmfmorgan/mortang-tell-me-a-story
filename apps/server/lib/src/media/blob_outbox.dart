import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'blob_keys.dart';

/// Queues [keys] (nulls skipped) for deletion. Call it in the SAME
/// transaction that drops or replaces the rows referencing them, so a failed
/// write queues nothing and a committed one can't leak a blob
/// (schema-design.md §4.3).
Future<void> queueBlobDeletions(
  Session session,
  Iterable<String?> keys, {
  Transaction? transaction,
}) async {
  final rows = [
    for (final key in keys)
      if (key != null) BlobDeletion(key: key),
  ];
  if (rows.isEmpty) return;
  await BlobDeletion.db.insert(session, rows, transaction: transaction);
}

/// Deletes one blob from storage. Tests pass a failing one.
typedef BlobDeleter = Future<void> Function(String key);

/// Deletes up to [batchSize] queued blobs, fewest attempts first. A blob that
/// fails to delete is logged and keeps its row with `attempts + 1`, so the
/// next run retries it. Returns how many were deleted.
Future<int> drainBlobDeletions(
  Session session, {
  int batchSize = 100,
  BlobDeleter? delete,
}) async {
  final deleteBlob =
      delete ??
      (key) => session.storage.deleteFile(storageId: blobStorageId, path: key);
  final rows = await BlobDeletion.db.find(
    session,
    orderByList: (t) => [t.attempts.asc(), t.createdAt.asc()],
    limit: batchSize,
  );
  var deleted = 0;
  for (final row in rows) {
    try {
      await deleteBlob(row.key);
    } catch (e, stackTrace) {
      session.log(
        'blob delete failed: ${row.key}',
        level: LogLevel.warning,
        exception: e,
        stackTrace: stackTrace,
      );
      await BlobDeletion.db.updateRow(
        session,
        row.copyWith(attempts: row.attempts + 1),
      );
      continue;
    }
    await BlobDeletion.db.deleteRow(session, row);
    deleted++;
  }
  return deleted;
}
